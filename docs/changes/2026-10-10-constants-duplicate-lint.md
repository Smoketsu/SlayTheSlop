# 2026-10-10: Lint for duplicate constant names

## What changed

`tests/core/test_constants.gd` gains `test_no_duplicate_constant_names`, a self-test, and the static
helper `duplicate_top_level_keys(text)` (returns each top-level key of a two-space-indented JSON
object that appears more than once, in first-repeat order).

## Why

Godot's JSON parser silently keeps the last of two equal keys. While splitting task 011, a git
auto-merge put `MULTI_TARGET_COUNT` into `data/constants.json` twice; every test passed because the
parsed file looked fine. This catches that on the raw text.

## Fields, variables and constants

None added to data or state. Test-only function above.
