#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${BUILD_ROOT:-$repo_root/.build/ci}"
cache_root="${SWIFTPM_CACHE_ROOT:-$build_root/swiftpm-cache}"
home_root="${SWIFTPM_HOME_ROOT:-$build_root/home}"
xdg_cache_root="${SWIFTPM_XDG_CACHE_ROOT:-$build_root/xdg-cache}"
clang_module_cache_root="${SWIFTPM_CLANG_MODULE_CACHE_ROOT:-$build_root/clang-module-cache}"

mkdir -p \
    "$cache_root" \
    "$home_root" \
    "$xdg_cache_root" \
    "$clang_module_cache_root"

export HOME="$home_root"
export XDG_CACHE_HOME="$xdg_cache_root"
export CLANG_MODULE_CACHE_PATH="$clang_module_cache_root"

example_package_manifests=()
while IFS= read -r manifest_path; do
    example_package_manifests+=("$manifest_path")
done < <(
    find "$repo_root" \
        \( -path "$repo_root/Examples/*" -o -path "$repo_root/Example/*" -o -path "$repo_root/Samples/*" -o -path "$repo_root/Sample/*" \) \
        -name Package.swift \
        -print \
        | sort
)

example_xcode_containers=()
while IFS= read -r container_path; do
    example_xcode_containers+=("$container_path")
done < <(
    find "$repo_root" \
        \( -path "$repo_root/Examples/*" -o -path "$repo_root/Example/*" -o -path "$repo_root/Samples/*" -o -path "$repo_root/Sample/*" \) \
        \( -name "*.xcodeproj" -o -name "*.xcworkspace" \) \
        -print \
        | sort
)

if ((${#example_package_manifests[@]} == 0 && ${#example_xcode_containers[@]} == 0)); then
    echo "[build-examples] no example app, package, workspace, or project detected; skipping"
    exit 0
fi

if ((${#example_xcode_containers[@]} > 0)); then
    echo "[build-examples] found Xcode example containers that need explicit build configuration:"
    printf '  %s\n' "${example_xcode_containers[@]}"
    echo "[build-examples] configure their scheme/build entry before enabling them in Phase 2"
    exit 1
fi

for manifest_path in "${example_package_manifests[@]}"; do
    package_root="$(dirname "$manifest_path")"
    package_name="$(basename "$package_root")"
    scratch_root="$build_root/examples/$package_name"

    mkdir -p "$scratch_root"

    echo "[build-examples] swift build --package-path $package_root"
    swift build \
        --disable-sandbox \
        --cache-path "$cache_root" \
        --scratch-path "$scratch_root" \
        --package-path "$package_root"
done
