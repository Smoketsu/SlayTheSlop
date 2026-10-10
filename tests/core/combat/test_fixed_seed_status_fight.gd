## Fixed-seed fight with statuses (task 009): a Tom-like deck (Arm Bar, Well, Actually, Advice ...)
## against a 2-armed Hitter and an armless Slime, played by a fixed bot policy. The same seed always
## gives the same requests, the same events and a recorded final state; every event and state on
## the way passes the schema checks and survives a snapshot round trip. Lane: core (Agent A).
##
## Bot policy (deterministic): each turn, play the first card in hand order that Core.validate()
## accepts, aimed at the leftmost enemy when it needs an enemy target; repeat until none is legal;
## then set Ready.
##
## If a rules change alters this fight on purpose, re-record the RECORDED values (the failure
## messages print the new ones) and say why in the PR. An unexplained change means determinism broke.
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Play := preload("res://core/combat/play.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")

## The run seed of the fight.
const SEED: int = 9009

## Most requests the bot may send before the test gives up (a guard against an endless fight).
const MAX_REQUESTS: int = 400

## Recorded outcome on Godot 4.7.2-stable: [result, final turn, applied requests].
const RECORDED: Array = ["won", 8, 32]

## Snapshot.state_hash of the final state, recorded on Godot 4.7.2-stable.
## Re-recorded by task 021: SCHEMA_VERSION 5 and the two new combat fields change the bytes; the
## fight itself is the same.
## Re-recorded again by task 017 (SCHEMA_VERSION 6, enemy haul and Brew-drop fields; same fight).
const FINAL_HASH: String = "82bfc93a0a53b5e0b5500dc25d4dd5e114836fe402c277883f10d0572e450d5c"


## Returns the bot's next request for p1 in this state (see the file header).
## rules: the ruleset. state: a state in the player phase. seq: the seq to use.
func _next_request(rules: Dictionary, state: Dictionary, seq: int) -> Dictionary:
	# dude: p1.
	var dude: Dictionary = state["dudes"][0]
	for uid: String in dude["hand"]:
		# card: the card's definition.
		var card: Dictionary = Play.card_def(rules, dude, uid)
		# target_id: the leftmost enemy for enemy-target cards, otherwise "".
		var target_id: String = state["combat"]["enemies"][0]["uid"] if card.get("target") == "enemy" else ""
		# request: the candidate play.
		var request: Dictionary = Fixtures.play("p1", seq, uid, target_id)
		if Core.validate(rules, state, request) == "":
			return request
	return Fixtures.set_ready("p1", seq)


## Plays the whole fight and returns {"state": the final state, "events": every event in order,
## "requests": how many were applied}.
func _replay() -> Dictionary:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: the fight as it goes.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_breaker"], ["test_hitter", "test_slime"])
	# events: every event from every applied request.
	var events: Array = []
	# seq: the next request's seq, which is also the number applied so far.
	var seq: int = 0
	while state["combat"]["phase"] == "player" and seq < MAX_REQUESTS:
		# result: what apply() returned for the bot's request.
		var result: Dictionary = Core.apply(rules, state, _next_request(rules, state, seq))
		assert_eq(result["reject"], "", "request %d" % seq)
		if result["reject"] != "":
			break
		for event: Variant in result["events"]:
			assert_no_errors(Event.check(event), "event at request %d" % seq)
		assert_no_errors(RunState.check(result["state"]), "state at request %d" % seq)
		# loaded: the state after a snapshot round trip.
		var loaded: Dictionary = Snapshot.from_bytes(Snapshot.to_bytes(result["state"]))
		assert_eq(loaded["state"], result["state"], "snapshot round trip at request %d" % seq)
		events.append_array(result["events"])
		state = result["state"]
		seq += 1
	return {"state": state, "events": events, "requests": seq}


## The fight ends as recorded, and on the way it exercised every status rule this task added.
func test_status_fight_ends_in_recorded_state() -> void:
	# end: the replayed fight.
	var end: Dictionary = _replay()
	# state: its final state.
	var state: Dictionary = end["state"]
	assert_eq([state["combat"]["result"], state["combat"]["turn"], end["requests"]], RECORDED, "recorded outcome")
	assert_eq(Snapshot.state_hash(state), FINAL_HASH, "final state hash (re-record only for an intended rules change)")
	# types: every event type that occurred.
	var types: Dictionary = {}
	for event: Dictionary in end["events"]:
		types[event["type"]] = true
	for wanted: String in ["status_changed", "grossed_out", "enemy_skipped", "armless"]:
		assert_true(types.has(wanted), "the fight includes a %s event" % wanted)


## Replaying the same seed twice gives byte-identical states and identical events.
func test_status_fight_replay_is_identical() -> void:
	# first: the first replay.
	var first: Dictionary = _replay()
	# second: the second replay.
	var second: Dictionary = _replay()
	assert_eq(Snapshot.to_bytes(first["state"]), Snapshot.to_bytes(second["state"]), "identical snapshot bytes")
	assert_eq(first["events"], second["events"], "identical events")
