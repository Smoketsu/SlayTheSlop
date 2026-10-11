---
id: 037
title: Power trigger "self_damaged" (Tough Skull)
lane: core
owner: A
status: done
branch: a/037-self-damaged-trigger
depends_on: [013, 015]
blocked_on: []
files:
  - core/schema/card_def.gd      # POWER_WHENS gains "self_damaged": separate contract PR first
  - core/combat/powers.gd
  - core/ops/ops.gd              # PLAYED_CARD_KEY, passes the self-damaged Dude to Powers.reactions
  - core/combat/play.gd          # marks a played card's effects
  - core/ops/README.md
  - tests/core/
---

## Goal

`tom_tough_skull` (Tough Skull, accepted in `docs/proposals/tom-slice-cards.md`) is a Power:
`power_triggers: [{"when": "self_damaged", "target": "self", "effects": [guard 3]}]`. Add the
trigger `when: "self_damaged"`: it fires each time the Power's own Dude takes damage from their own
card's `self_damage` effect (Skull Bash, Pickup Line, Noggin Knock, Headbutt), and not from enemies,
Burn or Bedbugs. Requested in task 012's proposal, "Ops this needs from Agent A", item 2.

## Read first

- `core/combat/powers.gd` (`WHEN_*` values and the events that fire them).
- `core/ops/self_damage.gd` (who uses it: Tom's cards, and Junk's `on_draw` / `on_end_of_turn_in_hand`).
- `core/ops/ops.gd` `fire_power_triggers_in_place` and `MAX_TRIGGER_DEPTH` (task 031).
- `core/schema/card_def.gd` `POWER_WHENS` (a contract).

## Acceptance checks

- [x] Contract PR (nothing else in it): `card_def.gd` `POWER_WHENS` gains `"self_damaged"`, with its
      comment and change file. Additive; needs Person B's approval.
- [x] A Power with `when: "self_damaged"` fires once per `self_damage` effect from its owner's own
      card, including when Guard absorbs all of it (G49's rule for thorns); an amount of 0 fires
      nothing.
- [x] It does not fire for enemy damage, Burn, Bedbugs or another Dude's card.
- [x] Fires after the damage is dealt; if the self-damage Passes Out the Dude, it does not fire
      (G34: a Passed Out Dude's Powers do not fire).
- [x] Tough Skull's data shape: Skull Bash with Tough Skull in play gives 3 Guard after the 2 self-damage.
- [x] `tools/test.sh` passes; fixed-seed hashes unchanged or re-recorded with the reason.

## Notes

- "From their own card" covers a card's `effects`; Junk triggers are excluded even though they use
  the same op, because the proposal names them. The op needs to know which kind of source ran it;
  the op context may already say so (card play vs card trigger). Record the rule as a gap if the
  GDD or the proposal leaves a case open.

## Log

- 2026-10-11 A: Created and claimed. Smoketsu (Person A) accepted all 16 new Tom cards on
  2026-10-11; steamjgrube (Person B) accepts by approving the board PR that adds this file.
- 2026-10-11 A: Contract merged in #92 (`POWER_WHENS` gains `"self_damaged"`).
- 2026-10-11 A: Built, in review on `a/037-self-damaged-trigger`.
  - How "from their own card" is told apart: `core/combat/play.gd` sets `Ops.PLAYED_CARD_KEY` in a
    played card's op context. `core/ops/ops.gd` `run()`, after a `self_damage` effect with that key,
    passes the actor to `Powers.reactions(..., self_damaged_id)`. A `damage_dealt` with no source on
    that Dude, amount above 0, fires that Dude's `self_damaged` Powers only (`matching(...,
    only_player_id)`). Junk triggers, Gear, Brews, the Bro Move, enemy moves and Power effects have
    no such key, so they never fire it. `core/ops/self_damage.gd` needed no change.
  - "Above 0" uses the event's `amount` (before Guard), so a hit Guard takes whole still fires;
    `self_damage` 0 emits no event, so it fires nothing.
  - Tests: `tests/core/ops/test_self_damaged_trigger.gd` (6): Skull Bash fires Tough Skull once,
    in order (damage, power_triggered, guard); through full Guard, once per copy; 0 fires nothing;
    Burn and an enemy hit fire nothing; Passed Out by it fires nothing; co-op, only the hurt Dude's.
  - Verified: with `PLAYED_CARD_KEY` forced false in `play.gd`, the two firing tests fail.
    `tools/test.sh`: 487 passed, 0 failed. Fixed-seed hashes unchanged.
  - Not done: Tough Skull's data (`tom_tough_skull`) is Agent B's.
- 2026-10-11 A: Done. Merged in #97 (contract #92). Tough Skull's data is Agent B's.
