---
id: 017
title: Floor 1 enemy behaviors that are not plain moves
lane: core
owner: A
status: done
branch: a/017-floor1-enemy-behaviors
depends_on: [011, 015]
blocked_on: []
files:
  - core/combat/
  - core/ops/
  - core/ai/
  - core/core.gd
  - core/schema/enemy_def.gd   # additive fields only, in a separate contract PR first
  - core/schema/enemy_state.gd
  - core/schema/combat_state.gd
  - core/schema/event.gd
  - core/schema/run_state.gd
  - core/schema/README.md
  - data/constants.json        # FADED_MAX_DAMAGE, separate contract PR
  - tests/core/enemies/
  - tests/core/ai/
  - tests/core/ops/
  - tests/core/schema/
  - tests/core/combat/test_fixed_seed_fight.gd         # hash re-record only
  - tests/core/combat/test_fixed_seed_status_fight.gd  # hash re-record only
  - tests/run/save/test_snapshot.gd                    # hash re-record only
---

## Goal

Every floor 1 enemy in the GDD table can be expressed as data and plays as described.

## Read first

GDD "Floor 1: The Basement"; task 010's list of requested ops and fields.

## Acceptance checks

- [x] Goblin Pledge: the last goblin standing calls one more Pledge (`enemy_spawned`). `test_goblins.gd::test_last_pledge_calls_one_more`, `test_last_goblin_counts_goblins_only`
- [x] Goblin Bouncer: alternating pattern; "Checks ID" applies 1 Noodle Arms. `test_goblins.gd::test_bouncer_alternates_and_checks_id`
- [x] Keg Slime: at half HP, splits into two Foam Slimes with 10 HP each. `test_floor1_enemies.gd::test_keg_slime_*`, `test_split_in_enemy_phase_waits_for_intents`
- [x] Dorm Rats: each bite steals 5 Dolla Bills; they flee on turn 4 with what they stole; killing one returns its haul. `test_dorm_rats_steal_return_and_flee`, `test_haul_is_per_player`
- [x] Skeleton Intern: every other turn, shuffles Paperwork into the target's deck. `test_skeleton_intern_alternates`, `test_skeleton_intern_paperwork` (added by the lead once task 015 was in the stack).
- [x] Boo-zer: Faded every other turn, taking at most 1 damage per hit. `test_boo_zer_faded_every_other_turn`
- [x] Kobold RA: Noise Complaint, 5 damage to a player who plays 5 or more cards in a turn. `test_kobold_noise_complaint`
- [x] Rivals: Goblin Shot-Caller (done: `test_shot_caller_escort_swole_and_replacement`), Sewer Gator (done: `test_sewer_gator_death_roll_and_swole`), Hall Monitor Golem (`test_hall_monitor_golem_every_third_card`, `test_hall_monitor_golem_adds_detention`).
- [x] Mimic Cooler's Brew drop is reported for the run lane (`brew_dropped` and `combat.brews_dropped`), not granted here. `test_mimic_cooler_reports_brew_drop`
- [ ] One test per enemy, using task 010's data. Done against **fixtures** (`tests/core/enemies/enemy_fixtures.gd`), because task 010 has not merged. Swap to the real data when it does.

## What Agent B's data (task 010) must use

Ids as in the fixtures: `goblin_pledge`, `goblin_bouncer`, `keg_slime`, `foam_slime`, `dorm_rat` (one
rat; the encounter puts 3 in the fight), `skeleton_intern`, `boo_zer`, `mimic_cooler`, `kobold_ra`,
`goblin_shot_caller`, `hall_monitor_golem`, `sewer_gator`. Field shapes are in
`core/schema/enemy_def.gd`; ops in `core/ops/README.md`. The fixtures show one way to write each:

