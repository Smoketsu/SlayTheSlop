## Tests for enemy targeting (core/ai/targeting.gd, task 011): one Dude, MULTI_TARGET_COUNT Dudes at
## MULTI_TARGET_PARTY_SIZE players, area attacks, never a Passed Out Dude. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Targeting := preload("res://core/ai/targeting.gd")
const Rng := preload("res://core/rng/rng.gd")
const AiFixtures := preload("res://tests/core/ai/ai_fixtures.gd")

## How many seeds each party-size check runs over.
const SEEDS: int = 300

## Targets of ai_duo's "poke" for a party of 3 on seeds 1..6, recorded.
const RECORDED_PARTY_OF_3: Array = [["p2", "p3"], ["p1", "p3"], ["p1", "p3"], ["p1", "p2"], ["p1", "p3"], ["p1", "p3"]]


## Returns the "poke" move of ai_duo (a damage move with no "target" field: a single-target attack).
## rules: the AI test ruleset.
func _poke(rules: Dictionary) -> Dictionary:
	return rules["enemies"]["ai_duo"]["moves"][0]


## A move's aim: its "target" field, else "dude" for a move that needs a target, else "none".
func test_aim_of() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	assert_eq(Targeting.aim_of(_poke(rules)), "dude", "damage with no target field")
	assert_eq(Targeting.aim_of(rules["enemies"]["ai_duo"]["moves"][1]), "none", "guard with no target field")
	assert_eq(Targeting.aim_of(rules["enemies"]["ai_area"]["moves"][0]), "all_dudes")
	assert_eq(Targeting.aim_of(rules["enemies"]["ai_quiet"]["moves"][0]), "none", "explicit none on a damage move")
	assert_eq(Targeting.aim_of(rules["enemies"]["ai_bouncer"]["moves"][1]), "dude")


## A single-target attack hits 1 Dude below MULTI_TARGET_PARTY_SIZE players and MULTI_TARGET_COUNT
## from there on (GDD: 1, 1, 2, 2); 1 if the constants are missing.
func test_single_target_count() -> void:
	# constants: the real tuning constants.
	var constants: Dictionary = AiFixtures.ruleset()["constants"]
	# counts: the count for party sizes 1..4.
	var counts: Array = [1, 2, 3, 4].map(func(size: int) -> int: return Targeting.single_target_count(constants, size))
	assert_eq(counts, [1, 1, 2, 2], "GDD 'Difficulty scaling'")
	assert_eq(Targeting.single_target_count({}, 4), 1, "missing constants")


## For every party size, a single-target attack picks the right number of different, standing Dudes
## in seat order; across seeds every Dude is picked sometimes. Solo makes no draw; a real choice
## makes one draw per target, on combat_ai only.
func test_targets_by_party_size() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# expected_counts: targets per party size 1..4.
	var expected_counts: Array = [1, 1, 2, 2]
	for size: int in [1, 2, 3, 4]:
		# seen: player ids picked at least once at this size.
		var seen: Dictionary = {}
		for run_seed: int in SEEDS:
			# state: a fresh AI state.
			var state: Dictionary = AiFixtures.ai_state(run_seed, size)
			# before: its streams.
			var before: Dictionary = state["rng"].duplicate()
			# targets: the pick.
			var targets: Array = Targeting.choose_in_place(rules["constants"], state, _poke(rules))
			assert_eq(targets.size(), expected_counts[size - 1], "party of %d" % size)
			# sorted: the targets in seat order.
			var sorted: Array = targets.duplicate()
			sorted.sort()
			assert_eq(targets, sorted, "seat order")
			for i: int in range(1, targets.size()):
				assert_ne(targets[i], targets[i - 1], "different Dudes")
			for player_id: String in targets:
				seen[player_id] = true
			for key: String in before:
				if key != "combat_ai":
					assert_eq(state["rng"][key], before[key], "only combat_ai moves")
			if size == 1:
				assert_eq(state["rng"], before, "solo: no draw")
		# all_ids: every player id at this size.
		var all_ids: Array = ["p1", "p2", "p3", "p4"].slice(0, size)
		# seen_ids: the ids picked, sorted.
		var seen_ids: Array = seen.keys()
		seen_ids.sort()
		assert_eq(seen_ids, all_ids, "every Dude is picked sometimes at party size %d" % size)


