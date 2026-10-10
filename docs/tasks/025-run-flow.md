---
id: 025
title: Run flow - new run, nodes, rewards, Tailgate, Baileys, Loot, Side Quests, floor end
lane: run
owner: A
status: in_review
branch: a/025-run-flow
depends_on: [007, 021, 023]
blocked_on: []
files:
  - core/run/
  - core/schema/          # additive contract PRs only: run screens, new request types, side quest format
  - data/constants.json   # additive constants from G22, in their own contract PR
  - tests/run/
  # Added while building (Agent A's core lane, small marked "Task 025" edits; see the log):
  - core/core.gd                  # routes vote_node and choose_reward
  - core/ruleset/ruleset.gd       # data/side_quests/ and data/encounters/
  - core/combat/                  # upgrades.gd and pending_statuses.gd (new); play.gd, powers.gd, piles.gd, fight.gd (hooks)
  - tests/core/                   # test_upgrades.gd; hash re-records; two tests adjusted (log)
  - docs/proposals/solo-slice-rule-gaps.md   # gaps G54-G61
---

## Goal

A whole solo run of floor 1 from seed to boss reward through `apply()`, with every node type.

## Read first

GDD "Run structure", "Prices at Baileys", "Example Side Quests", "Tom, the Enforcer" (starting Gear);
G14–G22.

## Acceptance checks

- [x] New run from (seed, list of `dude_id` by seat): Dudes from `data/dudes/`, starter decks with fresh card_uids, starting Gear, Dolla Bills as G20.
  `core/run/new_run.gd` `start()`; `tests/run/test_new_run.gd`.
- [x] Requests for the node screens. The GDD has only `vote_node` and `choose_reward`. Propose in a contract PR how Tailgate (Nap or Lift), Baileys (buy, remove a card, leave) and Side Quest choices are sent: reuse `choose_reward`, or add new types.
  Contract commit 1: reuse `choose_reward` for every node choice (offers in `dude_state.offers`), plus an optional `card_uid` for Lift and removal. Reasoning in `docs/changes/2026-10-10-025-schema.md`.
- [x] Brawl, Rival and Boss rewards as the node table; card offers from the player's `rewards` stream with G21 odds.
  `core/run/rewards.gd`, `core/run/pools.gd`; `test_brawl_reward`, `test_rival_reward`, `test_boss_reward_and_floor_end`, `test_card_reward_rarity_odds`, `test_brawl_brew_chance` in `tests/run/test_node_flow.gd`.
- [x] The Tailgate: Nap heals `TAILGATE_NAP_HEAL` of max HP; Lift upgrades one card (G15).
  `core/run/tailgate.gd`, `core/combat/upgrades.gd`; `tests/run/test_tailgate.gd` (a Lifted Arm Bar deals 11).
- [x] Baileys: stock and prices (G21), Shake is a Brew, removal costs 75 rising by 25.
  `core/run/baileys.gd`; `tests/run/test_baileys.gd` (Medical Card included, G26).
- [x] Loot: free Gear; the Mimic Cooler case (G19).
  `core/run/loot.gd`; `test_loot_gives_gear`, `test_mimic_cooler`, `test_mimic_odds`.
- [x] Side Quests: the format (contract PR, the GDD has none) and the five GDD examples, using the `side_quest` stream. `dumb_options_taken` counts.
  `core/schema/side_quest_def.gd`, `core/run/side_quests.gd`, `core/run/side_quest_ops.gd`; `tests/run/test_side_quests.gd` (each of the five, G23, G24, G25).
- [x] Boss: 1 of 3 Boss Gear, full heal; the floor ends (the slice ends here).
  `test_boss_reward_and_floor_end`; `run_phase` `"floor_end"`, event `floor_ended`.
- [x] Fixed-seed test: a scripted whole run gives a recorded final state.
  `tests/run/test_run_fixed_seed.gd`: seed 1, GDD Tom (80 HP), every node type on the path, 193 requests, `FINAL_HASH` `221de4ce…`; replay identical; save and load on the map, at a choice and mid-fight continue identically.

## Notes

- Player-facing text at Baileys follows CLAUDE.md: weed and Shake, never drinks.
- Split with Agent B: this task defines the Side Quest format and the rules that resolve them; task 016
  writes the five Side Quests as data, and task 014 writes Gear and Brews. Until those merge, tests use
  small fixtures under `tests/run/fixtures/`; switch the whole-run test to the real data afterwards.

### What Agent B's data must provide (the fixtures in `tests/run/fixtures/run_fixtures.gd` are the model)

