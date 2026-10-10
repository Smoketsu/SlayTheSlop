---
id: 031
title: Power trigger depth guard
lane: core
owner: A
status: in_progress
branch: claude/brave-cerf-to5qlg
depends_on: [013, 015, 017, 019, 021]
blocked_on: []
files:
  - core/ops/ops.gd
  - core/ops/README.md
  - core/combat/fight.gd                     # check_start refuses an unusable MAX_TRIGGER_DEPTH
  - data/constants.json                      # MAX_TRIGGER_DEPTH, separate contract PR
  - docs/proposals/solo-slice-rule-gaps.md   # one new gap entry, unanswered
  - tests/core/ops/
---

## Goal

`core/ops/ops.gd` `run()` fires Power triggers after every op, including the ops a trigger's own
effects run. A Power with `when: "enemy_buffed"` whose effects buff an enemy (Guard or Swole) would
fire itself without end and hang the fight. Cap how deeply Power triggers may nest, with the cap in
`data/constants.json`, so data can never hang the core, while legitimate chains (Reply Guy's Ick
Grosses Out an enemy, which fires Friend Zone) keep working. Raised by Agent B in its review of #50.

## Read first

- `core/ops/ops.gd` (`run`, `fire_power_triggers_in_place`, `make_context`).
- `core/combat/powers.gd` (which events fire which triggers).
- `core/combat/card_triggers.gd` and `core/ops/draw.gd` (a draw inside a trigger runs on_draw effects
  with a context built from the op context).
- GDD "Card types and keywords" (Powers). The GDD says nothing about triggers that feed themselves.

## Acceptance checks

- [ ] `data/constants.json` has `MAX_TRIGGER_DEPTH` (`{value, unit, meaning}`), in its own contract PR.
- [ ] The op context carries `trigger_depth`; each Power trigger's effects run one level deeper, and
      no trigger fires once the depth reaches `MAX_TRIGGER_DEPTH`.
- [ ] A self-feeding test Power (`enemy_buffed` that buffs the enemy) terminates and fires exactly
      `MAX_TRIGGER_DEPTH` times (`tests/core/ops/`).
- [ ] Reply Guy followed by Friend Zone still chains (`tests/core/ops/`).
- [ ] A gap entry for the cap in `docs/proposals/solo-slice-rule-gaps.md`, unanswered.
- [ ] `tools/test.sh` passes.

## Notes

- Stacked on the open task 013-019/021 stack (head: #50, `a/019-goblin-king-chad`); the code it
  changes is not on `main` yet.
- Optional, from the same review: the preload chain `ops.gd` -> `draw.gd` -> `card_triggers.gd` ->
  `ops.gd`. Look at passing the draw function in through the context instead of preloading.

## Log
- 2026-10-10 A: Created and claimed by Agent A (Smoketsu's session) on branch `claude/brave-cerf-to5qlg`.
