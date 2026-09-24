#!/bin/bash
# THE pre-commit gate (CLAUDE.md "Robustness rules"). Runs every suite in tests/ ONE AT A TIME and
# fails if ANY suite exits non-zero OR prints a SCRIPT ERROR / Parse Error — a suite can report
# "ALL PASSED" while a check silently errored out (merchant_smoke_test called a renamed method and
# its check "passed" without running). Usage:
#   tools/run_all_tests.sh              # every suite
#   tools/run_all_tests.sh fire loot    # only suites whose name contains one of the words
# Logs go to $TEST_LOG_DIR (default /tmp/df30_tests). Exit 0 only when everything is clean.
cd "$(dirname "$0")/.." || exit 2
LOG_DIR="${TEST_LOG_DIR:-/tmp/df30_tests}"
mkdir -p "$LOG_DIR"
if pgrep -f "godot --headless" >/dev/null; then
	echo "A headless godot is already running — stop it first (suites must run one at a time)." >&2
	exit 2
fi
godot --headless --import >"$LOG_DIR/_import.log" 2>&1 || { echo "IMPORT FAILED (see $LOG_DIR/_import.log)"; exit 1; }
bad=0
count=0
for t in tests/*.tscn; do
	n=$(basename "$t" .tscn)
	if [ $# -gt 0 ]; then
		hit=0
		for w in "$@"; do [[ "$n" == *"$w"* ]] && hit=1; done
		[ $hit -eq 0 ] && continue
	fi
	count=$((count + 1))
	log="$LOG_DIR/$n.log"
	timeout 300 godot --headless "res://$t" >"$log" 2>&1
	code=$?
	if [ $code -ne 0 ]; then
		echo "FAIL   $n (exit $code)"; grep -E "  FAIL " "$log" | head -5
		bad=$((bad + 1))
	elif grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
		echo "ERROR  $n (passed, but a script error fired — a check may not have run)"
		grep -E -A2 "SCRIPT ERROR|Parse Error" "$log" | head -6
		bad=$((bad + 1))
	else
		echo "ok     $n"
	fi
done
echo "---- $count suites, $bad bad ----"
[ $bad -eq 0 ]
