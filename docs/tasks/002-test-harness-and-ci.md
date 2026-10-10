---
id: 002
title: Test harness, pinned Godot install, CI, and the Commands section
lane: tools
owner: B
status: in_review
branch: b/002-test-harness-and-ci
depends_on: [001]
blocked_on: []
files:
  - tests/run_tests.gd
  - tests/framework/
  - tools/
  - .github/workflows/
  - CLAUDE.md            # "Commands" section only, in its own contract PR
---

## Goal

One command runs every test headless, from a clean checkout, on any agent's machine and in CI,
with the pinned Godot. **This is the first thing that unblocks both agents**: Agent A's tests in
`tests/core/` already exist and are waiting for it.

## Read first

CLAUDE.md "Commands" and "Tech stack"; `core/schema/README.md`; the tests in `tests/core/`, which
are written against the API below and are this task's acceptance test.

## Required interface (Agent A's tests depend on exactly this)

**Runner** `res://tests/run_tests.gd`, a script that extends `SceneTree`:

```
godot --headless --path . --import                                   # once, builds .godot/
godot --headless --path . --script res://tests/run_tests.gd          # all tests
godot --headless --path . --script res://tests/run_tests.gd -- rng   # only paths containing "rng"
```

- Runs every `res://tests/**/test_*.gd`, including `tests/core/` and `tests/run/`.
- Makes a fresh instance for each `test_*` method.
- A script that fails to parse, and a runtime error raised inside a test, each count as a failure.
  Godot does not stop a call on a script error, so capture errors with `OS.add_logger()` and a
  `Logger` subclass (Godot 4.5+).
- Exits with 0 when every test passes, 1 when any fails or none ran.

**Base class** `res://tests/framework/test_case.gd`: test files say
`extends "res://tests/framework/test_case.gd"`. It extends `RefCounted` and provides:

| Member | Behavior |
| --- | --- |
| `failures: Array[String]` | Failure messages for the current test; the runner reads it |
| `fail(message: String)` | Records a failure |
| `assert_true(condition: bool, message := "...")` / `assert_false(...)` | |
| `assert_eq(actual, expected, message := "")` | **Strict and deep**: types must match at every level, so `3` and `3.0` differ. Needed because Godot's JSON returns floats |
| `assert_ne(actual, unexpected, message := "...")` | Opposite of `assert_eq`, same strictness |
| `assert_no_errors(errors: Array, message := "...")` | Fails, listing them, if the array is non-empty; used with `core/schema` `check()` |
| `static strict_diff(a, b, path: String) -> String` | `""` when equal, otherwise where they first differ, e.g. `$.x[1].y: 2 != 3` |

Assertions record and continue; they do not stop the test.

**Pinned Godot**: version `4.7.2-stable`, official GitHub release zips, checked against these
SHA-512 values (copied from that release's `SHA512-SUMS.txt`):

| File | SHA-512 |
| --- | --- |
| `Godot_v4.7.2-stable_linux.x86_64.zip` | `9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65` |
| `Godot_v4.7.2-stable_linux.arm64.zip` | `dd59918da086bd49bde2f5450b5e567ff8650cbde9abbd7b8f4ca1197ff8c609baa38834666d032deafb47099078d7822279e2a0e06e5665745468f26533e7e2` |
| `Godot_v4.7.2-stable_macos.universal.zip` | `38aa16e5bba2083941fc5b3e54be0089bd4cc35e32415f5b9fd9a8a6a7b9818255d44532ea8ef94b5aef56c4b407c2d634fa4f657e4ebe681ebbf59b7bac69ca` |
| `Godot_v4.7.2-stable_win64.exe.zip` | `83decd58fdf67b9d657958a1ae6bf1929c20785315a81effe245874cdc57acb709bf868e00778a96984338c1b29dafdb453c6847747694621c6ecf5da2259993` |

Install into `.tools/` (already in `.gitignore`). The version pin is a shared contract.

## Acceptance checks

- [x] From a fresh clone, one documented command installs Godot 4.7.2-stable and runs all tests.
- [x] Every test in `tests/core/` passes, unmodified (22 tests at the time of writing).
- [x] A test file with a parse error, a failing assertion, and a runtime error each give exit code 1.
- [ ] CI runs the suite on every pull request and on pushes to `main`, and fails the check on a failing test.
      (Workflow written; not yet seen running on GitHub. Tick when the first PR shows the check.)
- [ ] CLAUDE.md "Commands" lists the exact commands, in its own contract PR.
- [ ] Optional: a Claude Code SessionStart hook installs Godot in new cloud sessions, so agents can test without setup.

## Notes

- Godot 4.4+ writes a `.uid` file beside each script. Commit them.
- Without `--import`, `class_name` scripts do not resolve in a fresh checkout. Agent A's code uses `preload` paths only, but other code may use `class_name`.
- Agent A built and verified a working draft of all of the above before the lane split was known,
  and removed it from its branch at Person A's request. Person A can pass it to you on request; you
  are free to design your own as long as the interface above holds.

## Log

- 2026-10-10 B: Claimed and built together. A claim PR was not possible: this task file exists only
  on task 001's branch, which is not merged. Person B told Agent B to start. This branch is cut from
  task 001's branch (`claude/practical-ride-8ake0f`) because Agent A's tests are the acceptance
  test; rebase onto `main` once 001 merges, after which the PR shows only Agent B's files.
- 2026-10-10 B: Done:
  - `tools/install_godot.sh`: downloads the pinned 4.7.2-stable zip for Linux x86_64/arm64 or macOS,
    checks its SHA-512 (values from the table above, re-checked against the release's
    `SHA512-SUMS.txt`), unzips into `.tools/godot-4.7.2/`, prints the binary path. Idempotent.
    Windows prints manual steps instead (no PowerShell installer yet).
  - `tools/test.sh [filters...]`: install if needed, `--import`, run the suite. This is the one command.
  - `tests/framework/test_case.gd` and `tests/run_tests.gd`: the interface above, unchanged.
    Errors are caught with an `OS.add_logger()` `Logger`; warnings are ignored. A file that does not
    parse fails as one entry named after the file. A test file with no `test_*` methods fails.
  - `tests/harness/test_harness.gd`: 5 self-tests. The exit-code tests build a throwaway project in
    the user data folder with a copy of the harness and one fixture, run a child Godot, check its
    exit code, and delete the project.
  - `.github/workflows/tests.yml`: runs `tools/test.sh` on pull requests and pushes to `main`,
    caching `.tools/` keyed on the installer.
- 2026-10-10 B: Verified:
  - `tools/test.sh` from a fresh clone with no `.tools/` or `.godot/`: `27 passed, 0 failed`, exit 0
    (Agent A's 22 + 5 self-tests).
  - `tools/test.sh constants`: `3 passed, 0 failed`. `tools/test.sh zzz`: exit 1 (nothing ran).
  - Mutation check: making the runner ignore logged errors turns `test_exit_codes` red.
- 2026-10-10 B: Not done:
  - CI not yet observed on GitHub (no PR has run it).
  - CLAUDE.md "Commands": goes in its own contract PR (`b/002-commands`), after this one merges.
  - Optional SessionStart hook: skipped. It would live in `.claude/settings.json`, which no lane owns.
  - Windows installer script.
- 2026-10-10 B: For the next agent:
  - `strict_diff` does not compare whether an array is typed, only its elements. `[] as Array[String]`
    and `[]` are equal.
  - `test_schema.gd`'s `test_json_corrupts_big_ints` passes only because `assert_ne` is strict: under
    Godot's `==`, float 2^60 equals int 2^60+1.
