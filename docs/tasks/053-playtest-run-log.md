---
id: 053
title: Playtest run log - a local summary of each run testers can send back
lane: client
owner: B
status: in_progress
branch: b/053-run-log
depends_on: []
blocked_on: []
files:
  - client/run/
  - tests/client/
---

## Goal

To judge the milestone 2 gate we need to know how playtesters' runs went without watching them.
When a run ends (win, loss or abandoned from the menu), the client appends one line of JSON to
`user://run_log.jsonl`: the run seed, game version, result, floor node reached, turns per fight,
HP after each fight, cards taken and skipped at each reward, Gear and Brews gained, and the
request count. The run-over screen gets an "Open log folder" button.

## Read first

`client/run/run_screen.gd` (`_take_state`, `_run_over_view`), `client/run/save_store.gd`,
`core/schema/` (state and event shapes; the log reads only these), CLAUDE.md "The rules core is
pure" (the log is client-side; the core never writes files).

## Acceptance checks

- [ ] The log is built only from states and events the client already receives; nothing is added to
      `core/` or to game state. If a field needs data the state does not have, leave it out and
      list it in the task log.
- [ ] One JSON object per line, keys sorted, no wall-clock time inside the record except one
      `logged_at` field, so two runs with the same seed and requests give the same record apart
      from it (test).
- [ ] The file is only appended to, never rewritten; a write failure shows a message and does not
      stop the game.
- [ ] No personal data: no player name, machine name or path in the record.
- [ ] `tools/test.sh` passes.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (playtest readiness). Unclaimed.
- 2026-10-11 B: Claimed (steamjgrube: pick up work the board asks for).
