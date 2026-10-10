---
id: 021
title: Gear and Brew definition formats, triggers, and use_brew
lane: core
owner: A
status: in_review
branch: a/021-gear-and-brew-format-and-effects
depends_on: [013, 015]
blocked_on: []
files:
  - core/schema/gear_def.gd     # new contract file, in its own PR first
  - core/schema/brew_def.gd     # new contract file, in its own PR first
  - core/schema/                # contract part 2: combat_state, event, run_state (additive), README
  - core/combat/
  - core/ops/
  - core/core.gd               # use_brew routing and the end-of-fight Gear hook
  - core/ruleset/              # register data/gear/ and data/brews/, check starting_gear
  - tests/core/ruleset/
  - tests/core/items/
  - tests/core/schema/
  - tests/core/combat/         # fixtures (test_gear), re-recorded hashes
  - tests/core/ai/ai_fixtures.gd  # builds with test_gear now that starting_gear is checked
  - tests/run/save/test_snapshot.gd  # re-recorded SAMPLE_HASH
  - docs/proposals/item-rule-gaps.md
---

## Goal

Gear and Brews are data, like cards. Define their formats (the GDD has none), the trigger points
Gear hooks into, and the `use_brew` request, so task 014 can write the slice's 10 Gear and the Brews.

## Read first

GDD "Items" (all tables), "Tom, the Enforcer" (Unused Gym Membership); task 014.

## Acceptance checks

- [x] Contract PR first: `gear_def.gd` and `brew_def.gd` (id, name, rarity, owner Dude or general/boss, effects or triggers), with tests in `tests/core/schema/`.
  Commit "Contract: Gear and Brew definition formats"; tests `tests/core/schema/test_item_defs.gd`.
