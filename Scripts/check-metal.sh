#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/Sources/BirdFlowMetal/Metal/BirdFlow.metal"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "check-metal.sh requires macOS and Apple's xcrun Metal toolchain." >&2
  exit 2
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun was not found. Install the Xcode command-line tools." >&2
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

xcrun -sdk macosx metal -std=metal3.1 -Wall -Wextra \
  -c "$SOURCE" -o "$TMP/BirdFlow.air"
xcrun -sdk macosx metallib "$TMP/BirdFlow.air" \
  -o "$TMP/BirdFlow.metallib"

echo "Metal source compiled successfully: $SOURCE"
