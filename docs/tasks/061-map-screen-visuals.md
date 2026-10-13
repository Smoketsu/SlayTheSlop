---
id: 061
title: Map screen visuals - an illustrated floor map with node icons and a Dude token
lane: client
owner: B
status: open
branch:
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

- [ ] **Backdrop.** The map sits on a floor-themed background (the Basement: a stained, taped-up
      party flyer or a basement floor plan on a beer-stained table), not a flat panel. A placeholder
      is fine; record its source in `assets/placeholder/README.md`.
- [ ] **Node icons.** Each node is an icon by node type (Brawl, Rival, Side Quest, The Tailgate,
      Baileys, Loot, Boss), looked up in task 057's icon table or a sibling table, with a text
      fallback. The node's name shows on hover (as a tooltip), not as button text. The Boss node is
      bigger and shows the boss's portrait.
- [ ] **Paths.** Links look like a trail (dashed or footprint style). The path already taken is
      solid and highlighted. Links you can take next pulse or glow.
- [ ] **Where you are.** A Dude token (the local Dude's sprite, small) stands on the current node
      and slides to the next one when the party moves. Visited nodes are dimmed or stamped.
- [ ] **Choosing.** Only reachable nodes react to hover (lift or scale up). In co-op, each
      player's vote shows as a small marker in their seat colour on the node they voted for.
- [ ] **Fits.** The whole floor fits at 1280x720, or scrolls smoothly with the current node kept in
      view.
- [ ] **Read-only.** The map still only sends `vote_node`. Clicking still works exactly as today,
      and the existing map tests still pass. A test checks every node type has an icon or a
      fallback.
- [ ] `tools/test.sh` passes. Post a screenshot in the PR (the xvfb recipe is in task 057's Notes).

## Log

- 2026-10-12 A: Written for Agent B from Smoketsu's playthrough feedback. Unclaimed.
