---
id: 022
title: Bot players and a fixed-seed balance simulation
lane: tools
owner: B
status: open
branch:
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

- [ ] Two bots in `tools/bots/`: **random** (a uniformly chosen legal request each step) and **greedy** (a written-down heuristic, for example the play that removes the most enemy HP, else the most Guard; ties broken by hand order).
- [ ] Once a fight is set up with task 007's fight-start function, bots change the game only by sending requests to `apply()`. They find legal plays from the state or by trying a request and reading `reject`; a rejected request is never counted as a play.
- [ ] Bot choices use a generator seeded from the seed under test and the bot's `player_id`. No `randi()`, `randomize()` or clock reads in `tools/bots/` or `tools/sim/` (a test greps for them), and bots never touch `run_state.rng`.
- [ ] `tools/sim/` plays N seeds against a given encounter list and party size and reports, per bot, per encounter and per party size: fights won and lost, mean and max turns, mean damage taken per Dude.
- [ ] Same seed list, same report: two runs of the simulation give byte-identical output (no times, dates or unordered keys in it).
- [ ] Runs as a test with a small N (`tests/tools/test_sim.gd`, 5 seeds, checked against a recorded report) and as a command with a large N; the command and its arguments are written in `tools/README.md`.
- [ ] Party size is an argument, never a literal 1. If the core or the data refuses a party size, the simulation stops with a message naming it.
- [ ] Every fight ends: a turn cap reports a fight that does not finish as "stalled" rather than hanging.

## Notes

- Real fights need Tom's data (task 006) and the floor 1 enemies (task 010). Until they merge, test
  with small in-memory definitions passed to task 005's ruleset builder.
- Which enemy groups form a Brawl is G19. Take the encounter list as input; do not pick floor 1's mix.
- The new command belongs in CLAUDE.md "Commands" too. That is a contract change: open its own PR,
  after task 002 has added the section.
- Win-rate target bands per party size are milestone 5 work; this task only measures.

## Log
