---
id: 009
title: Damage order, statuses, Broken Arm and Ick
lane: core
owner: A
status: done
branch: a/009-damage-order-and-statuses
depends_on: [007]
blocked_on: []
files:
  - core/combat/
  - core/ops/
  - tests/core/combat/
  - tests/core/ops/
  - core/schema/enemy_state.gd, core/schema/run_state.gd, core/schema/README.md, tests/core/schema/, tests/run/save/test_snapshot.gd (contract commit only)
---

## Goal

The GDD damage order exactly, the four general statuses, and both halves of Tom's kit, so every
number the player sees matches the GDD.

## Read first

GDD "Damage order", "Statuses", "Tom, the Enforcer"; `data/constants.json`.

## Acceptance checks

- [x] Damage: (base + Swole) × Noodle (0.75) × Broken Arm factor (enemy attackers) × Exposed (1.5), rounded down **once**, at step 5, then Guard, then HP. Exact arithmetic: no float drift. For example, compute with integer numerators and denominators from the constants, or show by test that every product of the constants at slice values rounds correctly. (`core/ops/damage.gd` with exact fractions from `core/ops/ratio.gd`; `test_damage_order.gd` `test_every_product_rounds_exactly`, `test_rounding_happens_once`, `test_ratios_are_exact`.)
- [x] Table-driven tests for the damage order, including every combination of the three multipliers, with k of n arms broken for n = 2. (`test_enemy_attack_table`, all 12 combinations with Swole and Guard, played through `Core.apply`; `test_dude_attack_table`.)
- [x] Exposed, Noodle Arms, Hungover, Foggy: apply, stack, wear off as answered in G1. Hungover Guard rounding as G4. (`test_apply_status.gd`, `test_statuses.gd`.)
- [x] `apply_status` with `broken_arm` raises `broken_arms` up to `arm_count`; Armless as G7, once per fight (`armless_used`). (`test_broken_arm_cap_and_zero_arms`, `test_armless_once_per_fight`, `test_armless_waits_for_a_damaging_move`.)
- [x] `apply_status` with `ick` adds to `ick` (Clout as G5); Grossed Out as G6, with threshold + `ICK_THRESHOLD_STEP`. (`test_ick_with_clout`, `test_grossed_out`, `test_grossed_out_skip`, `test_two_grossed_out_skips`.)
- [x] Ick thresholds start from `ICK_BASE_*` by tier, scaled by the party HP multiplier and rounded up (solo: unchanged). (Task 007 already did this; `test_ick_thresholds_by_tier_and_party` checks every tier for party sizes 1–4.)
- [x] Every tuning number comes from `ruleset.constants`. No value from `constants.json` (0.75, 1.5, 0.4, the Ick bases, the step) is written as a literal in `core/`; the PR description says how this was checked. (See the log.)

