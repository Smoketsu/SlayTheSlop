---
id: 005
title: Ruleset - turn content JSON text into the read-only data the core runs on
lane: core
owner: A
status: open
branch:
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

- [ ] `build(files: Dictionary) -> {ok, ruleset, errors}`, where `files` maps a repo path such as `data/cards/tom_punch.json` to its text.
- [ ] `ruleset.constants` maps each name to its `value` only (docs dropped); `_` keys skipped.
- [ ] Each definition is checked with its schema; the id must equal the file name; duplicate ids are errors. All errors are returned together, with the file path.
- [ ] Cross-references are checked: a Dude's `starter_deck`, `starting_gear` and `bro_move` name ids that exist (Gear only once task 021 adds Gear).
- [ ] A shared helper for callers that does the file reading (`data/**.json` to the `files` map) lives outside `core/`. Agent B owns `tools/`, so request it in a task rather than writing it there.
- [ ] Tests with in-memory text: a valid set, and each kind of error.

## Notes

- The ruleset must be treated as read-only by the core. Consider `make_read_only()` on the built Dictionaries.

## Log
