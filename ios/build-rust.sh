#!/bin/sh
set -eu

# Build before SwiftPM/Xcode; no checked-in binary or implicit network build step.
mode=${1:?usage: ios/build-rust.sh host|simulator|device}
started=$(date +%s)
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$mode" in
  host)
    target=$(rustc -vV | sed -n 's/^host: //p')
    output="$root/ios/.rust/host"
    ;;
  simulator)
    target=aarch64-apple-ios-sim
    output="$root/ios/.rust/iphonesimulator"
    ;;
  device)
    target=aarch64-apple-ios
    output="$root/ios/.rust/iphoneos"
    ;;
  *) echo "unknown Rust target: $mode" >&2; exit 2 ;;
esac
rustup target add --toolchain 1.85.1 "$target"
cargo +1.85.1 build --locked --manifest-path "$root/core/Cargo.toml" --target "$target" --release
mkdir -p "$output"
cp "$root/core/target/$target/release/libsuizai_core.a" "$output/libsuizai_core.a"
printf 'SUIZAI_METRIC rust_target=%s build_seconds=%s rust_staticlib_bytes=%s\n' \
  "$mode" "$(( $(date +%s) - started ))" "$(stat -f %z "$output/libsuizai_core.a")"
