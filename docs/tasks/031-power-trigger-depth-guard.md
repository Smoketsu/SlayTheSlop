---
id: 031
title: Power trigger depth guard
lane: core
owner: A
status: in_review
branch: claude/brave-cerf-to5qlg
depends_on: [013, 015, 017, 019, 021]
blocked_on: []
files:
  - core/ops/ops.gd
  - core/ops/README.md
  - core/combat/fight.gd                     # check_start refuses an unusable MAX_TRIGGER_DEPTH
  - data/constants.json                      # MAX_TRIGGER_DEPTH, separate contract PR
  - docs/proposals/solo-slice-rule-gaps.md   # one new gap entry (G53)
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

- [x] `data/constants.json` has `MAX_TRIGGER_DEPTH` (`{value, unit, meaning}`), in its own contract PR.
- [x] The op context carries `trigger_depth`; each Power trigger's effects run one level deeper, and
      no trigger fires once the depth reaches `MAX_TRIGGER_DEPTH`.
- [x] A self-feeding test Power (`enemy_buffed` that buffs the enemy) terminates and fires exactly
      `MAX_TRIGGER_DEPTH` times (`tests/core/ops/`).
- [x] Reply Guy followed by Friend Zone still chains (`tests/core/ops/`).
- [x] A gap entry for the cap in `docs/proposals/solo-slice-rule-gaps.md` (G53; since answered "accept, 8").
- [x] `tools/test.sh` passes.

## Notes

- Stacked on the open task 013-019/021 stack (head: #50, `a/019-goblin-king-chad`); the code it
  changes is not on `main` yet.
- Optional, from the same review: the preload chain `ops.gd` -> `draw.gd` -> `card_triggers.gd` ->
  `ops.gd`. Look at passing the draw function in through the context instead of preloading.
  **Not done, on purpose** (see the log).
- `Ops.make_context()` copies `trigger_depth` from an op context passed in place of the ruleset.
  That is how a draw inside a trigger keeps its depth: `card_triggers.gd` builds its on_draw context
  from the draw op's context. A new caller that builds a fresh context from the ruleset inside an op
  would restart the count at 0; pass the op context instead.
- `Ops.NESTING_OPS` (only `draw`): ops whose nested effects already fired their triggers, so
  `run()` does not react to the op's events again. Any future op that runs effects through
  `Ops.run()` belongs there, and must not emit a Power-relevant event itself.

## Log
- 2026-10-10 A: Created and claimed by Agent A (Smoketsu's session) on branch `claude/brave-cerf-to5qlg`.
- 2026-10-10 A: Done, in review. Three PRs: the claim (`claude/brave-cerf-to5qlg-claim`, task file
  only), the contract (`claude/brave-cerf-to5qlg-constants`: `MAX_TRIGGER_DEPTH` = 8, placed after
  `BRO_METER_SOLO_CARDS` so it merges cleanly with #46's `FADED_MAX_DAMAGE`), and the rules
  (`claude/brave-cerf-to5qlg`, stacked on #50 with both of the others merged in).
  - Built: `trigger_depth` in the op context; `fire_power_triggers_in_place` takes a `depth`
    (default 0), fires nothing at `MAX_TRIGGER_DEPTH`, and runs trigger effects at depth + 1;
    `Ops.check_constants`, called by `Fight.check_start`; gap G53, unanswered.
  - **Bug found and fixed:** a `draw` inside `Ops.run()` fired each Power trigger twice for its
    drawn cards' `on_draw` events (once inside, once again by the outer `run()` for the draw). With a
    Power that draws on an enemy buff and a card whose `on_draw` buffs enemies, the chain fired 114
    times instead of 8. Latent: no slice `on_draw` buffs or Grosses Out an enemy. Fixed with
    `Ops.NESTING_OPS`; `test_draw_does_not_fire_triggers_twice` and
    `test_chain_through_a_draw_is_capped` fail without it (checked).
  - Verified: `tools/test.sh` -> 351 passed, 0 failed (339 on the #50 head, 10 new in
    `tests/core/ops/test_trigger_depth.gd`, and 2 lint tests from `main`'s #38 that came in with
    the claim and contract branches). Fixed-seed hashes are unchanged.
  - Not done: the preload-cycle refactor. Passing the draw function through the context needs every
    top-level context builder (`play.gd`, `fight.gd`, `bro_move.gd`, `brews.gd`, `gear_triggers.gd`,
    `enemy_behaviors.gd`, and the tests that call `Ops.make_context` directly) to add it, because
    `ops.gd` cannot preload `card_triggers.gd` without the same cycle. A context that missed it
    would draw without running `on_draw` (Junk silently skipped), which is worse than a cycle
    Godot 4.7.2 resolves. If the people want it, a cleaner fix is to stop `card_triggers.gd`
    preloading `ops.gd` (pass the effect runner in from `fight.gd`); that is a separate task.
- 2026-10-10 A: #52 (claim) and #53 (`MAX_TRIGGER_DEPTH`) merged; #50 merged, so `main` now has
  the whole 013-021 stack and this branch merges it in. steamjgrube accepted G53 with the value 8 in
  the review of #53 (decision log, #54); the gap entry now records that answer.
