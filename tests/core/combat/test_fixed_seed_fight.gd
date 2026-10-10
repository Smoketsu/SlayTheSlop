## Fixed-seed scripted fight (task 007): a seed and a request list always give the same fight,
## ending in a recorded state. Replaying it twice gives identical snapshot bytes, and every state on
## the way survives a snapshot round trip. Lane: core (Agent A).
##
## If a rules change alters this fight on purpose, re-record FINAL_HASH (the failure message prints
## the new one) and say why in the PR. An unexplained change means determinism broke.
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")

## The run seed of the scripted fight.
const SEED: int = 20261010

## The scripted requests from p1, in order: [kind ("play" or "ready"), card_uid, target_id, seq,
## expected reject ("" = applied)]. Recorded from a simple bot on SEED; includes a duplicate seq,
## a bad target and a request after the fight ended. The fight is won in turn 4.
## Task 011 shortened it: G30 (enemy Guard drops to 0 at the start of its own action) stops the
## Turtle's Guard from piling up, so the Turtle dies in turn 4 instead of turn 5. The first 18
## requests are unchanged; the old turn-5 requests were cut and the last request (after the fight
## ended) is now step 18.
const SCRIPT: Array = [
	["play", "c10", "", 0, ""],
	["play", "c10", "", 0, "stale_seq"],
	["play", "c4", "e99", 1, "bad_target"],
	["play", "c4", "e11", 2, ""],
	["play", "c3", "e11", 3, ""],
	["play", "c6", "", 4, ""],
	["ready", "", "", 5, ""],
	["play", "c5", "", 6, ""],
	["play", "c7", "", 7, ""],
	["play", "c2", "e11", 8, ""],
	["ready", "", "", 9, ""],
	["play", "c3", "e11", 10, ""],
	["play", "c6", "", 11, ""],
	["play", "c9", "", 12, ""],
	["ready", "", "", 13, ""],
	["play", "c10", "", 14, ""],
	["play", "c2", "e12", 15, ""],
	["play", "c1", "e12", 16, ""],
	["play", "c4", "e12", 17, ""],
	["ready", "", "", 18, "wrong_phase"],
]

## Snapshot.state_hash of the final state, recorded on Godot 4.7.2-stable. Task 013 re-recorded it
## twice: for dude_state.powers / thorns and SCHEMA_VERSION 4, then because the solo Bro Meter now
## fills on every 3rd card in a turn (bro_meter differs; with that gain switched off the hash was
## unchanged). The fight is still won in turn 4.
const FINAL_HASH: String = "b3ccc860adc9d2b002f6521c42e614b40e83a0f34b4c90b0cbf934bb1266b969"


## Plays the whole fight: start_fight on SEED, then every SCRIPT request, checking each step.
## Returns {"state": the final state, "events": every event in order}.
func _replay() -> Dictionary:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: the fight as it goes.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_dummy", "test_turtle"])
	# events: every event from every applied request.
	var events: Array = []
	for step: Array in SCRIPT:
		# request: this step's request.
		var request: Dictionary = Fixtures.play("p1", step[3], step[1], step[2]) if step[0] == "play" \
			else Fixtures.set_ready("p1", step[3])
		# result: what apply() returned.
		var result: Dictionary = Core.apply(rules, state, request)
		assert_eq(result["reject"], step[4], "step %s" % str(step))
		if result["reject"] == "":
			assert_eq(result["state"]["state_version"], state["state_version"] + 1, "state_version + 1")
		else:
			assert_true(is_same(result["state"], state), "rejected: same state")
		for event: Variant in result["events"]:
			assert_no_errors(Event.check(event), "event at %s" % str(step))
		assert_no_errors(RunState.check(result["state"]), "state at %s" % str(step))
		# loaded: the state after a snapshot round trip.
		var loaded: Dictionary = Snapshot.from_bytes(Snapshot.to_bytes(result["state"]))
		assert_true(loaded["ok"], "snapshot loads at %s: %s" % [str(step), loaded["error"]])
		assert_eq(loaded["state"], result["state"], "snapshot round trip at %s" % str(step))
		events.append_array(result["events"])
		state = result["state"]
	return {"state": state, "events": events}


## The fight ends as recorded: won in turn 4, with the recorded hash.
func test_fight_ends_in_recorded_state() -> void:
	# end: the replayed fight.
	var end: Dictionary = _replay()
	# state: its final state.
	var state: Dictionary = end["state"]
	assert_eq([state["combat"]["phase"], state["combat"]["result"], state["combat"]["turn"]], ["over", "won", 4])
	assert_eq(state["state_version"], 17, "17 applied requests")
	assert_eq(state["dudes"][0]["last_seq"], 17)
	assert_eq(end["events"][-1], Event.make("fight_ended", {"result": "won"}))
	assert_true(end["events"].has(Event.make("deck_shuffled", {"player_id": "p1"})), "the discard pile was reshuffled (G8)")
	# final_hash: the final state's hash.
	var final_hash: String = Snapshot.state_hash(state)
	assert_eq(final_hash, FINAL_HASH, "final state hash (re-record only for an intended rules change)")


## Replaying the same seed and requests twice gives byte-identical states and identical events.
func test_replay_is_identical() -> void:
	# first: the first replay.
	var first: Dictionary = _replay()
	# second: the second replay.
	var second: Dictionary = _replay()
	assert_eq(Snapshot.to_bytes(first["state"]), Snapshot.to_bytes(second["state"]), "identical snapshot bytes")
	assert_eq(first["events"], second["events"], "identical events")
