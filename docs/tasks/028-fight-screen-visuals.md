---
id: 028
title: Fight screen visuals - character sprites, health bars, intents and event animation
lane: client
owner: B
status: done
branch: b/028-fight-visuals
depends_on: [024]
blocked_on: []
files:
  - client/
  - tests/client/
  - assets/            # only to add placeholder art the screen needs, with its source recorded
---

## Goal

The fight screen stops being text only. Each Dude and enemy is drawn with its placeholder sprite from
`assets/placeholder/characters/<def_id>.png` (#81), with an HP bar, Guard and statuses beside it, and
the enemy's intent above it. The events a request returns are played as short animations (hit,
Guard gained, death, Passed Out) in order, then the screen shows the new state. The client still
never changes game state: it only reads `state` and animates `events`.

## Read first

GDD "Technical design" (client and core), "Combat" (intents, statuses); CLAUDE.md "The rules core is
pure"; `client/fight/fight_screen.gd` and `fight_model.gd` (tasks 018, 024); `core/schema/event.gd`;
`assets/placeholder/README.md`.

## Acceptance checks

- [x] A sprite lookup in `client/` maps a Dude or enemy `def_id` to its texture, with a visible
      fallback for ids with no art (for example `foam_slime`); no id is hard-coded except in that
      lookup's fallback table.
- [x] The fight screen shows a sprite, HP bar, Guard and statuses for every Dude and enemy in state,
      and each enemy's intent; it updates after every request.
- [x] Damage, Guard, death and Passed Out events animate in event order; animation never changes
      `state` (a test freezes state read-only through a whole fight played by presses, as in 024).
- [x] Animations can be skipped or run instantly in tests (headless, no frame timing in assertions).
- [x] `tools/test.sh` passes.

## Notes

- `foam_slime` has no art yet; `rat_king` art exists without data.
- Run screens are task 020; this task only covers the fight screen.

## Log

- 2026-10-10 B: Written and claimed (next free even id). steamjgrube asked for the visualization
  system on the new placeholder assets.
- 2026-10-10 B: Built on `b/028-fight-visuals`; ready for review.
  - Done: `client/visual/sprites.gd` (def_id -> texture from `assets/placeholder/characters/`,
    `FALLBACKS` with `foam_slime` -> `keg_slime` art smaller and paler, generated generic box for any
    other id with no art); `client/visual/combatant_view.gd` (clickable view: intent, sprite, name,
    HP bar and text, Guard, statuses, details; drawn from one fight model entry);
    `client/visual/event_player.gd` (events in order: damage = red flash + shake + number pop,
    fully blocked hit and Guard gain = blue flash, heal = green, enemy died/fled/split = fade out,
    Passed Out = grey and tip over, every other event = log line only; `seconds <= 0` is instant).
    Fight screen: Dudes left, enemies right, a 4-line event log under them, then hand, actions and
    message; `_send()` plays events on the views, then redraws everything from the returned state.
    `fight_model.gd` entries also carry `def_id`, `hp_now`, `hp_max`.
  - Tests: new `tests/client/test_fight_visuals.gd` (every Dude and enemy id in data/ gets real art
    after import, `foam_slime` and unknown/malformed ids fall back, one view per combatant with sprite,
    HP and Guard from state and the HP bar following a hit, clicking an enemy view targets it, every
    `Event.TYPES` type maps to a kind and plays instantly in order through the screen with a redraw
    after, timed `play_one()` returns lengths without waiting and never changes state). The existing
    `test_full_fight_through_the_screen` (state frozen read-only through a whole fight) passes
    unchanged with the views on.
  - Verified: `tools/test.sh` -> `436 passed, 0 failed` (client: 22). `godot --headless --path .
    --quit-after 60` -> exit 0, no ERROR or SCRIPT ERROR lines. Looked at the screen under Xvfb
    (`xvfb-run ... --rendering-driver opengl3`, screenshots of the start, a Punch mid-animation and
    after): sprites, bars, intents and the red flash with "-6" pop-up show as intended.
  - Not done: no own art for `foam_slime` (uses the fallback); status changes, intents being set and
    enemies spawning only log (new enemies appear at the redraw); cards in hand are still text
    buttons; animation timing itself is not asserted anywhere (by design, tests run instantly).
- 2026-10-10 B: Follow-up from the lead: fight backgrounds. Merged `origin/main` (#84 placeholder
  backgrounds) into the branch (merge commit, no rebase).
  - Done: `client/visual/backgrounds.gd` (`room_for(state)`: the first enemy, left to right, with
    `assets/placeholder/backgrounds/<def_id>.webp` is a boss room; otherwise `FLOOR_ROOMS[floor]`,
    floor 1 -> `basement`, or `DEFAULT_ROOM` "basement"; a missing file gives null and the screen
    shows `FALLBACK_COLOR`). The fight screen picks the room once in `setup()` and draws it behind
    everything (cropped to fill), under a 50% black shade; the combatant views, event log and
    message bar got translucent dark panels.
  - Tests: 3 more in `tests/client/test_fight_visuals.gd`: the dev fight uses and draws the
    Basement; a state with `goblin_king_chad` among its enemies uses that room; unknown and malformed
    rooms, an unknown floor and no fight fall back without error, and the screen then shows the plain
    colour with no picture.
  - Verified: `tools/test.sh` -> `439 passed, 0 failed`. `godot --headless --path . --quit-after 60`
    -> exit 0, no ERROR lines. Xvfb screenshot of the Basement fight after a Punch: text and views
    readable over the room.
  - Not done: floors 2 and 3 have no rooms yet (they would use `DEFAULT_ROOM` until `FLOOR_ROOMS`
    gets entries); `rat_king` has a room but no enemy data, so it is never picked today.
- 2026-10-11 B: Done: merged (#85; claim #82; backgrounds from #84). Agent A's review left one
  non-blocking point: `EventPlayer.played` grows for the screen's whole life, which is fine for one
  fight; trim it if a player object is ever kept across a run. Follow-up, not done.
