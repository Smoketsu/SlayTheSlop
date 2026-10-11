---
id: 051
title: Playtest builds - export presets and a build script for Windows, macOS and Linux
lane: tools
owner: B
status: open
branch:
depends_on: []
blocked_on: []
files:
  - export_presets.cfg              # new build config at the root: a shared contract, own PR
  - tools/build.sh
  - tools/README.md
  - .gitignore                      # shared contract: only if the build output folder needs adding
  - tests/tools/
---

## Goal

Outside playtesters (the milestone 2 gate) need a game they can download and run without Godot.
Add Godot export presets for Windows, macOS and Linux and a `tools/build.sh` that uses the pinned
Godot from `tools/install_godot.sh` to export all three into a git-ignored `build/` folder.

## Read first

CLAUDE.md "Shared contracts" and "Tech stack"; `tools/install_godot.sh`, `tools/test.sh`;
Godot 4.7 documentation on command-line export (`--export-release`) and export templates.

## Acceptance checks

- [ ] `export_presets.cfg` and any `.gitignore` line go in their own contract PR first, with
      nothing else, approved by Smoketsu (CLAUDE.md "Shared contracts": build config). The presets
      exclude `tests/`, `tools/` and `docs/` from the exported game.
- [ ] `tools/build.sh` installs the export templates matching the pinned Godot version, verified by
      checksum the way `tools/install_godot.sh` verifies Godot, and exports each preset; it exits
      non-zero if any export fails.
- [ ] The Linux build starts headless and quits cleanly in a smoke test (for example a
      `--quit-after` run), run by `tools/build.sh --check` or a test in `tests/tools/`.
- [ ] `tools/README.md` documents the command, where the builds land, and that macOS builds are
      unsigned (playtesters must allow them in Security settings).
- [ ] `tools/test.sh` still passes and CI time does not grow by more than a minute (do not export
      in CI unless both people agree).

## Notes

- The run save lives in `user://`; say in `tools/README.md` where that is on each OS so testers can
  send a save if something breaks.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (playtest readiness). Unclaimed.
