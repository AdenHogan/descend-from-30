#!/bin/bash
# Run the descent bot over a list of seeds, ONE godot at a time, and summarise the lot.
#
#   tools/bot_sweep.sh <outdir> <group> "<seed seed ...>" [bot args...]
#   e.g. tools/bot_sweep.sh /tmp/sweep fighter "424242 101 102 103" --style=fighter --runs=3 --keep-going
#        tools/bot_sweep.sh /tmp/sweep strict  "424242 101 102"     --style=fighter --runs=1 --no-crowbar
#
# Files land as <outdir>/<group>_<seed>.{md,json,log}; run it again with another group to put a second configuration beside the
# first, then `python3 tools/bot_summary.py <outdir>` prints one comparison section per group (docs/BOT_RUNS.md).
# Each bot invocation is capped at 8 minutes of wall time (a hung run is recorded in <outdir>/_done.txt as exit=124).
set -u
OUT=${1:?outdir}; GROUP=${2:?group}; SEEDS=${3:?seeds}; shift 3
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
for sd in $SEEDS; do
  start=$(date +%s)
  timeout 480 godot --headless res://tools/bot_run.tscn -- --seed="$sd" --speed=8 --out="$OUT/${GROUP}_${sd}.md" "$@" > "$OUT/${GROUP}_${sd}.log" 2>&1
  echo "${GROUP}_${sd} exit=$? wall=$(( $(date +%s) - start ))" >> "$OUT/_done.txt"
done
