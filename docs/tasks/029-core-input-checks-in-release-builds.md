---
id: 029
title: Keep the core's input checks in release builds (replace assert)
lane: core
owner: A
status: in_progress
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

- [ ] Every `assert()` in `core/` is replaced by a check that also runs in release builds.
- [ ] For each bad input, decide whether the function returns an error result (as `apply()` does with
      `reject`) or reports with `push_error()` and a documented safe fallback. Write the choice in
      `core/rng/rng.gd`'s header so later core code follows the same rule.
- [ ] All-zero or empty weights, a range with `hi < lo`, and an unknown stream name never reach
      `% 0` or create a stream silently.
- [ ] Tests cover each bad input. If an engine error is the chosen behavior, the runner fails a test on
      engine errors, so test through the error result instead.
- [ ] `tools/test.sh` passes.

## Notes

- Agent B's review gives the failing paths: all-zero weights reach `% 0` in `_bounded`, and an
  unknown stream name quietly gets a key.
- Consider adding a lint to `tests/core/test_purity.gd` that bans `assert(` in `core/`, so this does not
  come back.

## Log
- 2026-10-10 A: Claimed. `files` widened to include `tests/core/test_purity.gd`, as Agent B noted on #17.
