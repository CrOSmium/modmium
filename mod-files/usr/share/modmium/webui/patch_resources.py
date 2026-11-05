#!/usr/bin/env python3
# replace borealis MOTD with modmium WebUI

from __future__ import annotations

import argparse
import errno
import gzip
import hashlib
import os
from pathlib import Path
import struct
import tempfile


HTML_MARKERS = (b'id="motd"', b"$i18n{motdUrl}", b'id="uninstall-btn"')
SCRIPT_MARKERS = (
    b"ShoppingServiceBrowserProxyImpl",
    b"createShoppingServiceHandler",
    b"ShoppingServiceHandlerFactory",
)
BACKUP_MAGIC = b"MODMGUI1"


class DataPack:
    def __init__(self, raw: bytes):
        self.raw = raw
        if len(raw) < 12:
            raise ValueError("truncated DataPack header")
        self.version, self.encoding, self.resource_count, self.alias_count = (
            struct.unpack_from("<IB3xHH", raw)
        )
        if self.version != 5:
            raise ValueError(f"unsupported DataPack version {self.version}")

        index_end = 12 + (self.resource_count + 1) * 6
        alias_end = index_end + self.alias_count * 4
        self.entries = [
            struct.unpack_from("<HI", raw, 12 + index * 6)
            for index in range(self.resource_count + 1)
        ]
        offsets = [offset for _, offset in self.entries]
        if alias_end > len(raw) or offsets != sorted(offsets) or offsets[-1] > len(raw):
            raise ValueError("invalid DataPack metadata")
        self.aliases = raw[index_end:alias_end]
        self.padding = raw[alias_end:offsets[0]]
        self.blobs = [raw[start:end] for start, end in zip(offsets, offsets[1:])]

    @staticmethod
    def decode(blob: bytes) -> bytes:
        return gzip.decompress(blob) if blob.startswith(b"\x1f\x8b") else blob

    def find(self, markers: tuple[bytes, ...], label: str) -> int:
        matches = []
        for index, blob in enumerate(self.blobs):
            try:
                content = self.decode(blob)
            except (EOFError, OSError):
                continue
            if all(marker in content for marker in markers):
                matches.append(index)
        if len(matches) != 1:
            ids = [self.entries[index][0] for index in matches]
            raise ValueError(f"expected one {label}; matching resource IDs: {ids}")
        return matches[0]

    def replace(self, index: int, content: bytes) -> None:
        if self.blobs[index].startswith(b"\x1f\x8b"):
            content = gzip.compress(content, compresslevel=9, mtime=0)
        self.blobs[index] = content

    def index(self, resource_id: int) -> int:
        matches = [
            index
            for index, (entry_id, _) in enumerate(self.entries[:-1])
            if entry_id == resource_id
        ]
        if len(matches) != 1:
            raise ValueError(f"expected one resource ID {resource_id}")
        return matches[0]

    def build(self) -> bytes:
        metadata_length = 12 + (self.resource_count + 1) * 6
        offsets = [metadata_length + len(self.aliases) + len(self.padding)]
        for blob in self.blobs:
            offsets.append(offsets[-1] + len(blob))

        output = bytearray(
            struct.pack(
                "<IB3xHH",
                self.version,
                self.encoding,
                self.resource_count,
                self.alias_count,
            )
        )
        for index, offset in enumerate(offsets):
            output += struct.pack("<HI", self.entries[index][0], offset)
        output += self.aliases + self.padding + b"".join(self.blobs)
        return bytes(output)


def atomic_replace(path: Path, content: bytes, old: os.stat_result | None = None) -> None:
    old = old or path.stat()
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(content)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, old.st_mode)
        os.chown(temporary, old.st_uid, old.st_gid)
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        temporary.unlink(missing_ok=True)


def replace_pak(path: Path, content: bytes, recovery: bytes) -> None:
    old = path.stat()
    try:
        atomic_replace(path, content, old)
        return
    except OSError as error:
        if error.errno != errno.ENOSPC:
            raise
    path.unlink()
    try:
        atomic_replace(path, content, old)
    except Exception:
        atomic_replace(path, recovery, old)
        raise


def read_backup(path: Path) -> tuple[bytes, list[tuple[int, bytes]], bool]:
    content = path.read_bytes()
    if content.startswith(b"\x1f\x8b"):
        content = gzip.decompress(content)
    if content.startswith(BACKUP_MAGIC):
        if len(content) < len(BACKUP_MAGIC) + 34:
            raise ValueError("truncated backup")
        offset = len(BACKUP_MAGIC)
        checksum = content[offset : offset + 32]
        offset += 32
        count = struct.unpack_from("<H", content, offset)[0]
        offset += 2
        resources = []
        for _ in range(count):
            if offset + 6 > len(content):
                raise ValueError("truncated backup resource")
            resource_id, length = struct.unpack_from("<HI", content, offset)
            offset += 6
            if offset + length > len(content):
                raise ValueError("truncated backup blob")
            resources.append((resource_id, content[offset : offset + length]))
            offset += length
        if offset != len(content) or count != 2 or len({item[0] for item in resources}) != 2:
            raise ValueError("invalid backup")
        return checksum, resources, False

    pack = DataPack(content)
    indexes = [
        pack.find(HTML_MARKERS, "Borealis MOTD HTML in legacy backup"),
        pack.find(SCRIPT_MARKERS, "Commerce browser proxy script in legacy backup"),
    ]
    resources = [(pack.entries[index][0], pack.blobs[index]) for index in indexes]
    return hashlib.sha256(content).digest(), resources, True


