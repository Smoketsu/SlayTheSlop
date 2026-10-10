---
id: 024
title: Fight screen on the real core and the real data (task 018 follow-up)
lane: client
owner: B
status: in_progress
branch: b/024-fight-screen-real-core
depends_on: [007, 013, 018]
blocked_on: []
files:
  - client/
  - tests/client/
---

## Goal

The placeholder fight screen (task 018) plays a real fight: requests go to `core/core.gd` instead of
the fake gateway, content comes from `data/` through `tools/data_files.gd` and the ruleset builder,
and every event type the core emits gets a placeholder animation line. This is the last step to the
first playable fight.

## Read first

Task 018 and its log; `core/core.gd` (`apply`, `validate`); `core/combat/party.gd`,
`core/combat/fight.gd` (`build_run_state`, `start_fight`); `core/schema/event.gd`;
`core/ops/README.md` (Chest Bump needs `target_id`, G33); `docs/proposals/decision-log.md`.

## Acceptance checks

- [ ] The screen's `Gateway` points at `core/core.gd`. The fake gateway is removed; tests that need
      canned events keep their own stub.
- [ ] With no `setup()`, the screen builds the ruleset from `data/` and starts a fight for Tom
      against a fixed floor 1 group on a fixed seed, using the core's own `Party.build_run_state` and
      `Fight.start_fight`. (A placeholder entry until task 020's run screens start fights from the map.)
- [ ] `use_bro_move` asks for an enemy when the Bro Move card's `target` is `enemy` and sends its
      `target_id` (G33).
- [ ] Every event type in `core/schema/event.gd` has a player-facing animation line; a test fails
      when a new event type is added without one.
- [ ] A test plays a whole fight through the screen's own presses on the real core and real data,
      to a decided result, with the state frozen read-only between requests (no client mutation).
- [ ] Nothing names Tom in client code (task 018's grep still prints nothing).
- [ ] `tools/test.sh` passes.

## Notes

- Setting the project's main scene (`project.godot`, a shared contract) is a separate small PR.

## Log

- 2026-10-10 B: Written and claimed. Next free even id (024).
