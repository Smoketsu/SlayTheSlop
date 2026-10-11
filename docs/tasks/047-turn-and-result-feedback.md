---
id: 047
title: Turn and fight-result feedback - banners, End Turn button, animation speed
lane: client
owner: B
status: in_progress
branch: b/047-turn-feedback
depends_on: [028]
blocked_on: []
files:
  - client/
  - tests/client/
---

## Goal

Task 028 animates hits, Guard and deaths. What is still missing is the rhythm of a fight: a short
"Your turn" / "Enemy turn" banner when the phase changes, a clear End Turn (ready) button that
pulses when the player has no playable card left, and a victory or Passed Out banner before the
screen moves on to rewards or the run-over screen. Add a setting for animation speed (normal, fast,
instant) kept in the client's user settings, not in game state.

## Read first

GDD "Turn flow", "Tone and humor"; `client/fight/fight_screen.gd` (`press_ready`, `_send`),
`client/visual/event_player.gd` (`play`, the per-event duration and the instant mode tests use),
`client/run/run_screen.gd` (`_on_fight_applied`, `_run_over_view`), `client/run/save_store.gd`.

## Acceptance checks

- [ ] A phase change in the returned events shows the matching banner after the events before it
      have played, and before the ones after it.
- [ ] The End Turn button pulses only when no card in hand can be played (ask the core, as task 041
      does; no rules in the client).
- [ ] Winning a fight shows a victory banner; losing shows the Passed Out banner; then the screen
      continues as it does today.
- [ ] The animation-speed setting changes the event player's duration; "instant" matches what tests
      use. It is saved in `user://` settings, never in the run save or state.
- [ ] None of this changes `state` (the task 024 read-only test still passes).
- [ ] `tools/test.sh` passes.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (fight-screen polish backlog). Unclaimed.
- 2026-10-11 B: Claimed. Work starts once 041 (#112) and 049 (#111) merge, since it builds on the card faces and the client settings store.
