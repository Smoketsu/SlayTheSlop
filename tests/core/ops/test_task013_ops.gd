## Tests for task 013's op checks and edge cases: the new ops' fields, the generic "if" and
## "target" fields, actors that are not Dudes, and Powers of a Passed Out Dude. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Ops := preload("res://core/ops/ops.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const TomFixtures := preload("res://tests/core/ops/tom_fixtures.gd")
const Event := preload("res://core/schema/event.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 31


## Ops.check accepts the new ops and generic fields and names each problem in bad ones.
func test_op_checks() -> void:
	for good: Dictionary in [{"op": "draw", "amount": 1}, {"op": "gain_hype", "amount": 1},
			{"op": "self_damage", "amount": 0}, {"op": "guard_per_broken_arm", "amount": 4}, {"op": "thorns", "amount": 3},
			{"op": "draw", "amount": 1, "if": "target_has_broken_arm"},
			{"op": "gain_hype", "amount": 1, "if": "target_now_armless"},
			{"op": "apply_status", "status": "broken_arm", "stacks": 1, "target": "all_enemies"}]:
		assert_eq(Ops.check(good), [] as Array[String], var_to_str(good))
	for bad: Dictionary in [{"op": "draw", "amount": 0}, {"op": "draw"}, {"op": "gain_hype", "amount": 0},
			{"op": "self_damage", "amount": -1}, {"op": "guard_per_broken_arm", "amount": 1.0},
			{"op": "thorns", "amount": 0}, {"op": "thorns", "amount": 3, "hits": 2},
			{"op": "draw", "amount": 1, "if": "target_is_sad"}, {"op": "draw", "amount": 1, "if": 1},
			{"op": "damage", "amount": 1, "target": "everyone"}]:
		assert_eq(Ops.check(bad).size(), 1, "one problem in %s" % var_to_str(bad))
	assert_false(Ops.needs_target([{"op": "draw", "amount": 1}, {"op": "self_damage", "amount": 1}, {"op": "thorns", "amount": 1}]))


## draw, gain_hype and thorns do nothing for an actor that is not a Dude; self_damage hurts an
## enemy actor; self_damage 0 emits nothing.
func test_actor_kinds() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: a fight, used as a working copy.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_tom"], ["test_hitter"])
	# context: the Hitter (e11) as the actor.
	var context: Dictionary = Ops.make_context(rules, "e11", [], true, false)
	# events: what the ops emitted.
	var events: Array = []
	for effect: Dictionary in [{"op": "draw", "amount": 2}, {"op": "gain_hype", "amount": 2}, {"op": "thorns", "amount": 2},
			{"op": "self_damage", "amount": 0}]:
		Ops.run(state, effect, context, events)
	assert_eq(events, [])
	Ops.run(state, {"op": "self_damage", "amount": 4}, context, events)
	assert_eq(events, [Event.make("damage_dealt", {"source_id": "e11", "target_id": "e11", "amount": 4, "blocked": 0, "hp_lost": 4})])


## A Passed Out Dude's Powers do not fire; the other Dude's still do.
func test_passed_out_dude_powers_do_not_fire() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: two Toms, each with Friend Zone active; p1 is Passed Out.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_tom", "test_tom"], ["test_turtle"])
	for seat: int in 2:
		# uid: a Friend Zone copy moved straight into the powers list (test setup).
		var uid: String = Fixtures.give(state, seat, "tom_test_friend_zone")
		state["dudes"][seat]["hand"].erase(uid)
		state["dudes"][seat]["powers"].append(uid)
	state["dudes"][0]["passed_out"] = true
	# events: the turn-start triggers.
	var events: Array = []
	Ops.fire_power_triggers_in_place(rules, state, preload("res://core/combat/powers.gd").matching(
		rules, state, "turn_start", ""), events)
	assert_eq(events.filter(func(event: Dictionary) -> bool: return event["type"] == "power_triggered").map(
		func(event: Dictionary) -> String: return event["player_id"]), ["p2"])
	assert_eq(state["combat"]["enemies"][0]["ick"], 1, "only p2's Friend Zone applied Ick")
