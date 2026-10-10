---
id: 016
title: The five GDD Side Quests as data
lane: content
owner: B
status: open
branch:
depends_on: [025]
blocked_on: [G23, G24, G25]
files:
  - data/side_quests/
  - tests/data/          # only to extend task 004's validation to the new folder
  - docs/tasks/          # only to write tasks asking Agent A for ops or fields that do not exist
---

## Goal

The Beer Pong Table, Gas-Station Sushi, 3 a.m. Tattoo, Free Couch on the Curb and The Unlabeled
Brownie as files in `data/side_quests/`, each with its safe and dumb option, in the format task 025
defines, so the run lane plays them from data rather than code.

## Read first

GDD "Example Side Quests", "Junk cards", "Statuses", "Rules that change in co-op" (Side Quests row),
"Run state" (`dumb_options_taken`), "Random streams" (`side_quest`); the Side Quest format in
`core/schema/` once task 025's contract PR has merged; task 008's Junk card ids.

## Acceptance checks

- [ ] `ls data/side_quests/*.json | wc -l` prints 5, one file per GDD Side Quest, ids in snake_case as task 025's format says. Ids never change once merged.
- [ ] Each file passes the Side Quest schema's `check()` and its id equals its file name.
- [ ] Each has exactly two options, the safe one and the dumb one, with the GDD's option names ("Walk away", "Skip it", "Go to bed", "Leave it", "Politely decline") and the GDD's numbers: bet 50 Dolla Bills, 50% to double; heal 25, 35% Hungover for 3 turns; random Gear and Regret; full heal, 30% Bedbugs; upgrade 2 random cards and 2 Foggy.
- [ ] The dumb option is marked as dumb in the way task 025's format says, so the core raises `dumb_options_taken`.
- [ ] Money is written with the `dolla_bills` field name and "Dolla Bills" in text; never `beer_money` or "gold".
- [ ] Chances are numbers in the fields task 025's format defines (not only in the text), so the core rolls them on the `side_quest` stream; no file assumes an outcome.
- [ ] Junk references are the ids from task 008 (`junk_hangover`, `junk_regret`, `junk_bedbugs`) and resolve once task 008 has merged.
- [ ] Task 004's validation covers `data/side_quests/` and passes with the suite (task 002's command).

## Notes

- The GDD is silent on these; ask, do not choose (Agent A can add them to `solo-slice-rule-gaps.md`
  as new G-numbers): betting 50 with fewer than 50 Dolla Bills; which pool "a random Gear" draws from
  and whether it can repeat owned Gear; "upgrade 2 random cards" when fewer than 2 can be upgraded
  (G15); whether "Hungover for 3 turns" means 3 stacks (G1).
- "Start the next fight with" Hungover or Foggy needs the run state to carry a pending status into
  the next fight. If task 025's format has no way to say it, request it in a task for Agent A.
- In co-op each player chooses for themselves. Outcomes apply to the choosing player only; no file
  may assume a single Dude.
- Any prompt or flavor text you add follows "Rules for writers": the joke lands on the Dude making the
  bad decision.

## Log
