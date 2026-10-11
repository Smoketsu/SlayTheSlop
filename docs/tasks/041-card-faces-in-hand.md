---
id: 041
title: Card faces in hand - cost, type, text, upgraded mark, playable state
lane: client
owner: B
status: open
branch:
depends_on: [028, 032]
blocked_on: []
files:
  - client/fight/
  - client/visual/
  - assets/placeholder/
  - tests/client/
---

## Goal

Cards in hand are still plain buttons. Draw each one as a card face: name, Hype cost in a corner,
type (Attack, Skill, Power, Junk) shown by frame colour and a label, rarity, and the rules text with
upgrades applied. Upgraded copies carry a visible mark (for example a "+" after the name). Cards the
player cannot play right now (not enough Hype, unplayable Junk, not their turn) are dimmed, and the
hovered card lifts and grows so its text can be read. Clicking a card works exactly as it does today.

## Read first

GDD "Card types and keywords", "Tone and humor" (glossary), "Tom, the Enforcer" (card tables). `client/fight/fight_screen.gd`
(`press_card`, `_redraw`), `client/visual/combatant_view.gd` (the panel style to match),
`core/combat/upgrades.gd` `upgraded()` (the effective definition; the screen already reads it, task
upgraded-card-display), `core/schema/card_def.gd` (`type`, `rarity`, `cost`, `text`).

## Acceptance checks

- [ ] A card-face view in `client/visual/` builds a card from its effective definition (after
      upgrades) and nothing else: no card id is hard-coded in it.
- [ ] It shows name, cost, type, rarity and rules text; X-cost or unplayable (cost -1) cards show
      that instead of a number.
- [ ] An upgraded copy shows the upgraded name mark and the upgraded text and cost.
- [ ] A card is dimmed when the core would refuse to play it. The view asks the core
      (`Core.validate` with the play request, or the same check the screen already uses); it does
      not re-implement Hype or playability rules in the client.
- [ ] Hover lifts and enlarges the card; it never changes `state` (the read-only state test from
      task 024 still passes through a fight played by presses).
- [ ] A test builds the face for a common card, an upgraded card and a Junk card and checks the
      text it shows (`drawn_text()` or an equivalent text collector).
- [ ] `tools/test.sh` passes.

## Notes

- Placeholder art only (CLAUDE.md "Writing and content rules"). Frames can be flat `StyleBoxFlat`
  colours; record any image you did not make in `assets/placeholder/README.md`.
- Must still work with a full hand of 10 cards at 1280x720 without overlapping the Dude or enemies.
  Fan or overlap the cards if they do not fit in a row.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (fight-screen polish backlog). Unclaimed.
