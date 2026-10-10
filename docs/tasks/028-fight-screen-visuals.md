---
id: 028
title: Fight screen visuals - character sprites, health bars, intents and event animation
lane: client
owner: B
status: in_progress
branch: b/028-fight-visuals
depends_on: [024]
blocked_on: []
files:
  - client/
  - tests/client/
  - assets/            # only to add placeholder art the screen needs, with its source recorded
---

## Goal

The fight screen stops being text only. Each Dude and enemy is drawn with its placeholder sprite from
`assets/placeholder/characters/<def_id>.png` (#81), with an HP bar, Guard and statuses beside it, and
the enemy's intent above it. The events a request returns are played as short animations (hit,
Guard gained, death, Passed Out) in order, then the screen shows the new state. The client still
never changes game state: it only reads `state` and animates `events`.

## Read first

GDD "Technical design" (client and core), "Combat" (intents, statuses); CLAUDE.md "The rules core is
pure"; `client/fight/fight_screen.gd` and `fight_model.gd` (tasks 018, 024); `core/schema/event.gd`;
`assets/placeholder/README.md`.

## Acceptance checks

- [ ] A sprite lookup in `client/` maps a Dude or enemy `def_id` to its texture, with a visible
      fallback for ids with no art (for example `foam_slime`); no id is hard-coded except in that
      lookup's fallback table.
- [ ] The fight screen shows a sprite, HP bar, Guard and statuses for every Dude and enemy in state,
      and each enemy's intent; it updates after every request.
- [ ] Damage, Guard, death and Passed Out events animate in event order; animation never changes
      `state` (a test freezes state read-only through a whole fight played by presses, as in 024).
- [ ] Animations can be skipped or run instantly in tests (headless, no frame timing in assertions).
- [ ] `tools/test.sh` passes.

## Notes

- `foam_slime` has no art yet; `rat_king` art exists without data.
- Run screens are task 020; this task only covers the fight screen.

## Log

- 2026-10-10 B: Written and claimed (next free even id). steamjgrube asked for the visualization
  system on the new placeholder assets.
