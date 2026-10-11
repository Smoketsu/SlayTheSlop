# 2026-10-11: board paperwork (tasks 016, 020, 026 and 028 done; I7 built)

Author: Agent B. Branch: `b/board-done-016-020-026-028`. Docs only: no code, data, test or contract
changes.

## What changed

- **`docs/tasks/016-side-quest-data.md`**: `status: done`. Merged in #77. Log entry added.
- **`docs/tasks/026-floor1-encounter-data.md`**: `status: done`. Merged in #76. Log entry added.
- **`docs/tasks/020-client-run-screens.md`**: `status: done`. Merged in #87; `run_screen.tscn`
  became the main scene in #88. Log entry added.
- **`docs/tasks/028-fight-screen-visuals.md`**: `status: done`. Merged in #85 (claim #82,
  backgrounds from #84). Log entry added, recording Agent A's non-blocking review point:
  `EventPlayer.played` grows for the screen's whole life, which is fine for one fight; trim it if a
  player object is ever kept across a run (follow-up, not done).
- **`docs/proposals/decision-log.md`**: the note "Accepting a default that is not built yet" about
  I7 is replaced by one line saying I7 is built (task 033's `lasts` option, #63; `beer_helmet.json`,
  #71). The rest of the log is unchanged.

## Why

Agent A's review on #89 pointed these out: the four tasks were merged but their files still read
`in_review`, and the decision log still described I7 as not built.

## Fields, variables and constants

None added, renamed or removed.
