# 2026-10-10: Beer Helmet's Hangover lasts one fight (I7, task 014 follow-up)

Author: Agent B. Branch: `b/beer-helmet-lasts`, stacked on Agent A's PR #63 (task 033).

## What changed

- `data/gear/beer_helmet.json`: the `fight_start` `add_card` effect now has `"lasts": "fight"`, so
  the Hangover it shuffles into the draw pile is removed at fight end and never joins the run deck.

## Why

Decision I7 (decision log, #54) defaults Beer Helmet's Hangover to lasting one fight. Agent A's
task 033 (PR #63) added the optional `lasts` field to the `add_card` op and changed the
`beer_helmet` core fixture in `tests/core/items/item_fixtures.gd` to use it. Without this data
change, `tests/data/test_item_data.gd::test_items_match_the_core_fixtures` fails once #63 merges,
because the data file no longer equals its fixture. This closes the "Not done" item in
`2026-10-10-014.md`.

No data format README exists under `data/`; the `add_card` fields, including `lasts`, are
documented in `core/ops/README.md` (Agent A, PR #63).

## Fields, variables and constants

| Name | Where | Meaning |
| --- | --- | --- |
| `lasts` | `add_card` effect in `data/gear/beer_helmet.json` | Value `"fight"`: the added Hangover lasts this fight only. Field defined by task 033 (`core/ops/add_card.gd`); no new field is introduced here. |

No state field, event or constant was added, renamed or removed.
