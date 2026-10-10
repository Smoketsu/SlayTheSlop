---
id: 023
title: Floor map generation and the map format
lane: run
owner: A
status: done
branch: a/023-floor-map-generation
depends_on: [003]
blocked_on: []
files:
  - core/run/map/
  - core/schema/run_state.gd   # only to document the map shape, in its own contract PR first
  - core/schema/README.md      # the same contract commit: "The floor map" section and the node id format
  - data/constants.json        # the same contract commit: additive MAP_ and NODE_SHARE_ constants
  - tests/run/map/
---

## Goal

Generate floor 1's branching map from the `map` stream, with node types in the GDD shares, and
define the `map` shape that `run_state.map`, `node_index` and `vote_node.node_id` refer to.

## Read first

GDD "Run structure" ("The loop", "Node types"); G18; `core/schema/run_state.gd`.

## Acceptance checks

- [x] Contract PR first: the shape of `map` (node ids, types, rows, links) in `run_state.gd` comments and `core/schema/README.md`.
  First commit on the branch, contract files only (plus `data/constants.json` and its change file); split it into its own PR.
- [x] Same seed, same map. Fixed-seed test against a recorded map. `test_fixed_seed_gives_recorded_map`, `test_same_seed_same_map`, `test_different_seeds_differ`.
- [x] Shares within rounding of the GDD table; one boss node at the end; every node reachable; every path reaches the boss. Checked per map by `_problems()` in `tests/run/map/test_floor_map.gd`.
- [x] Property test over 1,000 seeds: the structure rules from G18 hold for each. `test_g18_rules_hold_for_many_seeds` (seeds -500..499, real constants; about 1 s).
- [x] Pure: no file access (save/load is task 027 and still only produces bytes). `tests/core/test_purity.gd` and `test_documentation.gd` pass over `core/run/map/`.

## Notes

The map shape (full version in the header of `core/run/map/floor_map.gd`, summary in
`core/schema/README.md` "The floor map"):

- `map = {"floor": int, "nodes": [node, ...]}`, nodes ordered by row then column.
- `node = {"id": "r<row>c<column>", "row": int, "column": int, "type": String, "links": [ids]}`.
- `nodes[0]` is the entrance (row 0, type `start`), linked to every row-1 node. `node_index` is an
  index into `nodes`, so its `blank()` value 0 means "at the start of the floor". Moving to a node
  sets `node_index` to `index_of(map, node_id)`.
- Rows 1..`MAP_ROWS` (7) hold 2..4 nodes; row 1 all `brawl`, row 7 all `tailgate`; row 8 is one
  `boss`. Links: 1..2 per node, every next-row node linked into, links never cross.
- `generate(ruleset, state, floor_number) -> {state, map, error}` advances only the `map` stream
  and does not store the map; the run flow (task 025) sets `state.map` and `node_index = 0`.

Decisions taken here that the people should confirm (in the PR as well):

- **Shares vs the fixed rows (not settled by G18).** Shares are over rows 1..`MAP_ROWS` (entrance
  and boss excluded), rounded by largest remainder, and the fixed rows count toward their type.
  A pre-boss row of 4 Tailgates is more than a 12% share of most floors rounded up, so the
  pre-boss row's size is drawn only among sizes the share can hold. Effect over 1,000 seeds:
  pre-boss row of 2 nodes about 48%, 3 about 51%, 4 about 1%; the other rows are uniform 2..4.
  The alternative reading (shares over rows 2..6 only, as Slay the Spire does) would let every row
  be uniform but put far more Brawls and Tailgates on a floor than the GDD table says.
- Links never cross, and every valid non-crossing pattern between two rows is equally likely.
  Not a G18 rule; it keeps the map drawable.
- No placement rules beyond G18 (a Rival can be in row 2, Baileys can follow Baileys), because
  the GDD has none.
- The entrance node (`start`) is a representation choice for `node_index`, not a new node type
  in the GDD sense.
- `run_state.SCHEMA_VERSION` was not raised: the map shape was undefined before (`{}`), and no
  field changed. Raise it if the people prefer to mark the change.
- Not built here: a `check(map)` for the run flow or `snapshot.from_bytes()` to validate a loaded
  map. The tests' `_problems()` could become one; that belongs with task 025.
- G19 (Mimic Cooler replacing a Loot node) is task 025's encounters; the map only says `loot`.

## Log

- 2026-10-10 A: blocked on G18 (the GDD gives node shares but no map shape).
- 2026-10-10 A: Claimed. Every rule gap it waited on is answered "accept" (PR #20).
- 2026-10-10 A: G18 answered "accept". Done: contract commit (`run_state.gd` comments, schema
  README "The floor map", ten constants in `data/constants.json`, `docs/changes/2026-10-10-023-contract.md`),
  then `core/run/map/floor_map.gd` and `tests/run/map/test_floor_map.gd` (11 tests). Verified:
  `tools/test.sh` -> `104 passed, 0 failed` (Godot 4.7.2-stable, headless); `tools/test.sh map/`
  -> `11 passed, 0 failed` in about 5 s including import. Not done: the share/fixed-row decision
  above needs a person's confirmation; no map validator for loaded saves yet (task 025).
- 2026-10-10 A (lead): Split for review. The map shape docs are contract PR `a/023-contract`; the ten map
  constants moved into the constants contract PR (#24) so the two never edit `constants.json` at once.
  This branch = both contract branches + the generator and tests. `tools/test.sh` -> 104 passed, 0 failed.
  The shares-vs-fixed-rows reading is recorded as rule gap G31 (PR #20).
- 2026-10-10 A: Merged in #28 by Agent A under Smoketsu's temporary permission (Person B offline). Status `done`.
