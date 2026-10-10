## Goblin King Chad, the slice boss (task 019): starting Pledges (G13), Keg Stand's charge, cut and
## fall, Rage Cage below 50% HP, Rush every third turn, Paddle Swat otherwise (G12), the boss Ick
## threshold, Broken Arm on the Keg Stand, and a fixed-seed scripted fight. Lane: core (Agent A).
## Chad is the fixture in tests/core/enemies/enemy_fixtures.gd (task 010's data has not merged).
extends "res://tests/core/enemies/enemy_test_case.gd"

## Fixed seed for every fight in this file.
const SEED: int = 19019

## First turn of the scripted fight on which Haymakers may go at Chad himself (before it, only at a
## Keg Stand helper), so the fight lasts long enough to show Rush. Script choice, not balance.
const HAYMAKER_FREE_TURN: int = 7

## Seed of the scripted full fight.
const SCRIPT_SEED: int = 20261019

## Chad's intents in the scripted fight, turn by turn, recorded on Godot 4.7.2-stable.
const SCRIPT_CHAD_MOVES: Array = ["keg_stand", "keg_stand", "keg_stand_chug", "paddle_swat", "paddle_swat", "rush",
	"keg_stand", "paddle_swat", "rage_cage", "rage_cage", "rage_cage"]

## Snapshot.state_hash of the scripted fight's final state, recorded on Godot 4.7.2-stable after
## the outcome assertions passed. Re-record only for an intended rules change. Re-recorded by the
## lead when stacked on tasks 013, 015 and 021 (their state fields and the solo Bro Meter change the
## bytes); the result, move sequence and hits asserted above were unchanged.
const SCRIPT_HASH: String = "49845798a92a24fe925a600ee0671d1755f047d2f7c4aa499d67ca52a997cfba"


## Returns a solo fight against Chad (and his 2 Pledges) with a sturdy Dude.
## rules: the enemy test ruleset.
func _chad_fight(rules: Dictionary) -> Dictionary:
	return EnemyFixtures.solo_fight(rules, SEED, ["goblin_king_chad"], 500)


## Returns the intent move id of the enemy with this uid.
## state: a run state in a fight. uid: the enemy's uid.
func _move(state: Dictionary, uid: String) -> String:
	return enemy_by_uid(state, uid)["intent"]["move_id"]


## The fight starts with Chad and 2 Pledges to his right (G13). He has 140 HP, 2 arms and the boss
## Ick threshold ICK_BASE_BOSS, and on turn 1, with 2 Pledges, starts his Keg Stand: intent with no
## targets, charge_started naming both Pledges.
func test_start_and_keg_stand_begins() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# started: the fight's start, with its events.
	var started: Dictionary = Fight.start_fight(rules, Party.build_run_state(rules, SEED, ["test_dude"])["state"], ["goblin_king_chad"])
	assert_eq(started["error"], "")
	assert_valid(started["state"], started["events"])
	# state: the fight.
	var state: Dictionary = started["state"]
	assert_eq(lineup(state), ["goblin_king_chad", "goblin_pledge", "goblin_pledge"])
	# chad: Chad's state.
	var chad: Dictionary = state["combat"]["enemies"][0]
	# pledges: the Pledges' uids.
	var pledges: Array = [state["combat"]["enemies"][1]["uid"], state["combat"]["enemies"][2]["uid"]]
	assert_eq([chad["hp"], chad["max_hp"], chad["arm_count"]], [140, 140, 2])
	assert_eq(chad["ick_threshold"], rules["constants"]["ICK_BASE_BOSS"], "boss Ick threshold")
	assert_eq(chad["intent"], {"move_id": "keg_stand", "target_ids": []})
	assert_eq(chad["charge"], {"turns_charged": 1, "helper_uids": pledges, "fall_exposed": 2})
	# at: where Chad's intent_set is.
	var at: int = started["events"].find(Event.make("intent_set", {"enemy_uid": chad["uid"], "move_id": "keg_stand", "target_ids": []}))
	assert_eq(started["events"][at + 1], Event.make("charge_started", {"enemy_uid": chad["uid"], "helper_uids": pledges}))
	assert_eq(state["combat"]["enemies"][1]["intent"]["move_id"], "hit", "Pledges never call while Chad stands")


