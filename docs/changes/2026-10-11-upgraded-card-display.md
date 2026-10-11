# 2026-10-11: Client shows upgraded card copies with their upgraded definition (task upgraded-card-display)

Author: Agent B. Branch: `b/upgraded-card-display`. Lane: client (plus a client test). No core,
data, schema or contract change.

## What changed

- **`client/fight/fight_model.gd`** `_card()`: a hand entry's name, cost, text and target now come
  from the copy's effective definition, `core/combat/upgrades.gd` `definition_of()` (the upgraded
  definition for a Lifted copy), instead of the base definition looked up by `def_id`. A Lifted
  copy's name ends with `RunText.UPGRADED_MARK` ("+"), the same mark the run screens' card lists use.
- **`client/fight/fight_screen.gd`** `_card_def()`: returns the copy's effective definition, so the
  decision of what to pick before a card is sent (`_pick_for()`, the auto target, and the re-ask
  after a `bad_target` reject) follows an upgrade that changes the target.
- **`client/fight/targeting.gd`**: reads a definition's `"target"` with `get(..., NONE)`, so a copy
  with no usable definition (`definition_of()` returns `{}`: G15, an upgrade that cannot apply)
  asks for nothing and the core refuses it as `unplayable`, instead of a script error.
- **`client/run/run_text.gd`** `card_copy_name()` (Lift and removal card lists on the offer
  screen): the name comes from the copy's effective definition (falling back to the base name, then
  the `def_id`), so an upgrade that renames a card shows the new name with "+".
- **`tests/client/test_upgraded_cards.gd`** (new): marks a copy upgraded with the core's own Lift
  path (`core/run/grants.gd` `upgrade_card_in_place()`) and checks, on frozen states:
  - a Lifted Arm Bar in hand shows as "Arm Bar+" with cost and text equal to `definition_of()`'s
    (and that definition deals 11), on the model and on the hand button; other cards have no "+";
  - the Lifted Arm Bar still asks for an enemy and plays through the screen;
  - an in-memory test card whose upgrade changes target `self` -> `enemy` and its name asks for an
    enemy only when Lifted, and shows the upgraded name with "+" in the hand and in
    `card_copy_name()`;
  - a copy marked upgraded whose card has no upgrade shows `<def_id>+`, cost "-", and is refused as
    unplayable without an error.

## Why

The fight hand showed the base definition's cost, text and name for a Lifted copy, so after a Lift
at The Tailgate the hand did not match what the core plays.

## Not changed

- `client/fight/event_text.gd` `names_for()`: event lines still name a card copy by its base
  definition's name, without "+". Its names are merged over the states before and after a request,
  so "card_upgraded" would read "Arm Bar+ is upgraded."; left as is for a writer to decide.
- The Bro Move button (`fight_screen.gd` `press_bro_move()`) reads the Dude's `bro_move` definition,
  which is not a card copy, so it has no upgrade to show.
- Card rewards and Baileys cards (`RunText.card_text()`) show new copies, which are never upgraded.

## Fields, variables and constants

- Added: `fight_model.gd` hand entry field `"upgraded"` (bool: true when the copy is Lifted,
  `dude_state` `cards[uid].upgraded`; read-only display value).
- Added: `fight_model.gd` constants `Upgrades` (preload of `core/combat/upgrades.gd`) and `RunText`
  (preload of `client/run/run_text.gd`, for `UPGRADED_MARK`).
- Added: `fight_screen.gd` constant `Upgrades` and `run_text.gd` constant `Upgrades` (preloads of
  `core/combat/upgrades.gd`).
- Added: `test_upgraded_cards.gd` constants `ARM_BAR_ID`, `ARM_BAR_UPGRADED_DAMAGE`, `REACH_ID`,
  `REACH_CARD`, `STUCK_ID`, `STUCK_CARD` (test-only, documented in the file).
- Nothing renamed or removed.