| Enemy | Fields and ops |
| --- | --- |
| Goblin Pledge | `tags: ["goblin"]`; a weight-0 move with `{"op": "summon_enemy", "enemy_id": "goblin_pledge", "count": 1}`; `move_rules: [{"move_id": <that move>, "when": [{"if": "last_of_tag", "tag": "goblin"}]}]` |
| Goblin Bouncer | `tags: ["goblin"]`; `pattern` of a `guard` 8 move and a move with `damage` 9 + `apply_status noodle_arms 1` |
| Keg Slime | `split: {"into": "foam_slime", "count": 2, "at_hp_percent": 50}`; Foam Slime is its own file with `max_hp` 10 |
| Dorm Rat | bite `[damage 3, {"op": "steal_dolla_bills", "amount": 5}]`; a weight-0 move `[{"op": "flee"}]`; `move_rules: [{"move_id": <flee move>, "when": [{"if": "turn_at_least", "turn": 4}]}]` |
| Skeleton Intern | `pattern` of a hit and a move with `damage 6` + `{"op": "add_card", "card_id": "junk_paperwork", "to": "draw_pile", "shuffle_in": true}` and `"target": "dude"` |
| Boo-zer | `periodic_statuses: [{"status": "faded", "every": 2, "first_turn": 1 or 2}]` |
| Mimic Cooler | `drops_brews: 1` |
| Kobold RA | `triggers: [{"id": "noise_complaint", "on": "cards_played", "cards": 5, "repeat": false, "effects": [{"op": "damage", "amount": 5}]}]` |
| Goblin Shot-Caller | `tags: ["goblin"]`, `arrives_with: ["goblin_pledge", "goblin_pledge"]`, two `move_rules` on `turn_cycle {every 2, first_turn 2}` (first with `count_below goblin_pledge 2` → a `summon_enemy` move; then → `{"op": "gain_swole", "amount": 2, "tag": "goblin"}`) |
| Hall Monitor Golem | `triggers: [{"id": "detention", "on": "cards_played", "cards": 3, "repeat": true, "effects": [{"op": "add_card", "card_id": "junk_detention", "to": "discard_pile"}]}]` |
| Sewer Gator | Death Roll `damage 5, hits 3`; `triggers: [{"id": ..., "on": "unblocked_damage", "effects": [{"op": "gain_swole", "amount": 2}]}]` |

Content questions the GDD does not answer, left to the content lane (the fixtures use placeholders):
Foam Slime's attack (fixture: 3 damage); Goblin Shot-Caller's ordinary move (fixture: 10 damage);
whether Checks ID is the Bouncer's hit or its Guard move (fixture: the hit); whether the Intern's
Paperwork turn also hits (fixture: yes); which turn Boo-zer's cycle starts on (fixture: turn 1).

## Pending on 015 (add_card): done

The lead added both tests to `tests/core/enemies/test_floor1_enemies.gd` once task 015 was in the
stack; they pass. Original notes:

