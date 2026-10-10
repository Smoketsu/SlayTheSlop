---
id: 023
title: Floor map generation and the map format
lane: run
owner: A
status: blocked
branch:
depends_on: [003]
blocked_on: [G18]
files:
  - core/run/map/
  - core/schema/run_state.gd   # only to document the map shape, in its own contract PR first
  - tests/run/map/
---

## Goal

Generate floor 1's branching map from the `map` stream, with node types in the GDD shares, and
define the `map` shape that `run_state.map`, `node_index` and `vote_node.node_id` refer to.

## Read first

GDD "Run structure" ("The loop", "Node types"); G18; `core/schema/run_state.gd`.

## Acceptance checks

- [ ] Contract PR first: the shape of `map` (node ids, types, rows, links) in `run_state.gd` comments and `core/schema/README.md`.
- [ ] Same seed, same map. Fixed-seed test against a recorded map.
- [ ] Shares within rounding of the GDD table; one boss node at the end; every node reachable; every path reaches the boss.
- [ ] Property test over 1,000 seeds: the structure rules from G18 hold for each.
- [ ] Pure: no file access (save/load is task 027 and still only produces bytes).

## Log

- 2026-10-10 A: blocked on G18 (the GDD gives node shares but no map shape).
