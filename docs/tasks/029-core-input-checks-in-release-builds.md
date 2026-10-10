---
id: 029
title: Keep the core's input checks in release builds (replace assert)
lane: core
owner: A
status: done
branch: a/029-release-safe-checks
depends_on: [003]
blocked_on: []
files:
  - core/rng/
  - tests/core/rng/
  - tests/core/test_purity.gd     # the lint that bans assert( in core/
---

## Goal

GDScript removes `assert()` from release builds, so the checks in `core/rng/rng.gd` vanish in an
exported game. Bad input would then crash or behave silently wrong instead of failing clearly.
Raised by Agent B reviewing #12.

## Read first

`core/rng/rng.gd` (`key_for`, `next_int`, `weighted_index`, `_bounded`); `core/schema/README.md`
("The core's entry point").

## Acceptance checks

- [x] Every `assert()` in `core/` is replaced by a check that also runs in release builds.
- [x] For each bad input, decide whether the function returns an error result (as `apply()` does with
      `reject`) or reports with `push_error()` and a documented safe fallback. Write the choice in
      `core/rng/rng.gd`'s header so later core code follows the same rule.
- [x] All-zero or empty weights, a range with `hi < lo`, and an unknown stream name never reach
      `% 0` or create a stream silently.
- [x] Tests cover each bad input. If an engine error is the chosen behavior, the runner fails a test on
      engine errors, so test through the error result instead.
- [x] `tools/test.sh` passes.

## Notes

- Agent B's review gives the failing paths: all-zero weights reach `% 0` in `_bounded`, and an
  unknown stream name quietly gets a key.
- Consider adding a lint to `tests/core/test_purity.gd` that bans `assert(` in `core/`, so this does not
  come back.

## Log
- 2026-10-10 A: Claimed. `files` widened to include `tests/core/test_purity.gd`, as Agent B noted on #17.
- 2026-10-10 A: Claimed and done on branch `a/029-release-safe-checks`. Chosen rule (written in
  `core/rng/rng.gd`'s header for all core code): core functions report bad input through an error
  field, never `assert` or `push_error`. Every draw function (`next_u64`, `next_int`,
  `weighted_index`, `shuffle`) now returns `{"state", "value", "error"}`; `error` is `""` on success.
  On bad input the input state itself comes back (no stream advanced), `value` is a documented safe
  value (`0` for `next_u64`, `lo` for `next_int`, `NO_INDEX` = -1 for `weighted_index`, a copy of
  `items` in its original order for `shuffle`), and `error` is `"<function>: <problem>"`.
  `key_for` returns `NO_KEY` (`""`) for an unknown name or a wrong player_id, which every draw
  rejects; `create_streams` skips it, so no stream is created silently. `_bounded` returns without
  drawing for a count below 1, so `% 0` cannot happen; `shift_right_logical` now accepts any bit
  count. Purity lint bans `assert(` in `core/` (self-test `test_checker_bans_assert`). New tests in
  `tests/core/rng/test_rng_bad_input.gd` (8 tests): all-zero, empty, negative, float and
  overflowing weights; hi < lo and too-wide ranges; unknown stream names via `key_for`; unknown
  stream keys (including a per-player key for a player not in the run, and 0/1-item shuffles); a
  state with no `rng` or a float stream; bad player_ids in `create_streams`; valid input gives
  `error: ""` and the recorded seed-12345 values. Existing `test_rng.gd` is unchanged and passes.
  Verified: `tools/test.sh` -> `102 passed, 0 failed`.
  Not done: `with_new_streams` still expects a state that passes `RunState.check` (it reads
  `run_seed` and each Dude's `player_id` without checking); it returns a plain state, so changing
  that would change its return shape. Callers that ignore `error` get a safe value, but note that
  GDScript reads `array[-1]` as the last item, so `weighted_index` callers must check `error`.
  Task 007 (combat skeleton, written concurrently) must not use `assert(` in `core/`: the new lint
  fails it after rebase.
- 2026-10-10 A: Merged in #22 by Agent A under Smoketsu's temporary permission (Person B offline). Status `done`.
