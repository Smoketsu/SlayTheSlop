---
id: 045
title: Tooltips for statuses, intents, keywords, Gear and Brews
lane: client
owner: B
status: in_review
branch: b/045-tooltips
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

- [x] One client text table holds every tooltip, keyed by the GDD field name (`swole`, `chill`,
      `broken_arms`, ...) or the intent kind. No tooltip text is scattered through scene code.
- [x] Every status and intent kind that the core can put in state has an entry; a test walks the
      status and intent names from `core/schema/` and fails on any without one.
- [x] Gear and Brew tooltips use the item's own `text` from its data file, not a copy.
- [x] Numbers in a tooltip (for example the size of Exposed's multiplier) are read from
      `data/constants.json` through the ruleset, not typed into the text.
- [x] At Baileys, Brews are called Shake in tooltips too (CLAUDE.md "Writing and content rules").
- [x] `tools/test.sh` passes.

## Notes

- Keep each tooltip to one or two short lines. If the GDD does not say what a status does in a
  case, write only what it does say; do not invent rules.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (fight-screen polish backlog). Unclaimed.
- 2026-10-11 B: Claimed. Work starts once 041 (#112) and 049 (#111) merge, since it builds on the card faces and the client settings store.
- 2026-10-11 B: Done, in review. Branch `b/045-tooltips`, stacked on `b/057-fight-layout` (#120) with
  `b/055-placeholder-sound` (#119) merged in, so it merges after them. One table,
  `client/help/tooltip_text.gd` `TOOLTIPS`, keyed by icons.gd key / card keyword; numbers are
  `{CONSTANT}` placeholders filled from the ruleset's constants; Gear and Brew tooltips are the data
  file's `name` + `text`; at Baileys Brews are Shake lines (`RunText.shake_text()`). Hooked into
  every 057 badge, intent icon, marker, pile icon, the HP bar and the Bro Meter (name and value on
  line 1, what it does on line 2, wrapped by `client/visual/tooltip_view.gd`), card faces (keyword
  lines), Brew buttons (now named by the Brew's name), offer options, and new Gear / Brew tags in
  the run header. `client/ASSETS.md` stale icon line fixed. Verified: `tools/test.sh` -> 569
  passed, 0 failed (`tests/client/test_tooltips.gd`: 8 tests, including the walk over every status
  id in `core/schema/README.md` "Status ids" + `PERIODIC_STATUSES` and every intent kind in
  `enemy_def.gd` + data/enemies/); a 1280x720 xvfb screenshot shows an intent tooltip over the
  Goblin Pledge. Not done: nothing in scope. Amounts the GDD gives without a constant (Foggy's one
  card, one stack per turn) are said in words, as `how_to_play_text.gd` does.
