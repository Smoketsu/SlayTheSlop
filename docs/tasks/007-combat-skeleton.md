---
id: 007
title: Combat skeleton - apply(), turn flow, piles, Hype, basic damage and Guard
lane: core
owner: A
status: in_review
branch: a/007-combat-skeleton
depends_on: [003, 005]
blocked_on: []
files:
  - core/core.gd
  - core/combat/
  - core/ops/
  - tests/core/combat/
  - tests/core/ops/
---

## Goal

The core's entry point and a playable fight loop with the simplest effects, so the client and bot
lanes have something real to call. One fight, any number of Dudes (test with 1 and 2).

## Read first

GDD "Combat rules" ("Turn flow", "Stats"), "How a card gets played in co-op", "Network messages";
`core/schema/` (all of it).

## Acceptance checks

- [x] `apply(ruleset, state, request) -> {state, events, reject}` as in `core/schema/README.md`. Get both people to confirm the `ruleset` argument in this task's PR. (Built; **confirmation still needed** in the PR.)
- [x] Rejects with the right code: malformed (`bad_request`), `unknown_player`, `stale_seq`, `wrong_phase`, `passed_out`, `not_in_hand`, `unplayable`, `no_hype`, `bad_target`. A rejected request changes nothing (same `state_version`).
- [x] A function (not a request) that starts a fight from a list of enemy def ids, plus a test helper that builds a run state with a Dude's starter deck.
- [x] Turn flow 1–5 exactly as the GDD lists it: intents, Refresh (Guard to 0, Hype to `hype_per_turn`, draw `draw_per_turn`), player phase, end of turn (discard the hand), enemy phase left to right, new intents.
- [x] `set_ready` true from every non-Passed-Out Dude ends the player phase.
- [x] Ops `damage` (with `hits`) and `guard`, with Swole and Chill added. Damage subtracts Guard, then HP.
- [x] The fight is won when every enemy is dead and lost when every Dude is Passed Out. `combat.result` and `fight_ended` are set.
- [x] Every applied request raises `state_version` by 1, and every event passes `event.gd` `check()`.
- [x] Fixed-seed test: a scripted fight (seed, request list) ends in a recorded final state. Replaying it twice gives identical bytes.
- [x] `core/ops/README.md` starts the op catalogue: each op, its fields, and their meaning. Content agents read this.

## Notes

- Statuses, Broken Arm and Ick are task 009, enemy move choice is task 011. Here, enemies may use their first move.
- New event types or reject codes need a contract PR to `core/schema/` first.

## Log
- 2026-10-10 A: Claimed. G2 and G8 answered "accept" by Person A (PR a/g2-g8-answers).

