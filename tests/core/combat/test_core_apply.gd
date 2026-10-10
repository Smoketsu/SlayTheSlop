## Tests for core/core.gd apply(): every reject code, rejects changing nothing, state_version, and
## apply() never changing its inputs (task 007). Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")
const Request := preload("res://core/schema/request.gd")
const Party := preload("res://core/combat/party.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 7007


## Returns a solo fight against a Dummy and a Turtle in turn 1's player phase.
## rules: the test ruleset.
func _solo(rules: Dictionary) -> Dictionary:
	return Fixtures.fight(rules, SEED, ["test_dude"], ["test_dummy", "test_turtle"])


## Asserts that request is refused with reason, and that the state comes back as the same object,
## strictly equal to a copy taken before, with no events.
## rules: the ruleset. state: the state to apply to. request: the request. reason: the expected code.
func _assert_rejected(rules: Dictionary, state: Dictionary, request: Variant, reason: String) -> void:
	# before: a deep copy of the state, to compare against.
	var before: Dictionary = state.duplicate(true)
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], reason, "reject reason for %s" % var_to_str(request))
	assert_true(is_same(result["state"], state), reason + ": rejected state must be the state passed in")
	assert_eq(result["state"], before, reason + ": rejected state must be unchanged")
	assert_eq(result["events"], [], reason + ": rejected request has no events")
	assert_true(Request.REJECT_REASONS.has(reason), reason + " is a known reject code")


## Asserts that request is applied: no reject, state_version + 1, the sender's last_seq = seq,
## every event valid and the new state valid. Returns the result.
## rules: the ruleset. state: the state to apply to. request: the request.
func _assert_applied(rules: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], "", "request %s should apply" % var_to_str(request))
	assert_eq(result["state"]["state_version"], state["state_version"] + 1, "state_version rises by exactly 1")
	for event: Variant in result["events"]:
		assert_no_errors(Event.check(event), "event %s" % var_to_str(event))
	assert_no_errors(RunState.check(result["state"]), "state after %s" % request["type"])
	return result


## The fixtures build and the started fight is a valid state in the player phase.
func test_fixture_fight_starts() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	assert_false(rules.is_empty(), "fixture ruleset builds")
	# state: the started fight.
	var state: Dictionary = _solo(rules)
	assert_false(state.is_empty(), "fight starts")
	assert_no_errors(RunState.check(state), "started fight")
	assert_eq(state["combat"]["phase"], "player")


## Malformed requests are bad_request: not a Dictionary, unknown type, missing or mistyped field,
## an extra field.
func test_bad_request() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight in the player phase.
	var state: Dictionary = _solo(rules)
	_assert_rejected(rules, state, "play", "bad_request")
	_assert_rejected(rules, state, Fixtures.request("dance", "p1", 0), "bad_request")
	_assert_rejected(rules, state, {"type": "set_ready", "player_id": "p1", "seq": 0}, "bad_request")
	_assert_rejected(rules, state, {"type": "set_ready", "player_id": "p1", "seq": 0.0, "ready": true}, "bad_request")
	# extra: a set_ready with a field it does not have.
	var extra: Dictionary = Fixtures.set_ready("p1", 0)
	extra["card_uid"] = "c1"
	_assert_rejected(rules, state, extra, "bad_request")


## A player id with no Dude is unknown_player.
func test_unknown_player() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	_assert_rejected(rules, _solo(rules), Fixtures.set_ready("p2", 0), "unknown_player")


## seq must be above last_seq: an applied seq cannot be reused, and neither can a lower one.
## A rejected request does not move last_seq, so its seq may be used again.
func test_stale_seq() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight in the player phase.
	var state: Dictionary = _solo(rules)
	_assert_rejected(rules, state, Fixtures.set_ready("p1", -1), "stale_seq")
	# after: the state after p1 un-readies with seq 3 (applied).
	var after: Dictionary = _assert_applied(rules, state, Fixtures.set_ready("p1", 3, false))["state"]
	assert_eq(after["dudes"][0]["last_seq"], 3, "applied request sets last_seq")
	_assert_rejected(rules, after, Fixtures.set_ready("p1", 3, false), "stale_seq")
	_assert_rejected(rules, after, Fixtures.set_ready("p1", 2, false), "stale_seq")
	# rejected: a request that is refused (not in hand) with seq 4.
	var rejected: Dictionary = Core.apply(rules, after, Fixtures.play("p1", 4, "c999", ""))
	assert_eq(rejected["reject"], "not_in_hand")
	assert_eq(rejected["state"]["dudes"][0]["last_seq"], 3, "rejected request leaves last_seq")
	_assert_applied(rules, after, Fixtures.set_ready("p1", 4, false))


