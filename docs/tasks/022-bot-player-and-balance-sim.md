---
id: 022
title: Bot players and a fixed-seed balance simulation
lane: tools
owner: B
status: in_review
branch: b/022-bot-sim
depends_on: [007, 009, 011]
blocked_on: []
files:
  - tools/bots/
  - tools/sim/
  - tools/README.md
  - tests/tools/
---

## Goal

Headless bots that play fights through `apply()` only, and a batch simulation that plays a list of
seeds and reports fight win rate, turns and damage taken. This is the GDD's mitigation for its
"Balance across 1–4 players" risk, so it must work for any party size even though only 1 is built.

## Read first

GDD "Risks" (balance row), "Difficulty scaling", "Turn flow", "Bro Meter", "Random streams";
`core/schema/README.md` ("The core's entry point"), `request.gd`, `event.gd`; task 007's fight-start
function and test helper; `tests/core/test_purity.gd`.

## Acceptance checks

- [x] Two bots in `tools/bots/`: **random** (a uniformly chosen legal request each step) and **greedy** (a written-down heuristic, for example the play that removes the most enemy HP, else the most Guard; ties broken by hand order).
- [x] Once a fight is set up with task 007's fight-start function, bots change the game only by sending requests to `apply()`. They find legal plays from the state or by trying a request and reading `reject`; a rejected request is never counted as a play.
- [x] Bot choices use a generator seeded from the seed under test and the bot's `player_id`. No `randi()`, `randomize()` or clock reads in `tools/bots/` or `tools/sim/` (a test greps for them), and bots never touch `run_state.rng`.
- [x] `tools/sim/` plays N seeds against a given encounter list and party size and reports, per bot, per encounter and per party size: fights won and lost, mean and max turns, mean damage taken per Dude.
- [x] Same seed list, same report: two runs of the simulation give byte-identical output (no times, dates or unordered keys in it).
- [x] Runs as a test with a small N (`tests/tools/test_sim.gd`, 5 seeds, checked against a recorded report) and as a command with a large N; the command and its arguments are written in `tools/README.md`.
- [x] Party size is an argument, never a literal 1. If the core or the data refuses a party size, the simulation stops with a message naming it.
- [x] Every fight ends: a turn cap reports a fight that does not finish as "stalled" rather than hanging.

## Notes

- Real fights need Tom's data (task 006) and the floor 1 enemies (task 010). Until they merge, test
  with small in-memory definitions passed to task 005's ruleset builder.
- Which enemy groups form a Brawl is G19. Take the encounter list as input; do not pick floor 1's mix.
- The new command belongs in CLAUDE.md "Commands" too. That is a contract change: open its own PR,
  after task 002 has added the section.
- Win-rate target bands per party size are milestone 5 work; this task only measures.

## Log
- 2026-10-11 B: Claimed (steamjgrube: pick up work the board asks for).
- 2026-10-11 B: Done, in review on `b/022-bot-sim`. Bots in `tools/bots/`: `random` (uniform over
  every legal request, Ready included) and `greedy` (most enemy HP removed, else most Guard, else the
  first playable card, else Ready; ties by hand order). Legal requests are built from what a player
  sees (hand, Brew slots, Bro Move, each definition's `target`) and kept when `Core.validate()`
  accepts them (`tools/bots/bot_moves.gd`). Greedy scores a play by applying it to the current state
  with `Core.apply()` (pure) and reading only enemy HP and Guard from the result; the forecast is
  thrown away. Each bot owns a `RandomNumberGenerator` seeded from (seed under test, `player_id`).
  `tools/sim/fight_sim.gd` plays bots x party sizes x encounters x seeds, each fight from
  `Party.build_run_state()` + `Fight.start_fight()` (full HP, starter deck, starting Gear, no Brews),
  seats acting round-robin in seat order through `Core.apply()` only; a refused request stops the
  run with an error and is never counted. Turn cap (default 50) and a request cap give "stalled".
  Command: `tools/sim/run_sim.gd`, documented in `tools/README.md` (`--party-sizes`, `--seeds` and
  `--encounters` are required, so party size is never defaulted).
  Verified: `tools/test.sh` -> 532 passed, 0 failed (20 new in `tests/tools/`: recorded 5-seed
  report on in-memory fixtures, byte-identical reruns on fixtures and real data, every real fight
  ends, party sizes 0 and 5 refused by name, turn cap -> stalled, bots send only `validate()`-legal
  requests and never change the state they are given, grep for `randi()`/`randomize()`/clock reads
  and `rng` access, documentation lint from `tests/core/test_documentation.gd` on my folders).
  Full run: `"$(tools/install_godot.sh)" --headless --path . --script res://tools/sim/run_sim.gd --
  --party-sizes 1..4 --seeds 1..100 --encounters all` -> exit 0, 10,400 fights in 5 min 44 s,
  0 stalled. Headline (win %, all 13 floor 1 encounters, each fought from a fresh starter deck):
  greedy 83.8 / 99.8 / 93.6 / 100.0 at 1 / 2 / 3 / 4 players; random 73.0 / 85.7 / 85.0 / 91.2.
  Mean turns greedy 3.9 / 4.0 / 3.8 / 3.8; mean damage taken per Dude per fight greedy
  24.5 / 12.3 / 16.0 / 11.9 (Tom max HP 80).
  Per encounter, solo greedy: boss Goblin King Chad 0 % (6.2 turns, always 80 HP lost); Rivals
  Goblin Shot-Caller 35 %, Sewer Gator 55 %, Hall Monitor Golem 100 % (30.2 HP lost); every Brawl
  and the Mimic Cooler 100 % in 1.8-4.7 turns with 1.6-16.1 HP lost. Random solo: boss 1 %, Sewer
  Gator 0 % (and 0-1 % at every party size), Shot-Caller 8 %, Golem 42 %.
  Things that look off (reported, not changed; balance is the owner's call):
  1. Party size is not monotonic: greedy beats the boss 0 % solo, 97 % with 2 players, 19 % with 3
     and 100 % with 4 (random: 1 / 41 / 22 / 87 %). A likely cause, not checked: 3 players
     (`MULTI_TARGET_PARTY_SIZE`) is the first size where a single-target attack hits
     `MULTI_TARGET_COUNT` (2) Dudes, and at 4 players the fourth Tom adds damage while attacks still
     hit 2. The GDD's "extra enemies per Brawl" at 3-4 players is not built
     (G59), so 3-4 player Brawls are easier than the GDD intends.
  2. A fresh starter deck never beats the boss solo (greedy 0/100). A real run reaches the boss with
     rewards, Lifts and Gear, so this is a floor, not the run's win rate; a whole-run bot is not part
     of this task.
  3. Solo Rivals are coin flips or worse for a starter deck (Shot-Caller 35 %, Sewer Gator 55 %).
  Not done: the CLAUDE.md "Commands" line for the new command (a contract change; needs its own PR
  after this one merges). Party sizes above 1 repeat Tom (`--dudes` cycles), which measures scaling
  only and does not answer the GDD's open question on two players picking the same Dude. Brews are
  never in play (a fresh `build_run_state()` has 0 Brew slots), so the bots' Brew path is covered by
  the legality code only, not by these numbers. No whole-run simulation (map, rewards, shop).
