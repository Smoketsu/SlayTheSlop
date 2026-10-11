---
id: 037
title: Power trigger "self_damaged" (Tough Skull)
lane: core
owner: A
status: in_progress
branch: a/037-self-damaged-trigger
depends_on: [013, 015]
blocked_on: []
files:
  - core/schema/card_def.gd      # POWER_WHENS gains "self_damaged": separate contract PR first
  - core/combat/powers.gd
  - core/ops/self_damage.gd
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

- [ ] Contract PR (nothing else in it): `card_def.gd` `POWER_WHENS` gains `"self_damaged"`, with its
      comment and change file. Additive; needs Person B's approval.
- [ ] A Power with `when: "self_damaged"` fires once per `self_damage` effect from its owner's own
      card, including when Guard absorbs all of it (G49's rule for thorns); an amount of 0 fires
      nothing.
- [ ] It does not fire for enemy damage, Burn, Bedbugs or another Dude's card.
- [ ] Fires after the damage is dealt; if the self-damage Passes Out the Dude, it does not fire
      (G34: a Passed Out Dude's Powers do not fire).
- [ ] Tough Skull's data shape: Skull Bash with Tough Skull in play gives 3 Guard after the 2 self-damage.
- [ ] `tools/test.sh` passes; fixed-seed hashes unchanged or re-recorded with the reason.

## Notes

- "From their own card" covers a card's `effects`; Junk triggers are excluded even though they use
  the same op, because the proposal names them. The op needs to know which kind of source ran it;
  the op context may already say so (card play vs card trigger). Record the rule as a gap if the
  GDD or the proposal leaves a case open.

## Log

- 2026-10-11 A: Created and claimed. Smoketsu (Person A) accepted all 16 new Tom cards on
  2026-10-11; steamjgrube (Person B) accepts by approving the board PR that adds this file.
