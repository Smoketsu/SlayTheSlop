---
id: 061
title: Map screen visuals - an illustrated floor map with node icons and a Dude token
lane: client
owner: A
status: in_review
branch: a/061-map-visuals
depends_on: [057]
blocked_on: []
files:
  - client/run/map_screen.gd
  - client/run/run_text.gd
  - client/visual/
  - assets/placeholder/
  - tests/client/
---

## Goal

Smoketsu (2026-10-12): navigation between nodes works as intended, but the map should get "the
same care" as the fight screen got in task 057. Today the map is text buttons (`NODE_SIZE` 120x44)
joined by plain lines. Make it look like a place you are travelling through, without changing what
any click does.

## Read first

`client/run/map_screen.gd`, `client/run/run_screen_api.md`, `client/visual/icons.gd` and
`client/visual/floor_layout.gd` (task 057's icon table and style); GDD "Node types", "Floors"
(The Basement); `core/schema/run_state.gd` (map nodes, `node_index`, `path`, votes).

## Acceptance checks

- [x] **Backdrop.** The map sits on a floor-themed background (the Basement: a stained, taped-up
      party flyer or a basement floor plan on a beer-stained table), not a flat panel. A placeholder
      is fine; record its source in `assets/placeholder/README.md`.
- [x] **Node icons.** Each node is an icon by node type (Brawl, Rival, Side Quest, The Tailgate,
      Baileys, Loot, Boss), looked up in task 057's icon table or a sibling table, with a text
      fallback. The node's name shows on hover (as a tooltip), not as button text. The Boss node is
      bigger and shows the boss's portrait.
- [x] **Paths.** Links look like a trail (dashed or footprint style). The path already taken is
      solid and highlighted. Links you can take next pulse or glow.
- [x] **Where you are.** A Dude token (the local Dude's sprite, small) stands on the current node
      and slides to the next one when the party moves. Visited nodes are dimmed or stamped.
- [x] **Choosing.** Only reachable nodes react to hover (lift or scale up). In co-op, each
      player's vote shows as a small marker in their seat colour on the node they voted for.
- [x] **Fits.** The whole floor fits at 1280x720, or scrolls smoothly with the current node kept in
      view.
- [x] **Read-only.** The map still only sends `vote_node`. Clicking still works exactly as today,
      and the existing map tests still pass. A test checks every node type has an icon or a
      fallback.
- [x] `tools/test.sh` passes. Post a screenshot in the PR (the xvfb recipe is in task 057's Notes).

## Log

- 2026-10-12 A: Written for Agent B from Smoketsu's playthrough feedback. Unclaimed.
- 2026-10-13 A: Taken over from Agent B at Smoketsu's request (B is out of usage until Wednesday;
  Smoketsu lets Agent A work every lane and merge its own PRs until then). Claimed and done in one PR.
  - **Art:** `assets/placeholder/map/` (backdrop and 8 node icons), generated with the OpenAI image API
    on Smoketsu's account (as task 063's splashes); sources in `assets/placeholder/README.md` "Map".
  - **Lookup:** `client/visual/map_art.gd` (floor backdrop, `NODE_ICONS` by node type, the Boss portrait
    when the floor has exactly one boss, so a floor that "rolls one of two" never gives it away).
  - **Screen:** `client/run/map_screen.gd`: backdrop (tinted a little darker), header on a dark strip,
    icon buttons (58 px, Boss 96 px with Goblin King Chad's portrait), the name and "You are here" /
    "Your vote" in the tooltip; dashed trail links, the walked path solid red, the links you can take now
    pulsing; the local Dude's sprite as a token on the party's node, sliding 0.45 s to the next node;
    visited nodes dimmed; reachable nodes grow on hover (others have no hover); co-op vote markers in seat
    colours, in seat order. Fits 1280x720 for the slice's 7-row map; a taller map scrolls with the
    party's node kept in view. Clicking is unchanged (still only `vote_node`).
  - **Tests:** `tests/client/test_map_screen.gd` now reads node names from tooltips instead of button
    text (the task moves them there); new `tests/client/test_map_visuals.gd` (icons and fallbacks,
    1280x720 fit on every voting state, Boss size and portrait, token place and slide, visited tint,
    vote markers, the two-boss rule). `tools/test.sh` results are in the PR. Screenshots at 1280x720 were
    checked by eye.
  - **Not done:** visited nodes are dimmed, not stamped. The open-link pulse is not unit-tested (it is a
    draw-time opacity).
