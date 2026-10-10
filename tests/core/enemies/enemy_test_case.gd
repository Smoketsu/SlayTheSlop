## Shared helpers for the enemy behavior tests (tasks 017 and 019). Lane: core (Agent A).
##
## Not a test file itself (no test_ prefix); the test files extend it. Every request goes through the
## real Core.apply(), and every result is checked against the shared schemas and a snapshot round trip.
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const Fight := preload("res://core/combat/fight.gd")
const Party := preload("res://core/combat/party.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const EnemyFixtures := preload("res://tests/core/enemies/enemy_fixtures.gd")


## Applies a request, asserting it is accepted and that every event and the new state pass the
## schema checks and survive a snapshot round trip. Returns apply()'s result.
## rules: the ruleset. state: the state. request: the request.
func ok(rules: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], "", "request %s should apply" % var_to_str(request))
	assert_valid(result["state"], result["events"])
	return result


## Asserts that every event passes event.gd check(), the state passes run_state.check(), and a
## snapshot of it loads back identical.
## state: a run state. events: an event list.
func assert_valid(state: Dictionary, events: Array) -> void:
	for event: Variant in events:
		assert_no_errors(Event.check(event), "event %s" % var_to_str(event))
	assert_no_errors(RunState.check(state), "state")
	# loaded: the state after a snapshot round trip.
	var loaded: Dictionary = Snapshot.from_bytes(Snapshot.to_bytes(state))
	assert_eq(loaded["state"], state, "snapshot round trip")


## Gives the solo player a new copy of a card and plays it. Returns apply()'s result (asserted accepted).
## rules: the ruleset. state: the state, in the player phase; not changed (a copy gets the card).
## seq: the request's seq. def_id: the card to give and play. target_id: its target, or "".
func play(rules: Dictionary, state: Dictionary, seq: int, def_id: String, target_id: String) -> Dictionary:
	# given: a copy of state holding the new card.
	var given: Dictionary = state.duplicate(true)
	# uid: the new card's uid.
	var uid: String = Fixtures.give(given, 0, def_id)
	return ok(rules, given, Fixtures.play("p1", seq, uid, target_id))


## Presses Ready for the solo player. Returns apply()'s result (asserted accepted).
## rules: the ruleset. state: the state, in the player phase. seq: the request's seq.
func ready(rules: Dictionary, state: Dictionary, seq: int) -> Dictionary:
	return ok(rules, state, Fixtures.set_ready("p1", seq))


## Returns the events of one type, in order.
## events: an event list. type: the event type wanted.
func of_type(events: Array, type: String) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event["type"] == type)


## Returns the event types of a list, in order.
## events: an event list.
func types(events: Array) -> Array:
	return events.map(func(event: Dictionary) -> String: return event["type"])


## Returns the def_id of every enemy in the fight, left to right.
## state: a run state in a fight.
func lineup(state: Dictionary) -> Array:
	return state["combat"]["enemies"].map(func(enemy: Dictionary) -> String: return enemy["def_id"])


## Returns the enemy with this uid in the fight, or {} when it is not there.
## state: a run state in a fight. uid: the enemy's uid.
func enemy_by_uid(state: Dictionary, uid: String) -> Dictionary:
	for candidate: Dictionary in state["combat"]["enemies"]:
		if candidate["uid"] == uid:
			return candidate
	return {}
