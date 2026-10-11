---
id: 047
title: Turn and fight-result feedback - banners, End Turn button, animation speed
lane: client
owner: B
status: in_review
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

- [x] A phase change in the returned events shows the matching banner after the events before it
      have played, and before the ones after it.
- [x] The End Turn button pulses only when no card in hand can be played (ask the core, as task 041
      does; no rules in the client).
- [x] Winning a fight shows a victory banner; losing shows the Passed Out banner; then the screen
      continues as it does today.
- [x] The animation-speed setting changes the event player's duration; "instant" matches what tests
      use. It is saved in `user://` settings, never in the run save or state.
- [x] None of this changes `state` (the task 024 read-only test still passes).
- [x] `tools/test.sh` passes.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (fight-screen polish backlog). Unclaimed.
- 2026-10-11 B: Claimed. Work starts once 041 (#112) and 049 (#111) merge, since it builds on the card faces and the client settings store.
- 2026-10-11 B: Done, in review. Branch `b/047-turn-feedback`, stacked on `b/045-tooltips` (and
  through it on #120 and #119), so it merges after them. Banners: `event_player.gd banners_for()`
  places "Your turn" at `turn_started`, "Enemy turn" at the first enemy action (moved back over its
  Guard drop), "Victory" / "Passed Out" at `fight_ended`; `play()` shows each after the events before
  it and before the rest, and the fight screen also says "Your turn" when it opens on a player phase.
  The result banner plays before `state_applied`, so the run screen moves on after it. Ready pulses
  only when the core would accept a probe `set_ready` and refuse every card in hand. The client
  setting `animation_speed` (normal / fast / instant, factors 1.0 / 0.4 / 0) is on the main menu
  under the Sound row and multiplies the run screen's base length; instant gives 0 seconds, the
  same instant playback tests use. Verified: `tools/test.sh` -> 578 passed, 0 failed
  (`tests/client/test_turn_feedback.gd`: 9 tests; the task 024 read-only test
  `test_full_fight_through_the_screen` still passes, and a new frozen-state fight to a Passed Out
  ending passes); a 1280x720 xvfb screenshot shows the "Enemy turn" banner with Ready pulsing.
  Not done: the button keeps the label "Ready" rather than "End Turn" (the GDD's word; tests use it).
