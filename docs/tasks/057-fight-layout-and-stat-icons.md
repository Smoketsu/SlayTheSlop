---
id: 057
title: Fight layout - characters stand on the floor, stats as icons instead of text
lane: client
owner: B
status: in_review
branch: b/057-fight-layout
depends_on: [028]
blocked_on: []
files:
  - client/fight/
  - client/visual/
  - assets/placeholder/
  - tests/client/
---

## Goal

Smoketsu's feedback on the fight screen at 1280x720 (screenshot of `main` on 2026-10-11):

1. **Characters float at the top of the screen.** The background's floor runs across the middle of
   the frame, but Tom and the enemies sit in panels at the top left and top right. They should
   stand **on the floor**: each sprite's feet on the background's floor line, Tom on the left,
   enemies spread across the right, with no box behind them.
2. **The text under each character is too wordy** ("HP 12 / 12", "Guard 0", "0 of 2 arms broken",
   "Ick 0 / 5", "Draw 5 Discard 0", "Tapped 0"). Replace it with compact symbols: an HP bar with the
   number inside it, then a row of small icon badges with a number.
3. **The cards look messy.** Task 041 (card faces, in progress) covers this; this task only keeps
   the floor and the hand area from overlapping (see Notes).

## Read first

GDD "Turn flow", "Stats", "Statuses", "Enemies" (intents), "Bro Meter"; `client/fight/fight_screen.gd`
(`_redraw`, `_add_view`), `client/visual/combatant_view.gd`, `client/visual/backgrounds.gd`,
`client/visual/sprites.gd`, `client/visual/event_player.gd` (where hit numbers pop up);
`assets/placeholder/README.md`; tasks 041, 043, 045 and 047 (they share this screen).

## Acceptance checks

- [x] **Floor line.** Each fight background has a floor line: the height, as a fraction of the
      screen from the top, where characters' feet go. It lives in one client table next to
      `backgrounds.gd`'s room table, with a default for rooms without an entry. Every Dude and enemy
      sprite is placed with the bottom of its sprite on that line (a test checks this for the basement
      at 1280x720).
- [x] **Placement.** Dudes stand on the left of the floor and enemies on the right, spread evenly,
      left to right in state order (the order they act in). It still fits with 4 Dudes and 5 enemies
      at 1280x720, shrinking sprites if needed, without overlapping the hand area.
- [x] **No text block under characters.** Under each sprite: an HP bar with "current / max" inside
      it, then one row of badges. A badge is an icon plus a number and appears only when its value is
      not 0 (no "Guard 0", no "0 of 2 arms broken"). Badges: Guard, Swole and Chill, each status in state
      (Exposed, Noodle Arms, Hungover, Foggy, and the rest), broken arms ("k / n"), and Ick (shown
      as "current / threshold").
- [x] **Intent above the head.** An enemy's intent is an icon over its sprite: attack shows the
      damage number, with a small marker pointing at the targeted Dude when there is more than one;
      every other intent kind the core uses (defend and so on) has its own
      icon. No "Intent: attack -> Tom" text.
- [x] **Turn info off the characters.** Hype becomes an icon with a number beside the hand. The Bro
      Meter becomes a small bar. Draw, discard and Tapped counts become pile icons in the bottom
      corners (task 043 later makes them clickable). The "Turn 1 - player phase" line can stay as a
      small label.
- [x] **One icon table.** Badge and intent icons are looked up by GDD field name or intent kind
      (`guard`, `swole`, `broken_arms`, `ick`, `attack` ...) in one client table, like the sprite
      lookup. A missing icon falls back to a short text badge, never an error. A test walks every
      status and intent kind in `core/schema/` and checks each has an entry or a fallback.
- [x] **Hover still explains.** Every badge, intent icon and pile icon carries its name and value as
      tooltip text (task 045 will add full tooltips), so nothing the old text showed is lost.
- [x] **Still read-only.** Clicking an enemy or a Dude to target still works, and the read-only
      state test from task 024 still passes through a fight played by presses.
- [x] `tools/test.sh` passes. Post a screenshot of the new layout in the PR (see Notes for how).
      (Screenshots were taken and checked; the PR itself is opened by the person, who attaches them.)

## Notes

- **Assets: icons are needed, card frames are not.**
  - Cards (task 041) can be drawn entirely with `StyleBoxFlat` frames and labels; no art is needed.
  - Badges and intents need about 12–15 small icons (heart, shield, sword, flexed arm, broken arm,
    Hype orb, and so on). Default: Agent B draws simple ones itself, as SVG files written by hand or
    by a small script kept in `assets/placeholder/source/`. Godot imports SVG directly. Record them in
    `assets/placeholder/README.md` as made for this repository.
  - If Smoketsu later supplies an icon sheet (as with the character sheet), it replaces these with the
    same file names; no code changes.
