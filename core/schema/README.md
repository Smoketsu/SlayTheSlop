# core/schema — shared shapes

**Shared contract.** Both agents read this folder; change it only in a small PR that contains
nothing else, approved by the other agent's person (CLAUDE.md "Shared contracts").
Additive changes (a new optional field, a new event type, a new reject reason) are fine.
Renaming, removing or changing the meaning of anything here needs a proposal.

Every field's meaning, unit and range is in the comment next to it in the `.gd` file. This page
covers the rules that span files.

## Files

| File | Shape of | Source in the GDD |
| --- | --- | --- |
| `run_state.gd` | The whole state of a run: what `apply()` takes and returns, and what a save holds | "Run state" |
| `dude_state.gd` | One player's Dude, in `run_state.dudes` | "Dude state" |
| `combat_state.gd` | The fight in progress, in `run_state.combat` | "Turn flow" (no table; all fields added) |
| `enemy_state.gd` | One enemy in a fight, in `combat.enemies` | "Enemy fields" (per-fight values) |
| `request.gd` | Requests a player sends; reject reason codes | "Network messages" |
| `event.gd` | Events `apply()` returns for the client to animate | Examples under "How a card gets played in co-op" |
| `card_def.gd` | A card definition file in `data/cards/` | "Card definition fields" |
| `enemy_def.gd` | An enemy definition file in `data/enemies/` | "Enemy fields" (fixed values) |
| `dude_def.gd` | A Dude definition file in `data/dudes/` | The Dude attribute tables (no field table; added) |
| `shape.gd` | The type checker the files above use | — |
| `json_values.gd` | JSON parsing that turns whole numbers back into ints | — |

Each state or definition file has a `SPEC` (field → type), a `blank()` or nothing, and a
`check(value) -> Array[String]` that returns every problem found (empty means valid). Checks are
strict: unknown fields are errors, and an `int` field holding `3.0` is an error.

Gear, Brew and Side Quest definition formats are not here yet (tasks 021 and 025).

## The core's entry point

```gdscript
Core.apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary
# returns {"state": Dictionary, "events": Array[Dictionary], "reject": String}
```

- CLAUDE.md writes this as `apply(state, request)`. The extra `ruleset` argument is the loaded,
  read-only content (constants, cards, enemies, Dudes ...). It is passed in rather than read from
  disk because the core may not touch files, and it is kept out of `state` because saves refer to
  content by id. Accepted by both people on #23 (2026-10-10).
- `reject` is `""` when the request was applied. Otherwise it is one of `request.gd`'s
  `REJECT_REASONS`, `state` is returned unchanged (same `state_version`) and `events` is empty.
- An applied request raises `state_version` by exactly 1, however many events it produced.
- `apply()` never mutates its arguments; it returns a new state.

## Rules for state values

- Only JSON-shaped values: `Dictionary` (String keys), `Array`, `String`, `int`, `bool`, `null`.
  No `float`, no `Object`, no `Vector2`, no typed engine resources.
- Game values are `int`. Multipliers from `constants.json` (1.5, 0.75, 0.4 ...) are used inside a
  calculation and the result is rounded down where the GDD says; a float is never stored.
- Order is meaning. Lists are ordered (piles, enemies left to right, dudes by seat). Dictionaries
  are maps whose iteration order must never affect a result: sort the keys first.

## Ids

| Thing | Format | Made by |
| --- | --- | --- |
| Player / Dude in a run | `p1` .. `p4`, by seat | Core, at run start |
| Card copy (`card_uid`) | `c` + number, e.g. `c12` | Core, from `run_state.next_uid` |
| Enemy in a fight (`uid`) | `e` + number, e.g. `e3` | Core, from `run_state.next_uid` |
| Content (card, enemy, Dude, Gear, Brew) | `snake_case`, cards as `owner_card_name` | Content lane; never changes once merged |
| Map node (`node_id`) | `r<row>c<column>`, e.g. `r3c1`; unique within one floor's map | Run lane, when a floor's map is generated |

