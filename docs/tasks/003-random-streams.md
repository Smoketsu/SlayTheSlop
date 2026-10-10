---
id: 003
title: Named random streams derived from run_seed
lane: core
owner: A
status: open
branch:
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

- [ ] Streams `map`, `encounters`, `combat_ai`, `side_quest`, and per player `rewards:<pid>`, `shuffle:<pid>`, `dice:<pid>`.
- [ ] Pure functions over state: e.g. `next_int(state, stream, lo, hi) -> {state, value}`, plus a deterministic `shuffle`. No globals, no `randi()`.
- [ ] Drawing from one stream never changes another (test: interleave draws, compare with draws in isolation).
- [ ] Fixed-seed test: seed 12345 gives a recorded sequence for each stream, so a change in Godot's generator is caught.
- [ ] State survives `var_to_bytes`/`bytes_to_var` mid-sequence and continues identically.
- [ ] Stream derivation does not depend on `String.hash()` or anything else Godot may change between versions; write the mixing function out.
- [ ] `tests/core/test_purity.gd` still passes: only `core/rng/` may use `RandomNumberGenerator`.

## Notes

- `RandomNumberGenerator.state` is a 64-bit int and round-trips through `var_to_bytes` (not JSON).
- Godot's generator is PCG32, but its range functions are engine code; if you rely on them, the fixed-seed test is what protects us across engine upgrades. Writing your own small PCG or splitmix is also fine.

## Log
