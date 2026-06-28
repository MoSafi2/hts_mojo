#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "usage: $0 <source.mojo> [output-path]" >&2
    exit 2
fi

SOURCE_FILE="$1"
OUTPUT_PATH="${2:-build/$(basename "$SOURCE_FILE" .mojo)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

: "${CONDA_PREFIX:?pixi environment is required}"

mkdir -p "$(dirname "$OUTPUT_PATH")"

cc -shared -fPIC -I. -Iscripts \
    -I"$CONDA_PREFIX/include/htslib" \
    scripts/wrapper.c \
    -L"$CONDA_PREFIX/lib" -lhts \
    -o build/libwrapper.so

BUILD_OUTPUT="$OUTPUT_PATH.building"

pixi run mojo build \
    -I . \
    -Xlinker -Lbuild \
    -Xlinker -lwrapper \
    -Xlinker -L"$CONDA_PREFIX/lib" \
    -Xlinker -lhts \
    -o "$BUILD_OUTPUT" \
    "$SOURCE_FILE"

mv -f "$BUILD_OUTPUT" "$OUTPUT_PATH"
