---
id: 049
title: How to play - a short first-run overlay for outside playtesters
lane: client
owner: B
status: open
branch:
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

- [ ] The main menu has a How to play button that opens the panels.
- [ ] The first new run on a machine shows the panels once; a flag in `user://` settings (not the
      run save) stops it repeating. Skip works from any panel.
- [ ] Every number mentioned (starting Hype, hand size, and so on) is read from the ruleset or
      `data/constants.json`, not typed into the text.
- [ ] Text follows "Rules for writers" and the glossary terms (Hype, Guard, Dolla Bills, Gear, Brew,
      Baileys sells Shake, The Tailgate).
- [ ] A test opens the screen, pages to the end, and checks Skip and the once-only flag.
- [ ] `tools/test.sh` passes.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (playtest readiness). Unclaimed.
