# Dungeon Dudes

Dungeon Dudes is a co-op roguelike deckbuilder (1–4 players online) about five fantasy frat bros.
The full design is in `docs/GDD.md`. Read the sections your task touches before writing anything.

Two Claude Code agents work in this repository at the same time, each driven by a different person.
Most of this file exists so the two of you never edit the same lines, never overwrite each other,
and can always see what the other one is doing. Follow it even when a shortcut looks harmless.

## Status

- Bootstrap (task 001): a Godot project, the shared contracts (`core/schema/`, `data/constants.json`)
  and the task board exist, and the test harness runs in CI (task 002). No rules code yet.
- Current target: **GDD milestone 2, the solo slice.** Tom only, floor 1 (The Basement) only,
  about 30 cards, 10 Gear, one boss, placeholder art.
- Out of scope until that gate passes: networking, the other four Dudes, floors 2 and 3,
  the final boss, meta progression, real art and audio.
- Out of scope does not mean ignore. See "Build for co-op from the first commit" below.

Items marked **(proposed)** in this file are defaults nobody has confirmed. If your task depends on
one, say so in your PR so both people can confirm or change it. Do not treat them as settled.

## Sources of truth

| Question | Where the answer lives |
| --- | --- |
| What the game is, rules, numbers, names | `docs/GDD.md` |
| How the two agents work in this repo | This file |
| What a field, variable or constant means | GDD "Technical design" tables, then the code comment on it |
| Who is doing what right now | `docs/tasks/` |

- If the GDD and this file disagree on design, the GDD wins. On process, this file wins.
- `docs/GDD.md` is an exported snapshot (version 0.5) of a document the owner edits elsewhere.
  **Agents do not edit it.** To change the design, add `docs/proposals/<short-name>.md` stating
  what changes and why, and stop work that depends on it until a person answers.
- Every number in the GDD is an untested starting value. Implement it as written and keep it in
  data so it can be tuned. Do not "fix" balance on your own.
- The GDD's "Open questions" list is undecided. Never pick an answer yourself.

## The two agents

### Who is who

| Agent | Works for | Lanes it owns | Branch prefix |
| --- | --- | --- | --- |
| Agent A | Smoketsu | `core`, `run` | `a/` |
| Agent B | steamjgrube | `content`, `tools`, `client` | `b/` |

- At the start of a session, find out which agent you are. Ask your person if you cannot tell from
  the branch you were given or from a previous task file you own.
- The split follows the dependency order of milestone 2: A builds the rules, B feeds them data,
  tests and a screen. Either person can move a lane between agents by editing this table in its
  own PR.
- You may only claim tasks in the lanes your agent owns. If you have nothing left, write the task
  you would like the other agent to do instead of crossing into their lane.

### Lanes and directories

Each lane owns directories. Edit files only inside the lanes your agent owns.

| Lane | Owns | Does |
| --- | --- | --- |
| `core` | `core/` except `core/run/` and `core/schema/` | Rules: state, requests, events, damage order, statuses, enemy AI |
| `run` | `core/run/` | Map generation, node flow, rewards, shop, save and load |
| `content` | `data/` except `data/constants.json` | Card, enemy, Gear, Brew and Side Quest definitions |
| `tools` | `tools/`, `tests/` except `tests/core/` and `tests/run/` | Test harness, bot players, balance simulation, data validation |
| `client` | `client/`, `assets/` | Screens, input, animation of events |

- Tests for a lane live with that lane's owner: Agent A writes `tests/core/` and `tests/run/`,
  Agent B writes everything else under `tests/`. Neither agent edits the other's tests.
- If your task needs a change in the other agent's lane, do not make it. Open a task for that lane
  describing the exact change you need, and carry on with something else.
- Do not reformat, rename, reorder or "tidy" anything your task does not require. Cosmetic diffs
  in shared files cause conflicts for the other agent.
- Do not delete or rewrite the other agent's work because it looks wrong. Report it in a task or
  as a suggested change on their PR (see "Reviewing the other agent's work").

### Shared contracts

These files are read by both agents. A change to one can break the other agent mid-task.

- `core/schema/` (shapes of state, requests and events)
- `data/constants.json` (all tuning constants)
- The data file formats under `data/`
- `CLAUDE.md`
- `project.godot`, `.gitignore`, `.gitattributes` and `.github/workflows/` (build and CI config)
- The pinned Godot version (see "Tech stack")
- `docs/tasks/README.md` (the task file format). Each task file is edited by its owner.

Rules for changing a contract:

1. Change it in its own small PR that contains nothing else.
2. Additive changes (a new optional field, a new constant) are fine from either agent.
3. Renaming, removing or changing the meaning of a field needs a proposal and a person's approval.
4. A contract PR needs approval from the **other** agent's person before it merges. Never merge
   your own contract change.
