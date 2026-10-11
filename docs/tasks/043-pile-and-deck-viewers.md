---
id: 043
title: Pile and deck viewers - draw, discard, Tapped piles in a fight, the run deck on the map
lane: client
owner: B
status: in_progress
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

- [ ] Each fight pile shows its count and updates after every request.
- [ ] Clicking a pile opens an overlay of card faces; clicking outside or pressing Escape closes it.
- [ ] The draw pile is shown **sorted** (by type, then name), never in draw order, so the viewer
      does not reveal the shuffle.
- [ ] The run header has a Deck button on the map, reward, Tailgate, Baileys and Side Quest screens
      that shows the run deck with upgrades applied.
- [ ] Opening a viewer never sends a request and never changes `state` (test).
- [ ] A test opens each viewer and checks the cards it lists against the state.
- [ ] `tools/test.sh` passes.

## Notes

- Use the pile field names from `core/schema/` as written; if a pile you need is not in state, stop
  and write a task for Agent A rather than computing it in the client.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (fight-screen polish backlog). Unclaimed.
- 2026-10-11 B: Claimed. Work starts once 041 (#112) and 049 (#111) merge, since it builds on the card faces and the client settings store.
