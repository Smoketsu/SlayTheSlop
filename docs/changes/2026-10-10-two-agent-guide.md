# 2026-10-10: Two-agent CLAUDE.md, Baileys weed re-theme, Dolla Bills

## What changed

- `CLAUDE.md` rewritten for exactly two agents (A and B), each driven by a different person.
  - Lane ownership split (proposed): A owns `core` and `run`; B owns `content`, `tools`, `client`.
  - Tests split by owner: A writes `tests/core/` and `tests/run/`, B the rest of `tests/`.
  - Branch prefixes `a/` and `b/`; task ids odd for A, even for B (proposed).
  - New "Suggest, do not overwrite" section: every change goes through a PR, the other person
    merges, and reviews use GitHub suggested-change blocks instead of pushes to the other branch.
  - New `depends_on` field in task files and a `blocked` status.
  - Writing rule: at Baileys every Brew is shown as Shake; no beer or drinks at Baileys.
- `docs/GDD.md` (snapshot bumped to 0.5, change log row added):
  - Baileys node sells "cards, Gear and Shake" instead of "cards, Gear and Brews".
  - Glossary row added: "Potion bought at the shop" is Shake.
  - Prices at Baileys: "Brew 50–75" is now "Shake 50–75", with a paragraph defining Shake as
    the shop's name for any Brew. It is a normal Brew once bought.
  - Currency renamed from Beer Money to Dolla Bills everywhere in the GDD and CLAUDE.md.
  - Gear "Fake ID" renamed to "Medical Card". Effect unchanged.

## Why

Requested by the project's people: the repo will be worked on by two agents at once, and Baileys
should be a weed spot rather than a drinks shop.

## Fields, variables and constants

- Added task-file field `depends_on`: list of task ids that must merge before this task starts.
  Set by the task's author.
- Added task status value `blocked`.
- Renamed Dude state field `beer_money` to `dolla_bills`: currency held, a whole number of
  Dolla Bills, 0 or more. Changed only by the rules core. No code or saves used the old name yet.
- No `constants.json` constants were added, renamed or removed.
