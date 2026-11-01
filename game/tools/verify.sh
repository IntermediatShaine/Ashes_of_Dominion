#!/usr/bin/env bash
# Native Bash equivalent of verify.ps1. Errors and missing completion markers fail.
set -euo pipefail
check="${1:?check required: import/tests/smoke/relaunch}"
shift
engine="${1:-godot}"
if (($#)); then shift; fi
engine="$(command -v "$engine")"
if [[ "$engine" != /* ]]; then engine="$(cd "$(dirname "$engine")" && pwd)/$(basename "$engine")"; fi
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/aod-check-XXXXXXXX")"
trap 'rm -rf -- "$run_dir"' EXIT
log_dir="$run_dir/logs"
if [[ -n "${AOD_TEST_LOG_DIR:-}" ]]; then
  mkdir -p "$AOD_TEST_LOG_DIR"
  log_dir="$(cd "$AOD_TEST_LOG_DIR" && pwd)/$(basename "$run_dir")"
fi
mkdir -p "$log_dir"
export APPDATA="$run_dir/APPDATA" LOCALAPPDATA="$run_dir/LOCALAPPDATA"
export XDG_DATA_HOME="$run_dir/data" XDG_CONFIG_HOME="$run_dir/config" XDG_CACHE_HOME="$run_dir/cache"
mkdir -p "$APPDATA" "$LOCALAPPDATA" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
cd "$(dirname "$0")/.."
echo "CHECK: $check; isolated application data: $run_dir"
stage() {
  local name="$1" marker="$2" status=0
  shift 2
  "$engine" "$@" > "$log_dir/$name.log" 2>&1 || status=$?
  sed -i.bak $'s/\033\\[[0-9;]*m//g' "$log_dir/$name.log"
  cat "$log_dir/$name.log"
  if ((status != 0)) || grep -Eq '^[[:space:]]*(SCRIPT ERROR:|ERROR:|FAIL\b|RELAUNCH CHECK FAILED:)' "$log_dir/$name.log"; then
    echo "CHECK FAILED: $name (engine exit $status)"
    exit 1
  fi
  if ! grep -Eq "$marker" "$log_dir/$name.log"; then
    echo "CHECK FAILED: $name did not report successful completion"
    exit 1
  fi
  echo "CHECK PASSED: $name"
}
stage import 'Godot Engine v' --headless --path . --import
case "$check" in
  import) ;;
  tests) stage tests '=== [1-9][0-9]* tests, 0 failed ===' --headless --path . res://tests/test_runner.tscn -- "$@" ;;
  smoke) stage smoke 'Godot Engine v' --headless --path . --quit-after 60 ;;
  relaunch)
    stage write 'RELAUNCH CHECK: wrote slot ' --headless --path . res://tools/relaunch_check.tscn -- --phase=write
    stage verify 'RELAUNCH CHECK PASSED:' --headless --path . res://tools/relaunch_check.tscn -- --phase=verify
    ;;
  *) echo "Unknown check: $check" >&2; exit 2 ;;
esac
