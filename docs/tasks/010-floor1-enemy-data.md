---
id: 010
title: Floor 1 enemies and Goblin King Chad as data
lane: content
owner: B
status: open
branch:
depends_on: [001]
blocked_on: [G12, G13]
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

- [ ] One file per enemy, ids in snake_case (e.g. `goblin_pledge`, `sewer_gator_in_a_letterman_jacket` or a shorter agreed id; ids never change once merged).
- [ ] HP, `arm_count`, tier and floor exactly as the table. Each file's `text` holds the GDD behavior text.
- [ ] Moves for everything a plain move can express now (hits, Guard, applying statuses).
- [ ] Behaviors that need new fields or ops (splitting, fleeing, stealing, summoning, Faded, Noise Complaint, scripted alternation, Chad's charge) are listed in a task for Agent A (task 017 and 019 cover most; add what is missing).
- [ ] Chad: everything except his ordinary turn, which waits on G12.
- [ ] Each passes validation (task 004).

## Log
