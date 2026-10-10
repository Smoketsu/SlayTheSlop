---
id: 010
title: Floor 1 enemies and Goblin King Chad as data
lane: content
owner: B
status: in_review
branch: b/010-floor1-enemy-data
depends_on: [001]
blocked_on: []
files:
  - data/enemies/
  - docs/tasks/          # only to write tasks asking Agent A for ops or fields
---

## Goal

The 8 normal enemies and 3 Rivals of The Basement (plus Foam Slime), and Goblin King Chad, as
enemy files with the GDD's HP, arms and numbers.

## Read first

GDD "Floor 1: The Basement", "Goblin King Chad"; `core/schema/enemy_def.gd`.

## Acceptance checks

- [x] One file per enemy, ids in snake_case (e.g. `goblin_pledge`, `sewer_gator_in_a_letterman_jacket` or a shorter agreed id; ids never change once merged).
- [x] HP, `arm_count`, tier and floor exactly as the table. Each file's `text` holds the GDD behavior text.
- [x] Moves for everything a plain move can express now (hits, Guard, applying statuses).
- [x] Behaviors that need new fields or ops (splitting, fleeing, stealing, summoning, Faded, Noise Complaint, scripted alternation, Chad's charge) are listed in a task for Agent A (task 017 and 019 cover most; add what is missing).
- [x] Chad: everything except his ordinary turn, which waits on G12.
- [x] Each passes validation (task 004).

## Log
- 2026-10-10 B: Claimed. Every gap in `blocked_on` is answered (steamjgrube accepted all defaults; see `docs/proposals/decision-log.md`).
- 2026-10-10 B: Done. 13 files in `data/enemies/` (the 11 floor 1 enemies, Foam Slime, Goblin King Chad), copied from Agent A's `tests/core/enemies/enemy_fixtures.gd` (what the core's enemy tests play) plus each enemy's GDD behavior text as `text`. Ids as in the fixtures (`sewer_gator`, `dorm_rat` for one rat of the pack). Content placeholders kept as built (steamjgrube: accept all defaults; logged in docs/proposals/decision-log.md): Foam Slime hits 3, Shot-Caller's ordinary move 10, Checks ID is the Bouncer's hit, the Intern's Paperwork turn also hits, Boo-zer's Faded cycle start as in the fixture. Verified: `tools/test.sh` all passing. `tests/data/test_enemy_data.gd` checks the GDD table (tier, HP, arms), every file against its fixture, and plays a fixed-seed fight (seed 20261010) of real Tom against a real Goblin Pledge and Goblin Bouncer through `core/core.gd`: every state passes `run_state.check()`, replays are byte-identical, outcome recorded `["won", 7, 27, 75]`. That is the first fight played entirely on `data/`.
