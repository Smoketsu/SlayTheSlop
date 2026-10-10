## Tests for statuses in the turn flow (core/combat/statuses.gd and its hooks in fight.gd; task 009):
## wear-off timing (G1), Foggy at Refresh, statuses applied by enemies, the Grossed Out skip (G6),
## Armless once per fight (G7), Ick thresholds by tier and party size, and the constants check.
## Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Fight := preload("res://core/combat/fight.gd")
const Party := preload("res://core/combat/party.gd")
const Statuses := preload("res://core/combat/statuses.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const Event := preload("res://core/schema/event.gd")
const RunState := preload("res://core/schema/run_state.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 3131


## Applies a request, asserting it is accepted and that every event and the new state are valid.
## Returns apply()'s result.
## rules: the ruleset. state: the state. request: the request.
func _ok(rules: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], "", "request %s should apply" % var_to_str(request))
	for event: Variant in result["events"]:
		assert_no_errors(Event.check(event), "event %s" % var_to_str(event))
	assert_no_errors(RunState.check(result["state"]), "state")
	return result


## Returns the events of the given types, in order.
## events: an event list. types: the event types wanted.
func _of_types(events: Array, types: Array) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return types.has(event["type"]))


## Returns the index of the first event equal to wanted, or -1.
## events: an event list. wanted: the event to find.
func _index(events: Array, wanted: Dictionary) -> int:
	return events.find(wanted)


## G1 for Dudes: at End of turn, after the hand is discarded and before the enemy phase, a Dude
## loses 1 Exposed, Noodle Arms and Hungover; Foggy is untouched until the next Refresh, where it
## cuts the draw by its stacks and then loses 1.
func test_dude_wear_off_and_foggy() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight against a Turtle (no attacks), with p1 carrying four statuses.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_turtle"])
	state["dudes"][0]["statuses"] = {"exposed": 2, "noodle_arms": 1, "hungover": 1, "foggy": 2}
	# result: after Ready, in turn 2.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	# events: the turn change's events.
	var events: Array = result["events"]
	assert_eq(_of_types(events, ["status_changed"]), [
		Event.make("status_changed", {"target_id": "p1", "status": "exposed", "delta": -1, "stacks": 1}),
		Event.make("status_changed", {"target_id": "p1", "status": "hungover", "delta": -1, "stacks": 0}),
		Event.make("status_changed", {"target_id": "p1", "status": "noodle_arms", "delta": -1, "stacks": 0}),
		Event.make("status_changed", {"target_id": "p1", "status": "foggy", "delta": -1, "stacks": 1}),
	])
	# wear: index of the first End-of-turn wear-off event.
	var wear: int = _index(events, Event.make("status_changed", {"target_id": "p1", "status": "exposed", "delta": -1, "stacks": 1}))
	# last_discard: index of the last hand -> discard_pile move.
	var last_discard: int = -1
	for i: int in events.size():
		if events[i]["type"] == "card_moved" and events[i]["to"] == "discard_pile":
			last_discard = i
	assert_true(last_discard < wear and wear < _index(events, Event.make("enemy_acted", {"enemy_uid": "e11", "move_id": "shell"})),
		"wear-off happens after the discard and before the enemy phase")
	assert_eq(result["state"]["dudes"][0]["statuses"], {"exposed": 1, "foggy": 1})
	assert_eq(result["state"]["dudes"][0]["hand"].size(), rules["constants"]["BASE_DRAW"] - 2, "2 Foggy: 2 fewer cards")
	assert_eq(events[-1], Event.make("status_changed", {"target_id": "p1", "status": "foggy", "delta": -1, "stacks": 1}),
		"Foggy wears off right after the Refresh draw")
	# next: turn 3; 1 Foggy left, so 1 fewer card, then no Foggy and no Exposed.
	var next: Dictionary = _ok(rules, result["state"], Fixtures.set_ready("p1", 1))["state"]
	assert_eq(next["dudes"][0]["hand"].size(), rules["constants"]["BASE_DRAW"] - 1)
	assert_eq(next["dudes"][0]["statuses"], {})


