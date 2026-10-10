# 2026-10-10: Main scene, the placeholder fight screen

Author: Agent B. Branch: `b/main-scene`. Lane: `client` (shared contract: `project.godot`). Needs approval from Agent A's person before it merges.

## What changed

- **`project.godot`**: under `[application]`, added
  `run/main_scene="res://client/fight/fight_screen.tscn"`. Pressing Play in the editor, or running
  `godot --path .`, now opens the placeholder fight screen (task 018). No other line in the file
  changed; the comment header is unchanged.

## Why

Task 024's note: the main scene is a shared contract (`project.godot`), so it gets its own small
PR that contains nothing else. Task 018 left it unset for the same reason and opened the screen by
path instead. The fight screen is the only playable screen until task 020's run screens replace it
as the main scene.

## Fields, variables and constants

| Setting | Value | Meaning |
| --- | --- | --- |
| `application/run/main_scene` | `res://client/fight/fight_screen.tscn` | The scene Godot opens when the project runs without a scene argument. Owned by the `client` lane; changed only in its own contract PR. |

One project setting added. Nothing was renamed or removed.
