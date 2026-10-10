---
id: 026
title: Floor 1 encounters as data
lane: content
owner: B
status: in_progress
branch: b/026-floor1-encounters
depends_on: [010, 025]
blocked_on: []
files:
  - data/encounters/
  - tests/data/
  - docs/tasks/          # only to write tasks asking Agent A for fields that do not exist
---

## Goal

The Basement's encounter groups as files in `data/encounters/`, in the format task 025 defines
(`core/schema/encounter_def.gd`), so a run with the real data can leave the entrance. Without these
files the first `vote_node` on a fight node is refused (`test_nodes_without_content_are_refused`).

## Read first

GDD "Floor 1: The Basement", "Node types", "Map"; `core/schema/encounter_def.gd` and the
`ENCOUNTERS` constant in `tests/run/fixtures/run_fixtures.gd` (task 025); gap G61 in
`docs/proposals/solo-slice-rule-gaps.md`; task 010's enemy ids in `data/enemies/`.

## Acceptance checks

- [ ] One file per encounter in task 025's fixtures, id equal to file name, each passing
      `encounter_def.gd`'s `check()`: early Brawls `basement_goblin_pledges`, `basement_goblin_bouncer`,
      `basement_skeleton_intern`, `basement_pledge_and_intern`; Brawls `basement_keg_slime`,
      `basement_dorm_rats`, `basement_boo_zer`, `basement_kobold_ra`; Rivals
      `basement_goblin_shot_caller`, `basement_hall_monitor_golem`, `basement_sewer_gator`; Boss
      `basement_goblin_king_chad`; Loot `basement_mimic_cooler`.
- [ ] `"early": true` only on Brawls made of early enemies (G61), matching the fixtures.
- [ ] Every enemy id resolves in the real ruleset; escorts named in `arrives_with` are not listed.
- [ ] A test in `tests/data/` checks the files against task 025's fixtures and plays a fixed-seed run
      start on the real data far enough to enter the first Brawl.
- [ ] `tools/test.sh` passes.

## Notes

- The fixtures are Agent A's; copy them, do not edit `tests/run/`.

## Log

- 2026-10-10 B: Written and claimed. Next free even id (026). Task 025's review listed what the run
  lane wants (Agent B's review of #66).
