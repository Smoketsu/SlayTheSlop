---
id: 053
title: Playtest run log - a local summary of each run testers can send back
lane: client
owner: B
status: in_review
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

- [x] The log is built only from states and events the client already receives; nothing is added to
      `core/` or to game state. If a field needs data the state does not have, leave it out and
      list it in the task log.
- [x] One JSON object per line, keys sorted, no wall-clock time inside the record except one
      `logged_at` field, so two runs with the same seed and requests give the same record apart
      from it (test).
- [x] The file is only appended to, never rewritten; a write failure shows a message and does not
      stop the game.
- [x] No personal data: no player name, machine name or path in the record.
- [x] `tools/test.sh` passes.

## Notes

- Code: `client/run/run_log.gd` (new; the record, every key documented in its header) fed by
  `client/run/run_screen.gd` `apply()`, the one gateway every request goes through (map, offer and
  fight screens). Written in `_take_state()` on won/lost and in `_log_abandoned()` when New Run
  replaces an unfinished save. Tests: `tests/client/test_run_log.gd`.
- "Abandoned" means: New Run pressed on the menu while a saved, unfinished run exists. There is no
  in-run "back to menu" yet, so in practice that run was saved by an earlier session; it is logged
  from the save alone with `resumed: true`. A save that does not load is not logged.
- `run_seed` is written as a decimal string (a seed can be any 64-bit int; JSON readers use doubles).
- `game_version` is `application/config/version` from project.godot, which is not set yet, so it
  reads `RunLog.UNVERSIONED` ("unversioned") until a playtest build (task 051) sets it.
- Left out, because the client does not have the data (or only has part of it):
  - Fights, rewards, Gear/Brews gained and rejected requests from before a Continue: they live only
    in the session's memory; the record sets `resumed: true` and these lists start at the load.
    Run-wide values (`path`, `floor`, `requests_applied`) come from the state and are complete.
  - Which card was Lifted or removed: the record names those options "lift" / "remove" only
    (`offer_closed` does not carry the card; it could be read from `card_upgraded` / `card_removed`
    later).
  - Starting Gear and Brews (not "gained"; the new-run events never pass through `apply()`), and
    Brews offered but not kept (`brew_not_kept`).
  - In co-op, other players' rejected requests (never sent to this client).
  - Any duration or time per fight: no wall-clock value except `logged_at`, by design.
  - A run left unfinished with no later New Run is never logged (no record on quit).

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (playtest readiness). Unclaimed.
- 2026-10-11 B: Claimed (steamjgrube: pick up work the board asks for).
- 2026-10-11 B: Done on `b/053-run-log`. Added `client/run/run_log.gd` and small hooks in
  `client/run/run_screen.gd` (gateway `apply()`, `_on_run_ready()`, `_take_state()`, the run-over
  view's Open log folder button). Tests in `tests/client/test_run_log.gd` (8): same seed and requests
  give identical lines apart from `logged_at` on the full fixed-seed floor 1 run (keys sorted, ints
  stay ints), rejects counted, a line appended per run (append only), abandoned and resumed runs,
  write failure shows a message and play goes on, no personal data, Open log folder is a headless
  no-op. Not done: the fields listed under Notes. Verified with `tools/test.sh`: 520 passed,
  0 failed (`tools/test.sh client`: 68 passed, 0 failed).
