#!/usr/bin/env bash

set -euo pipefail

mode="${1:-full}"

case "$mode" in
  full)
    echo "[validate] swift test"
    swift test

    echo "[validate] swift build -Xswiftc -strict-concurrency=complete"
    swift build -Xswiftc -strict-concurrency=complete
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
