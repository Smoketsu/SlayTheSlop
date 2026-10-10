---
id: 009
title: Damage order, statuses, Broken Arm and Ick
lane: core
owner: A
status: in_progress
branch: a/009-damage-order-and-statuses
depends_on: [007]
blocked_on: []
files:
  - core/combat/
  - core/ops/
  - tests/core/combat/
---

## Goal

The GDD damage order exactly, the four general statuses, and both halves of Tom's kit, so every
number the player sees matches the GDD.

## Read first

GDD "Damage order", "Statuses", "Tom, the Enforcer"; `data/constants.json`.

## Acceptance checks

- [ ] Damage: (base + Swole) × Noodle (0.75) × Broken Arm factor (enemy attackers) × Exposed (1.5), rounded down **once**, at step 5, then Guard, then HP. Exact arithmetic: no float drift. For example, compute with integer numerators and denominators from the constants, or show by test that every product of the constants at slice values rounds correctly.
- [ ] Table-driven tests for the damage order, including every combination of the three multipliers, with k of n arms broken for n = 2.
- [ ] Exposed, Noodle Arms, Hungover, Foggy: apply, stack, wear off as answered in G1. Hungover Guard rounding as G4.
- [ ] `apply_status` with `broken_arm` raises `broken_arms` up to `arm_count`; Armless as G7, once per fight (`armless_used`).
- [ ] `apply_status` with `ick` adds to `ick` (Clout as G5); Grossed Out as G6, with threshold + `ICK_THRESHOLD_STEP`.
- [ ] Ick thresholds start from `ICK_BASE_*` by tier, scaled by the party HP multiplier and rounded up (solo: unchanged).
- [ ] Every tuning number comes from `ruleset.constants`. No value from `constants.json` (0.75, 1.5, 0.4, the Ick bases, the step) is written as a literal in `core/`; the PR description says how this was checked.

## Log
- 2026-10-10 A: Claimed. Every rule gap it waited on is answered "accept" (PR #20).
