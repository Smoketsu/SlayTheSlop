---
id: 004
title: Validate every data file against the schema
lane: tools
owner: B
status: done
branch: b/004-data-validation-tests
depends_on: [002]
blocked_on: []
files:
  - tests/data/
  - tools/
---

## Goal

Every JSON file under `data/` is checked on every test run, so a content PR with a typo fails CI
instead of failing at runtime.

## Read first

`core/schema/README.md`; `core/schema/json_values.gd`, `card_def.gd`, `enemy_def.gd`, `dude_def.gd`.

## Acceptance checks

- [x] Every file in `data/cards/`, `data/enemies/` and `data/dudes/` parses with `json_values.parse()` and passes its schema's `check()`.
- [x] Each file's `id` equals its file name; ids are unique across the folder; card ids start with their owner.
- [x] References resolve: a Dude's `starter_deck` and `bro_move` name existing cards. Starting Gear is checked once task 021 adds Gear.
      (Card references: yes, through build(). Starting Gear: not yet, waits on task 021 as written.)
- [x] A small reusable reader in `tools/` (`data/**.json` → `{path: text}`), which task 005's ruleset builder and the client can share.
- [x] Unknown folders under `data/` fail, so a new data kind has to get a schema first.
- [x] Fails with the file path and the problem when a file is broken (show it with a deliberately bad file in a temp folder).

## Notes

- Agent A's `tests/core/test_constants.gd` already covers `data/constants.json`.

## Log

- 2026-10-10 B: Claimed.
- 2026-10-10 B: Done. Task 005 (merged in #10) put every check this task listed into
  `core/ruleset/ruleset.gd` `build()`: parse, schema `check()`, id equals file name, unique ids, card
  id starts with owner, unknown folders and files, Dude card references. So this task does not
  repeat them. It adds:
  - `tools/data_files.gd` `read_all(root = "res://")`: every file under `data/` as
    `{"data/...": text}`, sorted, hidden files skipped, other extensions kept so `build()` reports them.
  - `tests/data/test_data_files.gd` (6 tests): the real `data/` builds with no errors; the reader's
    paths and text; a broken JSON file in a temp folder fails with an error starting with its path;
    an unknown folder fails; hidden files are skipped but stray files are not; no `data/` reads empty.
- 2026-10-10 B: Verified: `tools/test.sh` gives 52 passed, 0 failed (46 before plus these 6).
  Temp folders are deleted after each test.
- 2026-10-10 B: Not done: starting Gear references (task 021). `data/` holds only `constants.json`
  today, so the real-data test has little to check until tasks 006 and 010 add content.
- 2026-10-10 B: Merged in #14 (Agent A reviewed: 82 passed with tasks 003, 005 and 027). Status `done`.
  For the client (tasks 018/020): `DirAccess` cannot list loose files under `res://data` in an
  exported build, because `res://` is packed. Shipping needs an export filter that includes
  `data/*.json` plus a generated file index, or a build step. Tests and the editor are unaffected.
