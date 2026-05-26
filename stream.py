# written by lxrd
#!/usr/bin/env python3

import sys
import struct
import subprocess
import tempfile
import os
import re
import zlib
import time
import argparse
import requests

LINUX_VER_RE = re.compile(
    r'(\d+\.\d+\.\d+-\d+-[0-9a-g]+)|Linux version (\d+\.\d+\.\d+-?\d*-?[0-9a-g]*)'
)

def range_get(url, start, length):
    r = requests.get(url, headers={
        "Range": f"bytes={start}-{start + length - 1}",
        "Accept-Encoding": "identity"
    }, stream=True)
    r.raise_for_status()
    return b"".join(r.iter_content(chunk_size=65536))

def get_file_size(url):
    r = requests.head(url, headers={"Accept-Encoding": "identity"})
    r.raise_for_status()
    return int(r.headers["content-length"])

def find_eocd64(url, file_size):
    tail = range_get(url, file_size - 512, 512)
    loc = tail.rfind(b'PK\x06\x07')
    if loc == -1:
        raise ValueError("no ZIP64 EOCD locator")
    eocd64_off = struct.unpack_from("<Q", tail, loc + 8)[0]
    p = tail.rfind(b'PK\x06\x06')
    eocd64 = tail[p:] if p != -1 else range_get(url, eocd64_off, 56)
    if eocd64[:4] != b'PK\x06\x06':
        raise ValueError("bad EOCD64")
    return struct.unpack_from("<Q", eocd64, 48)[0], struct.unpack_from("<Q", eocd64, 40)[0]

def find_eocd(url, file_size):
    tail = range_get(url, file_size - 512, 512)
    p = tail.rfind(b'PK\x05\x06')
    if p == -1:
        raise ValueError("no EOCD")
    eocd = tail[p:]
    return struct.unpack_from("<I", eocd, 16)[0], struct.unpack_from("<I", eocd, 12)[0]

def parse_central_directory(url, cd_offset, cd_size):
    cd = range_get(url, cd_offset, cd_size)
    entries = []
    pos = 0
    while pos < len(cd):
        if cd[pos:pos+4] != b'PK\x01\x02':
            break
        compress_type     = struct.unpack_from("<H", cd, pos+10)[0]
        compressed_size   = struct.unpack_from("<I", cd, pos+20)[0]
        uncompressed_size = struct.unpack_from("<I", cd, pos+24)[0]
        fname_len         = struct.unpack_from("<H", cd, pos+28)[0]
        extra_len         = struct.unpack_from("<H", cd, pos+30)[0]
        comment_len       = struct.unpack_from("<H", cd, pos+32)[0]
        lh_offset         = struct.unpack_from("<I", cd, pos+42)[0]
        fname = cd[pos+46:pos+46+fname_len].decode("utf-8", errors="replace")
        extra = cd[pos+46+fname_len:pos+46+fname_len+extra_len]
        if lh_offset == 0xFFFFFFFF or compressed_size == 0xFFFFFFFF:
            epos = 0
            while epos < len(extra) - 4:
                tag  = struct.unpack_from("<H", extra, epos)[0]
                size = struct.unpack_from("<H", extra, epos+2)[0]
                if tag == 0x0001:
                    vals, vpos = [], epos+4
                    while vpos + 8 <= epos+4+size:
                        vals.append(struct.unpack_from("<Q", extra, vpos)[0])
                        vpos += 8
                    idx = 0
                    if uncompressed_size == 0xFFFFFFFF and idx < len(vals):
                        uncompressed_size = vals[idx]; idx += 1
                    if compressed_size == 0xFFFFFFFF and idx < len(vals):
                        compressed_size = vals[idx]; idx += 1
                    if lh_offset == 0xFFFFFFFF and idx < len(vals):
                        lh_offset = vals[idx]; idx += 1
                    break
                epos += 4 + size
        entries.append({
            "name": fname,
            "compress_type": compress_type,
            "uncompressed_size": uncompressed_size,
            "local_header_offset": lh_offset,
        })
        pos += 46 + fname_len + extra_len + comment_len
    return entries

def get_data_offset(url, lh_offset):
    lh = range_get(url, lh_offset, 30)
    if lh[:4] != b'PK\x03\x04':
        raise ValueError("bad local file header")
    return lh_offset + 30 + struct.unpack_from("<H", lh, 26)[0] + struct.unpack_from("<H", lh, 28)[0]

def stream_stored(url, data_offset, partitions):
    for skip, length, outfile, label in sorted(partitions, key=lambda x: x[0]):
        fetched = 0
        with open(outfile, 'wb') as f:
            while fetched < length:
                chunk = range_get(url, data_offset + skip + fetched, min(4*1024*1024, length - fetched))
                f.write(chunk)
                fetched += len(chunk)
                print(f"\r  {label}: {fetched//(1024*1024)}MB / {length//(1024*1024)}MB",
                      end="", flush=True, file=sys.stderr)
        print(file=sys.stderr)

