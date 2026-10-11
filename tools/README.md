# tools/

Lane: tools (Agent B). Scripts that build, check and measure the game; none of them is part of the
rules core, and none of them changes game data.

| Path | What it is |
| --- | --- |
| `test.sh` | Installs the pinned Godot if missing, imports the project, runs every test (CLAUDE.md "Commands") |
| `install_godot.sh` | Installs the pinned Godot into `.tools/` and prints the binary's path |
| `data_files.gd` | Reads every file under `data/` for `core/ruleset/ruleset.gd` `build()` |
| `bots/` | Bot players that play fights through `Core.apply()` only (task 022) |
| `sim/` | The fixed-seed fight simulation and its command (task 022) |

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