## Keg Stand with no Pledge killed: charging on turns 1 and 2, the 30-damage hit on turn 3 aimed at
## the Dude, then the charge is over; with 2 Pledges still up he starts another on turn 4.
func test_keg_stand_full_hit() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: the fight.
	var state: Dictionary = _chad_fight(rules)
	# chad: Chad's uid.
	var chad: String = state["combat"]["enemies"][0]["uid"]
	# result: the fight as it goes.
	var result: Dictionary = ready(rules, state, 0)
	assert_eq(_move(result["state"], chad), "keg_stand", "turn 2: still charging")
	assert_eq(enemy_by_uid(result["state"], chad)["charge"]["turns_charged"], 2)
	assert_eq(result["state"]["dudes"][0]["hp"], 490, "turn 1: only the Pledges hit")
	result = ready(rules, result["state"], 1)
	assert_eq(enemy_by_uid(result["state"], chad)["intent"], {"move_id": "keg_stand_chug", "target_ids": ["p1"]}, "turn 3: the hit")
	result = ready(rules, result["state"], 2)
	assert_eq(of_type(result["events"], "damage_dealt").filter(func(e: Dictionary) -> bool: return e["source_id"] == chad),
		[Event.make("damage_dealt", {"source_id": chad, "target_id": "p1", "amount": 30, "blocked": 0, "hp_lost": 30})])
	assert_eq(of_type(result["events"], "charge_started").size(), 1, "turn 4: a new Keg Stand")
	assert_eq(_move(result["state"], chad), "keg_stand")
	assert_eq(enemy_by_uid(result["state"], chad)["charge"]["turns_charged"], 1)


## Each Pledge killed during the charge removes 10, and Broken Arm reduces the rest (2 arms, 1
## broken: x 0.8): (30 - 10) x 0.8 = 16.
func test_keg_stand_cut_and_broken_arm() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: the fight.
	var state: Dictionary = _chad_fight(rules)
	# chad / pledge: Chad's uid and the first Pledge's.
	var chad: String = state["combat"]["enemies"][0]["uid"]
	# pledge: the first Pledge's uid.
	var pledge: String = state["combat"]["enemies"][1]["uid"]
	# result: the fight as it goes.
	var result: Dictionary = {"state": state}
	for seq: int in 3:
		result = play(rules, result["state"], seq, "neutral_test_poke", pledge)
	result = play(rules, result["state"], 3, "neutral_test_arm_bar", chad)
	assert_eq(enemy_by_uid(result["state"], chad)["broken_arms"], 1)
	assert_eq(of_type(result["events"], "enemy_fell"), [], "one helper left: no fall")
	result = ready(rules, result["state"], 4)
	result = ready(rules, result["state"], 5)
	assert_eq(_move(result["state"], chad), "keg_stand_chug")
	result = ready(rules, result["state"], 6)
	assert_eq(of_type(result["events"], "damage_dealt").filter(func(e: Dictionary) -> bool: return e["source_id"] == chad)
		.map(func(e: Dictionary) -> int: return e["amount"]), [16])
	assert_eq(_move(result["state"], chad), "paddle_swat", "turn 4: one Pledge, so no new Keg Stand")


## Kill both Pledges during the charge and he falls at once: the charge ends, Exposed 2, and he
## skips his next action (reason "fallen"). Then Paddle Swat on turn 2, Rush on turn 3 (2 new
## Pledges), and with 2 Pledges a new Keg Stand on turn 4.
func test_kill_both_and_he_falls() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: the fight.
	var state: Dictionary = _chad_fight(rules)
	# chad: Chad's uid.
	var chad: String = state["combat"]["enemies"][0]["uid"]
	# pledges: the Pledges' uids.
	var pledges: Array = [state["combat"]["enemies"][1]["uid"], state["combat"]["enemies"][2]["uid"]]
	# result: the fight as it goes.
	var result: Dictionary = {"state": state}
	for seq: int in 6:
		result = play(rules, result["state"], seq, "neutral_test_poke", pledges[seq / 3])
	assert_eq(result["events"].slice(result["events"].find(Event.make("enemy_died", {"enemy_uid": pledges[1]}))).slice(0, 4), [
		Event.make("enemy_died", {"enemy_uid": pledges[1]}),
		Event.make("enemy_fell", {"enemy_uid": chad}),
		Event.make("status_changed", {"target_id": chad, "status": "exposed", "delta": 2, "stacks": 2}),
		Event.make("card_moved", {"player_id": "p1", "card_uid": result["events"][0]["card_uid"], "from": "hand", "to": "discard_pile"}),
	])
	# fallen: Chad after the fall.
	var fallen: Dictionary = enemy_by_uid(result["state"], chad)
	assert_eq([fallen["charge"], fallen["fallen_skips"], fallen["statuses"]], [null, 1, {"exposed": 2}])
	result = play(rules, result["state"], 6, "neutral_test_poke", chad)
	assert_eq(of_type(result["events"], "damage_dealt")[0]["amount"], 7, "Exposed: 5 x 1.5, rounded down")
	result = ready(rules, result["state"], 7)
	assert_true(result["events"].has(Event.make("enemy_skipped", {"enemy_uid": chad, "reason": "fallen"})), "he skips a turn")
	assert_eq(of_type(result["events"], "enemy_acted"), [])
	assert_eq(enemy_by_uid(result["state"], chad)["statuses"], {"exposed": 1}, "Exposed wears off 1 per turn")
	assert_eq(enemy_by_uid(result["state"], chad)["fallen_skips"], 0)
	assert_eq(enemy_by_uid(result["state"], chad)["intent"], {"move_id": "paddle_swat", "target_ids": ["p1"]}, "turn 2")
	result = ready(rules, result["state"], 8)
	assert_eq(result["state"]["dudes"][0]["hp"], 488, "Paddle Swat for 12")
	assert_eq(_move(result["state"], chad), "rush", "turn 3: Rush")
	result = ready(rules, result["state"], 9)
	assert_eq(of_type(result["events"], "enemy_spawned").map(func(e: Dictionary) -> String: return e["def_id"]),
		["goblin_pledge", "goblin_pledge"], "Rush summons 2 Pledges")
	assert_eq(_move(result["state"], chad), "keg_stand", "turn 4: 2 Pledges again, so Keg Stand")
	assert_eq(of_type(result["events"], "charge_started").size(), 1)


