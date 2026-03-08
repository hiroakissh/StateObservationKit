#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_path="$repo_root/.swift-format"
mode="${1:-check}"

shift || true

zero_sha="0000000000000000000000000000000000000000"

all_swift_files() {
    git -C "$repo_root" ls-files -- "*.swift" "Package.swift"
}

changed_swift_files() {
    local base_ref="${1:-}"
    local head_ref="${2:-HEAD}"

    if [[ -z "$base_ref" || "$base_ref" == "$zero_sha" ]]; then
        all_swift_files
        return
    fi

    git -C "$repo_root" diff --name-only --diff-filter=ACMR "$base_ref" "$head_ref" -- "*.swift" "Package.swift"
}

run_lint() {
    local -a files=("$@")

    if ((${#files[@]} == 0)); then
        echo "[format] no Swift files to check"
        return 0
    fi

    echo "[format] checking ${#files[@]} file(s)"
    (
        cd "$repo_root"
        swift format lint --strict --configuration "$config_path" --parallel "${files[@]}"
    )
}

run_format() {
    local -a files=("$@")

    if ((${#files[@]} == 0)); then
        echo "[format] no Swift files to format"
        return 0
    fi

    echo "[format] formatting ${#files[@]} file(s)"
    (
        cd "$repo_root"
        swift format format --in-place --configuration "$config_path" --parallel "${files[@]}"
    )
}

case "$mode" in
    format)
        if (($# > 0)); then
            run_format "$@"
        else
            files=()
            while IFS= read -r file; do
                files+=("$file")
            done < <(all_swift_files)
            if ((${#files[@]} == 0)); then
                run_format
            else
                run_format "${files[@]}"
            fi
        fi
        ;;
    check)
        if (($# > 0)); then
            run_lint "$@"
        else
            files=()
            while IFS= read -r file; do
                files+=("$file")
            done < <(all_swift_files)
            if ((${#files[@]} == 0)); then
                run_lint
            else
                run_lint "${files[@]}"
            fi
        fi
        ;;
    check-changed)
        base_ref="${1:-}"
        head_ref="${2:-HEAD}"
        files=()
        while IFS= read -r file; do
            files+=("$file")
        done < <(changed_swift_files "$base_ref" "$head_ref")
        if ((${#files[@]} == 0)); then
            run_lint
        else
            run_lint "${files[@]}"
        fi
        ;;
    *)
        echo "usage: $0 [format|check|check-changed [base-ref] [head-ref]] [path ...]" >&2
        exit 1
        ;;
esac