- [x] Trigger points, at least: stat change while owned, start of fight, first turn, end of fight, each card play by kind. Enough for every Gear chosen in G16.
  `stats` (while owned), `fight_start`, `first_turn`, `fight_end`, `card_played` (with `card_type` / `min_cost`), `ick_applied` (Body Spray), and `modifiers` (Championship Ring, Medical Card, Dad's Platinum Card). `core/combat/gear_triggers.gd`, documented in `core/ops/README.md` "Gear".
- [x] `use_brew`: costs no Hype, any time in the player phase; empties the slot; `brews_drunk` + 1; `empty_slot` reject.
  `core/combat/brews.gd`; also `unplayable` and `bad_target`. `tests/core/items/test_brews.gd`.
- [x] Add `data/gear/` (and `data/brews/`) to `core/ruleset/ruleset.gd` `KINDS`, check each Dude's `starting_gear` against it, and flip `test_starting_gear_is_not_checked_yet` (moved here from task 005).
  Now `test_starting_gear_must_name_gear`, plus `test_bad_gear_and_brew_files_are_reported`.
- [ ] One test per slice Gear and Brew, using task 014's data once merged.
  Done with fixtures (`tests/core/items/item_fixtures.gd`) for every item whose ops exist on main.
  Backwards Cap, Energy Drink, Special Brownie and Beer Helmet's Hangover need task 013/015 ops; their
  tests are in the last commit of this branch and pass only once 013 and 015 are merged (see Log).
  Switching to task 014's real files waits on 014.

## Notes

### The format task 014 must follow

`tests/core/items/item_fixtures.gd` `GEAR` and `BREWS` hold all 13 Gear and 8 Brews written exactly
as task 014 should write them (one file each in `data/gear/<id>.json` and `data/brews/<id>.json`).
In short:

- Gear: `{"id", "name", "owner", "rarity", "text", "stats": {stat: int}, "triggers": [...],
  "modifiers": [...]}`. Owners `tom` (id prefixed `tom_`), `general`, `boss` (no prefix). Rarity
  `starter` for Unused Gym Membership, `boss` for the three Boss Gear (G28), else the GDD's.
- Stat Gear: `"stats": {"swole": 1}` (Lifting Belt), `{"chill": 1}` (Lucky Lighter),
  `{"max_hp": 8}` (Gallon Jug), `{"hype_per_turn": 1}` (Beer Helmet, Dad's Platinum Card),
  `{"draw_per_turn": 1}` (Cursed Intramural Trophy).
- Triggers: `{"when", "target", "effects", ...}`. Unused Gym Membership `fight_end`/`self`/`heal 6`;
  Arm Wrestling Table `fight_start`/`all_enemies`/`apply_status broken_arm 1`; Body Spray
  `ick_applied`/`trigger_target`/`damage 2` with `"amount_per_stack": true`; Backwards Cap
  `first_turn`/`self`/`draw 2`; Participation Trophy `fight_end`/`self`/`heal 8` with
  `"hp_below_percent": 50`; Beer Helmet `fight_start`/`self`/`add_card junk_hangover` to
  `draw_pile`, `shuffle_in` (but see I7); Cursed Trophy `fight_start`/`all_enemies`/`gain_stat swole 1`.
- Modifiers: Championship Ring `{"kind": "card_damage", "amount": 4, "card_type": "attack",
  "min_cost": 2}`; Medical Card `{"kind": "shop_price_percent", "amount": 80}`; Dad's Platinum Card
  `{"kind": "fight_dolla_bills_percent", "amount": 0}`.
- Brews: `{"id", "name", "rarity", "text", "target", "effects"}` plus optional `"solo": {"target",
  "effects"}`. Light Beer `self`/`heal 10`; Energy Drink `self`/`draw 3`; Protein Shake
  `self`/`gain_stat swole 3 "duration": "fight"`; Shot of Courage `all_enemies`/`apply_status exposed 3`;
  Special Brownie `self`/`gain_hype 2`, `add_card junk_hangover to discard_pile`; Hair of the Dog
  `self`/`remove_debuffs`, `tap_cards card_type junk`; Party Bowl `all_dudes`/`heal 8`; Smelling Salts
  `ally`/`[]` with `"solo": {"target": "self", "effects": [{"op": "prevent_pass_out", "hp": 1}]}`.

### Rules the GDD does not state

Built as suggested defaults and listed for the people in `docs/proposals/item-rule-gaps.md` (I1–I9):
Gallon Jug raises max HP only; Championship Ring is +4 per hit before the damage order; Body Spray
counts Clout and is not attack damage; end-of-fight Gear fires in the order gained and only after a
won fight; Party Bowl skips Passed Out Dudes; Beer Helmet's Hangover would stay in the deck (needs a
fight-only `add_card` option, I7); Smelling Salts' solo save does not stack; any Brew slot without a
Brew is `empty_slot`.

## Log
- 2026-10-10 A: Claimed. All rule gaps answered (#20). Started in parallel with its in-progress dependencies at Person A's instruction; shared op names are pinned (`draw`, `gain_hype`, `self_damage` from 013; `add_card`, `lose_hype` from 015).
- 2026-10-10 A: **Done.**
  - Contract part 1 (own commit): `core/schema/gear_def.gd`, `brew_def.gd`, README rows,
    `tests/core/schema/test_item_defs.gd`, `docs/changes/2026-10-10-021-item-formats.md`.
  - Contract part 2 (own commit): `combat_state` `fight_stat_changes` and `pass_out_saves`; events
    `gear_gained`, `gear_triggered`, `brew_used`, `stat_changed`, `pass_out_prevented`;
    `SCHEMA_VERSION` 4 → 5 (4 is 013's; renumbered by the lead at the merge); three state hashes
    re-recorded (bytes only); `tests/core/schema/test_item_state.gd`;
    `docs/changes/2026-10-10-021-schema.md`.
  - Core: `core/combat/gear_triggers.gd` (Gear gain, stats, trigger points, modifiers),
    `core/combat/brews.gd` (`use_brew`), five ops (`heal`, `gain_stat`, `remove_debuffs`,
    `tap_cards`, `prevent_pass_out`), the pass-out save in `bodies.gd`, small marked hooks in
    `fight.gd`, `play.gd`, `core.gd`, `party.gd`, `ops.gd` (context also carries `ruleset`), and the
    ruleset loading `data/gear/` and `data/brews/` and checking `starting_gear`.
  - Tests: `tests/core/items/test_gear.gd` (19), `test_brews.gd` (9),
    `test_fixed_seed_items_fight.gd` (2: recorded outcome `["won", 3, 80, 3, 15, 3]`, identical replays).
  **Not done:** tests on task 014's real data (not merged). Tests for Backwards Cap (turn 1 hand is
  BASE_DRAW + 2), Energy Drink (hand + 3), Special Brownie (+2 Hype, a `junk_hangover` copy on the
  discard pile) and Beer Helmet's Hangover (a `junk_hangover` copy created in the draw pile at fight
  start) are written in `tests/core/items/test_pending_ops.gd`, committed last and separately: they
  fail on main (no `draw`, `gain_hype`, `add_card`) and pass once 013 and 015 merge. Co-op Smelling
  Salts (waking) and `ally` targets are not built. Medical Card and Dad's Platinum Card are helpers
  (`GearTriggers.shop_price`, `fight_dolla_bills`) for the run lane (task 025) to call.
  **Found:** Beer Helmet's Hangover would join the run deck every fight (I7) unless `add_card` gets a
  fight-only option. Body Spray reacts to Ick by scanning `status_changed` events after each effect;
  any new place that runs a Dude's effects (013's Powers, e.g. Friend Zone) should call
  `GearTriggers.after_effect_in_place` (or `run_effects_in_place`) so Body Spray sees that Ick too.
  **Verified:** `tools/test.sh` (Godot 4.7.2-stable, headless) on the branch without the last
  commit -> 241 passed, 0 failed; the two contract commits alone -> 210 passed, 0 failed.
- 2026-10-10 A (lead): Stacked on tasks 013 and 015 for the PR. Contracts split into #43 (formats,
  on main) and #44 (state, on #40); `SCHEMA_VERSION` is **5** (4 is 013's; 017 takes 6), and the
  recorded hashes, including 013's Tom fight hash, were re-recorded once more after every outcome
  assertion passed. In the rules: `use_brew` passes `ruleset` to `finish_if_decided_in_place`;
  `Ops.make_context` keeps 013/015's version (carries `ruleset` and `cards`); `OPS` holds all ops in
  name order; in `play.gd` card_played Gear fires before the Bro Meter point; the ruleset's
  `add_card` card_id check (015) now also scans Gear trigger and Brew effects.
  `tests/core/items/test_pending_ops.gd` runs on this branch (see the PR for the result).
  Still open: turn-start Powers (Friend Zone at `turn_start`) do not call
  `GearTriggers.after_effect_in_place`, so Body Spray misses Ick applied there; Ick from Powers fired
  inside a card's effect is seen.
