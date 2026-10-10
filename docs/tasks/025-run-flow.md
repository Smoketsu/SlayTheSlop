---
id: 025
title: Run flow - new run, nodes, rewards, Tailgate, Baileys, Loot, Side Quests, floor end
lane: run
owner: A
status: in_progress
branch: a/025-run-flow
depends_on: [007, 021, 023]
blocked_on: []
files:
  - core/run/
  - core/schema/          # additive contract PRs only: run screens, new request types, side quest format
  - data/constants.json   # additive constants from G22, in their own contract PR
  - tests/run/
---

## Goal

A whole solo run of floor 1 from seed to boss reward through `apply()`, with every node type.

## Read first

GDD "Run structure", "Prices at Baileys", "Example Side Quests", "Tom, the Enforcer" (starting Gear);
G14–G22.

## Acceptance checks

- [ ] New run from (seed, list of `dude_id` by seat): Dudes from `data/dudes/`, starter decks with fresh card_uids, starting Gear, Dolla Bills as G20.
- [ ] Requests for the node screens. The GDD has only `vote_node` and `choose_reward`. Propose in a contract PR how Tailgate (Nap or Lift), Baileys (buy, remove a card, leave) and Side Quest choices are sent: reuse `choose_reward`, or add new types.
- [ ] Brawl, Rival and Boss rewards as the node table; card offers from the player's `rewards` stream with G21 odds.
- [ ] The Tailgate: Nap heals `TAILGATE_NAP_HEAL` of max HP; Lift upgrades one card (G15).
- [ ] Baileys: stock and prices (G21), Shake is a Brew, removal costs 75 rising by 25.
- [ ] Loot: free Gear; the Mimic Cooler case (G19).
- [ ] Side Quests: the format (contract PR, the GDD has none) and the five GDD examples, using the `side_quest` stream. `dumb_options_taken` counts.
- [ ] Boss: 1 of 3 Boss Gear, full heal; the floor ends (the slice ends here).
- [ ] Fixed-seed test: a scripted whole run gives a recorded final state.

## Notes

- Player-facing text at Baileys follows CLAUDE.md: weed and Shake, never drinks.
- Split with Agent B: this task defines the Side Quest format and the rules that resolve them; task 016
  writes the five Side Quests as data, and task 014 writes Gear and Brews. Until those merge, tests use
  small fixtures under `tests/run/fixtures/`; switch the whole-run test to the real data afterwards.

## Log

- 2026-10-10 A: blocked on G14–G22 and on tasks 007, 021 and 023.
- 2026-10-10 A: Claimed. Tasks 007, 021 and 023 are merged, and every gap it waited on is answered
  (G1–G31 in #20; G32–G52 and I1–I9 accepted by steamjgrube on #50).
