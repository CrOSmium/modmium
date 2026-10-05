#!/bin/sh
set -eu

target=${1:-aarch64-unknown-linux-musl}
serverDir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
case "$target" in
  aarch64-unknown-linux-musl) binArch=aarch64 ;;
  x86_64-unknown-linux-musl) binArch=x86-64 ;;
  *) echo "Unsupported target: $target" >&2; exit 1 ;;
esac
rustup target add "$target"

case "$target" in
  aarch64-unknown-linux-musl|x86_64-unknown-linux-musl)
    host=$(rustc -vV | sed -n 's/^host: //p')
    linker=$(rustc --print sysroot)/lib/rustlib/$host/bin/rust-lld
    if [ ! -x "$linker" ]; then
      echo "Rust LLD linker not found: $linker" >&2
      exit 1
    fi
    case "$target" in
      aarch64-unknown-linux-musl)
        export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER="$linker"
        ;;
      x86_64-unknown-linux-musl)
        export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER="$linker"
        ;;
    esac
    ;;
esac

cargo build --locked --release --manifest-path "$serverDir/Cargo.toml" \
  --target "$target"

cp "$serverDir/target/$target/release/modmium-web" \
  "$serverDir/../../../bin/.modmium-web-$binArch"
