#!/usr/bin/env bash
# Byte-compile the package and assert font-lock faces via Emacs batch.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
emacs_bin="${EMACS:-emacs}"
if ! command -v "$emacs_bin" >/dev/null 2>&1; then
    echo "SKIP  emacs not found"
    exit 0
fi
echo "== byte-compile =="
"$emacs_bin" --batch -L . -f batch-byte-compile awkrs-stdlib.el awkrs-mode.el
rm -f ./*.elc
echo "== face assertions =="
"$emacs_bin" --batch -L . -l scripts/face-test.el
