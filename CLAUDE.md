# Dungeon Dudes

Dungeon Dudes is a co-op roguelike deckbuilder (1–4 players online) about five fantasy frat bros.
The full design is in `docs/GDD.md`. Read the sections your task touches before writing anything.

Several agents work in this repository at the same time. Most of this file exists to stop you
from colliding with them. Follow it even when a shortcut looks harmless.

## Status

- The repository holds design only. No engine project, no code, no build or test commands exist yet.
- Current target: **GDD milestone 2, the solo slice.** Tom only, floor 1 (The Basement) only,
  about 30 cards, 10 Gear, one boss, placeholder art.
- Out of scope until that gate passes: networking, the other four Dudes, floors 2 and 3,
  the final boss, meta progression, real art and audio.
- Out of scope does not mean ignore. See "Build for co-op from the first commit" below.

Items marked **(proposed)** in this file are defaults nobody has confirmed. If your task depends on
one, say so in your PR so the owner can confirm or change it. Do not treat them as settled.

## Sources of truth

| Question | Where the answer lives |
| --- | --- |
| What the game is, rules, numbers, names | `docs/GDD.md` |
| How agents work in this repo | This file |
| What a field, variable or constant means | GDD "Technical design" tables, then the code comment on it |
| Who is doing what right now | `docs/tasks/` |

- If the GDD and this file disagree on design, the GDD wins. On process, this file wins.
- `docs/GDD.md` is an exported snapshot (version 0.4) of a document the owner edits elsewhere.
  **Do not edit it.** To change the design, add `docs/proposals/<short-name>.md` stating what
  changes and why, and stop work that depends on it until the owner answers.
- Every number in the GDD is an untested starting value. Implement it as written and keep it in
  data so it can be tuned. Do not "fix" balance on your own.
- The GDD's "Open questions" list is undecided. Never pick an answer yourself.

## Working alongside other agents

### One task, one owner, one branch

1. Tasks are files: `docs/tasks/<id>-<slug>.md`, one per task, with `status`, `owner`, `lane`,
   `files`, and acceptance checks. One file per task keeps agents out of each other's diffs.
2. Claim a task before touching code: set `status: in_progress` and `owner` in a PR that
   contains only that change, and get it merged first. If the task is already claimed, pick another.
3. Work on a branch named `task/<id>-<slug>`. One task per branch, one branch per PR.
4. If you share a checkout with another agent, use your own git worktree. Never switch branches
   in a directory another agent is using.
5. Never commit to `main` directly, never force-push a branch you did not create, and never
   rewrite history that has been pushed.
6. Rebase on `main` before opening the PR and again if `main` moves under you.

### Stay in your lane

Each task names a lane, and a lane owns directories. Edit files only inside your lane.

| Lane | Owns | Does |
| --- | --- | --- |
| `core` | `core/` except `core/run/` and `core/schema/` | Rules: state, requests, events, damage order, statuses, enemy AI |
| `content` | `data/` except `data/constants.json` | Card, enemy, Gear, Brew and Side Quest definitions |
| `client` | `client/` | Screens, input, animation of events |
| `run` | `core/run/` | Map generation, node flow, rewards, shop, save and load |
| `tools` | `tools/`, `tests/` | Test harness, bot players, balance simulation |

- If your task needs a change in another lane, do not make it. Open a task for that lane and
  describe the exact change you need.
- Do not reformat, rename, reorder or "tidy" anything your task does not require. Cosmetic diffs
  in shared files cause conflicts for every other agent.
- Do not delete or rewrite another agent's work because it looks wrong. Report it in a task.

### Shared contracts

These files are read by every lane. A change to one can break agents who are mid-task.

- `core/schema/` (shapes of state, requests and events)
- `data/constants.json` (all tuning constants)
- The data file formats under `data/`
- `CLAUDE.md`

Rules for changing a contract:

1. Change it in its own small PR that contains nothing else.
2. Additive changes (a new optional field, a new constant) are fine.
3. Renaming, removing or changing the meaning of a field needs a proposal and owner approval.
4. Update the matching GDD-style table and code comments in the same PR.

### Handoffs

Another agent will pick up where you stop, with none of your context. In every PR description and
in the task file, state:

- What is done and how you verified it (the command you ran and its result).
- What is not done, including anything you stubbed or skipped.
- Anything you found that the next agent would otherwise have to rediscover.

Report failures plainly. A task marked done with a failing or skipped test is worse than a task
left open.

## Architecture rules

These come from the GDD "Technical design" section. They hold from the first commit.

### The rules core is pure

- `core/` is a function: `apply(state, request) -> (new_state, events)`. It has no rendering,
  no scene tree, no input, no file or network access, and no dependence on frame timing.
- The client never changes game state. It sends a request and animates the events that come back.
  This is true in solo play too. There is one code path, and co-op reuses it.
- The core must run headless so tests and bot simulations can play thousands of fights.

### The rules core is deterministic

The same seed and the same requests must always produce the same state.