## Below 50% HP he uses Rage Cage (6 damage 3 times) every turn he is not charging, Rush turns
## included; while charging he keeps charging.
func test_rage_cage_below_half() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: the fight.
	var state: Dictionary = _chad_fight(rules)
	# chad: Chad's uid.
	var chad: String = state["combat"]["enemies"][0]["uid"]
	# charging: a copy where he is at 60 HP while charging.
	var charging: Dictionary = state.duplicate(true)
	charging["combat"]["enemies"][0]["hp"] = 60
	assert_eq(_move(ready(rules, charging, 0)["state"], chad), "keg_stand", "charging beats Rage Cage")
	# pledges: the Pledges' uids.
	var pledges: Array = [state["combat"]["enemies"][1]["uid"], state["combat"]["enemies"][2]["uid"]]
	# result: the fight as it goes.
	var result: Dictionary = {"state": state}
	for seq: int in 6:
		result = play(rules, result["state"], seq, "neutral_test_poke", pledges[seq / 3])
	result["state"]["combat"]["enemies"][0]["hp"] = 70
	result = ready(rules, result["state"], 6)
	assert_eq(_move(result["state"], chad), "paddle_swat", "70 of 140 is not below half")
	result["state"]["combat"]["enemies"][0]["hp"] = 69
	result = ready(rules, result["state"], 7)
	assert_eq(enemy_by_uid(result["state"], chad)["intent"], {"move_id": "rage_cage", "target_ids": ["p1"]}, "turn 3: Rage Cage, not Rush")
	result = ready(rules, result["state"], 8)
	assert_eq(of_type(result["events"], "damage_dealt").map(func(e: Dictionary) -> int: return e["amount"]), [6, 6, 6])
	assert_eq(_move(result["state"], chad), "rage_cage", "every turn")


## Fixed seed: a full scripted fight. Each turn the Slayer plays its cards by a fixed rule, then
## presses Ready, until the fight ends. Before HAYMAKER_FREE_TURN: only Braces while Chad lifts;
## Haymakers only at a Keg Stand helper on the turn his Keg Stand hit is coming; Arm Bars and Jabs at
## Chad; Braces last. From HAYMAKER_FREE_TURN on: Haymakers at a living helper whenever he charges,
## otherwise at him. Chad must die, his move sequence must match the recording and include every
## behavior (Keg Stand hit with a cut, a fall, Rush, Rage Cage, Paddle Swat), and the final state
## must have the recorded hash (recorded after these assertions passed); a replay is identical.
func test_scripted_fight() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# first: the fight.
	var first: Dictionary = _scripted(rules)
	# second: its replay.
	var second: Dictionary = _scripted(rules)
	assert_eq(first["state"]["combat"]["result"], "won", "Chad goes down")
	assert_eq(first["chad_moves"], SCRIPT_CHAD_MOVES, "recorded move sequence")
	assert_eq(of_type(first["events"], "charge_started").size(), 2, "two Keg Stands")
	assert_eq(of_type(first["events"], "enemy_fell").size(), 1, "the second one ends in a fall")
	assert_eq(of_type(first["events"], "enemy_spawned").size(), 2, "one Rush")
	# chad_hits: the damage of every hit Chad dealt, in order (Broken Arm shows in them).
	var chad_hits: Array = []
	for event: Dictionary in of_type(first["events"], "damage_dealt"):
		if event["source_id"] == first["chad"]:
			chad_hits.append(event["amount"])
	assert_eq(chad_hits, [16, 9, 7, 3, 3, 3, 3, 3, 3], "Keg Stand (30 - 10) x 0.8, Swats 12 x 0.8 and x 0.6, Rage Cages 6 x 0.6")
	assert_true(first["events"].has(Event.make("enemy_skipped", {"enemy_uid": first["chad"], "reason": "fallen"})))
	for move: String in ["keg_stand", "keg_stand_chug", "rush", "rage_cage"]:
		assert_true(first["chad_moves"].has(move), "uses %s" % move)
	assert_eq(Snapshot.state_hash(first["state"]), SCRIPT_HASH, "final state hash")
	assert_eq(Snapshot.to_bytes(second["state"]), Snapshot.to_bytes(first["state"]), "identical replay")
	assert_eq(second["events"], first["events"])


