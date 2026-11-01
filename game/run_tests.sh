#!/usr/bin/env bash
# Usage: bash run_tests.sh [path-to-godot] [--filter=name]
exec bash "$(dirname "$0")/tools/verify.sh" tests "$@"
