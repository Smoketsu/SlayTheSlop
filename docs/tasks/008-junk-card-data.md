---
id: 008
title: The six Junk cards as data
lane: content
owner: B
status: done
branch: b/008-junk-data
depends_on: [006]
blocked_on: []
files:
  - data/cards/
---

## Goal

`junk_hangover`, `junk_regret`, `junk_bedbugs`, `junk_paperwork`, `junk_detention`, `junk_burn` as
card files, using the ops task 015 adds.

## Read first

GDD "Junk cards"; task 015.

## Acceptance checks

- [x] Six files, owner `junk`, type `junk`, costs from the GDD (Paperwork 1, the rest -1 unplayable).
- [x] Rarity as answered in G17; how "Lasts: Run / Fight" is expressed agreed with Agent A in task 015.
- [x] Each passes validation (task 004).

## Log

- 2026-10-10 A (for B): blocked on G17. Junk has no rarity in the GDD's list.
- 2026-10-10 B: Claimed. Every gap in `blocked_on` is answered (steamjgrube accepted all defaults; see `docs/proposals/decision-log.md`). Starts once task 006 merges (depends_on).
- 2026-10-10 B: Done. Six files in `data/cards/`, copied from Agent A's `tests/core/combat/junk_fixtures.gd` (the cards the core's Junk tests play), plus each card's GDD text. Rarity `special` (G17); fight-only Junk uses `"lasts": "fight"` as task 015 built it. Verified: `tools/test.sh` all passing; `tests/data/test_junk_data.gd` checks every card against the GDD table and the fixture. Started before 006 merged: 008 has no reference to Tom's data, and the Gear and Brews (014) need these cards first.
- 2026-10-10 B: Merged with #60 (which landed #56–#59); Agent A reviewed it: 363 passed. Status `done`.