- **Task 016 (`data/side_quests/`)**, format `core/schema/side_quest_def.gd`: five files, ids
  `beer_pong_table`, `gas_station_sushi`, `three_am_tattoo`, `free_couch_on_the_curb`,
  `unlabeled_brownie` (or others B prefers; ids never change once merged). Each has `safe` and `dumb`
  with `label`, `text`, `effects`; safe labels as the GDD ("Walk away", "Skip it", "Go to bed",
  "Leave it", "Politely decline"), safe effects `[]`. Dumb effects, exactly:
  Beer Pong `min_dolla_bills: 50` (G23), `chance 50: then dolla_bills +50, else dolla_bills -50 and add_card junk_hangover`;
  Sushi `heal 25`, `chance 35: then next_fight_status hungover 3`;
  Tattoo `random_gear`, `add_card junk_regret`;
  Couch `full_heal`, `chance 30: then add_card junk_bedbugs`;
  Brownie `upgrade_random_cards 2`, `next_fight_status foggy 2`.
  The fixtures' prompts and dumb labels are placeholders for the content lane to write.
- **Task 014 (`data/gear/`, `data/brews/`)**: exactly as `tests/core/items/item_fixtures.gd` (task 021).
  The run lane reads: Gear `owner` (`general`, the Dude, `boss`) and `rarity` (`starter` and `boss`
  are never offered; common/uncommon/rare set Baileys prices), Brew `rarity` (Shake price), Medical
  Card's `shop_price_percent` 80 and Dad's Platinum Card's `fight_dolla_bills_percent` 0.
- **Encounters (`data/encounters/`, new folder, content lane; no task yet)**: format
  `core/schema/encounter_def.gd`; floor 1's groups from G19 as in the fixtures' `ENCOUNTERS`: eight
  Brawl groups (`early: true` on Pledges x2, Bouncer, Intern, Pledge + Intern; G61), the three Rivals,
  Goblin King Chad (`node: "boss"`) and the Mimic Cooler (`node: "loot"`). A run cannot enter a fight
  node without them (the vote is refused).
- **Task 006**: Tom's cards with rarities as the GDD table (only common/uncommon/rare are offered);
  `upgrade` field paths in the form `core/combat/upgrades.gd` documents (Arm Bar `{"effects[0].amount": 11}`).

### Decisions taken here (also in the code headers; gaps G54–G61 are new and unanswered)

- No new reject code: the run requests reuse `wrong_phase`, `bad_target` and `unplayable`, because
  `tests/client/test_fight_screen.gd` (Agent B) needs a client message for every code. Proposed
  follow-up: one contract PR adding `bad_node`, `unknown_reward`, `bad_choice`, `no_dolla_bills`,
  `no_slot` together with B's messages for them.
- A new run is `core/run/new_run.gd` `start()`, not a request; `pick_dude` stays `wrong_phase` until
  a lobby exists.
- `combat` is set to `null` once a won fight's rewards are out; a lost fight is kept (`run_phase` `"lost"`).
- `core/ops/README.md`'s "Not built yet" still says Side Quest ops are task 025's; Side Quest operations
  are a run-lane catalogue (`core/run/side_quest_ops.gd`), so that line should be updated in a later
  core PR (not touched here because task 031 is editing `core/ops/`).

## Log

- 2026-10-10 A: blocked on G14–G22 and on tasks 007, 021 and 023.
- 2026-10-10 A: Claimed. Tasks 007, 021 and 023 are merged, and every gap it waited on is answered
  (G1–G31 in #20; G32–G52 and I1–I9 accepted by steamjgrube on #50).
- 2026-10-10 A: **Done**, three commits on `a/025-run-flow`:
  1. contract (schema only): run_state/dude_state fields, SCHEMA_VERSION 8, `choose_reward.card_uid`,
     14 events, `side_quest_def.gd`, `encounter_def.gd` (`docs/changes/2026-10-10-025-schema.md`);
  2. contract (constants only): `LOOT_MIMIC_CHANCE`, `EARLY_BRAWL_COUNT`, `BOSS_GEAR_CHOICES`
     (`docs/changes/2026-10-10-025-constants.md`);
  3. the run lane, the marked core-lane edits, tests, re-recorded hashes, gaps G54–G61
     (`docs/changes/2026-10-10-025.md`).
  Commit 1 alone fails the recorded-hash tests (the version and blank fields change the bytes); they
  are re-recorded in commit 3 after every outcome assertion in them passed.
  **Verified:** `tools/test.sh` from the worktree root -> `391 passed, 0 failed`, exit 0 (Godot
  4.7.2-stable, headless), including the documentation and purity lints over the new files.
  **Not done:** real data (B's tasks 006, 008, 010, 014, 016 and the encounter files) is not merged, so
  every test uses `tests/run/fixtures/`; switch to it and re-record `FINAL_HASH` when it lands.
  Descending to floor 2 is out of scope (the slice ends at `floor_end`). Co-op Gear drafting, Spotting,
  Brawl extra enemies and Driver rotation are not built (G59). The five separate reject codes wait for
  the client's messages. Rule gaps G54–G61 need answers.
  **Found:** an upgraded card was "unplayable" until now (task 007's placeholder); Lift needed
  `core/combat/upgrades.gd`, so `test_core_apply.gd`'s Lift case now uses a card whose upgrade cannot
  apply. `tests/core/ruleset/test_ruleset.gd` used `data/side_quests/` as its example of an unknown
  folder; it now uses `data/events/`.
