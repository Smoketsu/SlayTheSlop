---
id: 035
title: Cards that target a Dude ("ally"), and Guard that lands on them (Bro Hug)
lane: core
owner: A
status: done
branch: a/035-ally-targets
depends_on: [013, 021]
blocked_on: []
files:
  - core/combat/play.gd          # legal targets of a play_card request
  - core/ops/guard.gd            # where Guard lands for an ally card
  - core/ops/ops.gd
  - core/ops/README.md
  - docs/proposals/solo-slice-rule-gaps.md   # one new gap entry (G62)
  - tests/core/
---

## Goal

`tom_bro_hug` (Bro Hug, accepted in `docs/proposals/tom-slice-cards.md`) is the first card with
`target: "ally"`: "Target Dude gains 7 Guard". Today a card with `target: "ally"` is refused as
`bad_target` (`core/ops/README.md`, "not built"). Build it so a card with `target: "ally"` lands on
the Dude the player picks (`play_card` `target_id` = that Dude's `player_id`), and its `guard`
effect gives the Guard to that Dude instead of the actor. In solo the only legal pick is the
player's own Dude (GDD "Card types and keywords": Assist). Requested in task 012's proposal, "Ops
this needs from Agent A", item 1.

## Read first

- GDD "Card types and keywords" (Assist), "Turn flow".
- `core/combat/play.gd` (how a play's targets are chosen) and `core/combat/brews.gd` `targets()`,
  which already resolves `"ally"` for Brews and should be the model, so cards and Brews agree.
- `core/ops/guard.gd` (Guard lands on the actor today) and `core/ops/README.md`.

## Acceptance checks

- [x] A card with `target: "ally"` and `target_id` = a Dude's `player_id` is accepted; its effects'
      targets are that Dude. An empty `target_id`, an enemy uid or an unknown id is `bad_target`.
- [x] A Passed Out Dude can't be picked (`bad_target`), matching Brews.
- [x] `guard` on an `ally` card gives the Guard to the picked Dude (`guard_changed` with that Dude's
      `player_id`); on every other card it still lands on the actor, so no existing card changes.
- [x] Solo: Bro Hug's data shape, picking the player's own Dude, gives 7 Guard (fixture test).
- [x] Co-op shape (2 Dudes in state, no networking): one Dude's Bro Hug guards the other.
- [x] `core/ops/README.md` no longer lists `ally` as not built; `puppet` still is.
- [x] Fixed-seed hashes unchanged, or re-recorded with the reason in the log. `tools/test.sh` passes.

## Notes

- No contract change expected: `"ally"` is already in `core/schema/card_def.gd` `TARGETS`, and
  `play_card` already carries `target_id`. If one turns out to be needed, it goes in its own PR.
- The client (Agent B) must let the player pick a Dude for an ally card; until it does, it can send
  the local player's own `player_id`.

## Log

- 2026-10-11 A: Created and claimed. Smoketsu (Person A) accepted all 16 new Tom cards on
  2026-10-11; steamjgrube (Person B) accepts by approving the board PR that adds this file.
- 2026-10-11 A: Built, in review on `a/035-ally-targets`.
  - `core/combat/play.gd` `targets()`: `"ally"` takes the `player_id` of any Dude who is not Passed
    Out, the player's own included; anything else is `bad_target`. `ALLY_TARGET` constant. For an
    ally card it sets `GuardOp.ON_TARGETS_KEY` in the op context.
  - `core/ops/guard.gd`: with `ON_TARGETS_KEY`, each target gains the Guard instead of the actor;
    `gain_in_place` takes an optional `receiver_id`: the giver's Chill applies, the receiver's
    Hungover. Without the key nothing changes (every existing card, Gear, Brew and enemy move).
  - Rule gaps the GDD leaves open are G62 in `docs/proposals/solo-slice-rule-gaps.md`, built as
    suggested (accepted under Smoketsu's standing instruction).
  - Correction to "Read first": `core/combat/brews.gd` does not resolve `"ally"`; Brews still refuse
    it (`bad_target`), so Brews are unchanged. Only `guard` honours the ally target;
    `guard_per_broken_arm` (Cast Party, a `self` card) still lands on the actor.
  - `tests/core/combat/test_core_apply.gd`: the old check that an ally card on `"p1"` is
    `bad_target` now checks `""` and an enemy instead (an own-Dude target is legal now).
  - Tests: `tests/core/ops/test_ally_targets.gd` (5): solo Bro Hug on yourself; bad targets (none,
    enemy, unknown, Passed Out); co-op hug guards only the teammate; giver's Chill and receiver's
    Hungover; Guard on an enemy-target card still lands on the player.
  - Verified: with the flag forced off in `play.gd`, the co-op and Chill/Hungover tests fail.
    `tools/test.sh`: 473 passed, 0 failed. Fixed-seed hashes unchanged.
  - Not done: the client's Dude pick (Agent B); Bro Hug's data (Agent B).
- 2026-10-11 A: Done. Merged in #96. Follow-up in the board PR: the run tests' fight bot
  (`tests/run/fixtures/run_helpers.gd` `bot_request`) now plays ally cards on its own Dude
  (`tests/run/test_bot_helpers.gd`). Bro Hug's data merged in #98.
