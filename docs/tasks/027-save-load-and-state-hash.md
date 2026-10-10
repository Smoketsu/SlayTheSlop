---
id: 027
title: Save and load snapshots, and the state hash
lane: run
owner: A
status: in_review
branch: a/027-save-load-and-state-hash
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

- [x] `to_bytes(state)` / `from_bytes(bytes) -> {ok, state, error}` using `var_to_bytes` / `bytes_to_var` without objects.
- [x] `from_bytes` runs `run_state.check()` and rejects a wrong `schema_version` with a clear error.
- [ ] Round trip is identical at every step of task 007's fixed-seed fight (strict `assert_eq`).
- [x] `state_hash(state)`: the same for equal states whatever the Dictionary insertion order (test this), and different after any change.
- [x] Pure: produces and consumes bytes; writing them to disk is the client's job.

## Log

- 2026-10-10 A: Started before the claim PR and tasks 001/002/007 merged, at Person A's instruction;
  verified with Agent A's local draft harness while writing it, then (after task 002 merged and
  `origin/main` was merged into this branch) with the real harness.
  **Done:** `core/run/save/snapshot.gd` with `to_bytes`, `from_bytes`, `state_hash` and `canonical`;
  17 tests in `tests/run/save/test_snapshot.gd` (round trips of blank, mid-fight and edge states
  with a seed above 2^53, int64 min/max and negative stream states; hash insertion-order
  independence; hash changes on 16 different one-field changes; a recorded hash for a fixed state;
  refusal of empty, short, every truncation, trailing bytes, random garbage, every corrupted byte,
  non-Dictionary, Object/float/StringName/typed Array/int key/Vector2i, invalid UTF-8, wrong,
  missing and mistyped `schema_version`, and states failing `run_state.check()`).
  **Verified:** `tools/test.sh` from the worktree root -> `44 passed, 0 failed` (exit 0), including
  the purity and documentation lints.
  **Not done:** the check "round trip is identical at every step of task 007's fixed-seed fight" is
  left unticked because task 007 does not exist yet. When it merges, add a test here that replays
  its fixed-seed fight and asserts `from_bytes(to_bytes(s))["state"] == s` and a stable
  `state_hash` after every request. Built against the merged schema only, with hand-built states.
  **Found along the way:**
  - `bytes_to_var` logs engine errors (which fail a test) on truncated data and invalid UTF-8,
    silently cuts a String at a NUL byte, and decodes an Object as `EncodedObjectAsID` even with
    objects disallowed. So `from_bytes` first walks the whole buffer (`_scan`) and accepts only
    null, bool, int, String, untyped Array and untyped Dictionary with String keys, every length
    inside the buffer, every String valid UTF-8 without NUL, and no trailing bytes. Only then does
    it call `bytes_to_var`. The fuzz tests (every truncation, every byte flipped three ways, 600
    random buffers) pass with no engine error, which is what proves the walk is at least as strict
    as Godot's decoder.
  - `to_bytes` writes the canonical form (keys sorted, Arrays untyped), so save bytes are
    deterministic and `state_hash` is simply SHA-256 of the snapshot bytes, as
    `core/schema/README.md` suggests. A loaded state therefore has sorted Dictionary insertion
    order, which is harmless because no result may depend on it.
  - The fixed hash (`SAMPLE_HASH` in the test) was recorded on Godot 4.7.2-stable. If an engine
    upgrade changes it, old saves and cross-version co-op hashes break; decide with both people.
  - `_scan` mirrors Godot 4's binary layout (marshalls.cpp). An engine upgrade that changes it
    shows up as round-trip test failures here.