- 2026-10-10 A: Built on branch `a/007-combat-skeleton` (no claim PR: the lead assigned the task
  and said to work in a worktree; the lead opens the PRs).
  **Done:**
  - `core/core.gd`: `Core.apply(ruleset, state, request) -> {"state", "events", "reject"}` (static;
    `Core.new().apply(...)` works too, for the client's gateway object) and `Core.validate(...)`, which
    returns the reject reason without applying (for bots). Checks in order: `bad_request` (also for a
    non-Dictionary request), `unknown_player`, `stale_seq`, `wrong_phase`, `passed_out`, then
    `not_in_hand`, `unplayable`, `no_hype`, `bad_target` for `play_card`; `empty_slot` for `use_brew`;
    `not_ready` for `use_bro_move`.
  - `core/combat/fight.gd`: `start_fight(ruleset, state, enemy_def_ids) -> {state, events, error}`
    (not a request; leaves `state_version` alone) and the turn flow 1–5. `core/combat/play.gd`
    (card play), `piles.gd` (opening shuffle, G8 draw, end-of-turn discard), `bodies.gd` (lookups,
    0 HP), `party_scaling.gd` (exact integer party scaling), `party.gd`
    (`build_run_state(ruleset, run_seed, dude_ids) -> {state, error}`).
  - `core/ops/`: `ops.gd` registry with `check`/`check_all` (content tests can call them), `damage.gd`
    (amount, optional hits; Swole per hit; Guard absorbs and is used up, G2), `guard.gd` (amount + Chill,
    always on the actor), `README.md` op catalogue.
  - Tests: `tests/core/combat/test_core_apply.gd` (every reject code, rejects strictly unchanged and
    the same object, version +1, inputs never mutated, instance call), `test_fight_flow.gd` (party
    builder, start_fight, scaling for 1–4 players, stub intents, card play, all_enemies + Tapped, exact
    solo turn-change event list, co-op Ready and Passed Out Dudes, G8 both cases, win, loss solo and
    co-op), `test_fixed_seed_fight.gd` (seed 20261010, 24 scripted requests incl. 3 rejects, won in
    turn 5, recorded `FINAL_HASH`, replay twice = identical bytes and events, snapshot round trip at
    every step), `tests/core/ops/test_ops.gd`; shared test content in `tests/core/combat/fixtures.gd`.
  - Verified: `tools/test.sh` -> `125 passed, 0 failed` (includes the purity and documentation lints).
  **Not done / stubbed:**
  - Enemy intents are a STUB for task 011: always the first move; a move with a `damage` op aims at the
    first Dude not Passed Out, other moves at nobody; targets that Passed Out before the enemy acts are
    skipped, not re-aimed. No multi-target rule (`MULTI_TARGET_PARTY_SIZE`).
  - Damage order steps 2–4, statuses, Broken Arm, Ick, Hungover, Foggy: task 009. Cards with
    `apply_status` (Arm Bar, Well, Actually) are `unplayable` until then.
  - Pocketed, Bro Meter gain and `use_bro_move` (rejected `not_ready` / `unplayable`): task 013.
    Brews (`use_brew` is `empty_slot` / `unplayable`): task 021. `ally`/`puppet` targets are
    `bad_target`. Cost `"x"`, `crunch: true`, and upgraded cards with a non-empty `upgrade` are
    `unplayable`. `pick_dude`, `vote_node`, `choose_reward` are `wrong_phase` (run flow, task 025).
  - `brew_slots` and `dolla_bills` start at 0 in `build_run_state` (G22, G20 unanswered).
  **Decisions for both people to confirm in the PR:**
  1. The `ruleset` argument of `apply()` (as proposed in `core/schema/README.md`).
  2. `last_seq` changes only when a request is applied. A rejected request changes nothing (so the
     state is strictly identical, as the acceptance check requires), and its seq may be reused. This
     contradicts the comment on `dude_state.last_seq` ("accepted or rejected"); that comment needs a
     contract PR (meaning change, so a person decides).
  3. Scaled enemy HP rounds down (Ick thresholds round up, as the GDD says).
  4. If one step both kills the last enemy and Passes Out the last Dude, the result is `lost`
     (cannot happen until self-damage, task 013).
  5. A Dude who is already Ready may still play cards (GDD does not say).
  6. Chill is added once per `guard` effect; Swole once per hit of every `damage` effect.
  **Found (needs a gap answer, not invented):** the GDD never resets **enemy** Guard (Refresh resets
  players' Guard only). As written, enemy Guard accumulates for the whole fight (Goblin Bouncer's
  8 Guard every other turn would stack). Suggested new gap for the proposal: enemies' Guard drops to 0
  at the start of their own action in the enemy phase.
  **Next agent:** `core/schema/` is unchanged. The client can swap `client/dev/fake_gateway.gd` for
  `res://core/core.gd` (task 018's one line); note the dev content's `ally` card is `bad_target` here.
  The checkout's `docs/proposals/solo-slice-rule-gaps.md` still shows G2 and G8 without answers; the
  lead said both were answered "accept", so the answers need merging into that file.
- 2026-10-10 A (lead): The claim did land as a PR after all (#21, merged by Agent B). Merged main into
  this branch to resolve the task-file conflict that created; `tools/test.sh` re-run after the merge.
