## Tests for enemy intents inside real fights (core/ai/intents.gd and its calls in
## core/combat/fight.gd, task 011): intent_set and move_history, the recorded 20-turn sequence,
## multi-target and area attacks, Passed Out targets, G30 Guard reset, start checks.
## Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Fight := preload("res://core/combat/fight.gd")
const Party := preload("res://core/combat/party.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const Intents := preload("res://core/ai/intents.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const AiFixtures := preload("res://tests/core/ai/ai_fixtures.gd")

## Seed of the recorded 20-turn fight.
const SEED: int = 20261010

## ai_duo's intents in turns 1..20 of a solo fight on SEED where the player only presses Ready,
## recorded on Godot 4.7.2-stable. Never three in a row.
const RECORDED_TWENTY: Array = ["poke", "poke", "brace", "poke", "poke", "brace", "brace", "poke", "brace", "brace",
	"poke", "brace", "poke", "brace", "brace", "poke", "poke", "brace", "brace", "poke"]


## Applies a request, asserting it is accepted and that every event and the new state pass the
## schema checks and survive a snapshot round trip. Returns apply()'s result.
## rules: the ruleset. state: the state. request: the request.
func _ok(rules: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], "", "request %s should apply" % var_to_str(request))
	_assert_valid(result["state"], result["events"])
	return result


## Asserts that every event passes event.gd check(), the state passes run_state.check(), and a
## snapshot of it loads back identical.
## state: a run state. events: an event list.
func _assert_valid(state: Dictionary, events: Array) -> void:
	for event: Variant in events:
		assert_no_errors(Event.check(event), "event %s" % var_to_str(event))
	assert_no_errors(RunState.check(state), "state")
	# loaded: the state after a snapshot round trip.
	var loaded: Dictionary = Snapshot.from_bytes(Snapshot.to_bytes(state))
	assert_eq(loaded["state"], state, "snapshot round trip")


## Returns the events of one type, in order.
## events: an event list. type: the event type wanted.
func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event["type"] == type)


## Plays a solo fight against ai_duo on SEED for 20 turns, pressing only Ready, and returns
## {"moves": the move of every intent_set in order, "state": the final state, "events": all events}.
func _twenty_turns() -> Dictionary:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# started: the fight's start.
	var started: Dictionary = Fight.start_fight(rules, Party.build_run_state(rules, SEED, ["test_dude"])["state"], ["ai_duo"])
	_assert_valid(started["state"], started["events"])
	# state: the fight as it goes.
	var state: Dictionary = started["state"]
	# events: every event, from the start on.
	var events: Array = started["events"].duplicate()
	for i: int in 19:
		# result: the turn change.
		var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", i))
		state = result["state"]
		events.append_array(result["events"])
	# moves: the intents' moves, in order.
	var moves: Array = _of_type(events, "intent_set").map(func(event: Dictionary) -> String: return event["move_id"])
	return {"moves": moves, "state": state, "events": events}


## Fixed seed: a two-move enemy shows a recorded intent sequence over 20 turns, the same on a replay,
## equal to its move_history, never three in a row, and every intent_set is aimed as its move says.
func test_twenty_turn_recorded_intents() -> void:
	# first: the fight.
	var first: Dictionary = _twenty_turns()
	assert_eq(first["state"]["combat"]["turn"], 20)
	assert_eq(first["moves"], RECORDED_TWENTY, "recorded intents")
	assert_eq(first["state"]["combat"]["enemies"][0]["move_history"], RECORDED_TWENTY, "move_history")
	for event: Dictionary in _of_type(first["events"], "intent_set"):
		assert_eq(event["target_ids"], ["p1"] if event["move_id"] == "poke" else [], "aim of %s" % event["move_id"])
	# second: a replay.
	var second: Dictionary = _twenty_turns()
	assert_eq(Snapshot.to_bytes(second["state"]), Snapshot.to_bytes(first["state"]), "identical replay")
	assert_eq(second["events"], first["events"])


