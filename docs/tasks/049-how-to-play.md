---
id: 049
title: How to play - a short first-run overlay for outside playtesters
lane: client
owner: B
status: in_review
branch: b/049-how-to-play
depends_on: []
blocked_on: []
files:
  - client/
  - tests/client/
---

## Goal

The milestone 2 gate is "outside playtesters finish the floor and start a second run unprompted".
People who have never seen the game need a short explanation. Add a "How to play" screen reachable
from the main menu, shown once automatically on the first new run: Hype and cost, Guard, enemy
intents, the Bro Meter and Chest Bump, the map node types, and Brews and Gear. Five to eight short
panels, each one or two sentences, with Next, Back and Skip.

## Read first

GDD "The loop", "Node types", "Turn flow", "Bro Meter", "Items", "Tone and humor", "Rules for writers";
`client/run/main_menu.gd`, `client/run/run_screen.gd`.

## Acceptance checks

- [x] The main menu has a How to play button that opens the panels.
- [x] The first new run on a machine shows the panels once; a flag in `user://` settings (not the
      run save) stops it repeating. Skip works from any panel.
- [x] Every number mentioned (starting Hype, hand size, and so on) is read from the ruleset or
      `data/constants.json`, not typed into the text.
- [x] Text follows "Rules for writers" and the glossary terms (Hype, Guard, Dolla Bills, Gear, Brew,
      Baileys sells Shake, The Tailgate).
- [x] A test opens the screen, pages to the end, and checks Skip and the once-only flag.
- [x] `tools/test.sh` passes.

## Notes

- Settings store: `client/settings/user_settings.gd` (static `get_setting(key, default, path)`,
  `set_setting(key, value, path) -> error`, `erase_settings(path)`; ConfigFile at
  `user://settings.cfg`, section `settings`, .tmp-then-rename writes, user:// paths only). Tasks 047
  (animation speed) and 055 (volume / mute) can add their own keys without touching this file; each
  key is a constant in the file that uses it.
- The seen flag is `HowToPlay.SEEN_KEY` = `"how_to_play_seen"` (`client/help/how_to_play.gd`). The run
  screen sets it whenever the panels open (menu button or the automatic first-run showing), so a
  player who read them from the menu is not shown them again on their first run.
- The run screen owns the overlay (`show_how_to_play()`, `how_to_play_screen()`, `settings_path`);
  the menu's button only emits `how_to_play_requested`. Continue never opens it.
- A settings file that does not parse reads as defaults, but Godot logs a ConfigFile parse error for
  it, which the test runner counts as a failure, so that case has no test.
- Any test that drives `run_screen` through New Run should set `settings_path` to its own user://
  file (as `tests/client/test_run_screen.gd` `_screen()` now does) so it never writes the real one.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (playtest readiness). Unclaimed.
- 2026-10-11 B: Claimed (steamjgrube: pick up work the board asks for).
- 2026-10-11 B: Done, in review. Seven panels (Hype and cards, Guard, enemy intents, Bro Meter and
  the Dude's Bro Move, the map's fights, the other stops, Brews and Gear) in `client/help/`, a How to
  play button on the main menu, shown once on the first new run via a new client settings store
  (`client/settings/user_settings.gd`). Every number comes from `ruleset["constants"]` or the Bro
  Move card's text. Tests: `tests/client/test_how_to_play.gd` (6), `tests/client/test_user_settings.gd`
  (3). Verified with `tools/test.sh`: 521 passed, 0 failed. Not done: nothing in scope; animation
  speed and volume settings are tasks 047 and 055.
