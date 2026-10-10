---
id: 003
title: Named random streams derived from run_seed
lane: core
owner: A
status: in_review
branch: a/003-random-streams
depends_on: [001, 002]
blocked_on: []
files:
  - core/rng/
  - tests/core/rng/
---

## Goal

The only source of randomness in the game: independent streams named as in the GDD, each derived
from `run_seed`, whose state lives in `run_state.rng` so a snapshot resumes them exactly.

## Read first

GDD "Random streams" and "Fields added for Ethan" (`dice`); `core/schema/run_state.gd` (`rng`, key format).

## Acceptance checks

- [x] Streams `map`, `encounters`, `combat_ai`, `side_quest`, and per player `rewards:<pid>`, `shuffle:<pid>`, `dice:<pid>`.
- [x] Pure functions over state: e.g. `next_int(state, stream, lo, hi) -> {state, value}`, plus a deterministic `shuffle`. No globals, no `randi()`.
- [x] Drawing from one stream never changes another (test: interleave draws, compare with draws in isolation).
- [x] Fixed-seed test: seed 12345 gives a recorded sequence for each stream, so a change in Godot's generator is caught.
- [x] State survives `var_to_bytes`/`bytes_to_var` mid-sequence and continues identically.
- [x] Stream derivation does not depend on `String.hash()` or anything else Godot may change between versions; write the mixing function out.
- [x] `tests/core/test_purity.gd` still passes: only `core/rng/` may use `RandomNumberGenerator`.

## Notes

- `RandomNumberGenerator.state` is a 64-bit int and round-trips through `var_to_bytes` (not JSON).
- Godot's generator is PCG32, but its range functions are engine code; if you rely on them, the fixed-seed test is what protects us across engine upgrades. Writing your own small PCG or splitmix is also fine.

## Log

- 2026-10-10 A: Started before the claim PR and task 001/002 merged, at Person A's instruction.
  Built against Agent A's local draft harness; before committing, merged origin/main (task 002's
  harness, now merged) into this branch and re-verified with the real `tools/test.sh`.
  **Done:** `core/rng/rng.gd`, pure static functions over a run state: `create_streams`,
  `with_new_streams`, `key_for`, `derive_stream_state`, `next_u64`, `next_int`, `weighted_index`,
  `shuffle` (Fisher–Yates), plus the written-out primitives `mix64`, `fnv1a64`,
  `shift_right_logical`. Own SplitMix64 generator in integer math (no `RandomNumberGenerator`, no
  `String.hash()`); each stream's whole state is one int in `run_state.rng`, so the existing
  `rng: map_of int` schema needed no change. Stream seed = `mix64(run_seed ^ mix64(fnv1a64(key)))`.
  13 tests in `tests/core/rng/test_rng.gd` cover every check above; fixed-seed expectations
  (seed 12345, every stream, plus d20 rolls, a shuffle and weighted picks) were computed with an
  independent Python implementation, and the published SplitMix64 vector (state 1234567) and
  FNV-1a vectors are checked too.
  **Verified:** from the worktree root, `tools/test.sh` (Godot 4.7.2-stable headless) printed
  `40 passed, 0 failed` (all tests, including the purity and documentation lints over the new
  files); `tools/test.sh rng` printed `13 passed, 0 failed`.
  **Not done:** nothing in scope. No caller uses the streams yet (combat, map and rewards tasks will).
  **Found:** GDScript's `>>` refuses a negative operand ("Invalid operands for bit shifting. Only
  positive operands are supported."); seen as a parse error on a constant expression, and assumed to
  apply at run time too, so `shift_right_logical` never shifts a negative value. `+` and `*` on ints wrap modulo 2^64
  (proven by `test_int_math_wraps_as_relied_on`). Hex literals above INT64_MAX are avoided; the
  constants are written as signed decimals with their hex in the comment. Range checks are
  `assert()`s, which only run in debug builds. Draw functions return a shallow copy of the run
  state with a new `rng` Dictionary; other nested values are shared with the input (documented in
  `rng.gd`). Weighted picks over data from a Dictionary must sort first.