## Log
- 2026-10-10 A: Claimed. Every rule gap it waited on is answered "accept" (PR #20).
- 2026-10-10 A: Built on branch `a/009-damage-order-and-statuses`, on top of task 007's unmerged
  branch (PR #23). The lead assigned the task; G1–G7 and G27 were answered "accept", so the
  "Suggested" text in `docs/proposals/solo-slice-rule-gaps.md` is the rule. That file in this
  checkout still shows the answers blank.
  **Done:**
  - **Contract commit (first, schema only):** `enemy_state.grossed_out_skips` (int, 0 or more),
    `SCHEMA_VERSION` 1 -> 2, and a README note. Two test hashes were re-recorded:
    `tests/run/save/test_snapshot.gd` `SAMPLE_HASH` (the sample has enemies) and task 007's
    `FINAL_HASH`. The fixed-seed fight's hash changed only through `schema_version`. With
    `SCHEMA_VERSION` set back to 1, the old hash matched again; that was checked by hand.
    See `docs/changes/2026-10-10-009-schema.md`.
  - **Damage order** in `core/ops/damage.gd` (`hit_amount`, `multiplier`, `broken_arm_factor`).
    Exact fractions come from `core/ops/ratio.gd`, with constants turned into reduced fractions
    through `party_scaling.gd` `to_millionths`. G3: only attack damage (Attack cards, enemy moves;
    Bro Moves when task 013 builds them) gets Swole and the multipliers.
  - **Hungover** (G4) in `core/ops/guard.gd`. **`apply_status`** in `core/ops/apply_status.gd`.
    **Statuses in the turn flow** in `core/combat/statuses.gd`, with small hooks in `fight.gd`
    marked "Task 009" (constants check, Foggy at Refresh, Dude wear-off at End of turn, the enemy
    skip check, enemy wear-off after its slot, context).
  - Cards with `apply_status` now play (Arm Bar plays, `test_status_cards_now_play`).
  - `core/ops/README.md` documents the damage order and `apply_status`.
  - **Tests:** 27 new tests in `tests/core/ops/test_damage_order.gd`,
    `tests/core/ops/test_apply_status.gd`, `tests/core/combat/test_statuses.gd` and
    `tests/core/combat/test_fixed_seed_status_fight.gd`, plus one schema test. The fixed-seed
    status fight uses seed 9009 and a deterministic bot. It is won in turn 8 after 32 requests,
    with two Grossed Outs on the Hitter and one on the Slime, one Armless skip, and wear-off events.
    The hash is recorded, every event and state is schema-checked and round-tripped, and two
    replays are byte-identical. Every event in that fight was read by hand; for example, the
    Armless Hitter later hits for 10 × 0.6 = 6.
  - **Verified:** `tools/test.sh` from the worktree root -> `153 passed, 0 failed`. That includes
    the purity and documentation lints.
  - **No literal constants in `core/`:** searched `core/**/*.gd` with comments excluded for
    `[^\w.](0\.75|1\.5|0\.4|0\.8|0\.3)\b` (no matches) and for the whole numbers `3|5|8|12`
    (only the byte sizes in `core/run/save/snapshot.gd`, task 027). The integer rule constants
    added here are `WEAR_PER_TURN` = 1, `FOGGY_DRAW_PER_STACK` = 1 and `SKIPS_PER_GROSSED_OUT` = 1.
    Each is named and documented as GDD rule text ("1 stack per turn", "1 fewer card", "its next
    action"). None is in the tuning table.
  **Not done:**
  - G9 (Chrome Dome thorns) is not built; it is task 013. Bro Moves do not exist yet; task 013
    must pass `attack` = true when it plays one.
  - Enemy move choice, intents, targeting and enemy Guard reset belong to task 011. Enemies still
    use task 007's first-move stub.
  **Decisions for the people to confirm (the GDD and the gap answers do not say):**
  1. Two Grossed Outs before the enemy acts cost two actions. `grossed_out_skips` is a count,
     following G6's "Ick applied while it is already waiting to skip still counts". If the answer is
     "one skip at most", cap the count at 1 in `apply_status.gd`; no schema change is needed.
  2. Foggy draws 1 fewer card **per stack**, as the lead's brief asked. The GDD's "Draws 1 fewer
     card" next to "1 stack per turn" could also mean 1 fewer while Foggy, with stacks as duration,
     the way Exposed is × 1.5 whatever its stacks. Changing this is one line in
     `statuses.gd` `refresh_draw_count`.
  3. `ICK_THRESHOLD_STEP` is added unscaled in co-op. The GDD scales only the starting thresholds.
     For a duo, a Pledge goes 9 -> 12.
  4. A status a body cannot carry does nothing (Hungover or Foggy on an enemy, Broken Arm or Ick on
     a Dude). This follows the GDD's "On" column.
  5. Passed Out Dudes' statuses do not wear off, because they skip turns, as they skip Refresh.
  6. An enemy's statuses wear off after its slot even when it skipped (Grossed Out or Armless).
     Grossed Out is used before Armless; Armless then waits for the next damaging move.
  7. Clout is added to Ick for any Dude who applies Ick. It is Tom's signature today. When other
     Dudes exist, Clout should only add to the Dude's own signature effect, and that needs a data
     field (for example a `signature` on the Dude definition). Not invented here.
  8. Swole is not added to non-attack damage, because Swole is "added to every hit of every attack".
     No current card has non-attack `damage`.
  **Found (consequences of G1 worth a look, no rule invented):**
  - 1 stack of Exposed applied to a Dude by an enemy wears off at the Dude's End of turn, before
    the next enemy phase. It only matters against enemies acting later in the same enemy phase.
    Enemy debuffs on Dudes need 2+ stacks to matter.
  - Noodle Arms applied to an enemy that then skips (Grossed Out) wears off without effect.
  - Nothing clears statuses, Guard or Ick when a fight ends. Dude statuses stay in the run state
    after a fight. Whether statuses end with the fight is a new gap. Suggested: statuses clear at
    fight end; this belongs to the run flow, task 025.
  **Merge note:** task 011 runs in parallel from the same base and may also add enemy fields and
  raise `SCHEMA_VERSION`. Whichever merges second sets it to 3 and re-records the two hashes. In
  `fight.gd`, 011 will touch `stub_intent` and the enemy loop. This task's edits there are one-line
  calls marked "Task 009".
- 2026-10-10 A: The lead reports task 011 is done on its own branch. It adds enemy `move_history`,
  sets `SCHEMA_VERSION` to 2, removes `stub_intent`, and calls `begin_action_in_place` (the G30
  enemy Guard reset) just before `_enemy_act_in_place`. When the branches merge:
  - Raise `SCHEMA_VERSION` to 3, because both branches change the shape.
  - Re-record both fixed-seed hashes.
  - In the enemy loop, the order is: `begin_action_in_place`, then
    `Statuses.skip_action_in_place` (which acts only if it returns false), then
    `Statuses.after_enemy_slot_in_place`.
  - Open question: should a Grossed Out or Armless enemy still lose its Guard? A skipped action
    is still the start of its own action, so the suggested answer is yes, which the order above
    gives.

  Fixed the stale `core/ops/README.md` line that said enemy Guard is never reset. It now gives the
  G30 rule. This was a docs-only change; `tools/test.sh` was re-run.
- 2026-10-10 A (lead): Combined with task 011 for review. Schema change is contract PR `a/009-contract`
  (stacked on #30, SCHEMA_VERSION 2 -> 3). This branch = 011's branch (#31) + that contract + 009's work.
  Conflicts resolved: `fight.gd` enemy loop runs 011's G30 Guard reset, then 009's skip check, then
  wear-off (a skipping enemy still has its Guard reset). The test Hitter now has `pattern: ["punch"]` so
  009's tests don't depend on 011's random move choice. Both fixed-seed fights end exactly as recorded
  (same result, turn and request count); only their hashes were re-recorded, for the new field and
  version. `tools/test.sh` -> 180 passed, 0 failed.
- 2026-10-10 A: Merged in #33 by Agent A under Smoketsu's temporary permission (Person B offline). Status `done`.
