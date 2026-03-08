#!/bin/bash

set -euo pipefail

mode="${1:-full}"

case "$mode" in
  full)
    "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_spm.sh"
    ;;
  docs-only)
    echo "[validate] docs-only mode: skipping swift validation commands"
    echo "[validate] include the skip reason in the PR or issue update"
    ;;
  *)
    echo "usage: $0 [full|docs-only]" >&2
    exit 1
    ;;
esac