5. Update the matching GDD-style table and code comments in the same PR.
6. After a contract PR merges, the other agent rebases before its next push.

## Working rules

### One task, one owner, one branch

1. Tasks are files: `docs/tasks/<id>-<slug>.md`, one per task, with `status`, `owner` (`A` or
   `B`), `lane`, `files`, `depends_on` and acceptance checks. One file per task keeps the two
   agents out of each other's diffs.
2. Task ids are numbers. Agent A uses odd numbers, Agent B uses even numbers, so the two of you
   never create the same id at the same time. **(proposed)**
3. Claim a task before touching code: set `status: in_progress` and `owner` in a PR that contains
   only that change, and get it merged first. If the task is already claimed, pick another.
4. Work on a branch named `<prefix><id>-<slug>`, for example `a/007-damage-order`. One task per
   branch, one branch per PR. If your session assigns you a branch name, use that one and record
   it in the task file.
5. If you share a checkout with the other agent, use your own git worktree. Never switch branches
   in a directory the other agent is using.
6. Never commit to `main` directly, never push to a branch the other agent created, and never
   rewrite history that has been pushed.
7. Rebase on `main` before opening the PR and again if `main` moves under you.

### Suggest, do not overwrite

The two people review each other's agent's work. Everything goes through a pull request.

- Open a PR for every change, even a one-line fix. Never merge your own PR; the other person
  merges it after review. **(proposed)**
- When you review the other agent's PR, put fixes in GitHub suggested-change blocks so the author
  can accept or reject them line by line:

  ````
  ```suggestion
  the replacement line
  ```
  ````

- Do not push commits to the other agent's branch to "help". A suggestion is the only way you
  change their work.
- Larger concerns (a different design, a missing case) go in a normal review comment that says
  what you would change and why. The author decides.
- When you receive a suggestion, accept it, or reply saying why not. Never leave one silent.

### Dependencies between the two agents

Most milestone 2 work flows one way: schema, then rules and data, then tests and the client.

- List what your task waits on in `depends_on`. Do not start a task whose dependencies are not
  merged; pick another or stub against the merged schema only.
- If you are blocked on the other agent, say so in your task file (`status: blocked`, plus what
  you need) and tell your person. Do not build the missing piece yourself.
- If both agents need the same new file, the lane table decides who creates it. If the table does
  not decide it, stop and ask.

### Handoffs

Either agent may pick up where you stop, with none of your context. In every PR description and
in the task file, state:

- What is done and how you verified it (the command you ran and its result).
- What is not done, including anything you stubbed or skipped.
- Anything you found that the next agent would otherwise have to rediscover.

Report failures plainly. A task marked done with a failing or skipped test is worse than a task
left open.

## Architecture rules

These come from the GDD "Technical design" section. They hold from the first commit.

### The rules core is pure

- `core/` is a function: `apply(ruleset, state, request) -> (new_state, events)`, where `ruleset` is
  the read-only content data (see `core/schema/README.md`). It has no rendering,
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
- A new effect operation (`op`) belongs to the `core` lane. Agent B requests it in a task;
  Agent A builds it.
- Every balance number lives in `data/constants.json` under the names in the GDD "Tuning
  constants" table. No magic numbers in code.

### Build for co-op from the first commit

Networking is out of scope, but the solo slice must not need a rewrite to add it.

- State holds a list of Dudes and a `party_size`, even though both are 1 for now.
- Per-player things stay per-player: deck, hand, Hype, HP, Dolla Bills, random streams.
- Requests carry `player_id` and `seq`. Every applied request raises `state_version` by 1.
- State must serialize to a full snapshot and load back to an identical state.
- Signature mechanics of other Dudes (Auras, Abs, Puppets, Crash, Rolls) are not built yet.
  Do not hard-code "the player is Tom" anywhere outside Tom's data files.

## Naming and identifiers

- Use the GDD's field names in code and data exactly: `hype`, `guard`, `dolla_bills`, `swole`,
  `chill`, `clout`, `broken_arms`, `ick_threshold`, `abs_ready`, and so on.
- Use the GDD's themed terms in everything a player reads: Hype, Guard, Dolla Bills, Gear, Brew,
  Shake, Rival, Side Quest, The Tailgate, Baileys, Tapped, Keg Level. The glossary is in
  "Tone and humor".
- Content ids are `snake_case` in the form `owner_card_name`, for example `tom_arm_bar`.
  An id never changes once merged, because saves refer to it. Changing a display name is fine.
- Do not reuse the id of removed content.

## Documentation standard

This is a hard requirement from the owner, not a style preference.

- Every variable, field, constant and function parameter gets a comment saying what it means,
  its unit or range, and who may change it. "Obvious" names still get one.
- A field that appears in a GDD table carries the same meaning in its code comment.
- Every PR adds one file, `docs/changes/<date>-<task-id>.md`, listing what changed, why, and each
  variable, field or constant that was added, renamed or removed. One file per PR means the two
  agents never edit the same change log.