## Goblin Bouncer-style pattern in a fight, and G30: it gains 8 Guard, keeps it through the
## players' turn, loses it (guard_changed) at the start of its next action, just before
## enemy_acted, then hits for 9 (no Guard of the Dude's in the way).
func test_bouncer_pattern_and_guard_reset() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# state: a solo fight against the Bouncer.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["ai_bouncer"])
	# uid: the Bouncer's uid.
	var uid: String = state["combat"]["enemies"][0]["uid"]
	assert_eq(state["combat"]["enemies"][0]["intent"], {"move_id": "guard_up", "target_ids": []})
	# result: after turn 1.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	# acted: from the enemy's action to the end of the turn change.
	var acted: Array = result["events"].slice(result["events"].find(Event.make("enemy_acted", {"enemy_uid": uid, "move_id": "guard_up"})))
	assert_eq(acted.slice(0, 4), [
		Event.make("enemy_acted", {"enemy_uid": uid, "move_id": "guard_up"}),
		Event.make("guard_changed", {"target_id": uid, "delta": 8, "guard": 8}),
		Event.make("turn_started", {"turn": 2}),
		Event.make("intent_set", {"enemy_uid": uid, "move_id": "hit", "target_ids": ["p1"]}),
	], "no Guard reset when it had none")
	assert_eq(result["state"]["combat"]["enemies"][0]["guard"], 8, "Guard kept through the players' turn")
	result = _ok(rules, result["state"], Fixtures.set_ready("p1", 1))
	# reset: index of the G30 reset.
	var reset: int = result["events"].find(Event.make("guard_changed", {"target_id": uid, "delta": -8, "guard": 0}))
	assert_true(reset != -1, "Guard dropped to 0 (G30)")
	assert_eq(result["events"].slice(reset, reset + 3), [
		Event.make("guard_changed", {"target_id": uid, "delta": -8, "guard": 0}),
		Event.make("enemy_acted", {"enemy_uid": uid, "move_id": "hit"}),
		Event.make("damage_dealt", {"source_id": uid, "target_id": "p1", "amount": 9, "blocked": 0, "hp_lost": 9}),
	], "reset before it acts")
	assert_eq(result["state"]["combat"]["enemies"][0]["intent"]["move_id"], "guard_up", "the pattern cycles")
	assert_eq(result["state"]["combat"]["enemies"][0]["move_history"], ["guard_up", "hit", "guard_up"])
	assert_eq(result["state"]["rng"]["combat_ai"], state["rng"]["combat_ai"], "patterns and solo aims never draw")


## Party of 3: a single-target attack is aimed at 2 different Dudes and hits exactly them.
func test_multi_target_in_fight() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# state: three Dudes against a Pledge (hits for 5).
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude", "test_dude"], ["test_pledge"])
	# targets: the Pledge's targets.
	var targets: Array = state["combat"]["enemies"][0]["intent"]["target_ids"]
	assert_eq(targets.size(), rules["constants"]["MULTI_TARGET_COUNT"])
	assert_ne(targets[0], targets[1])
	# result: after everyone is ready.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	result = _ok(rules, result["state"], Fixtures.set_ready("p2", 0))
	result = _ok(rules, result["state"], Fixtures.set_ready("p3", 0))
	# hit: who took damage.
	var hit: Array = _of_type(result["events"], "damage_dealt").map(func(event: Dictionary) -> String: return event["target_id"])
	assert_eq(hit, targets, "each target hit once, in seat order")


## An area attack is aimed at every Dude and hits each of them.
func test_area_attack_in_fight() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# state: two Dudes against ai_area.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["ai_area"])
	assert_eq(state["combat"]["enemies"][0]["intent"]["target_ids"], ["p1", "p2"])
	# result: after both are ready.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	result = _ok(rules, result["state"], Fixtures.set_ready("p2", 0))
	assert_eq(_of_type(result["events"], "damage_dealt").map(func(event: Dictionary) -> String: return event["target_id"]), ["p1", "p2"])


