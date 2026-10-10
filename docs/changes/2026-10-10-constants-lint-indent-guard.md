# 2026-10-10: Duplicate-constant lint fails on re-indentation

## What changed

`tests/core/test_constants.gd`:

- New test `test_duplicate_check_sees_every_key`. The raw text of `data/constants.json` must have at
  least as many top-level key lines as the parsed file has keys.
- New self-test `test_key_line_counter_ignores_other_indentation`.
- New static helper `top_level_key_count(text) -> int`. It counts lines that start a top-level key,
  using the same rule as `duplicate_top_level_keys`.
- New constant `TOP_LEVEL_KEY_PATTERN`, the line regex both helpers share. It was previously a
  literal inside `duplicate_top_level_keys`, and its behaviour is unchanged.

## Why

Agent B suggested this in the review of #36. The duplicate check reads only lines indented by
exactly two spaces. If the file were ever re-indented with tabs or four spaces, the check would see
no keys and pass without saying anything. Now it fails and asks for two-space indentation.

## Fields, variables and constants

- `TOP_LEVEL_KEY_PATTERN` (test-only const, String): a regex that matches one line opening a
  top-level key in a two-space-indented JSON object, and captures the key. Agent A may change it.

Nothing is added to data or state.
