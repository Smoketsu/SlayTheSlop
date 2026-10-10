## Tests for the solo Bro Meter (core/combat/bro_meter.gd) and use_bro_move with Tom's Bro Move,
## Chest Bump (core/combat/bro_move.gd), task 013. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const TomFixtures := preload("res://tests/core/ops/tom_fixtures.gd")
const Event := preload("res://core/schema/event.gd")
const RunState := preload("res://core/schema/run_state.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 777

## Hype given to Tom before the plays in these tests, so cost never gets in the way.
const PLENTY_OF_HYPE: int = 99


## Returns a fight of test_tom (one per seat in dude_ids' length) against the enemies, in turn 1's
## player phase, every Dude with PLENTY_OF_HYPE Hype.
## rules: the ruleset. dude_ids: Dude ids by seat. enemy_ids: enemy ids, left to right.
func _fight(rules: Dictionary, dude_ids: Array, enemy_ids: Array) -> Dictionary:
	# state: the fight.
	var state: Dictionary = Fixtures.fight(rules, SEED, dude_ids, enemy_ids)
	for dude: Dictionary in state["dudes"]:
		dude["hype"] = PLENTY_OF_HYPE
	return state


## Applies a request, asserting it is accepted, raises state_version by 1, and that every event and
## the new state are valid. Returns apply()'s result.
## rules: the ruleset. state: the state. request: the request.
func _ok(rules: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], "", "request %s should apply" % var_to_str(request))
	assert_eq(result["state"]["state_version"], state["state_version"] + 1)
	for event: Variant in result["events"]:
		assert_no_errors(Event.check(event), "event %s" % var_to_str(event))
	assert_no_errors(RunState.check(result["state"]), "state")
	return result


## Gives seat 0 a fresh Flex and plays it; returns apply()'s result.
## rules: the ruleset. state: the state, changed only by the added card.
func _flex(rules: Dictionary, state: Dictionary) -> Dictionary:
	# uid: the added Flex.
	var uid: String = Fixtures.give(state, 0, "tom_test_flex")
	return _ok(rules, state, Fixtures.play("p1", state["dudes"][0]["last_seq"] + 1, uid, ""))


## Returns the bro_meter_changed events, in order.
## events: an event list.
func _meter_events(events: Array) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event["type"] == "bro_meter_changed")


## Returns a use_bro_move request from p1 with the next seq, with target_id unless it is null.
## state: the state. target_id: the target, or null to leave the field out.
func _bro(state: Dictionary, target_id: Variant) -> Dictionary:
	# fields: the request's own fields.
	var fields: Dictionary = {} if target_id == null else {"target_id": target_id}
	return Fixtures.request("use_bro_move", "p1", state["dudes"][0]["last_seq"] + 1, fields)


## Solo: +1 on the 3rd and the 6th card of a turn (BRO_METER_SOLO_CARDS = 3), nothing on the others.
func test_solo_gain_every_third_card() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: a solo fight.
	var state: Dictionary = _fight(rules, ["test_tom"], ["test_hitter"])
	# gains: bro_meter_changed events per card, 1st to 6th.
	var gains: Array = []
	for i: int in 6:
		# result: one more Flex.
		var result: Dictionary = _flex(rules, state)
		gains.append(_meter_events(result["events"]))
		state = result["state"]
	assert_eq(rules["constants"]["BRO_METER_SOLO_CARDS"], 3)
	assert_eq(gains, [[], [], [Event.make("bro_meter_changed", {"delta": 1, "bro_meter": 1})], [], [],
		[Event.make("bro_meter_changed", {"delta": 1, "bro_meter": 2})]])
	assert_eq(state["bro_meter"], 2)


## The count restarts each turn: 2 cards, Ready, 1 card is no point.
func test_count_restarts_each_turn() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: two Flexes, then Ready, then one more.
	var state: Dictionary = _fight(rules, ["test_tom"], ["test_hitter"])
	state = _flex(rules, state)["state"]
	state = _flex(rules, state)["state"]
	state = _ok(rules, state, Fixtures.set_ready("p1", state["dudes"][0]["last_seq"] + 1))["state"]
	state["dudes"][0]["hype"] = PLENTY_OF_HYPE
	# result: the first card of turn 2.
	var result: Dictionary = _flex(rules, state)
	assert_eq(_meter_events(result["events"]), [])
	assert_eq(result["state"]["bro_meter"], 0)


