## Tests for the apply_status op (core/ops/apply_status.gd) and Hungover in the guard op (task 009):
## stacking, who can carry what, the Broken Arm cap, Ick with Clout (G5), Grossed Out (G6) and
## Hungover rounding (G4). Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Ops := preload("res://core/ops/ops.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const Event := preload("res://core/schema/event.gd")
const RunState := preload("res://core/schema/run_state.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 99


## Returns a solo fight against a Dummy (e11, 2 arms) and a Slime (e12, no arms), in turn 1's
## player phase.
## rules: the test ruleset.
func _fight(rules: Dictionary) -> Dictionary:
	return Fixtures.fight(rules, SEED, ["test_dude"], ["test_dummy", "test_slime"])


## Plays a fresh copy of def_id and returns apply()'s result, asserting it applied and that its
## events and state are valid.
## rules: the ruleset. state: the state. def_id: the card. target_id: the target or "". seq: the seq.
func _play(rules: Dictionary, state: Dictionary, def_id: String, target_id: String, seq: int = 0) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, Fixtures.play("p1", seq, Fixtures.give(state, 0, def_id), target_id))
	assert_eq(result["reject"], "", "playing %s" % def_id)
	for event: Variant in result["events"]:
		assert_no_errors(Event.check(event), "event")
	assert_no_errors(RunState.check(result["state"]), "state")
	return result


## Returns the status_changed and grossed_out events, in order.
## events: an event list.
func _status_events(events: Array) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event["type"] in ["status_changed", "grossed_out"])


## apply_status checks its fields: every status id, stacks 1 or more, nothing else.
func test_checks() -> void:
	for status: String in ["exposed", "noodle_arms", "hungover", "foggy", "broken_arm", "ick"]:
		assert_eq(Ops.check({"op": "apply_status", "status": status, "stacks": 1}), [] as Array[String], status)
	for bad: Dictionary in [{"op": "apply_status", "status": "bugs", "stacks": 1}, {"op": "apply_status", "status": "ick", "stacks": 0},
			{"op": "apply_status", "status": "ick"}, {"op": "apply_status", "stacks": 1}, {"op": "apply_status", "status": "ick", "stacks": 1.0},
			{"op": "apply_status", "status": "ick", "stacks": 1, "amount": 2}]:
		assert_ne(Ops.check(bad), [] as Array[String], "problem expected for %s" % var_to_str(bad))
	assert_true(Ops.needs_target([{"op": "apply_status", "status": "noodle_arms", "stacks": 1}]), "enemy debuffs aim at a Dude")


## Cards task 007 rejected as unplayable (apply_status did not exist) now play: Arm Bar deals 8 and
## breaks an arm.
func test_status_cards_now_play() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# result: after Arm Bar on the Dummy.
	var result: Dictionary = _play(rules, _fight(rules), "neutral_test_arm_bar", "e11")
	assert_eq(result["state"]["combat"]["enemies"][0]["hp"], 12)
	assert_eq(_status_events(result["events"]), [Event.make("status_changed", {"target_id": "e11", "status": "broken_arm", "delta": 1, "stacks": 1})])


## Exposed and Noodle Arms stack in statuses; each application emits status_changed with the new total.
func test_stacked_statuses_stack() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: the fight, after two Exposes and an Advice on the Dummy.
	var state: Dictionary = _fight(rules)
	# result: the latest apply() result.
	var result: Dictionary = _play(rules, state, "neutral_test_expose", "e11", 0)
	result = _play(rules, result["state"], "neutral_test_expose", "e11", 1)
	assert_eq(_status_events(result["events"]), [Event.make("status_changed", {"target_id": "e11", "status": "exposed", "delta": 2, "stacks": 4})])
	result = _play(rules, result["state"], "neutral_test_advice", "e11", 2)
	assert_eq(result["state"]["combat"]["enemies"][0]["statuses"], {"exposed": 4, "noodle_arms": 1})
	assert_eq(result["state"]["combat"]["enemies"][0]["ick"], 3)


## Broken Arm rises to arm_count and stops (G7): over-count breaks do nothing and emit nothing;
## an enemy with arm_count 0 is unaffected.
func test_broken_arm_cap_and_zero_arms() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# result: Snap All (5 arms) on the 2-armed Dummy.
	var result: Dictionary = _play(rules, _fight(rules), "neutral_test_snap_all", "e11", 0)
	assert_eq(result["state"]["combat"]["enemies"][0]["broken_arms"], 2)
	assert_eq(_status_events(result["events"]), [Event.make("status_changed", {"target_id": "e11", "status": "broken_arm", "delta": 2, "stacks": 2})])
	result = _play(rules, result["state"], "neutral_test_snap_all", "e11", 1)
	assert_eq(_status_events(result["events"]), [], "already Armless: nothing changes")
	assert_eq(result["state"]["combat"]["enemies"][0]["broken_arms"], 2)
	result = _play(rules, result["state"], "neutral_test_arm_bar", "e12", 2)
	assert_eq(result["state"]["combat"]["enemies"][1]["broken_arms"], 0, "no arms to break")
	assert_eq(_status_events(result["events"]), [])