- A new field, constant or message is not finished until it is documented in the same PR.

## Writing and content rules

All player-facing text follows the GDD "Rules for writers". The short version:

- The joke lands on a Dude, a monster or an institution. Never on a real-world group of people.
- No slurs, no sexual content, no jokes that need a victim to work.
- Tom's Ick is repellence that works on every enemy alike. Do not write it as hostility toward
  women. He thinks it is charisma.
- **Baileys sells weed, not drinks.** At Baileys every Brew is shown as Shake; it is still a
  normal Brew in data and in a Brew slot. Anything said or sold at Baileys is weed or Shake.
  Do not write beer or other drinks into Baileys.
- The Dudes, Dylan and Baileys may be named after real people or places. Do not add surnames,
  likenesses or personal details beyond what the GDD already contains.
- Firefly, Dragon Quest, Warhammer and Dungeons & Dragons are real brands and their use is an
  open question. Do not add new real brand names, real artists, logos or licensed material.
- Use placeholder art and sound you create or that is clearly free to use. Record the source of
  anything you did not create.

## Tech stack

| Choice | Value | Status |
| --- | --- | --- |
| Engine | Godot **4.7.2-stable**, official build (pinned; version and checksums in `tools/install_godot.sh`) | Confirmed by Person A and Person B 2026-10-10 |
| Language | GDScript | Confirmed by Person A and Person B 2026-10-10 |
| Data format | JSON, shaped like the GDD's example card definition, parsed with `core/schema/json_values.gd` | Confirmed by Person A 2026-10-10; Person B has not been asked separately |
| Core classes | Plain data and `RefCounted` only, no `Node` | Follows from "the rules core is pure" |

The GDD's open question on the engine is answered for this repository; the owner's GDD still
lists it. Upgrading the pinned Godot version is a contract change. Godot's JSON parser returns
every number as a float, and JSON cannot hold 64-bit ints: read `core/schema/README.md` before
parsing data or serializing state.

### Layout (proposed)

Directories are created by the first task that needs them.

```
core/            rules core, pure and headless             (Agent A)
core/schema/     shared shapes of state, requests, events  (contract)
core/run/        map, node flow, rewards, shop, save/load  (Agent A)
data/            cards/, dudes/, enemies/, gear/, brews/, side_quests/  (Agent B)
data/constants.json                                        (contract)
client/          scenes, UI, animation                     (Agent B)
assets/          placeholder art and sound (see assets/placeholder/README.md)  (Agent B)
tools/           bot players and balance simulation        (Agent B)
tests/core/, tests/run/                                    (Agent A)
tests/           everything else                           (Agent B)
docs/            GDD.md, tasks/, changes/, proposals/
```

### Commands

Run these from the repository root. They work on Linux and macOS; on Windows, use WSL or follow
the manual install steps that `tools/install_godot.sh` prints.

| Command | What it does |
| --- | --- |
| `tools/test.sh` | Installs the pinned Godot into `.tools/` if missing (checksum verified), imports the project, runs every test. Exit 0 only if all pass. Run it before every push |
| `tools/test.sh rng core/` | Runs only test files whose path contains any of the given words |
| `tools/install_godot.sh` | Installs the pinned Godot if missing and prints the binary's path |

- Tests are `res://tests/**/test_*.gd` files that extend `res://tests/framework/test_case.gd`.
  Each `test_*` method runs on a fresh instance. A failed assertion, a runtime error or a script
  that does not parse fails the run. The full interface is in task 002.
- CI (`.github/workflows/tests.yml`) runs `tools/test.sh` on every pull request and every push to
  `main`. A red check blocks the merge.
- Calling Godot directly: `"$(tools/install_godot.sh)" --headless --path . --import` once, then
  `"$(tools/install_godot.sh)" --headless --path . --script res://tests/run_tests.gd [-- filters]`.
- There is no linter or formatter yet. Agent A's `tests/core/test_documentation.gd` checks the
  documentation standard in Agent A's folders.

## Before you call a task done

- [ ] Every acceptance check in the task file passes, and you ran it yourself.
- [ ] Tests exist for the rule or content you added, including a fixed-seed case.
- [ ] Nothing outside your agent's lanes changed.
- [ ] Every new variable, field and constant is commented and listed in your change file.
- [ ] The task file says what is done, what is not, and how you verified it.
- [ ] The PR is open for the other person to review; you did not merge it yourself.

## Stop and ask your person when

- Your task needs an answer to one of the GDD's open questions.
- The GDD is silent or contradicts itself on a rule you must implement. Do not invent the rule.
- You need to rename or remove a shared contract field, or change a merged content id.
- You would have to delete or overwrite work you did not create.
- Both agents claim the same files, or the lane table does not say who owns a file.
- You are blocked on the other agent for longer than one task.