- All randomness comes from the named streams in the GDD (`map`, `encounters`, `rewards`,
  `shuffle`, `combat_ai`, `side_quest`, `dice`), each derived from `run_seed`. Never call a
  global random function.
- Never read the clock in `core/`.
- Never let results depend on the iteration order of an unordered collection. Sort first.
- Use integers for game values. Where the GDD multiplies (Exposed, Noodle Arms, Broken Arm),
  follow its "Damage order" list exactly, including where it rounds down.

### Content is data

- Cards, enemies, Gear, Brews and Side Quests are data files, not code. Adding a card should not
  need a `core` change unless it needs a new effect operation.
- A new effect operation (`op`) belongs to the `core` lane. Request it; do not add it from `content`.
- Every balance number lives in `data/constants.json` under the names in the GDD "Tuning
  constants" table. No magic numbers in code.

### Build for co-op from the first commit

Networking is out of scope, but the solo slice must not need a rewrite to add it.

- State holds a list of Dudes and a `party_size`, even though both are 1 for now.
- Per-player things stay per-player: deck, hand, Hype, HP, Beer Money, random streams.
- Requests carry `player_id` and `seq`. Every applied request raises `state_version` by 1.
- State must serialize to a full snapshot and load back to an identical state.
- Signature mechanics of other Dudes (Auras, Abs, Puppets, Crash, Rolls) are not built yet.
  Do not hard-code "the player is Tom" anywhere outside Tom's data files.

## Naming and identifiers

- Use the GDD's field names in code and data exactly: `hype`, `guard`, `beer_money`, `swole`,
  `chill`, `clout`, `broken_arms`, `ick_threshold`, `abs_ready`, and so on.
- Use the GDD's themed terms in everything a player reads: Hype, Guard, Beer Money, Gear, Brew,
  Rival, Side Quest, The Tailgate, Baileys, Tapped, Keg Level. The glossary is in "Tone and humor".
- Content ids are `snake_case` in the form `owner_card_name`, for example `tom_arm_bar`.
  An id never changes once merged, because saves refer to it. Changing a display name is fine.
- Do not reuse the id of removed content.

## Documentation standard

This is a hard requirement from the owner, not a style preference.

- Every variable, field, constant and function parameter gets a comment saying what it means,
  its unit or range, and who may change it. "Obvious" names still get one.
- A field that appears in a GDD table carries the same meaning in its code comment.
- Every PR adds one file, `docs/changes/<date>-<task-id>.md`, listing what changed, why, and each
  variable, field or constant that was added, renamed or removed. One file per PR means agents
  never edit the same change log.
- A new field, constant or message is not finished until it is documented in the same PR.

## Writing and content rules

All player-facing text follows the GDD "Rules for writers". The short version:

- The joke lands on a Dude, a monster or an institution. Never on a real-world group of people.
- No slurs, no sexual content, no jokes that need a victim to work.
- Tom's Ick is repellence that works on every enemy alike. Do not write it as hostility toward
  women. He thinks it is charisma.
- The Dudes, Dylan and Baileys may be named after real people or places. Do not add surnames,
  likenesses or personal details beyond what the GDD already contains.
- Firefly, Dragon Quest, Warhammer and Dungeons & Dragons are real brands and their use is an
  open question. Do not add new real brand names, real artists, logos or licensed material.
- Use placeholder art and sound you create or that is clearly free to use. Record the source of
  anything you did not create.

## Tech stack (proposed)

| Choice | Value | Status |
| --- | --- | --- |
| Engine | Godot 4 | Proposed in the GDD, listed there as an open question |
| Language | GDScript | Proposed here, unconfirmed |
| Data format | JSON, shaped like the GDD's example card definition | Proposed |
| Core classes | Plain data and `RefCounted` only, no `Node` | Follows from "the rules core is pure" |

The first task in the `core` lane must get the engine and language confirmed by the owner before
any engine code is committed.

### Layout (proposed)

Directories are created by the first task that needs them.

```
core/            rules core, pure and headless
core/schema/     shared shapes of state, requests and events
core/run/        map, node flow, rewards, shop, save and load
data/            cards/, enemies/, gear/, brews/, side_quests/, constants.json
client/          scenes, UI, animation
tools/           bot players and balance simulation
tests/           automated tests for core and data
docs/            GDD.md, tasks/, changes/, proposals/
```

### Commands

None exist yet. The PR that adds the first way to run, test or lint the project must record the
exact commands here, in its own contract PR.

## Before you call a task done

- [ ] Every acceptance check in the task file passes, and you ran it yourself.
- [ ] Tests exist for the rule or content you added, including a fixed-seed case.
- [ ] Nothing outside your lane changed.
- [ ] Every new variable, field and constant is commented and listed in your change file.
- [ ] The task file says what is done, what is not, and how you verified it.

## Stop and ask the owner when

- Your task needs an answer to one of the GDD's open questions.
- The GDD is silent or contradicts itself on a rule you must implement. Do not invent the rule.
- You need to rename or remove a shared contract field, or change a merged content id.
- You would have to delete or overwrite work you did not create.
- Two tasks claim the same files.
