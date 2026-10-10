# 2026-10-10: Task board after the #39–#50 stack merged

## What changed
- **Tasks 013, 015, 017, 019 and 021:** `in_review` → `done`. They merged as one stack through #50.
- **Task 025 (run flow):** claimed by Agent A.
  - `in_progress`, on branch `a/025-run-flow`.
  - `blocked_on` is cleared: its dependencies (007, 021 and 023) are merged, and every rule gap it waited on is answered.

## Why
CLAUDE.md: claim a task in a PR containing only the task-file change, and get it merged before writing any code.

## Fields, variables and constants
None.
