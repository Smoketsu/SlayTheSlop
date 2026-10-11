# tools/

Scripts for working on Dungeon Dudes. Lane: tools (Agent B). Run every command from the
repository root, on Linux or macOS (on Windows, use WSL).

| Command | What it does |
| --- | --- |
| `tools/install_godot.sh` | Installs the pinned Godot (4.7.2-stable) into `.tools/` if missing, checksum verified, and prints the binary's path |
| `tools/test.sh [words...]` | Imports the project and runs every test headless (see CLAUDE.md "Commands") |
| `tools/build.sh [--check] [PRESET...]` | Exports the playtest builds into `build/` (below) |

`tools/data_files.gd` is not a command: it reads every file under `data/` for the ruleset builder,
and the game itself loads it at runtime, so it ships inside every build (see `export_presets.cfg`).

## Playtest builds: `tools/build.sh`

```
tools/build.sh                          # export Windows, macOS and Linux into build/
tools/build.sh --check                  # the same, then smoke-test the Linux build
tools/build.sh --check Linux "Windows Desktop"   # only these presets
tools/build.sh --help
```

What it does, in order:

1. Installs the pinned Godot with `tools/install_godot.sh` if needed.
2. Installs the matching export templates (`Godot_v4.7.2-stable_export_templates.tpz` from the
   official GitHub release) if they are missing. The download is about 1 GB, once per machine; the
   script refuses it unless its SHA-512 equals the one pinned in the script (copied from the
   release's `SHA512-SUMS.txt`), the same way `install_godot.sh` checks Godot. Godot only looks
   for templates in its own data folder, so that is where they go (about 2 GB unpacked):
   - Linux: `~/.local/share/godot/export_templates/4.7.2.stable/` (or under `$XDG_DATA_HOME`)
   - macOS: `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`
3. Exports every preset in `export_presets.cfg` (or only the ones named) in release mode. Each
   preset's folder is emptied first, so no file from an older build is left behind.
4. With `--check`, runs the Linux build headless for 300 frames with a throwaway user data folder.
   It fails if the game exits with an error code or prints any engine or script error (for
   example a script or data file missing from the export). Needs a Linux x86_64 machine.

The exit code is 0 only if every export (and the check) succeeded. Exporting is **not** part of
`tools/test.sh` or CI (task 051). `tests/tools/test_export_presets.gd` runs in CI instead: it checks
the presets without exporting (three presets writing into `build/`, test and tool files excluded,
nothing the game loads excluded).

### Where the builds land

`build/` is git-ignored. Send testers the whole folder for their platform, zipped.

| Platform | Output | Approximate size |
| --- | --- | --- |
| Windows (x86_64) | `build/windows/DungeonDudes.exe` + `DungeonDudes.pck` (keep them together) | 110 MB |
| macOS (universal: Intel and Apple Silicon) | `build/macos/DungeonDudes.zip`, holding `Dungeon Dudes.app` | 65 MB |
| Linux (x86_64) | `build/linux/DungeonDudes.x86_64` + `DungeonDudes.pck` (keep them together) | 76 MB |

**macOS export is blocked for now.** Godot refuses a universal macOS build unless `project.godot`
sets `rendering/textures/vram_compression/import_etc2_astc=true`, and the official templates hold
no Intel-only build to fall back on. That one-line `project.godot` change is a shared-contract PR
of its own (task 051 log). Until it merges, `tools/build.sh` exits 1 after exporting the other two;
use `tools/build.sh --check Linux "Windows Desktop"` to build just those.

### What testers need to know

- **macOS: the app is unsigned.** It has only an ad-hoc signature, not an Apple Developer ID, and
  it is not notarized, so macOS blocks it the first time. Unzip it, move `Dungeon Dudes.app` to
  Applications, open it once (macOS refuses), then go to **System Settings > Privacy & Security**,
  scroll to the message about "Dungeon Dudes" and click **Open Anyway**, and confirm.
- **Windows: the .exe is unsigned.** SmartScreen may say "Windows protected your PC": click
  **More info**, then **Run anyway**. Keep `DungeonDudes.pck` next to the `.exe`.
- **Linux:** keep `DungeonDudes.pck` next to the binary; if the binary lost its executable bit in
  transfer, run `chmod +x DungeonDudes.x86_64`.

### Where the save and logs live (`user://`)

The game keeps its run save (`run.save`) and its log files (`logs/godot.log`, plus older ones) in
Godot's user data folder for the project name "Dungeon Dudes". Settings will go in the same folder
when the game has any (it saves none yet). If something breaks, ask the tester for `run.save` and
`logs/` from:

| OS | Folder |
| --- | --- |
| Windows | `%APPDATA%\Godot\app_userdata\Dungeon Dudes\` (type it into Explorer's address bar) |
| macOS | `~/Library/Application Support/Godot/app_userdata/Dungeon Dudes/` (Finder: Go > Go to Folder) |
| Linux | `~/.local/share/godot/app_userdata/Dungeon Dudes/` (or `$XDG_DATA_HOME/godot/...` if set) |

Deleting `run.save` starts the game fresh. Running the project from the Godot editor uses the same
folder, so on a developer's machine an exported build and the editor share one save.
`tools/build.sh --check` does not touch it (it runs with a throwaway folder).