## Plays the scripted fight described in test_scripted_fight and returns {"state": final state,
## "events": every event, "chad_moves": Chad's intents in order, "chad": his uid}.
## rules: the enemy test ruleset.
func _scripted(rules: Dictionary) -> Dictionary:
	# started: the fight's start.
	var started: Dictionary = Fight.start_fight(rules, Party.build_run_state(rules, SCRIPT_SEED, ["test_chad_slayer"])["state"],
		["goblin_king_chad"])
	# state: the fight as it goes.
	var state: Dictionary = started["state"]
	# events: every event.
	var events: Array = started["events"].duplicate()
	# chad: Chad's uid.
	var chad: String = state["combat"]["enemies"][0]["uid"]
	# seq: the next request's seq.
	var seq: int = 0
	while state["combat"]["phase"] != "over" and state["combat"]["turn"] <= 40:
		# request: the next request by the script.
		var request: Dictionary = _next_request(rules, state, chad, seq)
		# result: what it did.
		var result: Dictionary = ok(rules, state, request)
		state = result["state"]
		events.append_array(result["events"])
		seq += 1
	# chad_moves: Chad's intents, in order.
	var chad_moves: Array = of_type(events, "intent_set").filter(func(e: Dictionary) -> bool: return e["enemy_uid"] == chad) \
		.map(func(e: Dictionary) -> String: return e["move_id"])
	return {"state": state, "events": events, "chad_moves": chad_moves, "chad": chad}


## The script's choice for the next request: the first playable card by the rule in
## test_scripted_fight, or Ready when none is left.
## rules: the ruleset. state: the fight, in the player phase. chad: Chad's uid. seq: the seq to use.
func _next_request(rules: Dictionary, state: Dictionary, chad: String, seq: int) -> Dictionary:
	# dude: the Slayer.
	var dude: Dictionary = state["dudes"][0]
	# boss: Chad's state, or {} if he is dead.
	var boss: Dictionary = enemy_by_uid(state, chad)
	# helper: a living helper of his charge once his Keg Stand hit is coming, or "".
	var helper: String = ""
	# late: from HAYMAKER_FREE_TURN on, the script plays all out.
	var late: bool = state["combat"]["turn"] >= HAYMAKER_FREE_TURN
	if not boss.is_empty() and boss["charge"] != null and (late or boss["intent"]["move_id"] == "keg_stand_chug"):
		for uid: String in boss["charge"]["helper_uids"]:
			if helper == "" and not enemy_by_uid(state, uid).is_empty():
				helper = uid
	# main_target: who attacks go at: Chad, or the first enemy when he is gone.
	var main_target: String = chad if not boss.is_empty() else state["combat"]["enemies"][0]["uid"]
	# order: the card ids in the order the script tries them; only Braces while Chad lifts.
	var order: Array = ["neutral_test_haymaker", "neutral_test_arm_bar", "neutral_test_jab", "neutral_test_brace"]
	if not late and not boss.is_empty() and boss["intent"]["move_id"] == "keg_stand":
		order = ["neutral_test_brace"]
	for def_id: String in order:
		for uid: String in dude["hand"]:
			if dude["cards"][uid]["def_id"] != def_id:
				continue
			# target: this card's target.
			var target: String = ""
			if def_id == "neutral_test_haymaker":
				if helper == "" and not boss.is_empty() and not late:
					continue
				target = helper if helper != "" else main_target
			elif def_id != "neutral_test_brace":
				target = main_target
			# request: playing it.
			var request: Dictionary = Fixtures.play("p1", seq, uid, target)
			if Core.validate(rules, state, request) == "":
				return request
	return Fixtures.set_ready("p1", seq)
