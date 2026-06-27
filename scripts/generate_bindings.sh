#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_PATH="${1:-hts_mojo/_ffi.mojo}"
LAYOUT_PATH="${2:-tests/layout_ffi.mojo}"

cd "$ROOT_DIR"
mkdir -p "$(dirname "$OUT_PATH")" "$(dirname "$LAYOUT_PATH")"

tmp_out="$(mktemp "${OUT_PATH}.XXXXXX")"
trap 'rm -f "$tmp_out"' EXIT

pixi run mojo-bindgen scripts/wrapper.h -I . --layout-tests "$LAYOUT_PATH" -o "$tmp_out"

perl -0pi -e 's/\ndef abort\(\) abi\("C"\) -> None:\n    external_call\["abort", NoneType\]\(\)\n/\n/s' "$tmp_out"

mv "$tmp_out" "$OUT_PATH"
trap - EXIT
