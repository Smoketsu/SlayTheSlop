---
id: 043
title: Pile and deck viewers - draw, discard, Tapped piles in a fight, the run deck on the map
lane: client
owner: B
status: in_review
branch: b/043-pile-viewers
depends_on: [041]
blocked_on: []
files:
  - client/fight/
  - client/run/
  - client/visual/
  - tests/client/
---

## Goal

Players cannot see what is left in their draw pile, what they discarded, or what is in their deck
between fights. Add a count on each pile in a fight (draw, discard, and the pile the GDD calls
Tapped) that opens a scrollable grid of card faces (task 041) when clicked, and a "Deck" button on
the run header that shows the whole run deck, including upgrades, on every run screen.

## Read first

GDD "Turn flow" (piles), "Card types and keywords" (Tapped), "Tone and humor" (glossary);
`core/schema/` state shape for a Dude's piles and run deck; `client/fight/fight_screen.gd`,
`client/run/run_screen.gd` `_draw_header`.

## Acceptance checks

- [x] Each fight pile shows its count and updates after every request.
- [x] Clicking a pile opens an overlay of card faces; clicking outside or pressing Escape closes it.
- [x] The draw pile is shown **sorted** (by type, then name), never in draw order, so the viewer
      does not reveal the shuffle.
- [x] The run header has a Deck button on the map, reward, Tailgate, Baileys and Side Quest screens
      that shows the run deck with upgrades applied.
- [x] Opening a viewer never sends a request and never changes `state` (test).
- [x] A test opens each viewer and checks the cards it lists against the state.
- [x] `tools/test.sh` passes.

## Notes

- Use the pile field names from `core/schema/` as written; if a pile you need is not in state, stop
  and write a task for Agent A rather than computing it in the client.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (fight-screen polish backlog). Unclaimed.
- 2026-10-11 B: Claimed. Work starts once 041 (#112) and 049 (#111) merge, since it builds on the card faces and the client settings store.
- 2026-10-11 B: Done, in review. Branch `b/043-pile-viewers`, stacked on `b/047-turn-feedback`
  (and through it on `b/045-tooltips`, #120 and #119), so it merges after them. Every pile was
  already in state under the schema's names (`draw_pile`, `discard_pile`, `tapped_pile`, `deck`), so
  no task for Agent A was needed. Clicking a 057 pile icon opens `client/visual/pile_viewer.gd`, a
  scrollable grid of card faces; the draw pile is always sorted by type then name, the discard and
  Tapped piles are in pile order; Escape, Close or a click outside closes it. The run header's Deck
  button (map and every offer screen; hidden on the menu, in fights and on the run-over view) shows
  the whole deck, sorted, Lifted copies with their upgrade. Verified: `tools/test.sh` -> 584
  passed, 0 failed (`tests/client/test_pile_viewers.gd`: 6 tests: counts after a card and after
  Ready; each pile opened by a click and closed by Escape / outside click / Close with the state
  frozen and no request sent; draw pile sorted against a reversed draw order; the Deck button on the
  map and all five offer kinds with an upgraded copy, hidden in a fight); 1280x720 xvfb screenshots
  of the draw pile viewer and the deck viewer on the map. Not done: nothing in scope.
