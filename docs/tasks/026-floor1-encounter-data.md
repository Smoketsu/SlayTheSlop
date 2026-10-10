---
id: 026
title: Floor 1 encounters as data
lane: content
owner: B
status: in_review
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

- [x] One file per encounter in task 025's fixtures, id equal to file name, each passing
      `encounter_def.gd`'s `check()`: early Brawls `basement_goblin_pledges`, `basement_goblin_bouncer`,
      `basement_skeleton_intern`, `basement_pledge_and_intern`; Brawls `basement_keg_slime`,
      `basement_dorm_rats`, `basement_boo_zer`, `basement_kobold_ra`; Rivals
      `basement_goblin_shot_caller`, `basement_hall_monitor_golem`, `basement_sewer_gator`; Boss
      `basement_goblin_king_chad`; Loot `basement_mimic_cooler`.
- [x] `"early": true` only on Brawls made of early enemies (G61), matching the fixtures.
- [x] Every enemy id resolves in the real ruleset; escorts named in `arrives_with` are not listed.
- [x] A test in `tests/data/` checks the files against task 025's fixtures and plays a fixed-seed run
      start on the real data far enough to enter the first Brawl.
- [ ] `tools/test.sh` passes. (418 passed, 1 failed on this base: the client event-text test, fixed by
      `b/run-event-text`; every test this task adds or touches passes. See Log.)

## Notes

- The fixtures are Agent A's; copy them, do not edit `tests/run/`.

## Log

- 2026-10-10 B: Written and claimed. Next free even id (026). Task 025's review listed what the run
  lane wants (Agent B's review of #66).
- 2026-10-10 B: Done, in review on `b/026-floor1-encounters` (based on `a/025-run-flow`, which is not
  merged yet). 13 files in `data/encounters/`, each equal to task 025's `ENCOUNTERS` fixture plus a
  `text` note; `tests/data/test_encounter_data.gd` checks schema, ids, the fixtures, `early` (G61:
  Pledge + Intern is early, as the fixtures build it), enemy ids and escorts, and plays a fixed-seed
  run start (seed 20261010) on the real data into row 1's first Brawl: the vote is accepted, the
  fight starts, encounter `basement_pledge_and_intern` (recorded). `tools/data_files.gd` and
  `test_data_files.gd` needed no change (the reader reads every folder; the ruleset knows
  `data/encounters/`). Verified: `tools/test.sh` -> 418 passed, 1 failed; the failure is
  `tests/client/test_fight_screen.gd::test_every_reject_and_event_has_text` (14 run event types from
  task 025 with no client text), expected on this base and fixed on the stacked branch
  `b/run-event-text`. Not done: G61 still has no recorded answer; if a person answers "no", drop
  `"early"` from `basement_pledge_and_intern` together with Agent A's fixture.
