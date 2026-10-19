#!/bin/sh
set -eu

core_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$core_dir"
cargo test --offline
cargo build --offline

case "$(uname -s)" in
    Darwin) extra_libs="-framework Security -framework CoreFoundation -liconv" ;;
    Linux) extra_libs="-ldl -lpthread -lm" ;;
    *) echo "Unsupported C smoke-test host" >&2; exit 1 ;;
esac

# Intentional word splitting for the fixed system link flags above.
# shellcheck disable=SC2086
"${CC:-cc}" -std=c11 -Wall -Wextra -Werror -I"$core_dir/include" \
    "$core_dir/tests/ffi_smoke.c" "$core_dir/target/debug/libsuizai_core.a" \
    $extra_libs -o "$core_dir/target/ffi_smoke"
"$core_dir/target/ffi_smoke"
