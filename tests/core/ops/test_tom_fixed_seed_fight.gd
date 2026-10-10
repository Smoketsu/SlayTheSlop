## Fixed-seed fight with Tom-like fixture cards (task 013). Lane: core (Agent A).
##
## test_tom_all (one of each of Tom's 14 GDD cards, Bro Move Chest Bump) fights the Turtle (gains
## Guard each turn) and Flurry (3 hits) on SEED. A fixed policy, not a recorded script, picks every
## request, so no uids are hand-written. On this seed the fight uses the Bro Meter, Chest Bump and two
## Power triggers; Chrome Dome is never played (its thorns are covered by test_tom_cards.gd). Every
## event and state on the way is checked, every state survives a snapshot round trip, a second
## replay must give identical snapshot bytes, and the end is recorded.
##
## If a rules change alters this fight on purpose, re-record RECORDED (print the outcome) and
## FINAL_HASH (the failure message prints it) and say why in the PR.
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const TomFixtures := preload("res://tests/core/ops/tom_fixtures.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")

## The run seed of the fight.
const SEED: int = 20261013

## Most requests the policy may send before the test gives up (a safety stop, not a rule).
const MAX_REQUESTS: int = 300

## Recorded outcome on Godot 4.7.2-stable: [result, final turn, applied requests, bro_move_used
## events, power_triggered events, thorns_changed events, Tom's final HP].
const RECORDED: Array = ["won", 5, 18, 1, 2, 0, 74]

## Snapshot.state_hash of the final state, recorded on Godot 4.7.2-stable. Re-recorded by task 021
## (SCHEMA_VERSION 5, two new combat fields), task 017 (6) and task 019 (7); RECORDED still holds.
const FINAL_HASH: String = "0d54fed1a70cb3cb75c57b6234b02fa974f783744d56071b5c6333993bf6665a"


## Returns the request the policy sends next: the Bro Move when it is legal (aimed at the first
## enemy), else the first card in hand order that validate() accepts (aimed at the first enemy when
## it needs one), else Ready.
## rules: the ruleset. state: the state, in the player phase.
func _next_request(rules: Dictionary, state: Dictionary) -> Dictionary:
	# seq: the next seq.
	var seq: int = state["dudes"][0]["last_seq"] + 1
	# first: the leftmost enemy's uid.
	var first: String = state["combat"]["enemies"][0]["uid"]
	# bro: the Bro Move request.
	var bro: Dictionary = Fixtures.request("use_bro_move", "p1", seq, {"target_id": first})
	if Core.validate(rules, state, bro) == "":
		return bro
	for uid: String in state["dudes"][0]["hand"]:
		for target_id: String in [first, ""]:
			# play: one candidate.
			var play: Dictionary = Fixtures.play("p1", seq, uid, target_id)
			if Core.validate(rules, state, play) == "":
				return play
	return Fixtures.set_ready("p1", seq)


## Plays the whole fight. Returns {"state": the final state, "requests": applied requests,
## "events": every event in order}.
func _replay() -> Dictionary:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: the fight as it goes.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_tom_all"], ["test_turtle", "test_flurry"])
	# Test setup: the shared meter starts one point short (as if carried from earlier fights), so the
	# first 3-card turn fills it and the policy uses Chest Bump.
	state["bro_meter"] = rules["constants"]["BRO_METER_MAX"] - 1
	# events: every event.
	var events: Array = []
	# requests: requests applied so far.
	var requests: int = 0
	while state["combat"]["phase"] == "player" and requests < MAX_REQUESTS:
		# result: one request applied.
		var result: Dictionary = Core.apply(rules, state, _next_request(rules, state))
		assert_eq(result["reject"], "", "the policy only sends legal requests")
		if result["reject"] != "":
			break
		for event: Variant in result["events"]:
			assert_no_errors(Event.check(event), "event %s" % var_to_str(event))
		assert_no_errors(RunState.check(result["state"]), "state after request %d" % requests)
		# loaded: the state after a snapshot round trip.
		var loaded: Dictionary = Snapshot.from_bytes(Snapshot.to_bytes(result["state"]))
		assert_true(loaded["ok"], "snapshot loads after request %d" % requests)
		assert_eq(loaded["state"], result["state"], "snapshot round trip")
		events.append_array(result["events"])
		state = result["state"]
		requests += 1
	return {"state": state, "requests": requests, "events": events}


## Returns how many events of this type there are, optionally only those whose field equals value.
## events: an event list. type: the event type. field: a field to match, or "". value: its value.
func _count(events: Array, type: String, field: String = "", value: Variant = null) -> int:
	return events.filter(func(event: Dictionary) -> bool:
		return event["type"] == type and (field == "" or event[field] == value)).size()


## The fight ends as recorded, and a second replay is byte-identical.
func test_tom_fight_ends_in_recorded_state() -> void:
	# end: the first replay.
	var end: Dictionary = _replay()
	# state: its final state.
	var state: Dictionary = end["state"]
	# outcome: what to compare with RECORDED.
	var outcome: Array = [state["combat"]["result"], state["combat"]["turn"], end["requests"],
		_count(end["events"], "bro_move_used"), _count(end["events"], "power_triggered"),
		_count(end["events"], "thorns_changed"), state["dudes"][0]["hp"]]
	assert_eq(outcome, RECORDED, "recorded outcome")
	assert_eq(Snapshot.state_hash(state), FINAL_HASH, "final state hash (re-record only for an intended rules change)")
	assert_eq(Snapshot.to_bytes(_replay()["state"]), Snapshot.to_bytes(state), "a second replay is identical")
