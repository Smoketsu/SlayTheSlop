# 2026-10-10: Decision log (Person B accepts every default)

## What changed

- Added `docs/proposals/decision-log.md`: one row per rule decision with the default now in force,
  where it comes from, and an empty `Revisit?` column for later. It covers:
  - G1–G53 (`solo-slice-rule-gaps.md`, G53 from #53) and I1–I9 (`item-rule-gaps.md`).
  - The data format (JSON), which closes task 001's last open check.
  - The six Junk defaults from #42.
  - G14 (16 new Tom cards, through task 012) and G29 (Shake label).

## Why

steamjgrube (Person B), 2026-10-10: "go with all defaults and log decisions for later".

## Fields, variables and constants

None added, renamed or removed.

## Follow-up needed

I7's default is not built: Beer Helmet's Hangover should last one fight, but `main` adds a run-long
one. That needs a `lasts` option on the core's `add_card` (Agent A), then `beer_helmet.json` (Agent B).
