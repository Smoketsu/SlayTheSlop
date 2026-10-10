---
id: 019
title: Goblin King Chad, the slice boss
lane: core
owner: A
status: blocked
branch:
depends_on: [017]
blocked_on: [G12, G13]
files:
  - core/combat/
  - core/ops/
  - tests/core/enemies/
---

## Goal

Goblin King Chad plays as the GDD describes. Person A chose him as the slice's one boss on 2026-10-10.

## Read first

GDD "Goblin King Chad"; G12 and G13 in `docs/proposals/solo-slice-rule-gaps.md`.

## Acceptance checks

- [ ] Rush: every third turn, summons 2 Goblin Pledges.
- [ ] Keg Stand: charges for 2 turns, then hits one Dude for 30; each Pledge killed during the charge removes 10; kill both and he falls (skips a turn, Exposed 2).
- [ ] Below 50% HP: Rage Cage, 6 damage 3 times, every turn he is not charging.
- [ ] His remaining turns as answered in G12; starting Pledges as G13.
- [ ] Ick threshold from `ICK_BASE_BOSS`. Arm count 2, so Broken Arm reduces the Keg Stand hit.
- [ ] Fixed-seed test of a full scripted fight against him.

## Log

- 2026-10-10 A: blocked on G12 (his ordinary turn is not specified) and G13.