## Fixed seeds give recorded targets for a party of 3.
func test_recorded_targets() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# actual: the targets for seeds 1..6.
	var actual: Array = []
	for run_seed: int in range(1, 7):
		actual.append(Targeting.choose_in_place(rules["constants"], AiFixtures.ai_state(run_seed, 3), _poke(rules)))
	assert_eq(actual, RECORDED_PARTY_OF_3)


## A Passed Out Dude is never a target. With fewer standing Dudes than targets, every standing Dude
## is hit and no draw is made.
func test_never_passed_out() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	for run_seed: int in SEEDS:
		# four: a party of 4 with p1 Passed Out.
		var four: Dictionary = AiFixtures.ai_state(run_seed, 4)
		four["dudes"][0]["passed_out"] = true
		# targets: the pick.
		var targets: Array = Targeting.choose_in_place(rules["constants"], four, _poke(rules))
		assert_eq(targets.size(), 2)
		assert_false(targets.has("p1"), "never the Passed Out Dude")
		# three: a party of 3 with p2 Passed Out: both standing Dudes, no draw.
		var three: Dictionary = AiFixtures.ai_state(run_seed, 3)
		three["dudes"][1]["passed_out"] = true
		# before: its streams.
		var before: Dictionary = three["rng"].duplicate()
		assert_eq(Targeting.choose_in_place(rules["constants"], three, _poke(rules)), ["p1", "p3"])
		assert_eq(three["rng"], before, "no draw when every standing Dude is a target")
	# last: a party of 3 with only p2 standing.
	var last: Dictionary = AiFixtures.ai_state(1, 3)
	last["dudes"][0]["passed_out"] = true
	last["dudes"][2]["passed_out"] = true
	assert_eq(Targeting.choose_in_place(rules["constants"], last, _poke(rules)), ["p2"])
	# nobody: everyone Passed Out.
	var nobody: Dictionary = AiFixtures.ai_state(1, 2)
	nobody["dudes"][0]["passed_out"] = true
	nobody["dudes"][1]["passed_out"] = true
	assert_eq(Targeting.choose_in_place(rules["constants"], nobody, _poke(rules)), [])


## An area attack is aimed at every standing Dude, in seat order, with no draw; a move aimed at
## nobody, or a Guard move, has no targets.
func test_area_and_none() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# state: a party of 4 with p3 Passed Out.
	var state: Dictionary = AiFixtures.ai_state(7, 4)
	state["dudes"][2]["passed_out"] = true
	# before: its streams.
	var before: Dictionary = state["rng"].duplicate()
	assert_eq(Targeting.choose_in_place(rules["constants"], state, rules["enemies"]["ai_area"]["moves"][0]), ["p1", "p2", "p4"])
	assert_eq(Targeting.choose_in_place(rules["constants"], state, rules["enemies"]["ai_quiet"]["moves"][0]), [])
	assert_eq(Targeting.choose_in_place(rules["constants"], state, rules["enemies"]["ai_duo"]["moves"][1]), [])
	assert_eq(state["rng"], before, "no draws")


## Without the combat_ai stream, a choice that needs a draw takes the first standing Dudes in seat
## order and fails nothing (Fight.check_start refuses such a fight).
func test_missing_stream_takes_first_dudes() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# state: a party of 4 without streams.
	var state: Dictionary = AiFixtures.ai_state(1, 4)
	state["rng"] = {}
	assert_eq(Targeting.choose_in_place(rules["constants"], state, _poke(rules)), ["p1", "p2"])
