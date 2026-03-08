#!/bin/bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_file="$root_dir/VERSION"

read_version_file() {
  if [[ ! -f "$version_file" ]]; then
    echo "VERSION file not found at $version_file" >&2
    return 1
  fi

  tr -d '[:space:]' < "$version_file"
}

validate_version() {
  local version="$1"

  if [[ -z "$version" ]]; then
    echo "VERSION must not be empty." >&2
    return 1
  fi

  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
    echo "VERSION must use semantic version format MAJOR.MINOR.PATCH or MAJOR.MINOR.PATCH-prerelease: $version" >&2
    return 1
  fi
}

get_version_from_ref() {
  local ref="$1"
  git show "$ref:VERSION" 2>/dev/null | tr -d '[:space:]'
}

command_name="${1:-}"

case "$command_name" in
  get)
    version="$(read_version_file)"
    validate_version "$version"
    printf '%s\n' "$version"
    ;;
  get-from-ref)
    ref="${2:?git ref is required}"
    version="$(get_version_from_ref "$ref")"
    validate_version "$version"
    printf '%s\n' "$version"
    ;;
  validate)
    version="$(read_version_file)"
    validate_version "$version"
    echo "[release-version] VERSION=$version"
    ;;
  match-branch)
    branch="${2:?branch name is required}"
    prefix="feature/release-"

    if [[ "$branch" != "$prefix"* ]]; then
      echo "Release branch must start with $prefix: $branch" >&2
      exit 1
    fi

    version="$(read_version_file)"
    validate_version "$version"

    expected_version="${branch#${prefix}}"
    if [[ "$version" != "$expected_version" ]]; then
      echo "VERSION ($version) must match release branch suffix ($expected_version)." >&2
      exit 1
    fi

    echo "[release-version] branch=$branch VERSION=$version"
    ;;
  *)
    echo "usage: $0 {get|get-from-ref|validate|match-branch}" >&2
    exit 1
    ;;
esac