## Foggy never makes the draw negative, and a Passed Out Dude's statuses do not wear off (they skip
## turns).
func test_foggy_floor_and_passed_out() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# dude: a hand-made Dude state with more Foggy than draw.
	var dude: Dictionary = {"draw_per_turn": 5, "statuses": {"foggy": 9}}
	assert_eq(Statuses.refresh_draw_count(dude), 0)
	# state: a two-Dude fight with p2 Passed Out and Exposed.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["test_turtle"])
	state["dudes"][1]["hp"] = 0
	state["dudes"][1]["passed_out"] = true
	state["dudes"][1]["statuses"]["exposed"] = 1
	# result: after p1's Ready.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq(result["state"]["dudes"][1]["statuses"], {"exposed": 1})


## G1 for enemies: an enemy keeps its statuses for its own action (Noodle Arms weakens it) and loses
## 1 stack of each right after acting.
func test_enemy_wear_off_after_acting() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight against the Hitter (10 damage), Noodle 1 and Exposed 2.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_hitter"])
	state["combat"]["enemies"][0]["statuses"] = {"noodle_arms": 1, "exposed": 2}
	# result: after Ready.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	# events: the turn change's events.
	var events: Array = result["events"]
	assert_eq(_of_types(events, ["enemy_acted", "damage_dealt", "status_changed"]), [
		Event.make("enemy_acted", {"enemy_uid": "e11", "move_id": "punch"}),
		Event.make("damage_dealt", {"source_id": "e11", "target_id": "p1", "amount": 7, "blocked": 0, "hp_lost": 7}),
		Event.make("status_changed", {"target_id": "e11", "status": "exposed", "delta": -1, "stacks": 1}),
		Event.make("status_changed", {"target_id": "e11", "status": "noodle_arms", "delta": -1, "stacks": 0}),
	], "10 x 0.75 = 7.5 -> 7, then wear-off")
	assert_eq(result["state"]["combat"]["enemies"][0]["statuses"], {"exposed": 1})


## An enemy's apply_status lands on its intent's target: the Hexer gives p1 Exposed 2, Foggy,
## Hungover and Noodle Arms; Broken Arm and Ick cannot go on a Dude. The 4 damage after them lands
## on a now-Exposed Dude (6). Next turn p1 draws one fewer card.
func test_enemy_applies_statuses() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight against the Hexer.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_hexer"])
	assert_eq(state["combat"]["enemies"][0]["intent"], {"move_id": "hex", "target_ids": ["p1"]}, "a status move aims at a Dude")
	# result: after Ready.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq(_of_types(result["events"], ["damage_dealt"])[0]["amount"], 6, "4 x 1.5")
	assert_eq(result["state"]["dudes"][0]["statuses"], {"exposed": 2, "hungover": 1, "noodle_arms": 1},
		"Foggy was used by the Refresh right after and wore off")
	assert_eq(result["state"]["dudes"][0]["hand"].size(), rules["constants"]["BASE_DRAW"] - 1)


