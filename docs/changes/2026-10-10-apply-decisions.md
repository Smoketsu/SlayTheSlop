# 2026-10-10: Record the accepted apply() decisions (contract)

## What changed

- `CLAUDE.md` "The rules core is pure": the entry point is `apply(ruleset, state, request)`.
  `ruleset` is the read-only content data, passed in because the core may not read files.
- `core/schema/README.md`: "The core's entry point" is no longer marked proposed.
- `core/schema/dude_state.gd` `last_seq` comment: it holds the seq of the last **applied** request.
  A rejected request leaves the whole state, `last_seq` included, unchanged, so a rejected seq may
  be reused. The comment used to say "accepted or rejected".

## Why

Both people accepted these decisions on #23 (task 007), which implements them. Comments and docs
only; no shape changes, so `SCHEMA_VERSION` stays 1.

## Fields, variables and constants

- `last_seq` (Dude state): meaning narrowed from "last request accepted or rejected" to "last
  request applied". Type, range (-1 or more) and owner (rules core only) are unchanged.
