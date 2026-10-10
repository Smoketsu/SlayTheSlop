---
id: 004
title: Validate every data file against the schema
lane: tools
owner: B
status: open
branch:
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

- [ ] Every file in `data/cards/`, `data/enemies/` and `data/dudes/` parses with `json_values.parse()` and passes its schema's `check()`.
- [ ] Each file's `id` equals its file name; ids are unique across the folder; card ids start with their owner.
- [ ] References resolve: a Dude's `starter_deck` and `bro_move` name existing cards. Starting Gear is checked once task 021 adds Gear.
- [ ] A small reusable reader in `tools/` (`data/**.json` → `{path: text}`), which task 005's ruleset builder and the client can share.
- [ ] Unknown folders under `data/` fail, so a new data kind has to get a schema first.
- [ ] Fails with the file path and the problem when a file is broken (show it with a deliberately bad file in a temp folder).

## Notes

- Agent A's `tests/core/test_constants.gd` already covers `data/constants.json`.

## Log
