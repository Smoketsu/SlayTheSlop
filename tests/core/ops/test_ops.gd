## Tests for the effect ops in core/ops/: damage (Swole, hits, Guard per G2, HP floor) and guard
## (Chill), op checking, and unknown ops in enemy moves (task 007). Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Ops := preload("res://core/ops/ops.gd")
const Damage := preload("res://core/ops/damage.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const Event := preload("res://core/schema/event.gd")
const RunState := preload("res://core/schema/run_state.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 9


## Returns a solo fight against one Dummy (uid e11) in turn 1's player phase.
## rules: the test ruleset.
func _fight(rules: Dictionary) -> Dictionary:
	return Fixtures.fight(rules, SEED, ["test_dude"], ["test_dummy"])


## Plays a fresh copy of def_id at the Dummy and returns apply()'s result, asserting it applied
## and that its events and state are valid.
## rules: the ruleset. state: the state, changed only by the added card. def_id: the card to play.
## target_id: the target to send.
func _play(rules: Dictionary, state: Dictionary, def_id: String, target_id: String) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, def_id), target_id))
	assert_eq(result["reject"], "", "playing %s" % def_id)
	for event: Variant in result["events"]:
		assert_no_errors(Event.check(event), "event")
	assert_no_errors(RunState.check(result["state"]), "state")
	return result


## Returns the damage_dealt events, in order.
## events: an event list.
func _hits(events: Array) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event["type"] == "damage_dealt")


## G2: Guard absorbs damage and is reduced by what it absorbed; the rest comes off HP.
func test_guard_absorbs_and_is_used_up() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# cases: [enemy Guard before, expected blocked, expected hp_lost, expected Guard after] for a 6-damage Jab.
	var cases: Array = [[0, 0, 6, 0], [4, 4, 2, 0], [6, 6, 0, 0], [10, 6, 0, 4]]
	for case: Array in cases:
		# state: a fight with the Dummy's Guard set.
		var state: Dictionary = _fight(rules)
		state["combat"]["enemies"][0]["guard"] = case[0]
		# result: after the Jab.
		var result: Dictionary = _play(rules, state, "neutral_test_jab", "e11")
		assert_eq(_hits(result["events"]), [Event.make("damage_dealt",
			{"source_id": "p1", "target_id": "e11", "amount": 6, "blocked": case[1], "hp_lost": case[2]})], "Guard %d" % case[0])
		assert_eq(result["state"]["combat"]["enemies"][0]["guard"], case[3], "Guard left from %d" % case[0])
		assert_eq(result["state"]["combat"]["enemies"][0]["hp"], 20 - case[2])


## Swole is added to every hit; hits repeats the hit, and Guard carries over between hits.
func test_swole_and_hits() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight where p1 has 2 Swole and the Dummy has 5 Guard.
	var state: Dictionary = _fight(rules)
	state["dudes"][0]["swole"] = 2
	state["combat"]["enemies"][0]["guard"] = 5
	# result: after Double (4 damage, 2 hits) -> 6 per hit.
	var result: Dictionary = _play(rules, state, "neutral_test_double", "e11")
	assert_eq(_hits(result["events"]).map(func(event: Dictionary) -> Array: return [event["amount"], event["blocked"], event["hp_lost"]]),
		[[6, 5, 1], [6, 0, 6]])
	assert_eq(result["state"]["combat"]["enemies"][0]["hp"], 13)


## An enemy's Swole is added to its hits on a Dude, and a Dude's Guard absorbs them.
func test_enemy_swole_against_guard() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight where the Dummy (5 damage) has 3 Swole and p1 has 6 Guard.
	var state: Dictionary = _fight(rules)
	state["combat"]["enemies"][0]["swole"] = 3
	state["dudes"][0]["guard"] = 6
	# result: after Ready; the Dummy hits for 8.
	var result: Dictionary = Core.apply(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq(_hits(result["events"]), [Event.make("damage_dealt",
		{"source_id": "e11", "target_id": "p1", "amount": 8, "blocked": 6, "hp_lost": 2})])
	assert_eq(result["state"]["dudes"][0]["hp"], 28)


## guard adds the Dude's Chill once per guard effect.
func test_guard_adds_chill() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight where p1 has 3 Chill and 1 Guard.
	var state: Dictionary = _fight(rules)
	state["dudes"][0]["chill"] = 3
	state["dudes"][0]["guard"] = 1
	# result: after Brace (5 Guard).
	var result: Dictionary = _play(rules, state, "neutral_test_brace", "")
	assert_eq(result["state"]["dudes"][0]["guard"], 9)
	assert_true(result["events"].has(Event.make("guard_changed", {"target_id": "p1", "delta": 8, "guard": 9})))


## Enemy moves: unknown ops are skipped, the rest run; multi-hit enemy attacks and enemy Guard work.
func test_enemy_move_skips_unknown_op() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight against Flurry (2 damage x3, 3 Guard, and an op "warp" that does not exist).
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_flurry"])
	# result: after Ready.
	var result: Dictionary = Core.apply(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq(result["reject"], "")
	assert_eq(_hits(result["events"]).size(), 3)
	assert_eq(result["state"]["dudes"][0]["hp"], 24)
	assert_eq(result["state"]["combat"]["enemies"][0]["guard"], 3)


## Ops.check() accepts good effects and names each problem in bad ones.
func test_op_checks() -> void:
	assert_eq(Ops.check({"op": "damage", "amount": 8, "hits": 1}), [] as Array[String])
	assert_eq(Ops.check({"op": "damage", "amount": 8}), [] as Array[String], "hits is optional")
	assert_eq(Ops.check({"op": "guard", "amount": 0}), [] as Array[String])
	for bad: Variant in [{"op": "damage"}, {"op": "damage", "amount": 8.0}, {"op": "damage", "amount": -1},
			{"op": "damage", "amount": 1, "hits": 0}, {"op": "damage", "amount": 1, "stacks": 2},
			{"op": "guard", "amount": "5"}, {"op": "apply_status", "status": "ick", "stacks": 2}, {"amount": 1}, 5]:
		assert_ne(Ops.check(bad), [] as Array[String], "problem expected for %s" % var_to_str(bad))
	assert_true(Ops.needs_target([{"op": "guard", "amount": 1}, {"op": "damage", "amount": 1}]))
	assert_false(Ops.needs_target([{"op": "guard", "amount": 1}, {"op": "warp"}]))


## deal_in_place never takes HP below 0 and knocks out at exactly 0.
func test_overkill_stops_at_zero() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a two-Dude fight, used as a working copy here.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["test_dummy"])
	# events: what the hit emitted.
	var events: Array = []
	Damage.deal_in_place(state, "e21", "p1", 100, events)
	assert_eq(events, [
		Event.make("damage_dealt", {"source_id": "e21", "target_id": "p1", "amount": 100, "blocked": 0, "hp_lost": 30}),
		Event.make("dude_passed_out", {"player_id": "p1"}),
	])
	assert_eq([state["dudes"][0]["hp"], state["dudes"][0]["passed_out"]], [0, true])
	events = []
	Damage.deal_in_place(state, "e21", "p1", 5, events)
	assert_eq(events, [], "a Passed Out Dude cannot be hit again")
