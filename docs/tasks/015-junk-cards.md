---
id: 015
title: Junk card rules - Hangover, Regret, Bedbugs, Paperwork, Detention, Burn
lane: core
owner: A
status: in_progress
branch: a/015-junk-cards
depends_on: [013]
blocked_on: []
files:
  - core/combat/
  - core/ops/
  - tests/core/ops/
---

## Goal

The six Junk cards behave as the GDD's "Junk cards" table says, including when-drawn triggers,
end-of-turn triggers, the Detention play limit, and run-long versus fight-only Junk.

## Read first

GDD "Junk cards", "Card types and keywords" (Junk); the Kobold RA, Skeleton Intern and Hall Monitor
Golem rows, which add Junk.

## Acceptance checks

- [ ] Triggers when drawn (Hangover: lose 1 Hype; Bedbugs: take 1 damage) and at end of turn in hand (Burn: take 2).
- [ ] Detention: while it is in hand, at most 4 cards may be played this turn (`unplayable` beyond).
- [ ] Fight-only Junk (Paperwork, Detention, Burn) is removed from the Dude's `cards` and `deck` when the fight ends; run Junk stays.
- [ ] An op to add a Junk card to a pile, used by enemies and Side Quests (`card_created` event).
- [ ] One test per Junk card.

## Log
- 2026-10-10 A: Claimed. Every rule gap it waited on is answered (#20); task 009 is merged.
