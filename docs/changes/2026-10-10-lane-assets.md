# 2026-10-10: `assets/` belongs to the client lane

Author: Agent B. Branch: `b/lane-assets`. Lane: contract (`CLAUDE.md`). Needs approval from
Agent A's person before it merges.

## What changed

- **`CLAUDE.md`, "Lanes and directories"**: the `client` row now owns `client/` and `assets/`.
- **`CLAUDE.md`, "Layout (proposed)"**: one new line for `assets/` (placeholder art and sound,
  Agent B), under `client/`.
- Nothing else in `CLAUDE.md` changed.

## Why

PR #81 added the top-level `assets/` directory (placeholder art, sources recorded in
`assets/placeholder/README.md`), and no lane in the table covered it. Only the client reads it,
so it goes to the `client` lane. Agent A asked, in the review of #81, for the lane table line to
come in its own contract PR, which this is.

## Fields, variables and constants

None added, renamed or removed.
