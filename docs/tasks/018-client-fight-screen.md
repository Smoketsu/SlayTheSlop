---
id: 018
title: Placeholder fight screen - render state, send requests, animate events
lane: client
owner: B
status: done
branch: b/018-client-fight-screen
depends_on: [002]
blocked_on: []
files:
  - client/
  - tests/client/
---

## Goal

A playable placeholder fight screen in `client/` that draws a fight from the state, sends
`play_card`, `set_ready`, `use_brew` and `use_bro_move` requests, and animates the returned events
in order. The client never changes game state: solo uses the same request-and-events path co-op will.

## Read first

GDD "Turn flow", "Stats", "Statuses", "Bro Meter", "How a card gets played in co-op", "Network
messages"; CLAUDE.md "The rules core is pure" and "Writing and content rules"; `core/schema/README.md`,
`request.gd` (types and `REJECT_REASONS`), `event.gd` (the event catalogue), `dude_state.gd`,
`combat_state.gd`, `enemy_state.gd`, `enemy_def.gd` (move `intent` icon keys).

## Acceptance checks

- [x] The screen shows, from the state only: each Dude's HP / max HP, Guard, Hype, statuses with stacks, Brew slots, and draw, discard and Tapped pile counts; the hand; the Bro Meter against `BRO_METER_MAX` from the ruleset; each enemy's HP, Guard, statuses, intent icon and target portraits, Broken Arm as k of n, and Ick against its threshold.
- [x] The screen talks to one gateway with `apply(ruleset, state, request)`. A fake gateway in `client/dev/` returns canned events built with `event.gd` `make()`; swapping in the real core (task 007) changes one line.
- [x] Every request it sends passes `request.gd` `check()`, carries the local `player_id`, and raises that player's `seq` by 1 (test in `tests/client/`).
- [x] Targeting follows the card's `target`: `enemy` asks for an enemy, `all_enemies`, `self` and `none` do not; Assist targets the player in solo.
- [x] Events animate one at a time in list order; after the last one the screen redraws from the returned state. A test feeds a canned list and checks the animation log order, and a second test skips every event and gets the same final drawing.
- [x] Every `REJECT_REASONS` code has a player-facing message in the GDD's terms (e.g. `no_hype`: not enough Hype). On `bad_target` the screen asks for a new target, as the GDD's two-players-one-enemy case says.
- [x] No mutation: a test passes a state made read-only at every level (`make_read_only()` on each nested Dictionary and Array, since it is shallow) through a full canned turn and gets no runtime error from task 002's runner.
- [x] Nothing names Tom: Dude name and art come from `data/dudes/` and the state. `grep -rniE "\btom(_|\b)" client/ --include=*.gd --include=*.tscn` finds nothing outside comments.
- [x] Every art or sound file under `client/` is listed in `client/ASSETS.md` with its source (made by the agent, or a free-to-use source and its license).
- [x] The scene runs headless in tests (task 002's runner) with animation durations set to 0.

## Notes

- Use only event types in `event.gd`. If the screen needs one that is missing, ask Agent A for a
  contract PR; do not invent a type in the fake.
- The GDD does not say whether intents show a damage number. If you want one, ask, and get the number
  from the core; the client must not run the damage order itself.
- The client reads `data/**.json` text with task 004's reader and builds the ruleset with task 005;
  until those merge, the fake gateway can hold a small in-memory ruleset.
- Placeholder art: coloured shapes and text labels are enough. No real brands, logos or likenesses.

## Log

- 2026-10-10 B: Claimed.
- 2026-10-10 B: Done:
  - `client/fight/fight_screen.tscn` + `.gd`: placeholder screen (text on buttons, no art). It draws
    only from `fight_model.gd`, sends requests through one gateway constant (`Gateway`, the one line
    to change for task 007), plays events one at a time in order (`animation_seconds`, 0 in tests),
    then redraws from the returned state. On a reject it shows the message; on `bad_target` it keeps
    the card pending so the player picks again. Brews with targets are not handled (no Brew data yet).
  - `client/fight/fight_model.gd`: state -> display values (pure). `targeting.gd`: what to pick per
    card `target`; Assist (`ally`) targets yourself in solo and asks in co-op. `request_maker.gd`:
    player_id plus seq starting at the Dude's `last_seq + 1`, rising on every request made.
    `messages.gd`: a message for every `REJECT_REASONS` code, and GDD names for status ids.
  - `client/dev/fake_gateway.gd`: stand-in core with the README's apply() contract (never mutates,
    reject returns the state unchanged, applied raises `state_version` by 1). Only real event types,
    made with `event.gd make()`. `client/dev/dev_content.gd`: neutral placeholder cards, enemies and a
    Dude, built with the real `Ruleset.build()` and the real `constants.json`, plus a sample state that
    passes `RunState.check()`.
  - `client/ASSETS.md`: no asset files yet.
  - `tests/client/test_fight_screen.gd`: 11 tests, one or more per acceptance check above.
- 2026-10-10 B: Harness change (task 002's files, Agent B's lane): `tests/run_tests.gd` now runs the
  tests on the first frame instead of in `_initialize()`, because the root window is not in the tree
  until then and nodes added by a test never got `_ready()`. No interface change.
- 2026-10-10 B: Verified: `tools/test.sh` 93 passed, 0 failed (82 before + 11). Mutation check:
  making the screen write to its state turns `test_screen_never_changes_state` red with
  "Dictionary is in read-only state". The scene opens headless with no errors.
- 2026-10-10 B: Not done / for later:
  - No main scene: `project.godot` is a shared contract. Open the screen with
    `"$(tools/install_godot.sh)" --path . res://client/fight/fight_screen.tscn`. Setting
    `run/main_scene` needs its own small PR when task 020 adds a menu.
  - The fake gateway is not the rules: no damage order, no enemy turn, no draw. Delete it when task
    007 lands and change the `Gateway` line.
  - The screen uses `dev_content.gd` until tasks 006 and 010 add real data; then load it with
    `tools/data_files.gd` and `Ruleset.build()`. In an exported build, see task 004's note on listing
    `res://data`.
  - Intents show the icon key only, no damage number (the task says to ask first).
- 2026-10-10 B: Merged in #18 (Agent A reviewed: 93 passed). Status `done`. Follow-up when task 007
  lands: the real core emits events the fake does not (`intent_set`, `deck_shuffled`, `enemy_acted`
  and more, all already in `event.gd`); give each a placeholder animation and swap the `Gateway` line.
