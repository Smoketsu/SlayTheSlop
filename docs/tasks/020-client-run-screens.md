---
id: 020
title: Placeholder run screens - menu, map, rewards, Tailgate, Baileys, Side Quest, run over, saving
lane: client
owner: B
status: in_progress
branch: b/020-run-screens
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
  player can see which Brew a Shake is before buying was answered by G29 (accepted by both people):
  Baileys shows each Brew's name and effect, labelled Shake. The drink-named Brews were renamed (#78).
- Solo still goes through `vote_node` and per-player rewards; do not shortcut them, co-op reuses this.
- Real file access is allowed in `client/` only. Never pass a path into the core.
- Screen art and sources go in `client/ASSETS.md`, as in task 018.

## Log

- 2026-10-10 B: Claimed (steamjgrube: "work on task 20"). Plan: `client/run/run_screen.gd` routes on
  the run state alone (`run_phase`, the player's `offers`, an active fight) to a menu, map, offer,
  fight or run-over screen; `client/run/save_store.gd` writes `user://` saves (temp file, then
  rename). Map and offer screens share one small interface (`show_state`, `request_made`) so they
  can be built in parallel. Making the menu the main scene is a separate contract PR (`project.godot`).
- 2026-10-10 B (run core, branch `b/020-run-core`): Done: `client/run/run_screen.gd` + `.tscn`
  (`screen_for()` routes on run_phase, a running fight in `combat`, and otherwise the node's offers;
  `send()` adds player_id and seq = local last_seq + 1; the run screen is the fight screen's gateway,
  so every request goes through one `apply()` and is kept in `sent_requests`); `client/run/main_menu.gd`
  (New Run from a typed seed, or a client-picked one that is shown; Continue; load errors offer New
  Run); `client/run/save_store.gd` (`user://` only, `<path>.tmp` then rename). Saving: after every
  applied request outside a running fight, and when a new run starts; a finished run deletes the save.
  `fight_screen.gd` gained `state_applied(state)` and skips redrawing a state with no fight.
  Verified: `tools/test.sh` -> 453 passed, 0 failed (new: `tests/client/test_run_screen.gd`, 7 tests;
  `tests/client/test_save_store.gd`, 3 tests); `godot --headless --path . --quit-after 60` and the same
  with `res://client/run/run_screen.tscn`: no errors. Not done: the map and offer screens (separate
  work; the one-code-path test emits their `request_made` directly); making `run_screen.tscn` the main
  scene (contract PR: `run/main_scene="res://client/run/run_screen.tscn"` in `project.godot`).
  Notes for the map/offer screens: they are added to the tree before `show_state()` is first called,
  and `show_state()` is called again on the same instance after every applied request; the offer
  screen is also shown in run_phase "node" when this player has no open offers (co-op: waiting on the
  others) and must draw an empty list as waiting.
