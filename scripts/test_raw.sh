#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hts_mojo_raw.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

: "${CONDA_PREFIX:?pixi environment is required}"

cc -shared -fPIC -I. -Iscripts \
    -I"$CONDA_PREFIX/include/htslib" \
    scripts/wrapper.c \
    -L"$CONDA_PREFIX/lib" -lhts \
    -o "$BUILD_DIR/libwrapper.so"

pixi run mojo build \
    -I . \
    -Xlinker -L"$BUILD_DIR" \
    -Xlinker -lwrapper \
    -Xlinker -L"$CONDA_PREFIX/lib" \
    -Xlinker -lhts \
    -o "$BUILD_DIR/raw-tests" \
    tests/raw.mojo

LD_LIBRARY_PATH="$BUILD_DIR:$CONDA_PREFIX/lib:${LD_LIBRARY_PATH:-}" \
    "$BUILD_DIR/raw-tests"
