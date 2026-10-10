---
id: 001
title: Bootstrap - engine decision, project file, shared contracts, task board
lane: core
owner: A
status: blocked
branch: claude/practical-ride-8ake0f
depends_on: []
blocked_on: []
files:
  - CLAUDE.md
  - project.godot
  - .gitignore
  - .gitattributes
  - core/schema/
  - data/constants.json
  - tests/core/
  - docs/tasks/
  - docs/proposals/solo-slice-rule-gaps.md
  - docs/changes/2026-10-10-001.md
---

## Goal

Get the repository to the point where both agents can work in parallel: the engine decision is
recorded, Godot opens the project, the shared contracts every lane reads exist, and the milestone 2
work is split into claimable tasks.

## Read first

CLAUDE.md; GDD "Technical design" and "Scope, milestones and open questions".

## Acceptance checks

- [x] Engine and language confirmed by Person A: Godot 4 + GDScript; data format JSON. Boss for the slice: Goblin King Chad.
- [ ] Person B confirms the same (CLAUDE.md asks for both people). Approving this PR counts.
- [x] `project.godot` imports headless with Godot 4.7.2-stable (`godot --headless --path . --import`).
- [x] `data/constants.json` holds every GDD tuning constant with value, unit and meaning.
- [x] `core/schema/` defines run, Dude, combat and enemy state; requests; events; card, enemy and Dude definitions.
- [x] Tests in `tests/core/` cover the schema (including a snapshot round trip with a seed above 2^53), constants, core purity and the documentation standard.
- [x] Those tests run in CI (task 002, merged in #6).
- [x] Tasks 002–027 written; open rule questions collected in `docs/proposals/solo-slice-rule-gaps.md`.
- [x] `docs/changes/2026-10-10-001.md` lists every field, constant and message added.

## Notes

- **The bootstrap was not split into one PR per contract**, as CLAUDE.md asks, because this
  session may push only to its assigned branch. Commits are split by concern so it can be
  reviewed in pieces. If Person B prefers separate PRs, Person A can allow Agent A to push extra
  branches and the commits will be split out.
- No claim PR was made for this task: it creates the task board, so there was nowhere to claim it.
- Godot 4.4+ writes a `.uid` file beside every script. They are committed on purpose; Godot uses
  them to keep references stable when files move.

## Log

- 2026-10-10 A: Person A confirmed Godot 4 + GDScript, JSON data, Goblin King Chad as the slice boss.
  Pinned Godot **4.7.2-stable** (released 2026-08-18, the newest stable at the time).
- 2026-10-10 A: Merged the other branch (two-agent CLAUDE.md, GDD 0.5, Dolla Bills rename) before
  writing contracts; `beer_money` is `dolla_bills` throughout.
- 2026-10-10 A: I first wrote a test runner and Godot install script, then learned I am Agent A and
  those files are in Agent B's lane. Person A chose to hand them to Agent B: they are **not** in this
  branch; task 002 specifies them. Agent A verified this branch by overlaying that local draft
  harness, uncommitted: 26 tests passed, 0 failed (22 in `tests/core/` plus 4 harness self-tests).
  **Until task 002 merges, nothing in `tests/core/` can run from a clean checkout.**
- 2026-10-10 A: Merged to main in #4 and #5 (#5 merged by Agent A on Person A's authorization to
  merge Agent A's own PRs). Two checks stay open, so the status is `blocked`, not `done`: Person B
  has not yet confirmed the tech stack, and the tests cannot run in CI until task 002 lands.
  Set to `done` once both are true.
- 2026-10-10 A: Task 002 merged (#6). Reviewed by running `tools/test.sh` on its head with main
  merged in: 27 passed, 0 failed, with `tests/core/` unmodified. CI check ticked. Only Person B's
  confirmation of the tech stack remains.
