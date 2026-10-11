---
id: 045
title: Tooltips for statuses, intents, keywords, Gear and Brews
lane: client
owner: B
status: open
branch:
depends_on: [028]
blocked_on: []
files:
  - client/
  - tests/client/
---

## Goal

A new player cannot tell what Swole, Exposed, Noodle Arms, Broken Arm, Ick, Hungover and the other
statuses do, what an enemy's intent icon means, or what a Gear or Brew does. Hovering any of them
shows a short tooltip with its name and what it does, written from the GDD's rules and in the GDD's
voice. Keywords on a card face (task 041, if merged) get the same tooltip.

## Read first

GDD "Statuses", "Stats", "Card types and keywords", "Enemies" (intents), "Items", "Brews", "Tone and humor" and
"Rules for writers". `client/visual/combatant_view.gd` (where statuses and intents are drawn),
`client/run/run_text.gd` and `client/fight/event_text.gd` (where client text already lives).

## Acceptance checks

- [ ] One client text table holds every tooltip, keyed by the GDD field name (`swole`, `chill`,
      `broken_arms`, ...) or the intent kind. No tooltip text is scattered through scene code.
- [ ] Every status and intent kind that the core can put in state has an entry; a test walks the
      status and intent names from `core/schema/` and fails on any without one.
- [ ] Gear and Brew tooltips use the item's own `text` from its data file, not a copy.
- [ ] Numbers in a tooltip (for example the size of Exposed's multiplier) are read from
      `data/constants.json` through the ruleset, not typed into the text.
- [ ] At Baileys, Brews are called Shake in tooltips too (CLAUDE.md "Writing and content rules").
- [ ] `tools/test.sh` passes.

## Notes

- Keep each tooltip to one or two short lines. If the GDD does not say what a status does in a
  case, write only what it does say; do not invent rules.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (fight-screen polish backlog). Unclaimed.