## Statuses land only on bodies that can carry them: Hungover and Foggy on Dudes, Broken Arm and
## Ick on enemies. A self-targeted card applying all four changes only the Dude's two.
func test_who_can_carry_what() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# result: Self Mess (hungover, foggy, ick, broken_arm on the player).
	var result: Dictionary = _play(rules, _fight(rules), "neutral_test_self_mess", "")
	assert_eq(result["state"]["dudes"][0]["statuses"], {"hungover": 1, "foggy": 1})
	assert_eq(_status_events(result["events"]), [
		Event.make("status_changed", {"target_id": "p1", "status": "hungover", "delta": 1, "stacks": 1}),
		Event.make("status_changed", {"target_id": "p1", "status": "foggy", "delta": 1, "stacks": 1}),
	])
	# events: Hungover and Foggy run straight on an enemy target.
	var events: Array = []
	# state: a working copy for the direct call.
	var state: Dictionary = _fight(rules)
	Ops.run(state, {"op": "apply_status", "status": "hungover", "stacks": 1},
		Ops.make_context(rules, "p1", ["e11"], false, true), events)
	Ops.run(state, {"op": "apply_status", "status": "foggy", "stacks": 1},
		Ops.make_context(rules, "p1", ["e11"], false, true), events)
	assert_eq(events, [])
	assert_eq(state["combat"]["enemies"][0]["statuses"], {})


## G5: Clout is added once per application: 2 Ick + 1 Clout = 3; 4 Ick to all enemies = 5 each.
func test_ick_with_clout() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: the fight with p1 at 1 Clout and higher thresholds, so nobody is Grossed Out here.
	var state: Dictionary = _fight(rules)
	state["dudes"][0]["clout"] = 1
	for enemy: Dictionary in state["combat"]["enemies"]:
		enemy["ick_threshold"] = 20
	# result: Well, Actually on the Dummy.
	var result: Dictionary = _play(rules, state, "neutral_test_well_actually", "e11", 0)
	assert_eq(_status_events(result["events"]), [Event.make("status_changed", {"target_id": "e11", "status": "ick", "delta": 3, "stacks": 3})])
	result = _play(rules, result["state"], "neutral_test_pickup", "", 1)
	assert_eq(_status_events(result["events"]), [
		Event.make("status_changed", {"target_id": "e11", "status": "ick", "delta": 5, "stacks": 8}),
		Event.make("status_changed", {"target_id": "e12", "status": "ick", "delta": 5, "stacks": 5}),
	])


## G6: at the threshold Ick resets to 0, the threshold rises by ICK_THRESHOLD_STEP and a skip is
## queued; Ick applied while waiting counts toward the new threshold, and a second Grossed Out
## queues a second skip.
func test_grossed_out() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# base: the normal-tier starting threshold.
	var base: int = rules["constants"]["ICK_BASE_NORMAL"]
	# step: the threshold step.
	var step: int = rules["constants"]["ICK_THRESHOLD_STEP"]
	# state: the fight with the Dummy one Ick short of Grossed Out after a Well, Actually (2).
	var state: Dictionary = _fight(rules)
	state["combat"]["enemies"][0]["ick"] = base - 3
	# result: Well, Actually: Ick base - 1, not yet.
	var result: Dictionary = _play(rules, state, "neutral_test_well_actually", "e11", 0)
	assert_eq(result["state"]["combat"]["enemies"][0]["grossed_out_skips"], 0)
	result = _play(rules, result["state"], "neutral_test_well_actually", "e11", 1)
	assert_eq(_status_events(result["events"]), [
		Event.make("status_changed", {"target_id": "e11", "status": "ick", "delta": 2, "stacks": base + 1}),
		Event.make("grossed_out", {"enemy_uid": "e11", "new_threshold": base + step}),
		Event.make("status_changed", {"target_id": "e11", "status": "ick", "delta": -(base + 1), "stacks": 0}),
	])
	# dummy: the Dummy after its first Grossed Out.
	var dummy: Dictionary = result["state"]["combat"]["enemies"][0]
	assert_eq([dummy["ick"], dummy["ick_threshold"], dummy["grossed_out_skips"]], [0, base + step, 1])
	# Ick while it waits still counts: fill the new threshold exactly.
	result["state"]["combat"]["enemies"][0]["ick"] = base + step - 2
	result = _play(rules, result["state"], "neutral_test_well_actually", "e11", 2)
	dummy = result["state"]["combat"]["enemies"][0]
	assert_eq([dummy["ick"], dummy["ick_threshold"], dummy["grossed_out_skips"]], [0, base + 2 * step, 2])


## G4: a Hungover Dude's Guard from cards is (amount + Chill) x HUNGOVER_MULT, rounded down once.
## Brace (5) with 4 Chill: 9 x 0.75 = 6.75 -> 6 (multiplying before adding Chill would give 7).
## Guard not from a card is not reduced.
func test_hungover_guard() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	assert_true(is_equal_approx(float(rules["constants"]["HUNGOVER_MULT"]), 0.75), "expected numbers assume HUNGOVER_MULT 0.75")
	# cases: [Chill, expected Guard gained] for Brace (5) while Hungover.
	var cases: Array = [[0, 3], [1, 4], [4, 6]]
	for case: Array in cases:
		# state: a fight with a Hungover p1.
		var state: Dictionary = _fight(rules)
		state["dudes"][0]["chill"] = case[0]
		state["dudes"][0]["statuses"]["hungover"] = 1
		# result: after Brace.
		var result: Dictionary = _play(rules, state, "neutral_test_brace", "")
		assert_eq(result["state"]["dudes"][0]["guard"], case[1], "Chill %d" % case[0])
	# direct: a fight with a Hungover p1, for Guard that is not from a card.
	var direct: Dictionary = _fight(rules)
	direct["dudes"][0]["statuses"]["hungover"] = 1
	# events: from the direct call.
	var events: Array = []
	Ops.run(direct, {"op": "guard", "amount": 5}, Ops.make_context(rules, "p1", [], false, false), events)
	assert_eq(direct["dudes"][0]["guard"], 5)