Not added as test files, because they cannot pass before task 015 merges. Intended contents, to add
to `tests/core/enemies/test_floor1_enemies.gd` once `add_card` is on `main` (use task 015's junk
card definitions, or keep this file's fixture `junk_paperwork` / `junk_detention`, giving Paperwork
and Detention 015's `lasts: "fight"`):

```gdscript
## Skeleton Intern: on its Paperwork turn the target gets one Paperwork shuffled into the draw pile.
func test_skeleton_intern_paperwork() -> void:
	var rules: Dictionary = EnemyFixtures.ruleset()
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["skeleton_intern"])
	var result: Dictionary = ready(rules, state, 0)          # turn 1: hit
	assert_eq(of_type(result["events"], "card_created"), [])
	result = ready(rules, result["state"], 1)                # turn 2: hit + Paperwork
	var created: Array = of_type(result["events"], "card_created")
	assert_eq(created.size(), 1)
	assert_eq([created[0]["player_id"], created[0]["def_id"], created[0]["to"]], ["p1", "junk_paperwork", "draw_pile"])
	var dude: Dictionary = result["state"]["dudes"][0]
	assert_eq(dude["cards"][created[0]["card_uid"]]["def_id"], "junk_paperwork")
	# It was shuffled into the draw pile before turn 3's Refresh drew 5, so it is in the draw pile or the hand.
	assert_true(dude["draw_pile"].has(created[0]["card_uid"]) or dude["hand"].has(created[0]["card_uid"]))

## Hall Monitor Golem: the 3rd and 6th card of a turn each put one Detention on the discard pile.
func test_hall_monitor_golem_adds_detention() -> void:
	var rules: Dictionary = EnemyFixtures.ruleset()
	var result: Dictionary = {"state": EnemyFixtures.solo_fight(rules, SEED, ["hall_monitor_golem"], 100)}
	var detentions: Array = []
	for seq: int in 7:
		result = play(rules, result["state"], seq, "neutral_test_shrug", "")
		for event: Dictionary in of_type(result["events"], "card_created"):
			assert_eq([event["def_id"], event["to"]], ["junk_detention", "discard_pile"])
			detentions.append(seq + 1)
	assert_eq(detentions, [3, 6])
	assert_eq(result["state"]["dudes"][0]["discard_pile"].filter(
		func(uid: String) -> bool: return result["state"]["dudes"][0]["cards"][uid]["def_id"] == "junk_detention").size(), 2)
```

## Notes

- Rules decided where the GDD is silent (each is in the code's file header; confirm or change):
  1. Goblin Pledge checks "last goblin standing" when it picks its intent (turn flow step 1), so the
     players see the call coming; the call replaces its hit that turn; it can call again each time
     it is the last goblin (no once-per-fight limit). "Goblin" means any enemy with tag `goblin`.
  2. The summoned Pledge joins at the right end and acts from the next turn.
  3. Keg Slime splits once a hit leaves it above 0 and at or below half its max HP, checked after
     the card (or enemy action) that did it; a hit that kills it outright leaves nothing. The halves
     are fresh (no statuses, Ick or Guard carried over), take its position, and, if split in the
     player phase, pick intents at once and act that turn.
  4. Dorm Rats flee as their action in turn 4's enemy phase (intent shown at turn 4's start); a
     Grossed Out rat flees one turn later. A fight whose last enemies fled ends as "won". Haul is
     per player; a Passed Out Dude still gets theirs back.
  5. Stealing ignores Guard ("each bite steals").
  6. Faded caps every hit, attack or not, after rounding and before Guard. It is a status in
     `statuses` with 1 stack, switched at the start of each turn, never worn off.
  7. Noise Complaint fires once per turn, on the 5th card, after it resolves; not attack damage
     (G3); Guard absorbs it; one complaint per Kobold. Triggers still fire while the enemy waits to
     skip an action.
  8. Sewer Gator's Swole comes once per unblocked hit, added after the Death Roll effect, so the
     roll's own hits use the old Swole (3 unblocked hits: +6 for next time).
  9. Goblin Shot-Caller: on its every-other turn it replaces a dead Pledge if fewer than 2 are
     standing, otherwise gives Swole. Its escorts stand to its right. "All goblins" includes itself.
- Per-enemy numbers (steal 5, flee turn 4, half HP, Noise Complaint 5/5, every third card) are in
  the enemy data, not `constants.json`, like a move's damage. Only the status number
  `FADED_MAX_DAMAGE` is a constant.
- An enemy's Swole gain emits task 021's `stat_changed` (`stat` `"swole"`); the planned
  `swole_changed` was dropped at the merge. Task 013's Reply Guy reacts to it (`BUFF_EVENTS` and
  `BUFF_STATS` in `core/combat/powers.gd`).

## Log
- 2026-10-10 A: Claimed. All rule gaps answered (#20). Started in parallel with its in-progress dependencies at Person A's instruction; shared op names are pinned (`draw`, `gain_hype`, `self_damage` from 013; `add_card`, `lose_hype` from 015).

- 2026-10-10 A: blocked on G19; then G19 answered "accept" (#20).
- 2026-10-10 A: Done, except the two `add_card` checks pending on task 015 (above).
  Three commits: contract `FADED_MAX_DAMAGE`; contract schema (enemy definition fields, `haul`,
  `drops_brews`, `brews_dropped`, seven events, status `faded`, `SCHEMA_VERSION` 6 because 013 and 021
  take 4 and 5); implementation. Verified with `tools/test.sh`: all tests pass (exit 0). Three state
  hashes (`SAMPLE_HASH`, both `FINAL_HASH`es) were re-recorded for the new shape after their other
  assertions passed; they must be re-recorded again when merged with 013/015. Tests use fixture
  enemies until task 010's data merges. Not done: task 010's real data, the two pending checks.
- 2026-10-10 A (lead): Stacked on #45 (tasks 013, 015, 021) for the PR; contracts split into #46
  (constant) and #47 (schema, SCHEMA_VERSION 6). The two add_card tests are added and pass; Swole
  gains emit task 021's `stat_changed` and Reply Guy answers them. See
  `docs/changes/2026-10-10-017.md` "Merged with tasks 013, 015 and 021". Only "one test per enemy,
  using task 010's data" stays open (fixtures until task 010 merges).
- 2026-10-10 A: Merged with the whole stack in #50 (Agent B approved; 341 passed on `main`). Every
  rule gap it built on was accepted by steamjgrube in that review. Status `done`; open items, if any,
  are listed above (real data from Agent B's tasks).
