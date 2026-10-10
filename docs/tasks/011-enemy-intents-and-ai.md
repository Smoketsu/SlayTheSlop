---
id: 011
title: Enemy intents, move choice and targeting
lane: core
owner: A
status: in_review
branch: a/011-enemy-intents-and-ai
depends_on: [007]
blocked_on: []
files:
  - core/combat/
  - core/ai/
  - tests/core/ai/
---

## Goal

Enemies pick moves by weight from the `combat_ai` stream, never repeat a move three times in a row,
show their intent and target in advance, and follow scripted patterns where the data says so.

## Read first

GDD "Turn flow" steps 1 and 5, "Enemies" intro, "Difficulty scaling" (targets per attack);
`core/schema/enemy_def.gd`, `enemy_state.gd`.

## Acceptance checks

- [x] Weighted choice using only `combat_ai`; weight-0 moves are never chosen at random.
  (`tests/core/ai/test_move_choice.gd`: `test_first_choice_is_one_weighted_draw`,
  `test_first_choice_frequencies`, `test_weight_zero_never_chosen`;
  `test_intents_in_fight.gd`: `test_only_combat_ai_moves`)
- [x] No move three times in a row (G11: random choice only; scripted patterns exempt). Per-enemy
  history: `enemy_state.move_history`, added in the branch's first commit (contract, schema only).
  (`test_never_three_in_a_row`, `test_banned_move`, `test_pattern_followed_exactly`)
- [x] A data-driven way to script a pattern: optional enemy field `pattern` (contract commit), for
  example Goblin Bouncer `["guard_up", "hit"]`. (`test_pattern_followed_exactly`,
  `test_bouncer_pattern_and_guard_reset`)
- [x] Targets: one Dude, or `MULTI_TARGET_COUNT` (2) different Dudes at `MULTI_TARGET_PARTY_SIZE`
  players; never a Passed Out Dude; area attacks (move `"target": "all_dudes"`) hit everyone.
  (`tests/core/ai/test_targeting.gd`, `test_multi_target_in_fight`, `test_area_attack_in_fight`,
  `test_passed_out_target_is_skipped`)
- [x] Fixed-seed test: a recorded intent sequence for a two-move enemy over 20 turns
  (`test_twenty_turn_recorded_intents`).
- [x] G30: enemy Guard drops to 0 at the start of its own action (`test_bouncer_pattern_and_guard_reset`).

## Notes

- The AI is in `core/ai/`: `move_choice.gd`, `targeting.gd`, and `intents.gd`, the entry point
  that `core/combat/fight.gd` calls. The rules are written out in each file's header.
- `combat_ai` is drawn only when there is a real choice: two or more candidate moves, or more
  standing Dudes than targets needed. Solo fights against single-move enemies never move it.
- Contract changes are in their own commits, so each can be split into its own PR:
  - Schema (`docs/changes/2026-10-10-011-schema.md`): enemy `pattern`, move `target` and
    `MOVE_TARGETS`, enemy-state `move_history`, `SCHEMA_VERSION` 1 to 2.
  - Constants (`docs/changes/2026-10-10-011-constants.md`): `MULTI_TARGET_COUNT` = 2.

## Log

- 2026-10-10 A: G11 answered "accept". G30 ("an enemy's Guard drops to 0 at the start of its own
  action, before it acts") was given as accepted by the lead. G30 is not yet written in
  `docs/proposals/solo-slice-rule-gaps.md` on this branch.
- 2026-10-10 A: Done. Task 007's stub is replaced by `core/ai/`, including the G30 reset.
  - The schema contract commit also re-records `SAMPLE_HASH` in `tests/run/save/test_snapshot.gd`
    and `FINAL_HASH` in task 007's fixed-seed fight. A new state field changes the snapshot bytes.
  - Task 007's fixed-seed fight is shortened. Under G30 the Turtle's Guard no longer piles up, so
    the fight is won in turn 4. The reason is in `docs/changes/2026-10-10-011.md`.
  - The test fixture Dummy's `unused` move is now weight 0, so the existing flow tests keep a
    Dummy that always swings.
  - Verified with `tools/test.sh` from the worktree root: `152 passed, 0 failed`. The run includes
    `test_purity` and `test_documentation`.
- 2026-10-10 A: Not done, or outside this task's files:
  - `core/ops/README.md` (task 009's files) still says "Enemy Guard is never reset" in the `guard`
    op section. Since G30 that line is stale; whoever edits that file next should change it to
    "drops to 0 at the start of the enemy's own action (G30, core/ai/intents.gd)".
  - Content files (task 010) can use `pattern` and `target` only after the contract commit merges.
  - Summoned enemies (`enemy_spawned`, task 017) will need `Intents.set_intent_in_place` called when
    they join mid-fight. Nothing spawns yet.
- 2026-10-10 A: Rules the GDD does not decide. Each was implemented as below; both people please
  confirm:
  1. **A target passes out before the enemy acts.** It is skipped, not re-aimed: the intent the
     players saw is kept. If every target is down, the move's targeted effects land on nobody,
     and its effects on the enemy itself still happen. This is task 007's behavior, now tested.
  2. **An enemy with only one move of weight above 0** (Goblin Pledge in the GDD has one move). The
     no-three rule cannot hold, so the ban is lifted and it repeats. The GDD says enemies have
     2–4 moves; content may want to give such enemies a second move instead.
  3. **A skipped action** (Grossed Out or Armless, task 009). The skipped move still counts in
     `move_history`, because it is recorded when the intent is chosen. So it counts toward the
     no-three rule, and a pattern moves on past it rather than retrying it. The G30 Guard reset
     still happens for an enemy that then skips its action.
  4. **No pattern and no move with weight above 0** (a content error). The intent is `null`, there
     is no `intent_set`, and the enemy does nothing. Content validation should reject such files.
  5. **Party size, not standing Dudes, decides the target count.** If fewer Dudes are standing
     than the count, every standing Dude is hit.
  6. **The "2" in "single-target attacks hit 2 Dudes"** is the new constant `MULTI_TARGET_COUNT`.
     The "three in a row" limit is a code constant, `MAX_REPEATS` = 2, treated as a rule rather
     than a tuning number. Either could move into `constants.json` if the people prefer.
- 2026-10-10 A (lead): Split for review. Schema changes are contract PR `a/011-contract`; MULTI_TARGET_COUNT
  moved into the constants contract PR (#24). This branch = task 007 (#23) + both contract branches +
  the implementation. `tools/test.sh` -> 152 passed, 0 failed.