## G6: an enemy with a Grossed Out skip skips its whole action (no enemy_acted, no damage), the skip
## is used up, and its statuses still wear off after its slot. It acts normally the turn after.
func test_grossed_out_skip() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight against the Hitter, one Ick short; Well, Actually Grosses it Out.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_hitter"])
	state["combat"]["enemies"][0]["ick"] = state["combat"]["enemies"][0]["ick_threshold"] - 2
	state["combat"]["enemies"][0]["statuses"]["exposed"] = 1
	# result: after Well, Actually, then Ready.
	var result: Dictionary = _ok(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, "neutral_test_well_actually"), "e11"))
	assert_eq(result["state"]["combat"]["enemies"][0]["grossed_out_skips"], 1)
	result = _ok(rules, result["state"], Fixtures.set_ready("p1", 1))
	assert_eq(_of_types(result["events"], ["enemy_acted", "enemy_skipped", "damage_dealt", "status_changed"]), [
		Event.make("enemy_skipped", {"enemy_uid": "e11", "reason": "grossed_out"}),
		Event.make("status_changed", {"target_id": "e11", "status": "exposed", "delta": -1, "stacks": 0}),
	])
	assert_eq(result["state"]["combat"]["enemies"][0]["grossed_out_skips"], 0)
	assert_eq(result["state"]["dudes"][0]["hp"], 30)
	result = _ok(rules, result["state"], Fixtures.set_ready("p1", 2))
	assert_eq(_of_types(result["events"], ["enemy_acted"]), [Event.make("enemy_acted", {"enemy_uid": "e11", "move_id": "punch"})])


## Two Grossed Out skips cost two actions (G6: Ick while waiting still counts).
func test_two_grossed_out_skips() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight against the Hitter with 2 skips queued.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_hitter"])
	state["combat"]["enemies"][0]["grossed_out_skips"] = 2
	# result: two turns.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq(_of_types(result["events"], ["enemy_skipped"]).size(), 1)
	result = _ok(rules, result["state"], Fixtures.set_ready("p1", 1))
	assert_eq(_of_types(result["events"], ["enemy_skipped"]).size(), 1)
	assert_eq(result["state"]["combat"]["enemies"][0]["grossed_out_skips"], 0)
	assert_eq(result["state"]["dudes"][0]["hp"], 30)


## G7: when its last arm breaks, the enemy's next damaging move is skipped (armless, then
## enemy_skipped), once per fight; afterwards it attacks at the full Broken Arm reduction.
func test_armless_once_per_fight() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight against the Hitter; Snap All breaks both arms.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_hitter"])
	# result: after Snap All and Ready.
	var result: Dictionary = _ok(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, "neutral_test_snap_all"), "e11"))
	assert_true(Statuses.is_armless(result["state"]["combat"]["enemies"][0]))
	result = _ok(rules, result["state"], Fixtures.set_ready("p1", 1))
	assert_eq(_of_types(result["events"], ["armless", "enemy_skipped", "enemy_acted", "damage_dealt"]), [
		Event.make("armless", {"enemy_uid": "e11"}),
		Event.make("enemy_skipped", {"enemy_uid": "e11", "reason": "armless"}),
	])
	assert_true(result["state"]["combat"]["enemies"][0]["armless_used"])
	result = _ok(rules, result["state"], Fixtures.set_ready("p1", 2))
	assert_eq(_of_types(result["events"], ["armless", "enemy_skipped"]), [], "only once per fight")
	assert_eq(_of_types(result["events"], ["damage_dealt"])[0]["amount"], 6, "10 x (1 - 0.4) = 6")


## G7: a move that deals no damage still happens while Armless is waiting; the skip waits for the
## next damaging move. A Grossed Out skip is used before the Armless one.
func test_armless_waits_for_a_damaging_move() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight against an Armless Hitter that intends to pose (Guard only).
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_hitter"])
	state["combat"]["enemies"][0]["broken_arms"] = 2
	state["combat"]["enemies"][0]["intent"] = {"move_id": "pose", "target_ids": []}
	# result: after Ready: it poses.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq(_of_types(result["events"], ["enemy_acted", "enemy_skipped"]), [Event.make("enemy_acted", {"enemy_uid": "e11", "move_id": "pose"})])
	assert_false(result["state"]["combat"]["enemies"][0]["armless_used"])
	# grossed: turn 2 (intent punch) with a Grossed Out skip queued as well.
	var grossed: Dictionary = result["state"].duplicate(true)
	grossed["combat"]["enemies"][0]["grossed_out_skips"] = 1
	result = _ok(rules, grossed, Fixtures.set_ready("p1", 1))
	assert_eq(_of_types(result["events"], ["enemy_skipped"]), [Event.make("enemy_skipped", {"enemy_uid": "e11", "reason": "grossed_out"})])
	assert_false(result["state"]["combat"]["enemies"][0]["armless_used"], "Armless still waiting")
	result = _ok(rules, result["state"], Fixtures.set_ready("p1", 2))
	assert_eq(_of_types(result["events"], ["enemy_skipped"]), [Event.make("enemy_skipped", {"enemy_uid": "e11", "reason": "armless"})])
	assert_true(result["state"]["combat"]["enemies"][0]["armless_used"])