A `target_id` holds a player id or an enemy uid. The prefixes never collide.

## The floor map

`run_state.map` holds the current floor's map; `run_state.node_index` says where the party is on
it. The run lane owns the shape (generator and full rules: `core/run/map/floor_map.gd`, task 023).
The structure follows gap G18 in `docs/proposals/solo-slice-rule-gaps.md`.

```
map  = {"floor": int,                  # the floor this map belongs to, 1 or more
        "nodes": [node, ...]}          # ordered by row, then column
node = {"id": "r2c1",                  # "r<row>c<column>"; what vote_node.node_id names
        "row": 2,                      # 0 entrance, 1..MAP_ROWS the floor's rows, MAP_ROWS + 1 the boss
        "column": 1,                   # order within the row, 0 = leftmost
        "type": "rival",               # start | brawl | rival | side_quest | tailgate | baileys | loot | boss
        "links": ["r3c1", "r3c2"]}     # ids in the next row this node leads to, in column order
```

- `nodes[0]` is the entrance: row 0, type `start`, linked to every row-1 node. It is where the
  party stands before the first vote, so `node_index` 0 (the `blank()` value) means "at the
  start of the floor". It is not one of the floor's nodes in the GDD sense: no shares, no reward.
- `node_index` is an index into `nodes`. Moving to a node means setting `node_index` to its index.
- Rows 1..`MAP_ROWS` each hold `MAP_MIN_NODES_PER_ROW`..`MAP_MAX_NODES_PER_ROW` nodes. Each of
  their nodes links to 1..`MAP_MAX_LINKS` nodes of the next row, and every node of the next row
  has at least one link into it, so every node is reachable and every path reaches the boss.
  Links never cross: if node a is left of node b, none of a's targets is right of any of b's.
- Row 1 is all `brawl`; row `MAP_ROWS` (the row before the boss) is all `tailgate`; row
  `MAP_ROWS + 1` is one `boss` node with `links` `[]`.
- Node types over rows 1..`MAP_ROWS` follow the `NODE_SHARE_*` constants (GDD "Node types"),
  rounded to whole nodes per floor: each type's count is its exact share rounded down or up.
- Generated only from the `map` random stream, so the same seed gives the same map.

## Status ids

Used as keys in `statuses`, as `effects[].status` in `apply_status`, and in `status_changed` events.

| Id | GDD status | Stored in |
| --- | --- | --- |
| `exposed` | Exposed | `statuses` |
| `noodle_arms` | Noodle Arms | `statuses` |
| `hungover` | Hungover | `statuses` (Dudes) |
| `foggy` | Foggy | `statuses` (Dudes) |
| `broken_arm` | Broken Arm | `enemy.broken_arms` (not `statuses`), capped at `arm_count` |
| `ick` | Ick | `enemy.ick` (not `statuses`) |

Bugs (Nate) and later statuses are added when they are built.

## Serialization

- **Snapshots and saves:** `var_to_bytes(state)` and `bytes_to_var(bytes)`. This round-trips
  every 64-bit int exactly. Do not pass `true` for `allow_objects`.
- **Never JSON for state.** JSON numbers are doubles, so ints above 2^53 (the seed and random
  stream states) come back changed. `tests/core/schema/test_schema.gd` proves it.
- **Content data is JSON** and must be parsed with `json_values.parse()`, because Godot's parser
  returns every number as a float.
- The co-op state hash (GDD step 6) should be computed from the snapshot bytes; task 027.

## Changing this folder

1. Open a task (or use the one you are on) and say which shape changes and why.
2. In one PR containing nothing else: change the `.gd` file, its comments, this page if a
   cross-file rule changed, the tests in `tests/core/schema/`, and a `docs/changes/` file.
3. If the state shape changed, raise `run_state.SCHEMA_VERSION` by 1.
4. The other agent's person approves it; after it merges, the other agent rebases.
