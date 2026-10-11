---
id: 051
title: Playtest builds - export presets and a build script for Windows, macOS and Linux
lane: tools
owner: B
status: in_review
branch: b/051-playtest-builds
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
      (Branch `b/051-export-presets` holds only those two files; it still needs Smoketsu's
      approval. `tools/` is excluded except `tools/data_files.gd`, which the game loads: see Log.)
- [x] `tools/build.sh` installs the export templates matching the pinned Godot version, verified by
      checksum the way `tools/install_godot.sh` verifies Godot, and exports each preset; it exits
      non-zero if any export fails.
- [x] The Linux build starts headless and quits cleanly in a smoke test (for example a
      `--quit-after` run), run by `tools/build.sh --check` or a test in `tests/tools/`.
- [x] `tools/README.md` documents the command, where the builds land, and that macOS builds are
      unsigned (playtesters must allow them in Security settings).
- [x] `tools/test.sh` still passes and CI time does not grow by more than a minute (do not export
      in CI unless both people agree).

## Notes

- The run save lives in `user://`; say in `tools/README.md` where that is on each OS so testers can
  send a save if something breaks.

## Log

- 2026-10-11 A: Written for Agent B at Smoketsu's request (playtest readiness). Unclaimed.
- 2026-10-11 B: Claimed (steamjgrube: pick up work the board asks for).
- 2026-10-11 B: Done except the macOS export (blocked, below) and the contract PR's approval.
  Two branches: `b/051-export-presets` (from `main`: `export_presets.cfg` and `.gitignore` only, the
  contract PR) and `b/051-playtest-builds` (this one, which merges the contract branch, then adds
  `tools/build.sh`, `tools/README.md`, `tests/tools/test_export_presets.gd` and the change file).
  - **Presets:** "Windows Desktop" (`build/windows/DungeonDudes.exe` + `.pck`), "macOS"
    (`build/macos/DungeonDudes.zip`, universal, ad-hoc signed, not notarized) and "Linux"
    (`build/linux/DungeonDudes.x86_64` + `.pck`). Exclude filter in all three: `tests/*`, `docs/*`,
    `.github/*`, `tools/*.sh`, `tools/*/*`, `assets/placeholder/source/*`.
  - **`tools/` cannot be excluded whole.** `client/run/run_screen.gd` and `client/dev/dev_fight.gd`
    preload `res://tools/data_files.gd` to read `data/`. Tried in a scratch copy: with `tools/*`
    excluded the export succeeds but the game fails to start ("Preload file
    res://tools/data_files.gd does not exist"), and `tools/build.sh --check` fails on it. So only
    `tools/` scripts and subfolders are excluded, and `tests/tools/test_export_presets.gd` fails if
    any preset ever excludes a file the client or core refers to. A cleaner fix is to move
    `data_files.gd` out of `tools/` (client lane: a separate task), then exclude `tools/*`.
  - **`.gitignore`:** `build/` was already ignored. `export_presets.cfg` was ignored too (task 001),
    so the contract branch removes that line; Godot 4 keeps export passwords in
    `.godot/export_credentials.cfg`, which stays ignored.
  - **Templates:** `Godot_v4.7.2-stable_export_templates.tpz` from the official release, SHA-512
    `ca4d71c4…ccb84079` (full value in `tools/build.sh`, copied from the release's
    `SHA512-SUMS.txt`; the same file's Godot checksums match `install_godot.sh`). Installed into
    Godot's own templates folder (`~/.local/share/godot/export_templates/4.7.2.stable`): Godot cannot
    be pointed at `.tools/` without "self-contained mode", which would also move `user://` for
    `tools/test.sh`. Real download here: 993 MB, checksum matched, installed. A copy of the script
    with a wrong checksum refused the archive and left nothing installed.
  - **macOS export is blocked on `project.godot`.** Godot refuses a universal macOS export unless
    `rendering/textures/vram_compression/import_etc2_astc=true`, and the official templates hold
    only the universal macOS binary (an x86_64-only preset fails: "template binary
    godot_macos_release.x86_64 not found"). In a scratch copy with that one line added to
    `project.godot`, all three presets exported (macOS zip 64 MB, ad-hoc signed `Dungeon Dudes.app`)
    and `--check` passed. Our textures are all lossless (`compress/mode=0`), so the setting changes
    nothing else. Needs a small `project.godot` contract PR, approved by the other person; this task
    may not edit `project.godot`. Until then `tools/build.sh` exits 1 after the other two exports,
    and `tools/build.sh --check Linux "Windows Desktop"` builds just those.
  - **Verified:** `tools/build.sh --check` -> exit 1 (Windows and Linux exported, macOS refused as
    above). `tools/build.sh --check Linux "Windows Desktop"` -> exit 0: Windows 110 MB, Linux 76 MB
    (`.pck` 5.8 MB), "Smoke test passed: the Linux build started headless and quit cleanly." The
    Linux `.pck` holds `client/`, `core/`, `data/` (all JSON), the placeholder characters and
    backgrounds and `tools/data_files.gd`, and no `tests/`, `docs/` or other `tools/` file
    (`strings` on the `.pck`). `tools/test.sh` -> 516 passed, 0 failed, 33 s (32.8 s before the
    new test file; no export in CI). `shellcheck tools/build.sh` (0.11.0) -> clean.
  - **Not done:** the macOS build (blocked, above); nobody has run the Windows or macOS build on a
    real Windows or Mac yet. The smoke test runs only on Linux x86_64.
- 2026-10-11 B: macOS unblocked. Contract PRs: #114 (`export_presets.cfg` and `.gitignore`) and
  #115 (`project.godot` `import_etc2_astc=true`). Both need Smoketsu's approval and must merge
  before this branch, which merges both plus task 022 (for the shared `tools/README.md`). On that
  combined tree: `tools/build.sh --check` -> exit 0, all three presets exported (Windows 110 MB,
  macOS 64 MB, Linux 76 MB), "Smoke test passed". `tools/test.sh` -> 553 passed, 0 failed (after
  commenting two declarations in `tests/tools/test_export_presets.gd` that 022's documentation
  check flagged). The first acceptance check stays open until #114 is approved.
