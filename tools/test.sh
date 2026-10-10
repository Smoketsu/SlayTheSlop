#!/usr/bin/env bash
# Installs the pinned Godot if needed, imports the project, and runs every test headless.
# Lane: tools (Agent B). Exit code 0 when every test passes, 1 otherwise.
#
# Usage: tools/test.sh            # all tests
#        tools/test.sh rng core/  # only test files whose path contains "rng" or "core/"
set -euo pipefail

# REPO_ROOT: the repository root, found from this script's own location.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# GODOT: the pinned Godot binary, installed on first use.
GODOT="$("$REPO_ROOT/tools/install_godot.sh")"

# The import builds .godot/, which class_name scripts need in a fresh checkout. Its output is
# noise unless it fails.
if ! import_log="$("$GODOT" --headless --path "$REPO_ROOT" --import 2>&1)"; then
  echo "$import_log" >&2
  echo "test.sh: godot --import failed." >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  exec "$GODOT" --headless --path "$REPO_ROOT" --script res://tests/run_tests.gd -- "$@"
fi
exec "$GODOT" --headless --path "$REPO_ROOT" --script res://tests/run_tests.gd
