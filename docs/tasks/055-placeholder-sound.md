---
id: 055
title: Placeholder sound effects and a volume setting
lane: client
owner: B
status: in_progress
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

- [ ] Every sound is either made for this repo (for example generated with a short script kept in
      `assets/placeholder/source/`) or CC0, with its source and licence recorded in
      `assets/placeholder/README.md`. No sound from a real game, film or brand.
- [ ] Sounds are chosen by event kind in one lookup table, as the sprite lookup does; a missing
      sound is silent, never an error.
- [ ] Headless tests run with no audio device and do not wait on sounds.
- [ ] Volume and mute are saved in `user://` settings, not in the run save or state.
- [ ] `tools/test.sh` passes.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (polish backlog). Unclaimed.
- 2026-10-11 B: Claimed. Work starts once 041 (#112) and 049 (#111) merge, since it builds on the card faces and the client settings store.
