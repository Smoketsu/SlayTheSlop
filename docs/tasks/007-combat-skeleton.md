---
id: 007
title: Combat skeleton - apply(), turn flow, piles, Hype, basic damage and Guard
lane: core
owner: A
status: open
branch:
depends_on: [003, 005]
blocked_on: [G2, G8]
files:
  - core/core.gd
  - core/combat/
  - core/ops/
  - tests/core/combat/
---

## Goal

The core's entry point and a playable fight loop with the simplest effects, so the client and bot
lanes have something real to call. One fight, any number of Dudes (test with 1 and 2).

## Read first

GDD "Combat rules" ("Turn flow", "Stats"), "How a card gets played in co-op", "Network messages";
`core/schema/` (all of it).

## Acceptance checks

- [ ] `apply(ruleset, state, request) -> {state, events, reject}` as in `core/schema/README.md`. Get both people to confirm the `ruleset` argument in this task's PR.
- [ ] Rejects with the right code: malformed (`bad_request`), `unknown_player`, `stale_seq`, `wrong_phase`, `passed_out`, `not_in_hand`, `unplayable`, `no_hype`, `bad_target`. A rejected request changes nothing (same `state_version`).
- [ ] A function (not a request) that starts a fight from a list of enemy def ids, plus a test helper that builds a run state with a Dude's starter deck.
- [ ] Turn flow 1–5 exactly as the GDD lists it: intents, Refresh (Guard to 0, Hype to `hype_per_turn`, draw `draw_per_turn`), player phase, end of turn (discard the hand), enemy phase left to right, new intents.
- [ ] `set_ready` true from every non-Passed-Out Dude ends the player phase.
- [ ] Ops `damage` (with `hits`) and `guard`, with Swole and Chill added. Damage subtracts Guard, then HP.
- [ ] The fight is won when every enemy is dead and lost when every Dude is Passed Out. `combat.result` and `fight_ended` are set.
- [ ] Every applied request raises `state_version` by 1, and every event passes `event.gd` `check()`.
- [ ] Fixed-seed test: a scripted fight (seed, request list) ends in a recorded final state. Replaying it twice gives identical bytes.
- [ ] `core/ops/README.md` starts the op catalogue: each op, its fields, and their meaning. Content agents read this.

## Notes

- Statuses, Broken Arm and Ick are task 009, enemy move choice is task 011. Here, enemies may use their first move.
- New event types or reject codes need a contract PR to `core/schema/` first.

## Log
