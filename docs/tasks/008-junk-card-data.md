---
id: 008
title: The six Junk cards as data
lane: content
owner: B
status: in_progress
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

- [ ] Six files, owner `junk`, type `junk`, costs from the GDD (Paperwork 1, the rest -1 unplayable).
- [ ] Rarity as answered in G17; how "Lasts: Run / Fight" is expressed agreed with Agent A in task 015.
- [ ] Each passes validation (task 004).

## Log

- 2026-10-10 A (for B): blocked on G17. Junk has no rarity in the GDD's list.
- 2026-10-10 B: Claimed. Every gap in `blocked_on` is answered (steamjgrube accepted all defaults; see `docs/proposals/decision-log.md`). Starts once task 006 merges (depends_on).
