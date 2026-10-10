---
id: 013
title: Effect ops for Tom's cards, Powers, the solo Bro Meter and Chest Bump
lane: core
owner: A
status: in_progress
branch: a/013-tom-card-ops-and-bro-meter
depends_on: [009]
blocked_on: []
files:
  - core/combat/
  - core/ops/
  - tests/core/ops/
---

## Goal

Every effect operation Tom's 14 GDD cards and his Bro Move need, so task 006's data plays exactly as
the GDD text reads.

## Read first

GDD "Tom, the Enforcer" (card table), "Bro Meter", "Card types and keywords"; `core/ops/README.md`
(from task 007); task 006's requested-ops list, if it exists.

## Acceptance checks

- [ ] Ops (names to settle with task 006): `draw`, `gain_hype`, `self_damage`; conditions such as "if the target has a Broken Arm" (Wrist Lock) and "if the target is now Armless" (Snap City); "per Broken Arm on all enemies" (Cast Party); `all_enemies` targeting (Pickup Line); thorns for this turn (Chrome Dome).
- [ ] Powers: a played Power stays for the fight; triggers for Reply Guy (enemy gains a buff, G10) and Friend Zone (start of turn; Grossed Out → Exposed 2). Fight-scoped Power state needs a contract PR adding fields to `dude_state.gd` (or combat).
- [ ] Keywords `tapped` and `pocketed`.
- [ ] Bro Meter, solo: +1 for every third card played in a turn (3rd, 6th ...), capped at `BRO_METER_MAX`. `use_bro_move` at max empties it and plays the Dude's `bro_move` card for free (`not_ready` otherwise).
- [ ] One test per Tom card, using its real data file once task 006 has merged, and the GDD number in the assertion.
- [ ] `core/ops/README.md` lists every op added.

## Log
- 2026-10-10 A: Claimed. Every rule gap it waited on is answered (#20); task 009 is merged.
