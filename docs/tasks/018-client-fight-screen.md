---
id: 018
title: Placeholder fight screen - render state, send requests, animate events
lane: client
owner: B
status: open
branch:
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

- [ ] The screen shows, from the state only: each Dude's HP / max HP, Guard, Hype, statuses with stacks, Brew slots, and draw, discard and Tapped pile counts; the hand; the Bro Meter against `BRO_METER_MAX` from the ruleset; each enemy's HP, Guard, statuses, intent icon and target portraits, Broken Arm as k of n, and Ick against its threshold.
- [ ] The screen talks to one gateway with `apply(ruleset, state, request)`. A fake gateway in `client/dev/` returns canned events built with `event.gd` `make()`; swapping in the real core (task 007) changes one line.
- [ ] Every request it sends passes `request.gd` `check()`, carries the local `player_id`, and raises that player's `seq` by 1 (test in `tests/client/`).
- [ ] Targeting follows the card's `target`: `enemy` asks for an enemy, `all_enemies`, `self` and `none` do not; Assist targets the player in solo.
- [ ] Events animate one at a time in list order; after the last one the screen redraws from the returned state. A test feeds a canned list and checks the animation log order, and a second test skips every event and gets the same final drawing.
- [ ] Every `REJECT_REASONS` code has a player-facing message in the GDD's terms (e.g. `no_hype`: not enough Hype). On `bad_target` the screen asks for a new target, as the GDD's two-players-one-enemy case says.
- [ ] No mutation: a test passes a state made read-only at every level (`make_read_only()` on each nested Dictionary and Array, since it is shallow) through a full canned turn and gets no runtime error from task 002's runner.
- [ ] Nothing names Tom: Dude name and art come from `data/dudes/` and the state. `grep -rniE "\btom(_|\b)" client/ --include=*.gd --include=*.tscn` finds nothing outside comments.
- [ ] Every art or sound file under `client/` is listed in `client/ASSETS.md` with its source (made by the agent, or a free-to-use source and its license).
- [ ] The scene runs headless in tests (task 002's runner) with animation durations set to 0.

## Notes

- Use only event types in `event.gd`. If the screen needs one that is missing, ask Agent A for a
  contract PR; do not invent a type in the fake.
- The GDD does not say whether intents show a damage number. If you want one, ask, and get the number
  from the core; the client must not run the damage order itself.
- The client reads `data/**.json` text with task 004's reader and builds the ruleset with task 005;
  until those merge, the fake gateway can hold a small in-memory ruleset.
- Placeholder art: coloured shapes and text labels are enough. No real brands, logos or likenesses.

## Log
