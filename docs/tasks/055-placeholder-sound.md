---
id: 055
title: Placeholder sound effects and a volume setting
lane: client
owner: B
status: in_review
branch: b/055-placeholder-sound
depends_on: [028]
blocked_on: []
files:
  - assets/placeholder/
  - client/
  - tests/client/
---

## Goal

The game is silent. Add a small set of placeholder sounds played from the event player and the
screens: card played, hit, blocked hit, Guard gained, enemy death, Passed Out, button click, Dolla
Bills gained, victory and defeat. Add a master volume slider and mute in the client's `user://`
settings.

## Read first

GDD "Music and audio"; CLAUDE.md "Writing and content rules" (placeholder art and sound: make it yourself or use clearly
free sounds and record the source); `assets/placeholder/README.md`; `client/visual/event_player.gd`
(`effect_for` kinds).

## Acceptance checks

- [x] Every sound is either made for this repo (for example generated with a short script kept in
      `assets/placeholder/source/`) or CC0, with its source and licence recorded in
      `assets/placeholder/README.md`. No sound from a real game, film or brand.
- [x] Sounds are chosen by event kind in one lookup table, as the sprite lookup does; a missing
      sound is silent, never an error.
- [x] Headless tests run with no audio device and do not wait on sounds.
- [x] Volume and mute are saved in `user://` settings, not in the run save or state.
- [x] `tools/test.sh` passes.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (polish backlog). Unclaimed.
- 2026-10-11 B: Claimed. Work starts once 041 (#112) and 049 (#111) merge, since it builds on the card faces and the client settings store.
- 2026-10-11 B: Done, in review. Ten sounds (card played, hit, blocked hit, Guard gained, enemy
  death, Passed Out, button click, Dolla Bills gained, victory, defeat) synthesized by
  `assets/placeholder/source/make_sounds.py` (stdlib only, deterministic) into
  `assets/placeholder/sounds/*.wav` (16-bit mono 22050 Hz, all under 1 s, 173 KB total; source and
  licence in `assets/placeholder/README.md` "Sounds"). One lookup, `client/audio/sounds.gd` `FILES`,
  plus `kind_for_event()`; a missing kind or file is silent. Fight events play through
  `client/visual/event_player.gd` `play_one()`; button clicks and map/offer events (Dolla Bills)
  through `client/run/run_screen.gd`; `fight_screen.gd` untouched. Volume and mute: settings keys
  `master_volume` and `master_muted` (`client/audio/volume.gd`), applied to the Master bus, set from
  a Sound row (`client/settings/sound_settings.gd`) on the main menu. Under Godot's dummy audio
  driver (headless) the players are made but not started, so a sound still playing at quit is not
  reported as a leak. Verified: `tools/test.sh` 538 passed, 0 failed; `tools/test.sh sounds` 9
  passed. Not done: nobody has listened on a real audio device (none in the container); no floor
  music (not in this task).