## Requests outside the player phase, outside a fight, or of a non-fight type are wrong_phase.
func test_wrong_phase() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight in the player phase.
	var state: Dictionary = _solo(rules)
	_assert_rejected(rules, state, Fixtures.request("pick_dude", "p1", 0, {"dude_id": "test_dude"}), "wrong_phase")
	_assert_rejected(rules, state, Fixtures.request("vote_node", "p1", 0, {"node_id": "n1"}), "wrong_phase")
	_assert_rejected(rules, state, Fixtures.request("choose_reward", "p1", 0, {"reward_id": "r", "choice_index": 0}), "wrong_phase")
	# no_fight: a run with no fight.
	var no_fight: Dictionary = Party.build_run_state(rules, SEED, ["test_dude"])["state"]
	_assert_rejected(rules, no_fight, Fixtures.set_ready("p1", 0), "wrong_phase")
	# over: the fight after it ended.
	var over: Dictionary = state.duplicate(true)
	over["combat"]["phase"] = "over"
	over["combat"]["result"] = "won"
	_assert_rejected(rules, over, Fixtures.play("p1", 0, over["dudes"][0]["hand"][0], "e11"), "wrong_phase")


## A Passed Out Dude cannot act.
func test_passed_out() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a two-Dude fight with p2 Passed Out.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["test_dummy"])
	state["dudes"][1]["hp"] = 0
	state["dudes"][1]["passed_out"] = true
	_assert_rejected(rules, state, Fixtures.set_ready("p2", 0), "passed_out")
	_assert_rejected(rules, state, Fixtures.play("p2", 0, state["dudes"][1]["hand"][0], ""), "passed_out")


## play_card's own checks: not_in_hand, unplayable (cost -1, cost "x", unknown op, bad op field,
## crunch, unapplied upgrade), no_hype, bad_target.
func test_play_card_rejects() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight in the player phase, with test cards added to the hand.
	var state: Dictionary = _solo(rules)
	# enemy: the Dummy's uid.
	var enemy: String = state["combat"]["enemies"][0]["uid"]
	# in_draw: a card that is in the draw pile, not the hand.
	var in_draw: String = state["dudes"][0]["draw_pile"][0]
	_assert_rejected(rules, state, Fixtures.play("p1", 0, in_draw, enemy), "not_in_hand")
	_assert_rejected(rules, state, Fixtures.play("p1", 0, "c999", enemy), "not_in_hand")
	for def_id: String in ["junk_test_dud", "neutral_test_x", "neutral_test_mystery", "neutral_test_typo"]:
		_assert_rejected(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, def_id), enemy), "unplayable")
	# jab: a normal attack, used for the crunch, Hype and target cases.
	var jab: String = Fixtures.give(state, 0, "neutral_test_jab")
	# crunch: jab with crunch true.
	var crunch: Dictionary = Fixtures.play("p1", 0, jab, enemy)
	crunch["crunch"] = true
	_assert_rejected(rules, state, crunch, "unplayable")
	# lifted: an upgraded copy of a card with an upgrade.
	var lifted: String = Fixtures.give(state, 0, "neutral_test_lifted")
	state["dudes"][0]["cards"][lifted]["upgraded"] = true
	_assert_rejected(rules, state, Fixtures.play("p1", 0, lifted, enemy), "unplayable")
	_assert_rejected(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, "neutral_test_big"), enemy), "no_hype")
	_assert_rejected(rules, state, Fixtures.play("p1", 0, jab, ""), "bad_target")
	_assert_rejected(rules, state, Fixtures.play("p1", 0, jab, "e999"), "bad_target")
	_assert_rejected(rules, state, Fixtures.play("p1", 0, jab, "p1"), "bad_target")
	# brace: a self card; an enemy target is not legal for it.
	var brace: String = Fixtures.give(state, 0, "neutral_test_brace")
	_assert_rejected(rules, state, Fixtures.play("p1", 0, brace, enemy), "bad_target")
	_assert_rejected(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, "neutral_test_sweep"), enemy), "bad_target")
	_assert_rejected(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, "neutral_test_freebie"), "p1"), "bad_target")
	_assert_rejected(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, "neutral_test_spot"), "p1"), "bad_target")
	# hype: no Hype left, so a cost-1 card is no_hype even with a good target.
	state["dudes"][0]["hype"] = 0
	_assert_rejected(rules, state, Fixtures.play("p1", 0, jab, enemy), "no_hype")


