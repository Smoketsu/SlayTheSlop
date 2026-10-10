## A scripted whole solo run of floor 1, from a seed to the boss reward, through Core.apply() only
## (task 025's last acceptance check). Lane: run (Agent A).
##
## Content: the slice fixtures (tests/run/fixtures/run_fixtures.gd) with Tom as the GDD gives him.
## Player: tests/run/fixtures/run_bot.gd, which follows the map path visiting the most node types (on
## this seed: every type) and answers each node with a fixed policy. Every step's events pass
## Event.check(), every state RunState.check() and a Snapshot round trip. The final state's hash is
## recorded; it was recorded only after every outcome assertion below passed.
##
## If a rules change alters this run on purpose, re-record FINAL_HASH (the failure message prints the
## new value) and say why in the PR. When the content lane's real data merges, the run should switch to
## it and be re-recorded.
extends "res://tests/framework/test_case.gd"

const RunFixtures := preload("res://tests/run/fixtures/run_fixtures.gd")
const Helpers := preload("res://tests/run/fixtures/run_helpers.gd")
const Bot := preload("res://tests/run/fixtures/run_bot.gd")
const Core := preload("res://core/core.gd")
const NewRun := preload("res://core/run/new_run.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const FloorMap := preload("res://core/run/map/floor_map.gd")

## The run's seed: its floor 1 map has a path through every node type, and the bot wins with it.
const SEED: int = 1

## Snapshot.state_hash() of the final state, recorded on Godot 4.7.2-stable after every other
## assertion in test_whole_run_reaches_the_boss_reward passed.
const FINAL_HASH: String = "221de4ce5d318a1d8fd3e1f83580ae70ba5728a1f7d879d9cc00bccc7e611e99"


## Plays the run. Returns Bot.play()'s result plus "rules" and "start" (NewRun.start()'s result).
func _played() -> Dictionary:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# start: the new run.
	var start: Dictionary = NewRun.start(rules, SEED, ["tom"])
	# played: the whole run.
	var played: Dictionary = Bot.play(rules, start["state"])
	played["rules"] = rules
	played["start"] = start
	return played


## The whole run: every node type visited, every request applied and following the contract, the boss
## beaten, a Boss Gear picked, the floor over; the final state is the recorded one.
func test_whole_run_reaches_the_boss_reward() -> void:
	# played: the run.
	var played: Dictionary = _played()
	assert_eq(played["start"]["error"], "")
	assert_eq(Helpers.contract_problems(played["start"]), [] as Array[String])
	assert_eq(played["problems"], [] as Array[String], "every request applied and followed the contract")
	# state: the final state.
	var state: Dictionary = played["state"]
	# map: the floor's map.
	var map: Dictionary = state["map"]
	# events: every event of the run.
	var events: Array = played["events"]
	assert_eq(state["run_phase"], "floor_end")
	assert_eq(state["path"], played["plan"], "the bot followed its plan")
	# types: node types visited.
	var types: Dictionary = {}
	for node_id: String in state["path"]:
		types[map["nodes"][FloorMap.index_of(map, node_id)]["type"]] = true
	# expected: every node type of a floor.
	var expected: Array = ["baileys", "boss", "brawl", "loot", "rival", "side_quest", "tailgate"]
	# visited: the visited types, sorted.
	var visited: Array = types.keys()
	visited.sort()
	assert_eq(visited, expected, "every node type")
	assert_eq(map["nodes"][state["node_index"]]["type"], "boss")
	assert_eq(state["state_version"], played["requests"].size(), "one version per applied request")
	assert_eq(Helpers.of_type(events, "node_entered").size(), state["path"].size())
	assert_eq(Helpers.of_type(events, "floor_ended"), [{"type": "floor_ended", "floor": 1}])
	assert_eq(Helpers.of_type(events, "run_ended"), [], "the run was not lost")
	# kinds: offer kinds opened.
	var kinds: Dictionary = {}
	for event: Dictionary in Helpers.of_type(events, "offer_opened"):
		kinds[event["kind"]] = true
	for kind: String in ["card", "tailgate", "baileys", "side_quest", "boss_gear"]:
		assert_true(kinds.has(kind), "an offer of kind %s" % kind)
	# side_quest_ids: the reward ids of the Side Quest offers.
	var side_quest_ids: Array = Helpers.of_type(events, "offer_opened").filter(
		func(e: Dictionary) -> bool: return e["kind"] == "side_quest").map(func(e: Dictionary) -> String: return e["reward_id"])
	# dumb_picks: Side Quest offers closed with the dumb option.
	var dumb_picks: Array = Helpers.of_type(events, "offer_closed").filter(
		func(e: Dictionary) -> bool: return side_quest_ids.has(e["reward_id"]) and e["choice_index"] == 1)
	assert_eq(state["dumb_options_taken"], dumb_picks.size(), "every dumb pick counted")
	assert_true(state["dumb_options_taken"] >= 1, "the bot took a dumb option")
	# tom: Tom at the end.
	var tom: Dictionary = state["dudes"][0]
	assert_eq(tom["offers"], [])
	assert_eq(tom["hp"], tom["max_hp"], "the boss's full heal")
	assert_eq(played["rules"]["gear"][tom["gear"].back()]["owner"], "boss", "a Boss Gear picked last")
	assert_true(tom["deck"].size() > 10, "cards taken along the way")
	assert_eq(state["combat"], null)
	assert_eq(state["encounter_id"], "")
	assert_eq(Helpers.of_type(events, "fight_ended").filter(func(e: Dictionary) -> bool: return e["result"] == "won").size(),
		Helpers.of_type(events, "fight_started").size(), "every fight won")
	# final_hash: the final state's hash.
	var final_hash: String = Snapshot.state_hash(state)
	assert_eq(final_hash, FINAL_HASH, "final state hash (re-record only for an intended rules change)")


## The same seed and requests give the same states: replaying the recorded requests from a new run
## reaches the identical final state.
func test_replay_is_identical() -> void:
	# played: the run.
	var played: Dictionary = _played()
	# state: a fresh new run.
	var state: Dictionary = NewRun.start(played["rules"], SEED, ["tom"])["state"]
	for sent: Dictionary in played["requests"]:
		state = Core.apply(played["rules"], state, sent)["state"]
	assert_eq(Snapshot.state_hash(state), Snapshot.state_hash(played["state"]))
	assert_eq(state, played["state"])


## Save and load mid-run (GDD "Saving"): at a node choice, mid-fight and on the map, the state goes to
## bytes and back identical, and the rest of the run played from the loaded state ends identical.
func test_save_and_load_mid_run() -> void:
	# played: the run.
	var played: Dictionary = _played()
	# rules: its ruleset.
	var rules: Dictionary = played["rules"]
	# requests: the recorded requests.
	var requests: Array = played["requests"]
	# states: the state after each request, index i after requests[0..i].
	var states: Array = []
	# replayed: the run as it is replayed.
	var replayed: Dictionary = NewRun.start(rules, SEED, ["tom"])["state"]
	for sent: Dictionary in requests:
		replayed = Core.apply(rules, replayed, sent)["state"]
		states.append(replayed)
	# cuts: request counts after which to save: the first time the party is back on the map, the first
	# open choice on a node, and the first point past halfway in a fight.
	var cuts: Array = []
	# wanted: the three kinds of point, in the order above.
	var wanted: Array = ["map", "choice", "fight"]
	for kind: String in wanted:
		for i: int in states.size():
			# state: the state after i + 1 requests.
			var state: Dictionary = states[i]
			# point: what kind of point it is.
			var point: String = "map" if state["run_phase"] == "map" else ("fight" if state["combat"] != null else "choice")
			if point == kind and (kind != "fight" or i >= states.size() / 2):
				cuts.append(i + 1)
				break
	assert_eq(cuts.size(), 3, "a save point of each kind: %s" % str(cuts))
	for cut: int in cuts:
		# state: the run after cut requests.
		var state: Dictionary = states[cut - 1]
		# loaded: the save, loaded back.
		var loaded: Dictionary = Snapshot.from_bytes(Snapshot.to_bytes(state))
		assert_true(loaded["ok"], loaded["error"])
		assert_eq(loaded["state"], state, "identical after load at %d" % cut)
		# resumed: the rest of the run from the loaded state.
		var resumed: Dictionary = loaded["state"]
		for i: int in range(cut, requests.size()):
			# result: one request.
			var result: Dictionary = Core.apply(rules, resumed, requests[i])
			assert_eq(result["reject"], "", "request %d after loading" % i)
			resumed = result["state"]
		assert_eq(Snapshot.state_hash(resumed), Snapshot.state_hash(played["state"]), "same end after loading at %d" % cut)
