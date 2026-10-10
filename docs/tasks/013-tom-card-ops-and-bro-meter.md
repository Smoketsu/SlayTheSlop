---
id: 013
title: Effect ops for Tom's cards, Powers, the solo Bro Meter and Chest Bump
lane: core
owner: A
status: in_review
branch: a/013-tom-card-ops-and-bro-meter
depends_on: [009]
blocked_on: []
files:
  - core/combat/
  - core/ops/
  - tests/core/ops/
---

## Goal

Every effect operation Tom's 14 GDD cards and his Bro Move need, so task 006's data plays exactly as
the GDD text reads.

## Read first

GDD "Tom, the Enforcer" (card table), "Bro Meter", "Card types and keywords"; `core/ops/README.md`
(from task 007); task 006's requested-ops list, if it exists.

## Acceptance checks

- [x] Ops (names to settle with task 006): `draw`, `gain_hype`, `self_damage`; conditions such as "if the target has a Broken Arm" (Wrist Lock) and "if the target is now Armless" (Snap City); "per Broken Arm on all enemies" (Cast Party); `all_enemies` targeting (Pickup Line); thorns for this turn (Chrome Dome).
- [x] Powers: a played Power stays for the fight; triggers for Reply Guy (enemy gains a buff, G10) and Friend Zone (start of turn; Grossed Out → Exposed 2). Fight-scoped Power state needs a contract PR adding fields to `dude_state.gd` (or combat).
- [x] Keywords `tapped` and `pocketed`.
- [x] Bro Meter, solo: +1 for every third card played in a turn (3rd, 6th ...), capped at `BRO_METER_MAX`. `use_bro_move` at max empties it and plays the Dude's `bro_move` card for free (`not_ready` otherwise).
- [ ] One test per Tom card, using its real data file once task 006 has merged, and the GDD number in the assertion. **Half done:** one test per card with the GDD number exists (`tests/core/ops/test_tom_cards.gd`), on in-memory fixture copies of the GDD cards (`tests/core/ops/tom_fixtures.gd`). Task 006 has not merged, so the real-data part is not done.
- [x] `core/ops/README.md` lists every op added.

## Notes

- Op names and fields for task 006 are in `core/ops/README.md`, with a table "Tom's cards, written
  with these ops" giving each card's exact effects. Chest Bump needs `target: "enemy"` and its arm
  break written `{"op": "apply_status", "status": "broken_arm", "stacks": 1, "target": "all_enemies"}`.
  Powers use the new optional card field `power_triggers` (`core/schema/card_def.gd`).
- The client (task 018) sends `use_bro_move` with no `target_id`; Chest Bump targets one enemy, so
  that request is `bad_target` until the client sends `target_id` (gap G33).
- Task 015 (Junk) runs in parallel and edits `play.gd`, `fight.gd` and probably `piles.gd`; this
  task's edits there are small and marked "Task 013".

## Log
- 2026-10-10 A: Claimed. Every rule gap it waited on is answered (#20); task 009 is merged.

- 2026-10-10 A: Built on branch `a/013-tom-card-ops-and-bro-meter`, three commits:
  1. **Contract only** (`core/schema/` + `tests/core/schema/` + `docs/changes/2026-10-10-013-schema.md`
     + re-recorded hashes): `dude_state.powers`, `dude_state.thorns`, card `power_triggers`, optional
     `use_bro_move.target_id`, events `bro_move_used`, `thorns_changed`, `power_triggered`;
     `SCHEMA_VERSION` 3 → 4. Additive only.
  2. Gaps G32–G34 added to `docs/proposals/solo-slice-rule-gaps.md` (unanswered; built as suggested).
  3. The implementation, tests, README and `docs/changes/2026-10-10-013.md`.
- **Done:** ops `draw`, `gain_hype`, `self_damage` (lead's names and fields), `guard_per_broken_arm`,
  `thorns`; generic effect fields `if` (`target_has_broken_arm`, `target_now_armless`) and `target`
  (`all_enemies`); Powers with `turn_start`, `enemy_buffed`, `enemy_grossed_out` triggers; thorns per
  hit; pocketed; solo Bro Meter; `use_bro_move` with Chest Bump. Double Arm Day needs no new op:
  `damage 9, break 1, damage 9, break 1`.
- **Verified:** `tools/test.sh` from the worktree root → `232 passed, 0 failed`. Every new test
  checks each event with `event.gd` and each state with `run_state.check()`. The new fixed-seed
  fight (`test_tom_fixed_seed_fight.gd`, seed 20261013) is won in turn 5 after 18 requests, uses
  Chest Bump once, survives a snapshot round trip at every step and replays byte-identically.
- **Re-recorded:** the two task 007/009 fixed-seed `FINAL_HASH`es (twice: once in the contract
  commit for the new fields, once because the solo Bro Meter now fills in those fights). With the
  Bro Meter gain switched off by hand both matched the contract commit's hashes; all outcome
  assertions still hold. `SAMPLE_HASH` re-recorded in the contract commit only.
- **Not done / stubbed:** the co-op Bro Meter rule ("attacks an enemy a different player debuffed
  this turn") is not built; in co-op the meter never gains (documented in `bro_meter.gd`). It needs
  per-enemy "debuffed by" state (a contract change). No op raises an enemy's Swole yet, so Reply
  Guy reacts to enemy Guard only; the Swole op (task 017) must emit an event listed in
  `powers.gd` `BUFF_EVENTS`. Powers clear when the next fight starts (`Piles.prepare_for_fight_in_place`),
  not at fight end; task 025 may clear them at fight end too. Tests on task 006's real files: not
  done (not merged).
- **Decisions for the people** (beyond G32–G34):
  - Thorns trigger on every enemy hit, even one Guard fully absorbs; two Chrome Domes stack to 6; an
    enemy killed by thorns loses the rest of its hits.
  - Conditions are checked when the effect is reached. Wrist Lock that kills its target does not
    draw (a dead target has no Broken Arm). "Now Armless" is true for a target that was already
    Armless before Snap City.
  - Cast Party with no Broken Arms still adds Chill (the `guard` rule: Chill once per effect).
  - The Bro Move is not a card played: it does not count toward `cards_played_this_turn`, the Bro
    Meter or (later) Detention. It is attack damage (G3) and counts as from a card (Hungover).
  - The solo Bro Meter point is added after the card resolves, also when that card ends the fight;
    the meter is run state and carries to the next fight.
  - `turn_start` Powers fire after every Dude's Refresh, so Friend Zone's Ick lands after the
    enemies have shown their intents.
