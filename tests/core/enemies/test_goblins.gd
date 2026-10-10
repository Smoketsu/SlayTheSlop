## Floor 1 goblins (task 017): Goblin Pledge's call for help, Goblin Bouncer's alternation and
## Checks ID, Goblin Shot-Caller's escort, Swole and replacements. Lane: core (Agent A).
## Enemies are the fixtures in tests/core/enemies/enemy_fixtures.gd (task 010's data has not merged).
extends "res://tests/core/enemies/enemy_test_case.gd"

## Fixed seed for every fight in this file.
const SEED: int = 17017


## Goblin Pledge: while another goblin stands it hits for 5. Kill its partner and, at the next
## intents, the last goblin standing calls one more Pledge (intent with no targets), which joins at
## the right end in the enemy phase (enemy_spawned) with full HP, and next turn both hit again.
func test_last_pledge_calls_one_more() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: two Pledges.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["goblin_pledge", "goblin_pledge"])
	assert_eq(state["combat"]["enemies"].map(func(e: Dictionary) -> String: return e["intent"]["move_id"]), ["hit", "hit"])
	# first: the left Pledge's uid.
	var first: String = state["combat"]["enemies"][0]["uid"]
	# second: the right Pledge's uid.
	var second: String = state["combat"]["enemies"][1]["uid"]
	# result: the fight as it goes.
	var result: Dictionary = play(rules, state, 0, "neutral_test_poke", first)
	result = play(rules, result["state"], 1, "neutral_test_poke", first)
	result = play(rules, result["state"], 2, "neutral_test_poke", first)
	assert_eq(of_type(result["events"], "enemy_died"), [Event.make("enemy_died", {"enemy_uid": first})])
	assert_eq(result["state"]["combat"]["enemies"][0]["intent"], {"move_id": "hit", "target_ids": ["p1"]},
		"this turn's intent stays as shown")
	result = ready(rules, result["state"], 3)
	assert_eq(result["state"]["dudes"][0]["hp"], 25, "the survivor still hit for 5")
	assert_eq(enemy_by_uid(result["state"], second)["intent"], {"move_id": "call_for_help", "target_ids": []},
		"the last goblin standing calls for help")
	result = ready(rules, result["state"], 4)
	# spawned: the enemy_spawned events of turn 2's enemy phase.
	var spawned: Array = of_type(result["events"], "enemy_spawned")
	assert_eq(spawned.size(), 1, "exactly one more Pledge")
	assert_eq(spawned[0]["def_id"], "goblin_pledge")
	assert_eq(spawned[0]["index"], 1, "joins at the right end")
	assert_eq(result["state"]["dudes"][0]["hp"], 25, "calling is its action: no hit")
	assert_eq(lineup(result["state"]), ["goblin_pledge", "goblin_pledge"])
	# newcomer: the new Pledge.
	var newcomer: Dictionary = enemy_by_uid(result["state"], spawned[0]["enemy_uid"])
	assert_eq([newcomer["hp"], newcomer["max_hp"], newcomer["arm_count"], newcomer["ick_threshold"]], [12, 12, 2, 5])
	assert_eq(newcomer["intent"], {"move_id": "hit", "target_ids": ["p1"]}, "two goblins: both hit again")
	assert_eq(enemy_by_uid(result["state"], second)["intent"]["move_id"], "hit")


## "Last goblin standing" counts every goblin (tag "goblin"), not only Pledges, and only goblins:
## a Pledge next to a Goblin Bouncer never calls; a Pledge next to a Keg Slime calls at once.
func test_last_goblin_counts_goblins_only() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# with_bouncer: a Pledge and a Bouncer.
	var with_bouncer: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["goblin_pledge", "goblin_bouncer"])
	assert_eq(with_bouncer["combat"]["enemies"][0]["intent"]["move_id"], "hit")
	# with_slime: a Pledge and a Keg Slime.
	var with_slime: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["goblin_pledge", "keg_slime"])
	assert_eq(with_slime["combat"]["enemies"][0]["intent"]["move_id"], "call_for_help")
	# alone: a single Pledge calls from turn 1.
	var alone: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["goblin_pledge"])
	assert_eq(alone["combat"]["enemies"][0]["intent"], {"move_id": "call_for_help", "target_ids": []})


