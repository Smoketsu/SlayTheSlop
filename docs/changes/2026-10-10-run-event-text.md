# 2026-10-10: Client event text for the run events (stacked on #66)

## What changed
- `client/fight/event_text.gd`: one `TEMPLATES` line for each of the 14 event types task 025 adds
  to `core/schema/event.gd`. `line()` looks up code fields (status, node type, offer kind, Side
  Quest roll) through `messages.gd field_word()`; `names_for()` also names Side Quest definitions
  and the current map's nodes.
- `client/fight/messages.gd`: `NODE_TYPES`, `OFFER_KINDS`, `SIDE_QUEST_ROLLS` and `field_word()`.
- Added `tests/client/test_run_event_text.gd`: run lines resolve names, the Baileys lines never
  say Brew or a drink, and every template's placeholders are filled for every event type.

## Why
Agent A's review on #69 asked for these, so `main` stays green
(`test_every_reject_and_event_has_text`) when task 025 (#64 to #66) merges.

`item_bought` does not say what was bought, and `brew_gained` also follows a Shake bought at
Baileys, so neither line says "Brew": they name only the Brew itself (CLAUDE.md, GDD G29).
`side_quest_rolled` stays neutral ("it happens." / "it doesn't.") because the "then" outcome is
sometimes the bad one.

## Fields, variables and constants

| Name | Where | Change | Meaning |
| --- | --- | --- | --- |
| `TEMPLATES["floor_started"]` | `event_text.gd` | added | "Floor {floor} begins." |
| `TEMPLATES["vote_cast"]` | `event_text.gd` | added | "{player_id@} votes for {node_id@}." |
| `TEMPLATES["node_entered"]` | `event_text.gd` | added | "The party heads into {node_type@}." |
| `TEMPLATES["offer_opened"]` | `event_text.gd` | added | "{player_id@} has a choice: {kind@}." |
| `TEMPLATES["offer_closed"]` | `event_text.gd` | added | "{player_id@} is done choosing." |
| `TEMPLATES["item_bought"]` | `event_text.gd` | added | "{player_id@} pays {price} Dolla Bills at Baileys." |
| `TEMPLATES["card_upgraded"]` | `event_text.gd` | added | "{card_uid@} is upgraded." |
| `TEMPLATES["brew_gained"]` | `event_text.gd` | added | "{player_id@} stashes {brew_id@} for later." |
| `TEMPLATES["brew_not_kept"]` | `event_text.gd` | added | "{player_id@} has no room for {brew_id@}." |
| `TEMPLATES["side_quest_rolled"]` | `event_text.gd` | added | "{side_quest_id@}: {percent}% chance... {won@}" |
| `TEMPLATES["pending_status_added"]` | `event_text.gd` | added | "{player_id@} will start the next fight with {stacks} {status@}." |
| `TEMPLATES["dude_revived"]` | `event_text.gd` | added | "{player_id@} wakes up with {hp} HP." |
| `TEMPLATES["floor_ended"]` | `event_text.gd` | added | "Floor {floor} cleared!" |
| `TEMPLATES["run_ended"]` | `event_text.gd` | added | "The run is over: {result}." |
| `names_for()` | `event_text.gd` | changed | Also maps Side Quest ids (ruleset `side_quests`) and map node ids (state `map.nodes`, named by type) |
| `line()` `{field@}` | `event_text.gd` | changed | Falls back to `Messages.field_word(key, value)` instead of special-casing `status` only |
| `NODE_TYPES` | `messages.gd` | added | Map node type -> how a line names it ("a Brawl", "Baileys" ...) |
| `OFFER_KINDS` | `messages.gd` | added | Offer kind -> what the choice is ("Nap or Lift" ...) |
| `SIDE_QUEST_ROLLS` | `messages.gd` | added | `won` as text -> end of the `side_quest_rolled` line |
| `field_word(key, value)` | `messages.gd` | added | Player-facing word for a code field's value; any other value returned as is |
| `RULESET`, `STATE`, `_line()` | `tests/client/test_run_event_text.gd` | added | Test fixtures and helper |

No shared contract changed.
