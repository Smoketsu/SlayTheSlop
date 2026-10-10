## Floor 1 enemies, Foam Slime and Goblin King Chad as data (task 010), plus a fixed-seed fight
## played entirely on the real data/ folder. Lane: tools (Agent B).
## GDD "Floor 1: The Basement", "Goblin King Chad"; G11–G13, G30, G35–G47 (all as built).
extends "res://tests/framework/test_case.gd"

const Check := preload("res://tests/data/content_check.gd")
const EnemyFixtures := preload("res://tests/core/enemies/enemy_fixtures.gd")
const Core := preload("res://core/core.gd")
const Party := preload("res://core/combat/party.gd")
const Fight := preload("res://core/combat/fight.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const RunState := preload("res://core/schema/run_state.gd")

## The run seed of the real-data fight.
const SEED: int = 20261010
## The enemies of the real-data fight, left to right.
const FOES: Array[String] = ["goblin_pledge", "goblin_bouncer"]
## Most requests the policy may send before the test gives up (a safety stop, not a rule).
const MAX_REQUESTS: int = 300
## Recorded outcome on Godot 4.7.2-stable with the data as merged in task 010: [result, final turn,
## applied requests, Tom's final HP]. If a data or rules change alters this fight on purpose,
## re-record it and say why in the PR.
const RECORDED: Array = ["won", 7, 27, 75]
## GDD floor 1 table: enemy id -> [tier, max HP, arms]. Foam Slime is the Keg Slime's split.
const GDD := {
	"goblin_pledge": ["normal", 12, 2], "goblin_bouncer": ["normal", 28, 2], "keg_slime": ["normal", 24, 0],
	"dorm_rat": ["normal", 8, 2], "skeleton_intern": ["normal", 18, 2], "boo_zer": ["normal", 16, 0],
	"mimic_cooler": ["normal", 30, 0], "kobold_ra": ["normal", 22, 2], "goblin_shot_caller": ["rival", 60, 2],
	"hall_monitor_golem": ["rival", 75, 2], "sewer_gator": ["rival", 68, 2], "foam_slime": ["normal", 10, 0],
	"goblin_king_chad": ["boss", 140, 2],
}


## Every enemy file has the GDD's tier, HP and arm count, and data/enemies holds exactly these.
func test_enemies_match_the_gdd_table() -> void:
	# ids: the GDD ids, sorted.
	var ids: Array = GDD.keys()
	ids.sort()
	assert_eq(Check.ids_in("data/enemies"), ids, "enemy files")
	for id: String in GDD:
		# enemy: the data file.
		var enemy: Dictionary = Check.load_file("data/enemies/%s.json" % id)
		assert_eq([enemy.get("tier"), enemy.get("max_hp"), enemy.get("arm_count")], GDD[id], id)


## Every enemy file is exactly the fixture the core's enemy tests play, plus a non-empty "text"
## holding the GDD's behavior text (the fixtures have none).
func test_enemies_match_the_core_fixtures() -> void:
	for id: String in EnemyFixtures.ENEMIES:
		# enemy: the data file; its display text is checked, then set aside for the comparison.
		var enemy: Dictionary = Check.load_file("data/enemies/%s.json" % id)
		assert_ne(enemy.get("text", ""), "", "%s has the GDD behavior text" % id)
		enemy.erase("text")
		assert_eq(enemy, Check.as_data(EnemyFixtures.ENEMIES[id]), id)


## Tom fights a Goblin Pledge and a Goblin Bouncer on the real data with a fixed policy. Every state
## passes run_state.check(), the fight ends as RECORDED, and a replay gives identical snapshot bytes.
func test_fixed_seed_fight_on_real_data() -> void:
	# first, second: two replays of the same fight.
	var first: Dictionary = _replay()
	var second: Dictionary = _replay()
	if first.is_empty() or second.is_empty():
		return
	assert_ne(first["state"]["combat"]["result"], "", "the fight is decided within %d requests" % MAX_REQUESTS)
	assert_eq(Snapshot.to_bytes(second["state"]), Snapshot.to_bytes(first["state"]), "a replay is identical")
	assert_eq(second["requests"], first["requests"], "same number of applied requests")
	# outcome: what this fight ended with.
	var outcome: Array = [first["state"]["combat"]["result"], first["state"]["combat"]["turn"], first["requests"], first["state"]["dudes"][0]["hp"]]
	assert_eq(outcome, RECORDED, "recorded outcome")


## Plays the fight. Returns {"state", "requests"}, or {} after recording a failure.
func _replay() -> Dictionary:
	# rules: the real ruleset.
	var rules: Dictionary = Check.real_ruleset()
	assert_false(rules.is_empty(), "data/ builds")
	if rules.is_empty():
		return {}
	# party: the run state with Tom in seat 1.
	var party: Dictionary = Party.build_run_state(rules, SEED, ["tom"])
	assert_eq(party["error"], "", "build_run_state")
	# started: the fight against FOES.
	var started: Dictionary = Fight.start_fight(rules, party["state"], FOES)
	assert_eq(started["error"], "", "start_fight")
	if started["error"] != "":
		return {}
	# state: the current state; applied: requests the core accepted.
	var state: Dictionary = started["state"]
	var applied: int = 0
	for i: int in MAX_REQUESTS:
		if state["combat"]["result"] != "":
			break
		# result: the core's answer to the policy's next request.
		var result: Dictionary = Core.apply(rules, state, _next_request(rules, state))
		assert_eq(result["reject"], "", "the policy only sends legal requests")
		if result["reject"] != "":
			return {}
		state = result["state"]
		applied += 1
		assert_no_errors(RunState.check(state), "state after request %d" % applied)
	return {"state": state, "requests": applied}


## Returns the policy's next request: the Bro Move at the first enemy when legal, else the first
## card in hand the core accepts (aimed at the first enemy, or no target), else Ready.
## rules: the ruleset. state: the state, in the player phase.
func _next_request(rules: Dictionary, state: Dictionary) -> Dictionary:
	# seq: the next seq. first: the leftmost enemy's uid.
	var seq: int = state["dudes"][0]["last_seq"] + 1
	var first: String = state["combat"]["enemies"][0]["uid"]
	# bro: the Bro Move request (Chest Bump needs a target, G33).
	var bro: Dictionary = {"type": "use_bro_move", "player_id": "p1", "seq": seq, "target_id": first}
	if Core.validate(rules, state, bro) == "":
		return bro
	for uid: String in state["dudes"][0]["hand"]:
		for target_id: String in [first, ""]:
			# play: one candidate.
			var play: Dictionary = {"type": "play_card", "player_id": "p1", "seq": seq, "card_uid": uid, "target_id": target_id, "crunch": false}
			if Core.validate(rules, state, play) == "":
				return play
	return {"type": "set_ready", "player_id": "p1", "seq": seq, "ready": true}
