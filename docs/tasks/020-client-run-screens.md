---
id: 020
title: Placeholder run screens - menu, map, rewards, Tailgate, Baileys, Side Quest, run over, saving
lane: client
owner: B
status: open
branch:
depends_on: [018, 025, 027]
blocked_on: []
files:
  - client/
  - tests/client/
---

## Goal

Every screen a solo floor 1 run passes through, around task 018's fight screen: a main menu that
starts a run from a seed, the map, card and Gear rewards, The Tailgate, Baileys, Side Quests, the
boss reward and the run-over screen. The run is saved to disk after every node using task 027's bytes;
the client writes the file, the core never does.

## Read first

GDD "Run structure" (all of it), "Example Side Quests", "Prices at Baileys", "Sessions" (saving),
"Glossary of themed terms"; CLAUDE.md "Writing and content rules" (Baileys); task 025's request types
and screen state in `core/schema/`; task 027's `to_bytes` / `from_bytes`; task 018's gateway.

## Acceptance checks

- [ ] Main menu: New Run takes a seed typed by the player (or shows the one it picked) and starts the run through the core's new-run entry point from task 025; Continue loads the save.
- [ ] Which screen is shown comes from the run state alone (node type, pending reward or choice), never from a flow kept in the client. Loading a save mid-run opens the right screen.
- [ ] Map: shows floor 1's nodes and links from `run_state.map` and the party's position; choosing a node sends `vote_node`.
- [ ] Reward, Tailgate (Nap or Lift), Baileys (buy, remove a card, leave), Side Quest (safe or dumb) and boss reward (1 of 3 Boss Gear) send exactly the requests task 025 defines, including `choose_reward` with `-1` to skip where allowed. Each passes `request.gd` `check()`.
- [ ] Prices, offers and Dolla Bills shown are read from the state; the client computes no price, discount or odds.
- [ ] At Baileys every Brew is labelled Shake: a test opens Baileys with each of the 8 Brews in stock and every Brew label reads "Shake". No Baileys string mentions beer or another drink.
- [ ] Run over: shows won (boss beaten) or passed out, then returns to the menu. No Rep or meta progression (out of scope).
- [ ] Saving: after every node the client writes `to_bytes(state)` to a file under `user://`, replacing the old save safely (write to a temp file, then rename). A test saves, loads with `from_bytes`, and gets a strictly equal state.
- [ ] A corrupt or wrong-version save shows `from_bytes`'s error and offers New Run; it does not crash (test with a truncated file).
- [ ] One code path: a test drives the screens' input handlers through a fixed-seed run from the menu to the first reward, then replays the same request list straight through `apply()`; both final states are equal.

## Notes

- **Baileys sells weed, not drinks.** Anything said or sold there is weed or Shake. Whether the
  player can see which Brew a Shake is before buying is not in the GDD; ask, do not choose.
- Solo still goes through `vote_node` and per-player rewards; do not shortcut them, co-op reuses this.
- Real file access is allowed in `client/` only. Never pass a path into the core.
- Screen art and sources go in `client/ASSETS.md`, as in task 018.

## Log
