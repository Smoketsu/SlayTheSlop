---
id: 016
title: The five GDD Side Quests as data
lane: content
owner: B
status: done
branch: b/016-side-quest-data
depends_on: [025]
blocked_on: []
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

- [x] `ls data/side_quests/*.json | wc -l` prints 5, one file per GDD Side Quest, ids in snake_case as task 025's format says. Ids never change once merged.
- [x] Each file passes the Side Quest schema's `check()` and its id equals its file name.
- [x] Each has exactly two options, the safe one and the dumb one, with the GDD's option names ("Walk away", "Skip it", "Go to bed", "Leave it", "Politely decline") and the GDD's numbers: bet 50 Dolla Bills, 50% to double; heal 25, 35% Hungover for 3 turns; random Gear and Regret; full heal, 30% Bedbugs; upgrade 2 random cards and 2 Foggy.
- [x] The dumb option is marked as dumb in the way task 025's format says, so the core raises `dumb_options_taken`.
- [x] Money is written with the `dolla_bills` field name and "Dolla Bills" in text; never `beer_money` or "gold".
- [x] Chances are numbers in the fields task 025's format defines (not only in the text), so the core rolls them on the `side_quest` stream; no file assumes an outcome.
- [x] Junk references are the ids from task 008 (`junk_hangover`, `junk_regret`, `junk_bedbugs`) and resolve once task 008 has merged.
- [x] Task 004's validation covers `data/side_quests/` and passes with the suite (task 002's command).

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

- 2026-10-10 B: Claimed. G23, G24 and G25 have defaults built by task 025 (#66) and accepted by
  Person B under "go with all defaults" (decision log); unblocked on that basis.
- 2026-10-10 B: Done, in review on `b/016-side-quest-data` (based on `a/025-run-flow`, which is not
  merged yet, with `b/026-floor1-encounters` merged in, which carries `b/run-event-text`). Five files
  in `data/side_quests/` with task 025's ids. Their rules (effects, chances, `min_dolla_bills`, Junk
  ids, safe labels) equal task 025's `SIDE_QUESTS` fixture exactly. New writing: the five prompts and
  the dumb labels "Eat the whole tray", "Tell him to surprise you" and "Take a nap on it"; the GDD's
  own dumb labels "Bet 50 Dolla Bills" and "Eat it" are kept. Option `text` keeps the GDD's rules
  wording, since the schema says it must describe the effects exactly; safe options say "Nothing
  happens.". Every prompt says "you", so any Dude can take it in co-op.
  `tests/data/test_side_quest_data.gd` checks the file list, the schema, id = file name, the GDD names
  and safe labels, the rules against the fixture (text fields set aside), no "beer money" or "gold",
  and plays every dumb option through `Core.apply()` on the real data at seeds 20261016 (every chance
  roll lost) and 1 (every chance roll won), with a replay giving identical snapshot bytes; outcomes
  are recorded in `RECORDED`. `tests/data/test_data_files.gd` gains
  `test_bad_side_quest_is_reported_with_its_path`. `tools/data_files.gd` needed no change (it reads
  every folder; the ruleset knows `data/side_quests/`). Verified: `ls data/side_quests/*.json | wc -l`
  -> 5; `tools/test.sh` -> 427 passed, 0 failed. Not done: G54 (fewer than 2 upgradable cards) still
  has no recorded answer; the files follow the built default (only Arm Bar can be upgraded today, so
  the Brownie upgrades 1 card). "gold" is checked as a plain substring, so a future word like
  "golden" would trip the test; change the check then, not the text.
- 2026-10-11 B: Done: merged (#77).