## A target who passes out before the enemy acts is skipped, not re-aimed: the move happens
## (enemy_acted) but hits nobody. The next intent is aimed at a standing Dude.
func test_passed_out_target_is_skipped() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# state: two Dudes against a Pledge.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["test_pledge"])
	# target: who the Pledge aims at.
	var target: String = state["combat"]["enemies"][0]["intent"]["target_ids"][0]
	# other: the other Dude.
	var other: String = "p2" if target == "p1" else "p1"
	# out: the state with the target Passed Out before the enemy phase (test setup).
	var out: Dictionary = state.duplicate(true)
	out["dudes"][Bodies.dude_index(out, target)]["hp"] = 0
	out["dudes"][Bodies.dude_index(out, target)]["passed_out"] = true
	# result: after the other Dude is ready.
	var result: Dictionary = _ok(rules, out, Fixtures.set_ready(other, 0))
	assert_eq(_of_type(result["events"], "enemy_acted").size(), 1, "the move still happens")
	assert_eq(_of_type(result["events"], "damage_dealt"), [], "not re-aimed at the other Dude")
	assert_eq(result["state"]["combat"]["enemies"][0]["intent"]["target_ids"], [other], "next intent: a standing Dude")


## An enemy with no move it can choose shows no intent (null, no intent_set) and does nothing.
func test_enemy_without_choosable_move() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# started: a fight against ai_stuck and a Turtle.
	var started: Dictionary = Fight.start_fight(rules, Party.build_run_state(rules, SEED, ["test_dude"])["state"], ["ai_stuck", "test_turtle"])
	assert_eq(started["error"], "")
	# stuck: ai_stuck's state.
	var stuck: Dictionary = started["state"]["combat"]["enemies"][0]
	assert_eq([stuck["intent"], stuck["move_history"]], [null, []])
	assert_eq(_of_type(started["events"], "intent_set").size(), 1, "only the Turtle's")
	# result: after Ready.
	var result: Dictionary = _ok(rules, started["state"], Fixtures.set_ready("p1", 0))
	assert_eq(_of_type(result["events"], "enemy_acted").map(func(event: Dictionary) -> String: return event["enemy_uid"]),
		[started["state"]["combat"]["enemies"][1]["uid"]], "only the Turtle acts")


## Intents only move combat_ai (and Refresh only the shuffle streams): the other streams stay put.
func test_only_combat_ai_moves() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# state: two Dudes against ai_duo, which draws its move every turn and its target from two Dudes.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["ai_duo"])
	# result: after a turn.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	result = _ok(rules, result["state"], Fixtures.set_ready("p2", 0))
	assert_ne(result["state"]["rng"]["combat_ai"], state["rng"]["combat_ai"], "combat_ai drawn from")
	for key: String in ["map", "encounters", "side_quest", "rewards:p1", "rewards:p2", "dice:p1", "dice:p2"]:
		assert_eq(result["state"]["rng"][key], state["rng"][key], "%s untouched" % key)


## start_fight refuses a run without the combat_ai stream, or a ruleset without the AI's constants.
func test_check_start() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# run: a solo run outside a fight.
	var run: Dictionary = Party.build_run_state(rules, SEED, ["test_dude"])["state"]
	assert_eq(Intents.check_start(rules, run), "")
	# no_ai: the run without combat_ai.
	var no_ai: Dictionary = run.duplicate(true)
	no_ai["rng"].erase("combat_ai")
	assert_true(Fight.start_fight(rules, no_ai, ["ai_duo"])["error"].contains("combat_ai"))
	for name: String in Intents.NEEDED_CONSTANTS:
		# broken: a writable copy of the ruleset without one constant.
		var broken: Dictionary = rules.duplicate(true)
		broken["constants"].erase(name)
		assert_true(Fight.start_fight(broken, run, ["ai_duo"])["error"].contains(name), name)
	# zero: a ruleset with MULTI_TARGET_COUNT 0.
	var zero: Dictionary = rules.duplicate(true)
	zero["constants"]["MULTI_TARGET_COUNT"] = 0
	assert_ne(Intents.check_start(zero, run), "")
