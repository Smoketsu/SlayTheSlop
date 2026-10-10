---
id: 005
title: Ruleset - turn content JSON text into the read-only data the core runs on
lane: core
owner: A
status: done
branch: a/005-ruleset-loader
depends_on: [001, 002]
blocked_on: []
files:
  - core/ruleset/
  - tests/core/ruleset/
---

## Goal

A pure function that takes the text of every content file and returns the `ruleset` passed to
`apply()`: constants by name, and cards, enemies and Dudes by id, all validated. The core may not
read files, so callers (client, tools, tests) read the text and pass it in.

## Read first

`core/schema/README.md` ("The core's entry point"); `core/schema/json_values.gd`, `card_def.gd`,
`enemy_def.gd`, `dude_def.gd`; `data/constants.json`.

## Acceptance checks

- [x] `build(files: Dictionary) -> {ok, ruleset, errors}`, where `files` maps a repo path such as `data/cards/tom_punch.json` to its text.
- [x] `ruleset.constants` maps each name to its `value` only (docs dropped); `_` keys skipped.
- [x] Each definition is checked with its schema; the id must equal the file name; duplicate ids are errors. All errors are returned together, with the file path.
- [x] Cross-references are checked: a Dude's `starter_deck`, `starting_gear` and `bro_move` name ids that exist (Gear only once task 021 adds Gear).
  `starter_deck` and `bro_move`: done. `starting_gear`: not checked until task 021 (no Gear format yet); pinned by `test_starting_gear_is_not_checked_yet`.
- [x] A shared helper for callers that does the file reading (`data/**.json` to the `files` map) lives outside `core/`. Agent B owns `tools/`, so request it in a task rather than writing it there.
  Not written here (Agent B's lane). Requested from Agent B: task 004 already asks for this reader.
- [x] Tests with in-memory text: a valid set, and each kind of error.

## Notes

- The ruleset must be treated as read-only by the core. Consider `make_read_only()` on the built Dictionaries.

## Log

- 2026-10-10 A: Started before the claim PR and task 001/002 merged, at Person A's instruction;
  verified with Agent A's local draft harness.
  **Done:** `core/ruleset/ruleset.gd` with `build(files)` (pure, no file access) and `freeze(value)`.
  Parses each file with `json_values.parse`, checks it with its schema's `check()`, requires id ==
  file name, reports duplicate ids (naming the first file), files outside `data/cards/`,
  `data/enemies/`, `data/dudes/` and `data/constants.json` (including `data/gear/` and
  sub-folders), non-`.json` files, a missing or malformed constants file, constant values that are
  not int/float/bool, and Dude `starter_deck` / `bro_move` ids that are not valid cards. All errors
  come back from one call, sorted by path, each starting with `<path>: `. A failed build returns an
  empty ruleset. The ruleset is read-only at every level (`make_read_only()` is shallow, so
  `freeze()` walks it). Tests: `tests/core/ruleset/test_ruleset.gd`, 19 tests, in-memory text plus
  one that builds from the real `data/constants.json` alone (ints for BASE_HYPE etc., floats for the
  multipliers and fractions).
  **Not done:** `starting_gear` is not checked (no Gear format until task 021; task 021 should add
  `data/gear/` to `KINDS` and flip `test_starting_gear_is_not_checked_yet`). The shared file reader
  outside `core/` is Agent B's (task 004 already asks for it). Read-only-ness is tested with
  `is_read_only()` at every level, not by writing, because the harness fails a test on any engine
  error and a write to a read-only Dictionary raises one.
  **Found:** Godot's JSON parser accepts trailing commas (`{"id": "x", }` parses), and
  `json_values.parse`'s "line N" is 0-based (Godot's `get_error_line()`). Not changed here: it is a
  `core/schema/` contract.
  **Verified:** `/tmp/claude-0/-home-user-SlayTheSlop/d2338099-8269-5851-b04b-e8ed9a537cf9/scratchpad/verify.sh /home/user/SlayTheSlop/.claude/worktrees/agent-a40fc120437732dee`
  (Godot 4.7.2-stable, headless, draft harness from task 002) -> `45 passed, 0 failed`, including
  the purity and documentation lints over the new files.
- 2026-10-10 A (lead): Merged origin/main (task 002 harness) into this branch and re-ran with the real
  harness: `tools/test.sh` -> 46 passed, 0 failed. Reviewed and pushed by the lead Agent A session.
- 2026-10-10 A: Merged in #10. The file reader landed in Agent B's task 004 (`tools/data_files.gd`, #14),
  so that check is ticked. The `starting_gear` check moves to task 021, which owns the Gear format;
  it is listed there. Status `done`.
