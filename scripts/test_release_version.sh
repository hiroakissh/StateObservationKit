#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/scripts"
cp "$repo_root/scripts/release_version.sh" "$tmp_dir/scripts/release_version.sh"
chmod +x "$tmp_dir/scripts/release_version.sh"

run_in_fixture() {
  local version="$1"
  shift

  printf '%s\n' "$version" > "$tmp_dir/VERSION"
  "$tmp_dir/scripts/release_version.sh" "$@"
}

echo "[test-release-version] validate stable semver"
run_in_fixture "1.2.3" validate

echo "[test-release-version] validate prerelease semver"
run_in_fixture "1.2.3-beta.1" validate

echo "[test-release-version] match release branch"
run_in_fixture "1.2.3-beta.1" match-branch "feature/release-1.2.3-beta.1"

echo "[test-release-version] reject invalid prerelease"
if run_in_fixture "1.0.0-." validate; then
  echo "invalid prerelease format unexpectedly passed validation" >&2
  exit 1
fi

echo "[test-release-version] reject mismatched branch/version"
if run_in_fixture "1.2.3" match-branch "feature/release-1.2.4"; then
  echo "branch/version mismatch unexpectedly passed validation" >&2
  exit 1
fi

echo "[test-release-version] all checks passed"