## Goblin Bouncer: 8 Guard, then the 9-damage Checks ID that applies 1 Noodle Arms, alternating.
func test_bouncer_alternates_and_checks_id() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: one Bouncer.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["goblin_bouncer"])
	# uid: the Bouncer's uid.
	var uid: String = state["combat"]["enemies"][0]["uid"]
	assert_eq(state["combat"]["enemies"][0]["intent"], {"move_id": "bounce", "target_ids": []})
	# result: the fight as it goes.
	var result: Dictionary = ready(rules, state, 0)
	assert_eq(result["state"]["combat"]["enemies"][0]["guard"], 8, "8 Guard")
	assert_eq(result["state"]["combat"]["enemies"][0]["intent"], {"move_id": "checks_id", "target_ids": ["p1"]})
	result = ready(rules, result["state"], 1)
	# acted: the events from Checks ID on.
	var acted: Array = result["events"].slice(result["events"].find(Event.make("enemy_acted", {"enemy_uid": uid, "move_id": "checks_id"})))
	assert_eq(acted.slice(0, 3), [
		Event.make("enemy_acted", {"enemy_uid": uid, "move_id": "checks_id"}),
		Event.make("damage_dealt", {"source_id": uid, "target_id": "p1", "amount": 9, "blocked": 0, "hp_lost": 9}),
		Event.make("status_changed", {"target_id": "p1", "status": "noodle_arms", "delta": 1, "stacks": 1}),
	])
	assert_eq(result["state"]["dudes"][0]["statuses"], {"noodle_arms": 1}, "1 Noodle Arms")
	result = ready(rules, result["state"], 2)
	result = ready(rules, result["state"], 3)
	assert_eq(result["state"]["combat"]["enemies"][0]["move_history"], ["bounce", "checks_id", "bounce", "checks_id", "bounce"])


## Goblin Shot-Caller: arrives with 2 Pledges (part of fight_started, to its right). On turn 2,
## with both Pledges standing, every goblin gains 2 Swole and the Pledges hit for 7. Kill a Pledge
## and on turn 4 it replaces it instead. Between those turns it uses its ordinary move. The Pledges
## never call for help while it stands.
func test_shot_caller_escort_swole_and_replacement() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# started: the fight's start, with its events.
	var started: Dictionary = Fight.start_fight(rules,
		Party.build_run_state(rules, SEED, ["test_dude"])["state"], ["goblin_shot_caller"])
	assert_eq(started["error"], "")
	assert_valid(started["state"], started["events"])
	# state: the fight, with a sturdier Dude.
	var state: Dictionary = started["state"]
	state["dudes"][0]["hp"] = 500
	state["dudes"][0]["max_hp"] = 500
	assert_eq(lineup(state), ["goblin_shot_caller", "goblin_pledge", "goblin_pledge"], "arrives with 2 Pledges")
	# uids: the three enemies' uids, left to right.
	var uids: Array = state["combat"]["enemies"].map(func(e: Dictionary) -> String: return e["uid"])
	assert_eq(started["events"][0], Event.make("fight_started", {"enemy_uids": uids}))
	assert_eq(of_type(started["events"], "enemy_spawned"), [], "escorts are not spawned")
	assert_eq(state["combat"]["enemies"][0]["ick_threshold"], 8, "Rival Ick threshold")
	assert_eq(state["combat"]["enemies"][0]["intent"]["move_id"], "whip")
	# result: the fight as it goes.
	var result: Dictionary = ready(rules, state, 0)
	assert_eq(result["state"]["combat"]["enemies"][0]["intent"], {"move_id": "pregame", "target_ids": []}, "turn 2")
	result = ready(rules, result["state"], 1)
	assert_eq(of_type(result["events"], "stat_changed"), [
		Event.make("stat_changed", {"target_id": uids[0], "stat": "swole", "delta": 2, "value": 2}),
		Event.make("stat_changed", {"target_id": uids[1], "stat": "swole", "delta": 2, "value": 2}),
		Event.make("stat_changed", {"target_id": uids[2], "stat": "swole", "delta": 2, "value": 2}),
	], "all goblins gain 2 Swole")
	# pledge_hits: the Pledges' hits on turn 2, after the Swole.
	var pledge_hits: Array = of_type(result["events"], "damage_dealt").map(func(e: Dictionary) -> int: return e["amount"])
	assert_eq(pledge_hits, [7, 7], "5 + 2 Swole")
	assert_eq(result["state"]["combat"]["enemies"][0]["intent"]["move_id"], "whip", "turn 3: its ordinary move")
	# Turn 3: kill the second Pledge (12 HP) with three Pokes.
	for seq: int in [2, 3, 4]:
		result = play(rules, result["state"], seq, "neutral_test_poke", uids[2])
	assert_eq(lineup(result["state"]), ["goblin_shot_caller", "goblin_pledge"])
	result = ready(rules, result["state"], 5)
	assert_eq(result["state"]["combat"]["enemies"][0]["intent"], {"move_id": "next_pledge", "target_ids": []},
		"turn 4: a Pledge is missing, so it replaces it")
	assert_eq(result["state"]["combat"]["enemies"][1]["intent"]["move_id"], "hit", "no call while the Shot-Caller stands")
	result = ready(rules, result["state"], 6)
	assert_eq(of_type(result["events"], "enemy_spawned").size(), 1, "one replacement")
	assert_eq(lineup(result["state"]), ["goblin_shot_caller", "goblin_pledge", "goblin_pledge"])
	assert_eq(result["state"]["combat"]["enemies"][2]["swole"], 0, "the replacement has no Swole yet")
	assert_eq(result["state"]["combat"]["enemies"][0]["move_history"], ["whip", "pregame", "whip", "next_pledge", "whip"])
