#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${BUILD_ROOT:-$repo_root/.build/ci}"
cache_root="${SWIFTPM_CACHE_ROOT:-$build_root/swiftpm-cache}"
scratch_root="${SWIFTPM_SCRATCH_ROOT:-$build_root/swiftpm}"
home_root="${SWIFTPM_HOME_ROOT:-$build_root/home}"
xdg_cache_root="${SWIFTPM_XDG_CACHE_ROOT:-$build_root/xdg-cache}"
clang_module_cache_root="${SWIFTPM_CLANG_MODULE_CACHE_ROOT:-$build_root/clang-module-cache}"

mkdir -p \
    "$cache_root" \
    "$scratch_root" \
    "$home_root" \
    "$xdg_cache_root" \
    "$clang_module_cache_root"

export HOME="$home_root"
export XDG_CACHE_HOME="$xdg_cache_root"
export CLANG_MODULE_CACHE_PATH="$clang_module_cache_root"

swiftpm_args=(
    --disable-sandbox
    --cache-path "$cache_root"
    --scratch-path "$scratch_root"
)

cd "$repo_root"

echo "[test-spm] swift test"
swift test "${swiftpm_args[@]}"

echo "[test-spm] swift build -Xswiftc -strict-concurrency=complete"
swift build "${swiftpm_args[@]}" -Xswiftc -strict-concurrency=complete
