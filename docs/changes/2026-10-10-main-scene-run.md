# 2026-10-10: the main scene is the run screen (contract)

## What changed

- `project.godot`: `application/run/main_scene` goes from `res://client/fight/fight_screen.tscn` to
  `res://client/run/run_screen.tscn`. Nothing else in the file changed.

## Why

Task 020 (#87) added the run screen: the main menu (New Run, Continue), the map, every node's
choices, the fight and the run-over view. Running the project should open the menu, not a dev fight.
The fight screen still runs on its own (its dev fight) when opened directly.

## Fields, variables and constants

| Setting | Change |
| --- | --- |
| `application/run/main_scene` | Value changed from the fight screen to the run screen. |