- **Floor line for the basement.** In the 1280x720 screenshot the floor's back edge is at about 0.60 of
  the height. Measure it on each background rather than trusting this number.
- **Hand area.** The hand and buttons should sit below the characters' feet, about the bottom 30% of the
  screen. Agree the split with task 041 if both are open at once; whichever merges second rebases.
- **Screenshots without a display.** `xvfb-run -a -s "-screen 0 1280x720x24" "$(tools/install_godot.sh)"
  --rendering-driver opengl3 --resolution 1280x720 --path . --script <script>`. The script is a
  `SceneTree` script that adds `res://client/fight/fight_screen.tscn` to `root`, waits about 30 frames, then
  calls `root.get_texture().get_image().save_png(path)`. It works in the cloud container. Do not commit the
  PNG.

## Log

- 2026-10-11 A: Written for Agent B from Smoketsu's feedback on the fight screen screenshot.
  Unclaimed.
- 2026-10-11 B: Claimed. Work starts once 041 (#112) merges, since both rework `fight_screen.gd`.
- 2026-10-11 B: Done, on `b/057-fight-layout`, stacked on 041 (#112) because both rework
  `client/fight/fight_screen.gd`; it merges after #112 (rebase if #112 changes first).
  - Floor line: `client/visual/backgrounds.gd` `FLOOR_LINES` (+ `DEFAULT_FLOOR_LINE` 0.60,
    `floor_line()`). Measured on each picture at 1280x720 with a pixel grid: the floor's back edge is
    at 0.55 in the Basement (not 0.60 as the note guessed), 0.54 in Goblin King Chad's room and 0.55
    in the Rat King's. Feet are set at 0.60 in all three, a little in front of the back edge, so the
    characters stand on the floor in front of the altars rather than inside the wall.
  - Layout: `client/visual/floor_layout.gd` (a Container) stands Dudes on the left 42% and enemies on
    the right 53%, evenly spaced, state order, one slot width for both sides; crowded floors shrink
    every sprite alike. Name, HP bar and badges end above the hand area (bottom 30%,
    `fight_screen.gd` `HAND_SHARE`, matching 041's hand).
  - Views: `client/visual/combatant_view.gd` rewritten: no panel (a faint light on hover only), intent
    icon over the head, sprite feet on the line, name, HP bar with "current / max" and a heart, one
    badge row (`client/visual/stat_badge.gd`) shown only for values not 0, shrunk to one row when
    narrow. Attack numbers come from the core (`core/ops/damage.gd` `hit_amount()`, so Swole, Noodle
    Arms, Broken Arm and Exposed count); a skipped move (Grossed Out, fallen, Armless, from
    `core/combat/statuses.gd` `skip_reason()`) shows Zzz. In co-op each Dude has a seat-coloured
    marker over its head and each attack carries a marker of the same colour per targeted Dude.
  - Turn info: Hype orb left of the hand, draw pile bottom-left, discard and Tapped piles
    bottom-right, Bro Meter bar above the buttons; the turn label is "Turn 1 - player phase"; message
    and event log moved to the top strip.
  - Icons: one table, `client/visual/icons.gd` `ICONS` (26 keys); 26 SVGs drawn for this repository
    by `assets/placeholder/source/make_icons.py` into `assets/placeholder/icons/` (with their
    `.import` files), recorded in `assets/placeholder/README.md` "Icons". Missing icon -> short text
    tag.
  - Verified: `tools/test.sh` -> 552 passed, 0 failed (new `tests/client/test_fight_layout.gd`, 12
    tests: floor line on the Basement at 1280x720, 4 Dudes + 5 enemies fit without overlap and above
    the cards, slot plan, no 0 badges and no old text, intent icons and numbers, co-op markers and
    clicking a crowded enemy, turn info placement, tooltips on every icon, every status and intent
    kind in `core/schema/` has an icon plus the fallback, icons recorded, documentation lint). The
    task 024 read-only full fight (`test_fight_screen.gd`) and the click-to-target tests still pass.
    A mutation (feet 5 px off the line) makes the two floor tests fail. Screenshots at 1280x720 via
    xvfb (1 Dude + 3 enemies with a full hand; 4 Dudes + 5 enemies; 2 Dudes against the boss in its
    room) were checked by eye.
  - Not done / for others: `client/ASSETS.md` is outside this task's files and still says the fight
    screen uses no icon files; it should point at `assets/placeholder/README.md` "Icons" (one line,
    any client task). The number on Goblin King Chad's charged release is its most ("up to", before
    the helper cut): the exact number needs a read-only core helper for the cut, which I did not
    copy into the client. A teammate's Hype shows as a badge on their view; their pile counts are no
    longer shown anywhere (task 043 adds pile viewers). Full tooltip text is task 045's; the icon
    table's names are what 045 can key on.