## The meter stops at BRO_METER_MAX (10): a 3rd card at 10 changes nothing and emits nothing.
func test_capped_at_max() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: a full meter.
	var state: Dictionary = _fight(rules, ["test_tom"], ["test_hitter"])
	state["bro_meter"] = rules["constants"]["BRO_METER_MAX"]
	state = _flex(rules, state)["state"]
	state = _flex(rules, state)["state"]
	# result: the 3rd card.
	var result: Dictionary = _flex(rules, state)
	assert_eq(_meter_events(result["events"]), [])
	assert_eq(result["state"]["bro_meter"], 10, "BRO_METER_MAX")


## Co-op (party_size 2): the solo rule does not apply, and the co-op rule is not built yet.
func test_no_solo_gain_in_co_op() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: two Toms.
	var state: Dictionary = _fight(rules, ["test_tom", "test_tom"], ["test_hitter"])
	for i: int in 3:
		state = _flex(rules, state)["state"]
	assert_eq(state["bro_meter"], 0)


## use_bro_move below BRO_METER_MAX is not_ready, and nothing changes.
func test_bro_move_not_ready() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: a meter at 9.
	var state: Dictionary = _fight(rules, ["test_tom"], ["test_hitter"])
	state["bro_meter"] = rules["constants"]["BRO_METER_MAX"] - 1
	# result: the attempt.
	var result: Dictionary = Core.apply(rules, state, _bro(state, "e11"))
	assert_eq(result["reject"], "not_ready")
	assert_true(is_same(result["state"], state), "the same state comes back")
	assert_eq(result["events"], [])


## Chest Bump: "Deal 20 damage. Break 1 arm on every enemy". At 10 the meter empties, the Bro
## Move is played for free (no Hype, not from the hand, no card played), as attack damage.
func test_chest_bump() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: a full meter; Hitter (60 HP) and Dummy (20 HP), both 2 arms.
	var state: Dictionary = _fight(rules, ["test_tom"], ["test_hitter", "test_dummy"])
	state["bro_meter"] = rules["constants"]["BRO_METER_MAX"]
	# dude: Tom before.
	var dude: Dictionary = state["dudes"][0].duplicate(true)
	# result: Chest Bump at the Hitter.
	var result: Dictionary = _ok(rules, state, _bro(state, "e11"))
	assert_eq(result["events"], [
		Event.make("bro_meter_changed", {"delta": -10, "bro_meter": 0}),
		Event.make("bro_move_used", {"player_id": "p1", "def_id": "tom_test_chest_bump", "target_id": "e11"}),
		Event.make("damage_dealt", {"source_id": "p1", "target_id": "e11", "amount": 20, "blocked": 0, "hp_lost": 20}),
		Event.make("status_changed", {"target_id": "e11", "status": "broken_arm", "delta": 1, "stacks": 1}),
		Event.make("status_changed", {"target_id": "e12", "status": "broken_arm", "delta": 1, "stacks": 1}),
	])
	# after: Tom afterwards.
	var after: Dictionary = result["state"]["dudes"][0]
	assert_eq(result["state"]["bro_meter"], 0, "emptied")
	assert_eq(result["state"]["combat"]["enemies"][0]["hp"], 60 - 20, "20 damage")
	assert_eq([after["hype"], after["cards_played_this_turn"], after["hand"]],
		[dude["hype"], dude["cards_played_this_turn"], dude["hand"]], "free, and not a card from the hand")
	# exposed: Bro Moves are attack damage (G3), so Exposed applies: 20 x 1.5 = 30.
	var exposed: Dictionary = _fight(rules, ["test_tom"], ["test_hitter"])
	exposed["bro_meter"] = rules["constants"]["BRO_METER_MAX"]
	exposed["combat"]["enemies"][0]["statuses"] = {"exposed": 1}
	result = _ok(rules, exposed, _bro(exposed, "e11"))
	assert_eq(result["state"]["combat"]["enemies"][0]["hp"], 60 - 30)


## Chest Bump needs an enemy: a missing or dead target is bad_target. A Bro Move that kills the
## last enemy ends the fight.
func test_chest_bump_target_and_win() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: a full meter against a Dummy at 20 HP.
	var state: Dictionary = _fight(rules, ["test_tom"], ["test_dummy"])
	state["bro_meter"] = rules["constants"]["BRO_METER_MAX"]
	assert_eq(Core.apply(rules, state, _bro(state, null))["reject"], "bad_target", "no target_id")
	assert_eq(Core.apply(rules, state, _bro(state, "e99"))["reject"], "bad_target", "no such enemy")
	# result: the Bro Move kills the Dummy.
	var result: Dictionary = _ok(rules, state, _bro(state, "e11"))
	assert_eq(result["state"]["combat"]["result"], "won")
	assert_eq(result["events"][-1], Event.make("fight_ended", {"result": "won"}))
