# tools/

Scripts for working on Dungeon Dudes. Lane: tools (Agent B). None of them is part of the rules core,
and none of them changes game data. Run every command from the repository root, on Linux or macOS
(on Windows, use WSL).

| Path | What it is |
| --- | --- |
| `install_godot.sh` | Installs the pinned Godot (4.7.2-stable) into `.tools/` if missing, checksum verified, and prints the binary's path |
| `test.sh [words...]` | Imports the project and runs every test headless (see CLAUDE.md "Commands") |
| `build.sh [--check] [PRESET...]` | Exports the playtest builds into `build/` (task 051, below) |
| `data_files.gd` | Not a command: reads every file under `data/` for `core/ruleset/ruleset.gd` `build()`. The game itself loads it at runtime, so it ships inside every build (see `export_presets.cfg`) |
| `bots/` | Bot players that play fights through `Core.apply()` only (task 022, below) |
| `sim/` | The fixed-seed fight simulation and its command (task 022, below) |

## Bots (`tools/bots/`)

A bot plays one seat. It sees what a player sees (its hand, Brew slots, Bro Move, the enemies, the
Dudes) and sends one request at a time; only `Core.apply()` changes the game. It never reads the
draw pile or `run_state.rng`.

- `bot_moves.gd`: the legal requests of a seat, built from the hand and the targets each card asks
  for, kept when `Core.validate()` accepts them, in a fixed "canonical" order (hand order, then Brew
  slots, then the Bro Move, then Ready).
- `random_bot.gd` (`random`): picks one legal request uniformly at random, Ready included.
- `greedy_bot.gd` (`greedy`): the play that removes the most enemy HP; else the most Guard; else the
  first playable card; else Ready. Ties go to hand order. It scores a play by asking the core what it
  would do (`Core.apply()` on the current state, result thrown away).
- `bots.gd`: `Bots.make(name, run_seed, player_id)`.

Each bot has its own `RandomNumberGenerator`, seeded from the seed under test and its `player_id`
(`BotMoves.bot_seed()`). No global random function and no clock read is allowed in `tools/bots/` or
`tools/sim/`; `tests/tools/test_bots.gd` scans for them.

## Fight simulation (`tools/sim/`)

Plays every seed against every encounter, at every party size, with every bot, and reports per bot,
per party size and per encounter: fights won, lost and stalled, win %, mean and max turns, and mean
damage taken per Dude (also per seat). Each fight starts fresh: full HP, the starter deck and
starting Gear, no Brews (`core/combat/party.gd` `build_run_state()` then `core/combat/fight.gd`
`start_fight()`). The rules are in the header of `sim/fight_sim.gd`.

Run it from the repository root:

```
"$(tools/install_godot.sh)" --headless --path . --import      # once, in a fresh checkout
"$(tools/install_godot.sh)" --headless --path . --script res://tools/sim/run_sim.gd -- \
    --party-sizes 1..4 --seeds 1..100 --encounters all --out sim_report.txt
```

| Argument | Required | Meaning |
| --- | --- | --- |
| `--party-sizes` | yes | Party sizes to play, for example `1` or `1..4` or `1, 3`. A size the core or the data refuses stops the run with a message naming it |
| `--seeds` | yes | Seeds under test, for example `1..100` or `1, 5, 9` |
| `--encounters` | yes | Comma-separated: encounter ids from `data/encounters/`, enemy ids joined with `+` (`goblin_pledge+dorm_rat`), or `all` (every encounter, sorted by id, each measured on its own) |
| `--bots` | no | `greedy`, `random` or both (default: both) |
| `--dudes` | no | Dude ids that fill the seats in order, repeated as needed (default: every Dude in `data/dudes/`, sorted). With only Tom built, party size 3 is three Toms: a way to measure, not an answer to the GDD's open question on picking the same Dude twice |
| `--turn-cap` | no | A fight still running when this turn ends is "stalled" (default 50) |
| `--out` | no | Also write the report to this file |

Options may also be written `--name=value`. The report goes to stdout; errors go to stderr and the
exit code is 1. The same arguments on the same data always give a byte-identical report (no dates,
times or unordered keys). Speed on the solo-slice data: the command above (both bots, 4 party sizes,
13 encounters, 100 seeds: 10,400 fights) took about 6 minutes on one core.

`tests/tools/test_sim.gd` runs a 5-seed simulation of small in-memory content
(`tests/tools/sim_fixtures.gd`) and compares it with `tests/tools/sim_expected_report.txt`. If a
deliberate rules change alters that report, the test's failure message prints the new one; check the
change is expected and replace the file with it in the same PR.

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

**macOS needs `import_etc2_astc`.** Godot refuses a universal macOS build unless `project.godot`
sets `rendering/textures/vram_compression/import_etc2_astc=true`, and the official templates hold
no Intel-only build to fall back on. That one-line `project.godot` change is its own contract PR
(task 051 log). Until it is on your branch, `tools/build.sh` exits 1 after exporting the other two;
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

The game keeps these in Godot's user data folder for the project name "Dungeon Dudes":

- `run.save`: the run in progress (deleted when a run ends).
- `run_log.jsonl`: one line per finished or abandoned run (task 053). The run-over screen's
  **Open log folder** button opens this folder. **This is the file to ask playtesters for.**
- `settings.cfg`: client settings, such as whether How to play was already shown (task 049).
- `logs/godot.log` (plus older ones): Godot's own log.

If something breaks, ask the tester for `run_log.jsonl`, `run.save` and `logs/` from:

| OS | Folder |
| --- | --- |
| Windows | `%APPDATA%\Godot\app_userdata\Dungeon Dudes\` (type it into Explorer's address bar) |
| macOS | `~/Library/Application Support/Godot/app_userdata/Dungeon Dudes/` (Finder: Go > Go to Folder) |
| Linux | `~/.local/share/godot/app_userdata/Dungeon Dudes/` (or `$XDG_DATA_HOME/godot/...` if set) |

Deleting `run.save` starts the game fresh. Running the project from the Godot editor uses the same
folder, so on a developer's machine an exported build and the editor share one save.
`tools/build.sh --check` does not touch it (it runs with a throwaway folder).