## A target that died to an earlier card is bad_target, and its Hype is not spent (GDD "How a card
## gets played in co-op").
func test_dead_target_is_bad_target() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight with the Dummy at 1 HP and two Jabs in hand.
	var state: Dictionary = _solo(rules)
	state["combat"]["enemies"][0]["hp"] = 1
	# enemy: the Dummy's uid.
	var enemy: String = state["combat"]["enemies"][0]["uid"]
	# first: the Jab that kills it.
	var first: String = Fixtures.give(state, 0, "neutral_test_jab")
	# second: the Jab aimed at it afterwards.
	var second: String = Fixtures.give(state, 0, "neutral_test_jab")
	# after: the state after the first Jab killed the Dummy.
	var after: Dictionary = _assert_applied(rules, state, Fixtures.play("p1", 0, first, enemy))["state"]
	_assert_rejected(rules, after, Fixtures.play("p1", 1, second, enemy), "bad_target")
	assert_eq(after["dudes"][0]["hype"], state["dudes"][0]["hype"] - 1, "only the first card's Hype is spent")


## use_brew: empty_slot for an empty slot; a filled slot is unplayable until Brews exist.
## use_bro_move: not_ready below BRO_METER_MAX; at max it applies since task 013 (its tests are in
## tests/core/ops/test_bro_meter.gd), but a bad target is bad_target.
func test_brew_and_bro_move_rejects() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight in the player phase.
	var state: Dictionary = _solo(rules)
	_assert_rejected(rules, state, Fixtures.request("use_brew", "p1", 0, {"slot": 0, "target_id": ""}), "empty_slot")
	_assert_rejected(rules, state, Fixtures.request("use_brew", "p1", 0, {"slot": -1, "target_id": ""}), "empty_slot")
	_assert_rejected(rules, state, Fixtures.request("use_bro_move", "p1", 0), "not_ready")
	# filled: the same fight with a Brew held and a full Bro Meter.
	var filled: Dictionary = state.duplicate(true)
	filled["dudes"][0]["brew_slots"] = 1
	filled["dudes"][0]["brews"] = ["test_brew"]
	filled["bro_meter"] = rules["constants"]["BRO_METER_MAX"]
	_assert_rejected(rules, filled, Fixtures.request("use_brew", "p1", 0, {"slot": 0, "target_id": ""}), "unplayable")
	_assert_rejected(rules, filled, Fixtures.request("use_bro_move", "p1", 0, {"target_id": "e99"}), "bad_target")
	assert_eq(Core.apply(rules, filled, Fixtures.request("use_bro_move", "p1", 0))["reject"], "", "at max it applies")


## apply() changes none of its arguments, whether the request is applied or rejected, and an
## applied request returns a different state object.
func test_apply_never_mutates_inputs() -> void:
	# rules: the test ruleset (read-only, so any write to it would also be an engine error).
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight in the player phase.
	var state: Dictionary = _solo(rules)
	# enemy: the Dummy's uid.
	var enemy: String = state["combat"]["enemies"][0]["uid"]
	# jab: a Jab in hand.
	var jab: String = Fixtures.give(state, 0, "neutral_test_jab")
	for request: Dictionary in [Fixtures.play("p1", 0, jab, enemy), Fixtures.set_ready("p1", 0), Fixtures.play("p1", 0, jab, "")]:
		# state_before: a deep copy of the state taken before the call.
		var state_before: Dictionary = state.duplicate(true)
		# request_before: a deep copy of the request taken before the call.
		var request_before: Dictionary = request.duplicate(true)
		# result: what apply() returned.
		var result: Dictionary = Core.apply(rules, state, request)
		assert_eq(state, state_before, "state unchanged by %s" % request["type"])
		assert_eq(request, request_before, "request unchanged by %s" % request["type"])
		if result["reject"] == "":
			assert_false(is_same(result["state"], state), "applied request returns a new state")
			assert_false(is_same(result["state"]["dudes"], state["dudes"]), "new state shares no lists with the old")


## The client's gateway holds an object: Core.new().apply() gives the same result as Core.apply().
func test_apply_through_an_instance() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight in the player phase.
	var state: Dictionary = _solo(rules)
	# gateway: an instance, as client/fight/fight_screen.gd uses one.
	var gateway: RefCounted = Core.new()
	assert_eq(gateway.apply(rules, state, Fixtures.set_ready("p1", 0)), Core.apply(rules, state, Fixtures.set_ready("p1", 0)))