def write_backup(
    path: Path, checksum: bytes, resources: list[tuple[int, bytes]], source: Path
) -> None:
    content = bytearray(BACKUP_MAGIC + checksum + struct.pack("<H", len(resources)))
    for resource_id, blob in resources:
        content += struct.pack("<HI", resource_id, len(blob)) + blob
    compressed = gzip.compress(bytes(content), compresslevel=9, mtime=0)
    atomic_replace(path, compressed, path.stat() if path.exists() else source.stat())


def migrate_backup(path: Path, legacy: Path | None, source: Path) -> None:
    if not legacy or not legacy.is_file():
        return
    checksum, resources, _ = read_backup(legacy)
    if path.is_file() and read_backup(path)[:2] != (checksum, resources):
        raise ValueError("backup files do not match")
    if not path.exists():
        write_backup(path, checksum, resources, source)
    legacy.unlink()


def apply(path: Path, backup: Path, html_path: Path, script_path: Path) -> None:
    current = path.read_bytes()
    pack = DataPack(current)
    try:
        html_index = pack.find(HTML_MARKERS, "Borealis MOTD HTML")
        script_index = pack.find(SCRIPT_MARKERS, "Commerce browser proxy script")
        checksum = hashlib.sha256(current).digest()
        resources = [
            (pack.entries[html_index][0], pack.blobs[html_index]),
            (pack.entries[script_index][0], pack.blobs[script_index]),
        ]
    except ValueError:
        if not backup.is_file():
            raise
        checksum, resources, legacy = read_backup(backup)
        html_index = pack.index(resources[0][0])
        script_index = pack.index(resources[1][0])
        pack.blobs[html_index] = resources[0][1]
        pack.blobs[script_index] = resources[1][1]
        if hashlib.sha256(pack.build()).digest() != checksum:
            raise ValueError("backup does not match the current PAK")
        if legacy:
            write_backup(backup, checksum, resources, path)

    if backup.exists():
        saved_checksum, saved_resources, legacy = read_backup(backup)
        if (saved_checksum, saved_resources) != (checksum, resources):
            raise ValueError(f"existing backup does not match the original PAK: {backup}")
        if legacy:
            write_backup(backup, checksum, resources, path)
    else:
        write_backup(backup, checksum, resources, path)
        if read_backup(backup)[:2] != (checksum, resources):
            raise ValueError("backup verification failed")

    html = html_path.read_bytes()
    script = script_path.read_bytes()
    pack.replace(html_index, html)
    pack.replace(script_index, script)
    rebuilt = pack.build()
    check = DataPack(rebuilt)
    if check.decode(check.blobs[html_index]) != html:
        raise ValueError("rebuilt HTML verification failed")
    if check.decode(check.blobs[script_index]) != script:
        raise ValueError("rebuilt script verification failed")
    replace_pak(path, rebuilt, current)
    print(
        f"patched {path}: HTML resource {pack.entries[html_index][0]}, "
        f"script resource {pack.entries[script_index][0]}"
    )


def restore(path: Path, backup: Path) -> None:
    current = path.read_bytes()
    checksum, resources, _ = read_backup(backup)
    pack = DataPack(current)
    for resource_id, blob in resources:
        pack.blobs[pack.index(resource_id)] = blob
    restored = pack.build()
    if hashlib.sha256(restored).digest() != checksum:
        raise ValueError("restored PAK does not match the original")
    replace_pak(path, restored, current)
    if hashlib.sha256(path.read_bytes()).digest() != checksum:
        raise ValueError("restore verification failed")
    print(f"restored {path} from {backup}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("pak", type=Path)
    parser.add_argument("--backup", type=Path)
    parser.add_argument("--legacy-backup", type=Path)
    parser.add_argument("--restore", action="store_true")
    parser.add_argument("--html", type=Path, default=Path(__file__).with_name("borealis_motd.html"))
    parser.add_argument("--script", type=Path, default=Path(__file__).with_name("shopping_service_browser_proxy.js"))
    args = parser.parse_args()
    pak = args.pak.resolve()
    backup = (args.backup or pak.with_name(f"{pak.name}.modmium-backup")).resolve()
    migrate_backup(backup, args.legacy_backup, pak)
    if args.restore:
        restore(pak, backup)
    else:
        apply(pak, backup, args.html.resolve(), args.script.resolve())


if __name__ == "__main__":
    main()
