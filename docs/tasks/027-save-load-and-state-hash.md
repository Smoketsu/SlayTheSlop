---
id: 027
title: Save and load snapshots, and the state hash
lane: run
owner: A
status: open
branch:
depends_on: [007]
blocked_on: []
files:
  - core/run/save/
  - tests/run/save/
---

## Goal

A state goes to bytes and back identically, refuses bytes it cannot trust, and has a stable hash
for the co-op desync check (GDD "How a card gets played in co-op", step 6).

## Read first

`core/schema/README.md` ("Serialization"); GDD "Saving".

## Acceptance checks

- [ ] `to_bytes(state)` / `from_bytes(bytes) -> {ok, state, error}` using `var_to_bytes` / `bytes_to_var` without objects.
- [ ] `from_bytes` runs `run_state.check()` and rejects a wrong `schema_version` with a clear error.
- [ ] Round trip is identical at every step of task 007's fixed-seed fight (strict `assert_eq`).
- [ ] `state_hash(state)`: the same for equal states whatever the Dictionary insertion order (test this), and different after any change.
- [ ] Pure: produces and consumes bytes; writing them to disk is the client's job.

## Log
