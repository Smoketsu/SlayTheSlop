---
id: 035
title: Cards that target a Dude ("ally"), and Guard that lands on them (Bro Hug)
lane: core
owner: A
status: in_progress
branch: a/035-ally-targets
depends_on: [013, 021]
blocked_on: []
files:
  - core/combat/play.gd          # legal targets of a play_card request
  - core/ops/guard.gd            # where Guard lands for an ally card
  - core/ops/ops.gd
  - core/ops/README.md
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

- [ ] A card with `target: "ally"` and `target_id` = a Dude's `player_id` is accepted; its effects'
      targets are that Dude. An empty `target_id`, an enemy uid or an unknown id is `bad_target`.
- [ ] A Passed Out Dude can't be picked (`bad_target`), matching Brews.
- [ ] `guard` on an `ally` card gives the Guard to the picked Dude (`guard_changed` with that Dude's
      `player_id`); on every other card it still lands on the actor, so no existing card changes.
- [ ] Solo: Bro Hug's data shape, picking the player's own Dude, gives 7 Guard (fixture test).
- [ ] Co-op shape (2 Dudes in state, no networking): one Dude's Bro Hug guards the other.
- [ ] `core/ops/README.md` no longer lists `ally` as not built; `puppet` still is.
- [ ] Fixed-seed hashes unchanged, or re-recorded with the reason in the log. `tools/test.sh` passes.

## Notes

- No contract change expected: `"ally"` is already in `core/schema/card_def.gd` `TARGETS`, and
  `play_card` already carries `target_id`. If one turns out to be needed, it goes in its own PR.
- The client (Agent B) must let the player pick a Dude for an ally card; until it does, it can send
  the local player's own `player_id`.

## Log

- 2026-10-11 A: Created and claimed. Smoketsu (Person A) accepted all 16 new Tom cards on
  2026-10-11; steamjgrube (Person B) accepts by approving the board PR that adds this file.
