---
id: 006
title: Tom's data - the 14 GDD cards, his Dude file, and Chest Bump
lane: content
owner: B
status: in_progress
branch: b/006-tom-data
depends_on: [001]
blocked_on: []
files:
  - data/cards/
  - data/dudes/tom.json
  - docs/tasks/          # only to write a task asking Agent A for ops that do not exist
---

## Goal

Tom as data: `data/dudes/tom.json` and one file per card for his 14 GDD cards plus his Bro Move,
using the GDD's numbers and wording exactly.

## Read first

GDD "Tom, the Enforcer", "Bro Meter", "Example card definition", "Card definition fields";
`core/schema/card_def.gd`, `dude_def.gd`; `core/ops/README.md` once task 007 adds it.

## Acceptance checks

- [ ] `data/dudes/tom.json`: max HP 80, starter deck 4 Punch, 4 Flex, 1 Arm Bar, 1 Well, Actually; starting Gear `tom_unused_gym_membership`; `bro_move` `tom_chest_bump`.
- [ ] 14 card files, ids `tom_<name>` (e.g. `tom_punch`, `tom_well_actually`), each passing `card_def.check()`. `tom_arm_bar` matches the GDD example exactly.
- [ ] `tom_chest_bump`: "Deal 20 damage. Break 1 arm on every enemy", cost 0. Its rarity waits on G17.
- [ ] Each card has `text` with the GDD's effect wording.
- [ ] Effects use only ops in `core/ops/README.md`. For every card that needs an op that does not exist, write a task for Agent A (odd id) with the exact op and fields you want, and leave that card's effects as the GDD text in `text` with `effects: []` until the op exists.
- [ ] `upgrade` is `{}` for every card except Arm Bar (G15).
- [ ] Passes task 004's validation once it exists.

## Notes

- Punch and Flex appear in every Dude's starter deck with identical numbers. The GDD does not say whether they are one shared card or per-Dude copies; `tom_punch` follows the id rule. Raise it with both people if you think `neutral_punch` is better; do not pick silently.

## Log
- 2026-10-10 B: Claimed. Every gap in `blocked_on` is answered (steamjgrube accepted all defaults; see `docs/proposals/decision-log.md`).
