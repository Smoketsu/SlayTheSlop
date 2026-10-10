---
id: 015
title: Junk card rules - Hangover, Regret, Bedbugs, Paperwork, Detention, Burn
lane: core
owner: A
status: in_review
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

- [x] Triggers when drawn (Hangover: lose 1 Hype; Bedbugs: take 1 damage) and at end of turn in hand (Burn: take 2).
- [x] Detention: while it is in hand, at most 4 cards may be played this turn (`unplayable` beyond).
- [x] Fight-only Junk (Paperwork, Detention, Burn) is removed from the Dude's `cards` and `deck` when the fight ends; run Junk stays.
- [x] An op to add a Junk card to a pile, used by enemies and Side Quests (`card_created` event). Side Quests outside a fight: see the Log.
- [x] One test per Junk card.

## Log
- 2026-10-10 A: Claimed. Every rule gap it waited on is answered (#20); task 009 is merged.

- 2026-10-10 A: claimed and built on `a/015-junk-cards`, **in parallel with task 013** rather than
  after it. The lead fixed the split: 013 owns Tom's ops (`draw`, `gain_hype`, `self_damage` ...),
  Powers and the Bro Meter. 015 uses nothing 013 adds.
  - **Commit 1 (contract only):** `core/schema/` + `tests/core/schema/` +
    `docs/changes/2026-10-10-015-schema.md`.
    - `card_def.gd`: rarity `special` (G17) and optional fields `on_draw`,
      `on_end_of_turn_in_hand`, `play_limit_in_hand`, `lasts` (`run` default | `fight`) and
      `removable`.
    - `event.gd`: new event `card_removed`.
    - The state shape is unchanged, so `SCHEMA_VERSION` stays 3.
  - **Commit 2:**
    - New ops `add_card`, `lose_hype` and `self_damage`. `self_damage` duplicates 013's name at
      the lead's request; the lead dedupes.
    - `core/combat/card_triggers.gd`, with small "Task 015" hooks in `fight.gd`, `play.gd` and
      `core.gd`.
    - The ruleset build checks `add_card` ids.
    - Docs in `core/ops/README.md`, plus tests.
  - Change files: `docs/changes/2026-10-10-015-schema.md`, `docs/changes/2026-10-10-015.md`.
  - Verified: `tools/test.sh` from the worktree root printed `225 passed, 0 failed`.
    - 13 tests in `tests/core/combat/test_junk_cards.gd`.
    - 11 tests in `tests/core/ops/test_junk_ops.gd`.
    - 1 test in `tests/core/schema/test_schema.gd`.
    - No recorded hash changed.
  - **Not done:**
    - The real Junk data files are task 008. `tests/core/combat/junk_fixtures.gd` holds this
      task's reading of the six cards, with the ids `junk_hangover` etc., and
      `core/ops/README.md` lists them as data.
    - Side Quests that add Junk **outside a fight** (Beer Pong, 3 a.m. Tattoo, Free Couch) are run
      lane (task 025). `add_card` only targets piles. Task 025 can call
      `AddCard.create_in_place()` or add the copy to `cards` and `deck` itself.
    - Hair of the Dog (Tap Junk in hand) and Beer Helmet are task 021.
  - **For other tasks:**
    - **013:** the `draw` op should call `CardTriggers.draw_in_place(context, state, i, n, events)`
      so `on_draw` runs. The op context now has `cards`.
    - **Everyone:** `Fight.finish_if_decided_in_place` now takes `ruleset` first.
    - **013:** decide whether `use_bro_move` counts against Detention's limit. Today the limit
      checks only `play_card`.
  - **Decisions for the people (defaults built, please confirm):**
    1. A card without `lasts` lasts the run. So a non-Junk card that `add_card` creates in a fight
       joins the run deck for good. Slay the Spire makes such copies fight-only.
    2. Beer Helmet ("Start each fight with a Hangover in your draw pile") with Hangover lasting the
       run would pile up a Hangover every fight. Task 021 probably wants an `add_card` override that
       makes that copy fight-only. Not built.
    3. Hangover drawn at Refresh costs Hype that turn, because Hype is refilled before the draw. At
       0 Hype it does nothing.
    4. Detention counts every card played this turn, including those played before it reached the
       hand. Several Detentions do not stack: the smallest limit applies.
    5. Bedbugs at Refresh or Burn at End of turn can Pass Out the last Dude. The fight is then lost
       at once: no player phase, or no enemy phase. A Passed Out Dude's triggers do not run.
    6. Burn and Bedbugs damage goes through Guard (G3, as the gap answer says). Exposed does not
       raise it.
    7. Fight-only cards are removed when a fight ends either way, won or lost, after `fight_ended`,
       with `card_removed` (`from` = the pile the card was in).
    8. `add_card` without `shuffle_in` puts the card on top of the draw pile. With `shuffle_in`,
       every position from top to bottom is equally likely.
    9. A card or Brew's `add_card` lands on the player, whatever the card targets. In an enemy move
       it lands on the intent's target Dudes.
  - GDD notes: the "Card types and keywords" Junk row leaves out Detention. This task's Read-first
    line names Kobold RA, but Kobold RA adds no Junk (Noise Complaint is task 017).
- 2026-10-10 A (lead): Rebased onto task 013 for the PR. Kept one `self_damage` (013's file, merged
  with this task's: `source_id ""` as `event.gd` defines, `amount` 0 does nothing, no damage once
  the fight is decided); Skull Bash's two test assertions and `test_actor_kinds` now expect `source_id ""`. 013's `draw` op
  now draws through `CardTriggers.draw_in_place`, so `on_draw` also runs on mid-turn draws.
  `Ops.make_context` carries both `ruleset` (013) and `cards` (015) and unwraps an op context passed
  as a ruleset. `use_bro_move` passes `ruleset` to `finish_if_decided_in_place`.
