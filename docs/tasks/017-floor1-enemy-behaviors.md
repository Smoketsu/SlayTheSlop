---
id: 017
title: Floor 1 enemy behaviors that are not plain moves
lane: core
owner: A
status: in_progress
branch: a/017-floor1-enemy-behaviors
depends_on: [011, 015]
blocked_on: []
files:
  - core/combat/
  - core/ops/
  - core/schema/enemy_def.gd   # additive fields only, in a separate contract PR first
  - tests/core/enemies/
---

## Goal

Every floor 1 enemy in the GDD table can be expressed as data and plays as described.

## Read first

GDD "Floor 1: The Basement"; task 010's list of requested ops and fields.

## Acceptance checks

- [ ] Goblin Pledge: the last goblin standing calls one more Pledge (`enemy_spawned`).
- [ ] Goblin Bouncer: alternating pattern; "Checks ID" applies 1 Noodle Arms.
- [ ] Keg Slime: at half HP, splits into two Foam Slimes with 10 HP each.
- [ ] Dorm Rats: each bite steals 5 Dolla Bills; they flee on turn 4 with what they stole; killing one returns its haul.
- [ ] Skeleton Intern: every other turn, shuffles Paperwork into the target's deck.
- [ ] Boo-zer: Faded every other turn, taking at most 1 damage per hit.
- [ ] Kobold RA: Noise Complaint, 5 damage to a player who plays 5 or more cards in a turn.
- [ ] Rivals: Goblin Shot-Caller, Hall Monitor Golem (Detention), Sewer Gator (Death Roll; Swole on unblocked damage).
- [ ] Mimic Cooler's Brew drop is reported for the run lane (an event or result field), not granted here.
- [ ] One test per enemy, using task 010's data.

## Log
- 2026-10-10 A: Claimed. All rule gaps answered (#20). Started in parallel with its in-progress dependencies at Person A's instruction; shared op names are pinned (`draw`, `gain_hype`, `self_damage` from 013; `add_card`, `lose_hype` from 015).
