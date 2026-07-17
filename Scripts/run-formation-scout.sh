#!/bin/zsh
set -euo pipefail

mode="${1:-quick}"
case "$mode" in
  quick)
    lateral_offsets=(0)
    vertical_offsets=(-3 -4)
    ;;
  full)
    lateral_offsets=(0 0.5 1)
    vertical_offsets=(-2 -3 -4 -5)
    ;;
  *)
    print -u2 "usage: $0 [quick|full]"
    exit 2
    ;;
esac

phase_offsets=(0 0.25 0.5 0.75)
root="${BIRDFLOW_FORMATION_ARCHIVE_ROOT:-ValidationArtifacts/formation-flight-scout-v1}"

swift build -c release

for y in "${lateral_offsets[@]}"; do
  for z in "${vertical_offsets[@]}"; do
    for phase in "${phase_offsets[@]}"; do
      label="y${y//./p}-z${z#-}-phase${phase//./p}"
      .build/release/birdflow validate formation-flight \
        --chord-cells 8 \
        --cycles 3 \
        --offset-x 0 \
        --offset-y "$y" \
        --offset-z "$z" \
        --phase-offset "$phase" \
        --archive "$root/$label"
    done
  done
done

python3 Scripts/summarize-formation-scout.py "$root" --mode "$mode"
