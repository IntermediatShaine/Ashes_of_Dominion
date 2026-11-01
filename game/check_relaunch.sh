#!/usr/bin/env bash
# Save → quit → relaunch → Continue, as two separate engine processes.
# Usage: ./check_relaunch.sh [path-to-godot]
set -u
GODOT="${1:-godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import > /dev/null 2>&1
for phase in write verify; do
  OUT="$("$GODOT" --headless --path . res://tools/relaunch_check.tscn -- --phase=$phase 2>&1)"
  STATUS=$?
  echo "$OUT" | grep -vE "^\s*$"
  if [ $STATUS -ne 0 ] || echo "$OUT" | grep -qE "SCRIPT ERROR|^ERROR:"; then
    echo "!!! relaunch check failed in phase '$phase'"
    exit 1
  fi
done
