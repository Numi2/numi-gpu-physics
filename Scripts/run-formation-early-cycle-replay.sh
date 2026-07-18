#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PHASES="0.755,0.765,0.775,0.785,0.795,0.805,0.815,0.825,0.835,0.845"
REPLAY_ROOT="ValidationArtifacts/formation-flight-early-cycle-replay"
RESOLUTIONS="${BIRDFLOW_FORMATION_REPLAY_RESOLUTIONS:-16 20}"

verify_sha() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(shasum -a 256 "$path" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "locked input changed: $path" >&2
    exit 1
  fi
}

verify_sha \
  ValidationArtifacts/formation-flight-promotion/c16-best-z3-phase025/formation-flight-report.json \
  fd025d4ecb2147917d3011c6238a07996bd29c8e6f5b82cb202179f226e7f415
verify_sha \
  ValidationArtifacts/formation-flight-promotion/c20-best-z3-phase025/formation-flight-report.json \
  03f8dc2f24026e8d1702c05a49ec08d3f51577e838c7966cf2f5cd3cec9c15d6
verify_sha \
  ValidationArtifacts/formation-flight-promotion/formation-flight-c20-discriminator-summary.json \
  6a9b74712f57c0b75d1c5c9d3cbbcfdad2c314d66637d112acb9e5c2b7e56493

swift build -c release --product birdflow

for resolution in $RESOLUTIONS; do
  case "$resolution" in
    16|20) ;;
    *)
      echo "unsupported replay resolution: $resolution" >&2
      exit 1
      ;;
  esac
  reference="ValidationArtifacts/formation-flight-promotion/c${resolution}-best-z3-phase025/formation-flight-report.json"
  archive="$REPLAY_ROOT/c${resolution}-best-z3-phase025"
  report="$archive/formation-flight-field-replay-report.json"
  if [[ -f "$report" ]]; then
    python3 - "$report" <<'PY'
import json
import sys
report = json.load(open(sys.argv[1]))
if not report["gates"]["passed"]:
    raise SystemExit(f"existing replay failed: {sys.argv[1]}")
if report["gates"]["maximumRelativeReferenceCoupledHistoryDifference"] > 1e-6:
    raise SystemExit(f"existing replay misses its reference: {sys.argv[1]}")
print(f"reusing passed replay: {sys.argv[1]}")
PY
    continue
  fi
  .build/release/birdflow validate formation-flight \
    --chord-cells "$resolution" \
    --cycles 5 \
    --offset-z -3 \
    --phase-offset 0.25 \
    --field-phases "$PHASES" \
    --field-replay-reference "$reference" \
    --archive "$archive"
done

if [[ -f "$REPLAY_ROOT/c16-best-z3-phase025/formation-flight-field-replay-report.json" \
  && -f "$REPLAY_ROOT/c20-best-z3-phase025/formation-flight-field-replay-report.json" ]]; then
  ./Scripts/analyze-formation-early-cycle-fields.py
fi
