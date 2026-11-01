#!/usr/bin/env bash
# Usage: bash check_relaunch.sh [path-to-godot]
exec bash "$(dirname "$0")/tools/verify.sh" relaunch "$@"
