---
id: 039
title: Op "damage_from_missing_hp" (Nothing to Lose)
lane: core
owner: A
status: done
branch: a/039-damage-from-missing-hp
depends_on: [009, 013]
blocked_on: []
files:
  - core/ops/damage_from_missing_hp.gd
  - core/ops/ops.gd              # registers the op
  - core/ops/README.md
  - tests/core/
---

## Goal

`tom_nothing_to_lose` (Nothing to Lose, accepted in `docs/proposals/tom-slice-cards.md`) deals
attack damage equal to Tom's missing HP, capped. Add the op `damage_from_missing_hp` with field
`cap` (int, 0 or more): attack damage of `min(max_hp − hp, cap)` for the actor, then the normal
damage order (Swole, Exposed, Noodle Arms, Broken Arm, Guard). The cap (30 on the card) is data on
the card, not a constant. Requested in task 012's proposal, "Ops this needs from Agent A", item 3.

## Read first

- `core/ops/damage.gd` (the damage order and its events) and GDD "Damage order".
- `core/ops/README.md` (op catalogue format) and `core/ops/ops.gd` (op registry, `NEEDS_TARGET`).

## Acceptance checks

- [x] `Ops.check` accepts `{"op": "damage_from_missing_hp", "cap": <int ≥ 0>}` and refuses a missing,
      negative or non-int `cap` and unknown fields.
- [x] Base damage is the actor's `max_hp − hp` at the moment the effect runs, capped at `cap`; it then
      goes through the same damage order as `damage` (it is attack damage: G3), so Swole and the
      multipliers apply and Guard absorbs it.
- [x] At full HP the base is 0; the hit still goes through the order (Swole can make it more than 0),
      matching how `damage` treats a base of 0.
- [x] Nothing to Lose's data shape: Tom at 40/70 deals 30 (cap), at 60/70 deals 10 (before modifiers).
- [x] `core/ops/README.md` documents the op. `tools/test.sh` passes.

## Notes

- If `damage` with a base of 0 behaves differently from the check above, follow `damage` and note it here.

## Log

- 2026-10-11 A: Created and claimed. Smoketsu (Person A) accepted all 16 new Tom cards on
  2026-10-11; steamjgrube (Person B) accepts by approving the board PR that adds this file.
- 2026-10-11 A: Built, in review on `a/039-damage-from-missing-hp`.
  - `core/ops/damage_from_missing_hp.gd`: base = actor's `max_hp - hp` when the effect runs, clamped
    to 0..`cap`, then one `damage` hit through `core/ops/damage.gd` (attack damage on Attack cards,
    G3). A gone actor deals nothing. Registered in `ops.gd`; documented in `core/ops/README.md`.
  - Base 0 at full HP behaves as `damage` with amount 0 does: Swole still adds (checked).
  - Tests: `tests/core/ops/test_damage_from_missing_hp.gd` (6): field check; base capped at
    80/70/50/20 HP; base read after an earlier self-damage on the same card; same damage as a plain
    10-damage Attack under Swole and Exposed; a Skill gets no Swole; full HP plus Swole.
  - Verified: with the base replaced by `cap`, 5 of the 6 tests fail (the field check passes, as it
    should). `tools/test.sh`: 474 passed, 0 failed.
  - Not done: the card data (`tom_nothing_to_lose`) is Agent B's.
- 2026-10-11 A: Done. Merged in #93. Nothing to Lose's data merged in #98.
