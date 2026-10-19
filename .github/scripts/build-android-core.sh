#!/usr/bin/env bash
set -euo pipefail

output_dir="${1:?Android Rust output directory required}"
# Hosted runners may export ANDROID_NDK_HOME for a different preinstalled revision.
ndk="${ANDROID_HOME:?ANDROID_HOME required}/ndk/27.2.12479018"
host_tag="linux-x86_64"
if [[ "$(uname -s)" == Darwin ]]; then host_tag="darwin-x86_64"; fi
toolchain="$ndk/toolchains/llvm/prebuilt/$host_tag/bin"
if [[ ! -d "$toolchain" ]]; then
  echo "Pinned Android NDK 27.2.12479018 is missing: $toolchain" >&2
  exit 1
fi
if ! grep -Eq '^Pkg.Revision *= *27\.2\.12479018$' "$ndk/source.properties"; then
  echo "Android NDK 27.2.12479018 required: $ndk" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$output_dir"
export CARGO_TARGET_DIR="$output_dir/target"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$toolchain/aarch64-linux-android26-clang"
export CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="$toolchain/x86_64-linux-android26-clang"
for mapping in 'aarch64-linux-android arm64-v8a' 'x86_64-linux-android x86_64'; do
  read -r target abi <<< "$mapping"
  cargo +1.85.1 build --locked --release --manifest-path "$repo_root/core/Cargo.toml" --target "$target"
  mkdir -p "$output_dir/$abi"
  cp "$output_dir/target/$target/release/libsuizai_core.a" "$output_dir/$abi/libsuizai_core.a"
done
