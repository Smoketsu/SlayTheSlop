# 002: Floor 1 enemy data

| Field | Value |
| --- | --- |
| `status` | in_progress |
| `owner` | B |
| `lane` | content |
| `branch` | `b/002-floor1-enemies` |
| `files` | `data/enemies/floor1/*.json` (one file per enemy), `docs/changes/<date>-002.md` |
| `depends_on` | none |

## Goal

Write the 11 floor 1 enemies from GDD "Enemies / Floor 1: The Basement" as JSON data files, using
the fields in GDD "Technical design / Enemy fields" (`id`, `name`, `floor`, `tier`, `max_hp`,
`arm_count`, `moves`). Moves use `effects` shaped like a card's, per the GDD.

Bosses are not in this task. Milestone 2 needs one floor 1 boss, which will be a separate task.

## Acceptance checks

- [ ] One file per enemy, 11 in all: Goblin Pledge, Goblin Bouncer, Keg Slime, Dorm Rats,
      Skeleton Intern, Boo-zer, Mimic Cooler, Kobold RA, Goblin Shot-Caller, Hall Monitor Golem,
      Sewer Gator in a Letterman Jacket.
- [ ] Every `max_hp`, `arm_count`, `tier` and damage number matches the GDD exactly.
- [ ] Ids are `snake_case` and follow the content id rule in `CLAUDE.md`.
- [ ] Every file parses as JSON.
- [ ] No Ick threshold is stored per enemy; it comes from `ICK_BASE_*` by tier.
- [ ] Every behavior that needs an effect `op` the GDD does not already show
      (`damage`, `guard`, `apply_status`, ...) is listed in a `core` task request for Agent A.
      It is not invented in data.
- [ ] Where the GDD is silent (move weights, the order of moves, which moves an enemy has when
      the GDD names only one), the gap is listed in a proposal for both people. No invented values.

## Known gaps to raise (found while writing this task)

- The GDD says each enemy has 2–4 moves and never uses one three times in a row, but gives no
  move `weight` values, and several enemies have only one move described (Goblin Pledge,
  Keg Slime, Boo-zer, Mimic Cooler, Kobold RA).
- Special behaviors that will likely need new `op`s: summoning (Goblin Pledge, Goblin
  Shot-Caller), splitting (Keg Slime into Foam Slimes, which also need a data file), stealing and
  fleeing (Dorm Rats), adding Junk to decks (Skeleton Intern, Hall Monitor Golem), Faded damage
  cap (Boo-zer), disguise as Loot (Mimic Cooler), card-count triggers (Kobold RA, Hall Monitor
  Golem), on-unblocked-damage Swole (Sewer Gator).

## Progress

Claimed. Nothing built yet.
