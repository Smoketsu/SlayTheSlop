# Task board

One file per task: `docs/tasks/<id>-<slug>.md`. The folder is the board; there is no index file to
keep in sync, so the two agents never edit the same line here. This README is a shared contract
(change it in its own PR, approved by the other person).

Find work with, for example:

```
grep -l "^status: open" docs/tasks/*.md          # unclaimed tasks
grep -l "^owner: A" docs/tasks/*.md               # Agent A's tasks
```

## Ids, owners, lanes

- Ids are three-digit numbers. **Agent A creates odd ids, Agent B creates even ids**, so neither
  agent can take an id the other is about to use. Never reuse an id.
- `owner` is the agent whose lanes include the task's `lane` (CLAUDE.md "Who is who"):
  A owns `core` and `run`; B owns `content`, `tools` and `client`. An agent may write a task for the
  other agent's lane (with its own parity of id), but only that lane's agent claims it.
- One exception: the bootstrap backlog (tasks 001–027) was written by Agent A in one sitting before
  Agent B started, so there its ids follow the **owner** (even = B). From 028 on, the creator's
  parity applies.

## File format

```markdown
---
id: 007
title: Combat skeleton
lane: core                      # core | run | content | tools | client
owner: A                        # A or B, from the lane
status: open                    # open | in_progress | blocked | in_review | done
branch:                         # set when claimed, e.g. a/007-combat-skeleton or the session's branch
depends_on: [003, 005]          # task ids that must be merged first
blocked_on: [G1, G2]            # open questions (docs/proposals/...) that must be answered first
files:                          # paths this task may create or edit; nothing else
  - core/combat/
  - tests/core/combat/
---

## Goal
What the task delivers, in two or three sentences.

## Read first
GDD sections and repository files.

## Acceptance checks
- [ ] Concrete checks, each one a command or a test name the next agent can run.

## Notes
Things the next agent would otherwise rediscover.

## Log
- 2026-10-10 A: what happened, newest last. Done / not done / how verified.
```

## Status values

| Status | Meaning | Set by |
| --- | --- | --- |
| `open` | Nobody is on it. Dependencies may still be pending. | Author |
| `in_progress` | Claimed. `branch` is filled in. | Owner, in a claim PR containing only that change |
| `blocked` | Nothing useful can start: waiting on a question or on the other agent. Say what, in the log. A task with unanswered `blocked_on` items stays `open` if some of it can proceed. | Owner |
| `in_review` | PR open for the other person. | Owner |
| `done` | Merged, acceptance checks ran and passed. | Owner, in the task's own PR |

## Rules (from CLAUDE.md, repeated so they are next to the board)

1. Claim before you touch code: a PR that only sets `status: in_progress` and `branch`, merged first.
2. Do not start a task until everything in `depends_on` is merged and `blocked_on` is answered.
   If you must, stub only against merged schema and say so in the log.
3. Edit only the paths in `files`, plus your own task file and your own `docs/changes/<date>-<id>.md`,
   which every task may add without listing them. Need something else? Write a task for it.
4. Finishing: tick the checks, write the log entry (what is done, what is not, the command you ran
   and its result), add `docs/changes/<date>-<id>.md`, and set `status: in_review`.