def stream_deflate(url, data_offset, partitions):
    partitions = sorted(partitions, key=lambda x: x[0])
    r = requests.get(url, headers={
        "Range": f"bytes={data_offset}-",
        "Accept-Encoding": "identity"
    }, stream=True)
    r.raise_for_status()
    dec = zlib.decompressobj(wbits=-15)
    decompressed = http_bytes = 0
    handles = [(skip, length, open(outfile, 'wb'), label, 0)
               for skip, length, outfile, label in partitions]
    try:
        for chunk in r.iter_content(chunk_size=2*1024*1024):
            http_bytes += len(chunk)
            out = dec.decompress(chunk)
            if not out:
                continue
            new_handles = []
            for skip, length, f, label, written in handles:
                if decompressed + len(out) > skip:
                    s = max(0, skip - decompressed)
                    data = out[s:s + length - written]
                    f.write(data)
                    written += len(data)
                    print(f"\r  {label}: {written//(1024*1024)}MB / {length//(1024*1024)}MB"
                          f"  ({http_bytes//(1024*1024)}MB downloaded)",
                          end="", flush=True, file=sys.stderr)
                if written < length:
                    new_handles.append((skip, length, f, label, written))
                else:
                    print(file=sys.stderr)
                    f.close()
            handles = new_handles
            decompressed += len(out)
            if not handles:
                break
    finally:
        for _, _, f, _, _ in handles:
            f.close()
    r.close()

def fetch_partitions(url, data_offset, compress_type, partitions):
    parts = [(s * 512, n * 512, o, l) for s, n, o, l in partitions]
    if compress_type == 0:
        stream_stored(url, data_offset, parts)
    else:
        stream_deflate(url, data_offset, parts)

def get_partition_table(url, data_offset, compress_type):
    if compress_type == 0:
        return range_get(url, data_offset, 10*1024*1024)
    r = requests.get(url, headers={
        "Range": f"bytes={data_offset}-",
        "Accept-Encoding": "identity"
    }, stream=True)
    r.raise_for_status()
    dec = zlib.decompressobj(wbits=-15)
    buf = b""
    for chunk in r.iter_content(chunk_size=1024*1024):
        buf += dec.decompress(chunk)
        if len(buf) >= 10*1024*1024:
            break
    r.close()
    return buf[:10*1024*1024]

def linux_version(kernel_path):
    with open(kernel_path, 'rb') as f:
        data = f.read()
    for s in re.findall(rb'[ -~]{4,}', data):
        m = LINUX_VER_RE.search(s.decode('ascii', errors='ignore'))
        if m:
            return m.group(0)
    try:
        d = tempfile.mkdtemp()
        subprocess.check_output(["binwalk", "--extract", "--directory", d, kernel_path],
                                 stderr=subprocess.DEVNULL)
        for root, _, files in os.walk(d):
            for fn in files:
                with open(os.path.join(root, fn), 'rb') as f:
                    for s in re.findall(rb'[ -~]{4,}', f.read()):
                        m = LINUX_VER_RE.search(s.decode('ascii', errors='ignore'))
                        if m:
                            return m.group(0)
    except Exception:
        pass
    return None

def tpm_version(kernel_path):
    try:
        out = subprocess.check_output(["futility", "show", kernel_path],
                                       stderr=subprocess.DEVNULL).decode()
        for line in out.splitlines():
            if "Kernel version:" in line:
                return line.split()[-1]
    except Exception:
        pass
    return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--recovery-url", required=True)
    parser.add_argument("--kern-output", default="kern.bin")
    parser.add_argument("--root-output", default="root.bin")
    args = parser.parse_args()

    url = args.recovery_url
    kern_out = args.kern_output
    root_out = args.root_output

    t0 = time.time()
    file_size = get_file_size(url)
    print(f"size: {file_size//(1024*1024)}MB", file=sys.stderr)

    try:
        cd_offset, cd_size = find_eocd64(url, file_size)
    except ValueError:
        cd_offset, cd_size = find_eocd(url, file_size)

    entries = parse_central_directory(url, cd_offset, cd_size)
    if not entries:
        sys.exit("error: empty zip")

    entry = entries[0]
    ctype = entry['compress_type']
    if ctype not in (0, 8):
        sys.exit(f"error: unsupported compress type {ctype}")

    print(f"{entry['name']}  {'stored' if ctype == 0 else 'deflate'}  "
          f"{entry['uncompressed_size']//(1024*1024)}MB", file=sys.stderr)

    data_offset = get_data_offset(url, entry['local_header_offset'])

    pt = get_partition_table(url, data_offset, ctype)
    with tempfile.NamedTemporaryFile(delete=False, suffix=".bin") as f:
        f.write(pt)
        pt_tmp = f.name
    try:
        gdisk = subprocess.check_output(["gdisk", "-l", pt_tmp],
                                         stderr=subprocess.DEVNULL).decode()
    finally:
        os.unlink(pt_tmp)

    def parse_part(name):
        for line in gdisk.splitlines():
            if name in line:
                p = line.split()
                return int(p[1]), int(p[2]) - int(p[1]) + 1
        return None, None

    kern_start, kern_sectors = parse_part("KERN-B")
    root_start, root_sectors = parse_part("ROOT-A")

    if not kern_start:
        sys.exit("error: KERN-B not found\n" + gdisk)
    if not root_start:
        sys.exit("error: ROOT-A not found\n" + gdisk)

    print(f"ROOT-A: {root_sectors*512//(1024*1024)}MB  KERN-B: {kern_sectors*512//(1024*1024)}MB",
          file=sys.stderr)

    fetch_partitions(url, data_offset, ctype, [
        (root_start, root_sectors, root_out, "ROOT-A"),
        (kern_start, kern_sectors, kern_out, "KERN-B"),
    ])

    tpm = tpm_version(kern_out)
    lv  = linux_version(kern_out)
    if tpm: print(f"tpm version: {tpm}")
    if lv:  print(f"linux version: {lv}")
    print(f"done in {time.time() - t0:.1f}s", file=sys.stderr)

if __name__ == "__main__":
    main()
