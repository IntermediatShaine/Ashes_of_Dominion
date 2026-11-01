#!/usr/bin/env bash
# Runs the automated test suite headless. Usage: ./run_tests.sh [path-to-godot] [--filter=name]
# Exit code is non-zero if any test fails OR if the engine reported a script error
# (a runtime script error aborts the test that hit it, so it must count as a failure).
set -u
GODOT="${1:-godot}"
shift || true
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT="$("$GODOT" --headless --path . res://tests/test_runner.tscn -- "$@" 2>&1)"
STATUS=$?
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "SCRIPT ERROR|^ERROR:"; then
  echo "!!! engine errors were reported above — treating as failure"
  exit 1
fi
exit $STATUS
