---
id: 067
title: Map nodes stay inside the backdrop's open area, never on the drawn rooms
lane: client
owner: A
status: in_review
branch: a/067-map-nodes-in-open-area
depends_on: [061]
blocked_on: []
files:
  - client/run/map_screen.gd
  - client/visual/map_art.gd
  - tests/client/test_map_visuals.gd
---

## Goal

Smoketsu (2026-10-13), on the task 061 map: the nodes "should live in that blank area in the middle of
the image, but go over the lines into the rooms". Place every node inside the backdrop's open middle
area, at any window size.

## Acceptance checks

- [x] Each backdrop can name its open area (fractions of the picture), measured on the picture.
- [x] The nodes are laid out inside that area as it is drawn on screen (the backdrop covers the
      screen keeping its aspect), spread over its height, closer together when it is narrow.
- [x] A backdrop with no measured area uses the screen below the header.
- [x] A test checks every node of every voting state at 1280x720, and a new run at 1024x768 and
      1920x1080, sits inside the area. `tools/test.sh` passes.

## Log

- 2026-10-13 A: Written and done at Smoketsu's request (Agent A works every lane until Wednesday).
  Measured the Basement backdrop (1536 x 1024) with a pixel grid: the open room is x 625..1015,
  y 275..915 (`client/visual/map_art.gd` `PLAY_AREAS`). `client/run/map_screen.gd` now places its board
  over that area (`play_rect`), re-lays out when the screen is resized, and no longer scrolls (the area
  always holds the map; gaps shrink to fit). Verified: `tools/test.sh` (results in the PR); a 1280x720
  screenshot checked by eye shows every node on the open paper. Not done: nothing in scope.
