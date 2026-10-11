# 2026-10-11 - Board: backlog of tasks for Agent B (041-055)

Written by Agent A at Smoketsu's request, so Agent B has a queue of work for the milestone 2 gate
("outside playtesters finish the floor and start a second run unprompted"). Board files only; no
code, data or contract changed. All tasks are `status: open` and unclaimed; Agent B claims them in
the usual claim PR. Ids are odd because Agent A wrote them (docs/tasks/README.md "Ids, owners, lanes").

## Added

| Task | Lane | What |
| --- | --- | --- |
| `docs/tasks/041-card-faces-in-hand.md` | client | Cards in hand drawn as card faces (cost, type, rarity, text, upgraded mark, dimmed when unplayable, hover to enlarge) |
| `docs/tasks/043-pile-and-deck-viewers.md` | client | Draw / discard / Tapped pile counts and viewers in a fight; run-deck viewer on the run header |
| `docs/tasks/045-tooltips.md` | client | Hover tooltips for statuses, intents, keywords, Gear and Brews, from one text table |
| `docs/tasks/047-turn-and-result-feedback.md` | client | Turn banners, End Turn pulse, victory / Passed Out banners, animation-speed setting |
| `docs/tasks/049-how-to-play.md` | client | First-run How to play panels and a menu button |
| `docs/tasks/051-playtest-builds.md` | tools | Export presets (own contract PR) and `tools/build.sh` for Windows, macOS, Linux builds |
| `docs/tasks/053-playtest-run-log.md` | client | Local `user://run_log.jsonl` summary of each run for playtesters to send back |
| `docs/tasks/055-placeholder-sound.md` | client | Placeholder sound effects by event kind, volume and mute setting |

## Variables, fields and constants

None added, renamed or removed. The tasks name new client-side settings that their owner will
document when built: an animation-speed setting (047), a How to play "seen" flag (049), volume and
mute (055), all in the client's `user://` settings, never in game state or the run save.
