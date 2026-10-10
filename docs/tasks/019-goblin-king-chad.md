---
id: 019
title: Goblin King Chad, the slice boss
lane: core
owner: A
status: done
branch: a/019-goblin-king-chad
depends_on: [017]
blocked_on: []
files:
  - core/combat/
  - core/ops/
  - core/ai/
  - core/schema/enemy_def.gd    # additive, separate contract commit
  - core/schema/enemy_state.gd
  - core/schema/event.gd
  - core/schema/run_state.gd
  - core/schema/README.md
  - tests/core/enemies/
  - tests/core/schema/
  - tests/core/combat/test_fixed_seed_fight.gd         # hash re-record only
  - tests/core/combat/test_fixed_seed_status_fight.gd  # hash re-record only
  - tests/run/save/test_snapshot.gd                    # hash re-record only
---

## Goal

Goblin King Chad plays as the GDD describes. Person A chose him as the slice's one boss on 2026-10-10.

## Read first

GDD "Goblin King Chad"; G12 and G13 in `docs/proposals/solo-slice-rule-gaps.md`.

## Acceptance checks

All in `tests/core/enemies/test_goblin_king_chad.gd`, against the fixture Chad in
`tests/core/enemies/enemy_fixtures.gd` (task 010's data has not merged).

- [x] Rush: every third turn, summons 2 Goblin Pledges. `test_kill_both_and_he_falls` (turn 3)
- [x] Keg Stand: charges for 2 turns, then hits one Dude for 30; each Pledge killed during the charge removes 10; kill both and he falls (skips a turn, Exposed 2). `test_start_and_keg_stand_begins`, `test_keg_stand_full_hit`, `test_keg_stand_cut_and_broken_arm`, `test_kill_both_and_he_falls`
- [x] Below 50% HP: Rage Cage, 6 damage 3 times, every turn he is not charging. `test_rage_cage_below_half`
- [x] His remaining turns as answered in G12 (Paddle Swat 12); starting Pledges as G13. `test_start_and_keg_stand_begins`, `test_kill_both_and_he_falls`
- [x] Ick threshold from `ICK_BASE_BOSS`. Arm count 2, so Broken Arm reduces the Keg Stand hit. `test_start_and_keg_stand_begins`, `test_keg_stand_cut_and_broken_arm` ((30 - 10) x 0.8 = 16)
- [x] Fixed-seed test of a full scripted fight against him. `test_scripted_fight` (seed 20261019; Chad's moves and the final state hash recorded after the outcome assertions passed)

## What Agent B's data (task 010) must use for Chad

Id `goblin_king_chad`, tier `boss`, `max_hp` 140, `arm_count` 2, and as in the fixture:
`tags: ["goblin"]` (so his Pledges never call for help), `arrives_with: ["goblin_pledge",
"goblin_pledge"]` (G13), `charge: {"move_id": <lift move>, "turns": 2, "release_move_id": <hit
move>, "helper_def_id": "goblin_pledge", "helpers": 2, "fall_exposed": 2}`, the hit move's effect
`{"op": "charged_hit", "amount": 30, "cut_per_helper_lost": 10}`, the lift move with `"target":
"none"` and no effects, and `move_rules` in this order: lift when `count_at_least goblin_pledge 2`;
Rage Cage (`damage 6, hits 3`) when `hp_below_percent 50`; Rush (`summon_enemy goblin_pledge,
count 2`) when `turn_cycle every 3, first_turn 3`; Paddle Swat (`damage 12`, weight 1) otherwise.

## Notes

Decisions where the GDD and G12 are silent (each in the code's file headers; confirm or change):

1. Rule order: a charge in progress beats everything; then Keg Stand (2 Pledges standing) beats
   Rage Cage, which beats Rush, which beats Paddle Swat. So below 50% with 2 Pledges up he still
   starts a Keg Stand ("Rage Cage every turn he is not charging"; the Keg Stand start turn counts as
   charging), and below 50% he never Rushes.
2. The charge's turns: the start turn and the next are the 2 charging turns (intent "lift", no
   targets); the hit is the third turn's intent, aimed like any single-target attack. Pledges killed
   at any time from the start turn's intent to the hit count.
3. The lifting Pledges are the first 2 Pledges left to right when the charge starts; a Pledge
   summoned later does not lift and its death does not count.
4. "Kill both and he falls": the moment the second lifter dies the charge ends, he gains Exposed 2
   and skips his next action (the current turn's charging or hit action). Exposed then wears off
   one stack per enemy slot (G1). His next intent is chosen normally.
5. A Grossed Out skip on the hit turn wastes the hit; the charge still ends.
6. The Keg Stand hit is attack damage: Swole, Noodle Arms, Broken Arm and Exposed apply after the
   cut, in the GDD damage order.

## Log

- 2026-10-10 A: blocked on G12 (his ordinary turn is not specified) and G13.
- 2026-10-10 A: Claimed. All rule gaps answered (#20). Started in parallel with its in-progress dependencies at Person A's instruction; shared op names are pinned (`draw`, `gain_hype`, `self_damage` from 013; `add_card`, `lose_hype` from 015).
- 2026-10-10 A: G12 and G13 answered "accept" (#20). Done. Two commits on top of task 017: contract
  schema (enemy `charge`, `fallen_skips`, events `charge_started` and `enemy_fell`, `SCHEMA_VERSION`
  7 by the lead's numbering) and implementation. Verified with `tools/test.sh`: all tests pass
  (exit 0). The three state hashes were re-recorded for the new shape after their other assertions
  passed; they must be re-recorded again when merged with tasks 013, 015 and 021. Not done: task
  010's real Chad data (tests use the fixture).
- 2026-10-10 A (lead): Stacked on the 017 rules PR (tasks 013, 015, 017, 021 below it) and the 019
  contract (#48, SCHEMA_VERSION 7). `SCRIPT_HASH` re-recorded after every outcome assertion passed
  (see `docs/changes/2026-10-10-019.md`).
- 2026-10-10 A: Merged with the whole stack in #50 (Agent B approved; 341 passed on `main`). Every
  rule gap it built on was accepted by steamjgrube in that review. Status `done`; open items, if any,
  are listed above (real data from Agent B's tasks).