## Ick thresholds start at ICK_BASE_<tier> scaled by the party HP multiplier, rounded up (task 007
## builds them; checked here for every tier and party size), and a Grossed Out adds the unscaled
## ICK_THRESHOLD_STEP.
func test_ick_thresholds_by_tier_and_party() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# constants: the tuning constants.
	var constants: Dictionary = rules["constants"]
	for size: int in [1, 2, 3, 4]:
		# ids: that many Dudes.
		var ids: Array = []
		ids.resize(size)
		ids.fill("test_dude")
		# state: a fight against one enemy of each tier.
		var state: Dictionary = Fixtures.fight(rules, SEED, ids, ["test_pledge", "test_rival", "test_boss"])
		# millionths: the party's HP multiplier in millionths, 1000000 + 800000 per extra player.
		var millionths: int = 1000000 + roundi(float(constants["HP_SCALE_PER_EXTRA_PLAYER"]) * 1000000) * (size - 1)
		for i: int in 3:
			# base: the tier's solo threshold.
			var base: int = constants[["ICK_BASE_NORMAL", "ICK_BASE_RIVAL", "ICK_BASE_BOSS"][i]]
			assert_eq(state["combat"]["enemies"][i]["ick_threshold"], (base * millionths + 999999) / 1000000,
				"party %d, tier %d" % [size, i])
	# duo: a two-player fight; the Pledge's threshold is ceil(5 x 1.8) = 9 and rises by the step.
	var duo: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["test_pledge"])
	# threshold: the Pledge's starting threshold.
	var threshold: int = duo["combat"]["enemies"][0]["ick_threshold"]
	duo["combat"]["enemies"][0]["ick"] = threshold - 1
	# result: after Well, Actually.
	var result: Dictionary = _ok(rules, duo, Fixtures.play("p1", 0, Fixtures.give(duo, 0, "neutral_test_well_actually"), "e21"))
	assert_eq(result["state"]["combat"]["enemies"][0]["ick_threshold"], threshold + constants["ICK_THRESHOLD_STEP"])


## start_fight refuses a ruleset whose status constants are missing or out of range.
func test_status_constants_are_checked() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# run: a solo run outside a fight.
	var run: Dictionary = Party.build_run_state(rules, SEED, ["test_dude"])["state"]
	assert_eq(Statuses.check_constants(rules["constants"]), "")
	# changes: constant name -> a bad value (null removes it).
	var changes: Dictionary = {"EXPOSED_MULT": null, "NOODLE_MULT": -0.5, "HUNGOVER_MULT": "x",
		"BROKEN_ARM_MAX_REDUCTION": 1.5, "ICK_THRESHOLD_STEP": 3.0}
	for name: String in changes:
		# broken: a writable copy of the ruleset with one constant broken.
		var broken: Dictionary = {"constants": rules["constants"].duplicate(), "cards": rules["cards"],
			"enemies": rules["enemies"], "dudes": rules["dudes"]}
		if typeof(changes[name]) == TYPE_NIL:
			broken["constants"].erase(name)
		else:
			broken["constants"][name] = changes[name]
		# error: start_fight's refusal.
		var error: String = Fight.start_fight(broken, run, ["test_dummy"])["error"]
		assert_true(error.contains(name), "%s: %s" % [name, error])
