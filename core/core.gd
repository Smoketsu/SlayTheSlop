## The rules core's entry point (task 007). Lane: core (Agent A).
##
##   const Core := preload("res://core/core.gd")
##   var result: Dictionary = Core.apply(ruleset, state, request)
##   # result = {"state": Dictionary, "events": Array, "reject": String}
##
## apply() is static; Core.new().apply(...) works too, for code that holds a gateway object
## (client/fight/fight_screen.gd). As core/schema/README.md "The core's entry point" says:
##   - ruleset is the read-only content from core/ruleset/ruleset.gd build() (constants, cards,
##     enemies, Dudes). It is an argument because the core may not read files.
##   - reject is "" when the request was applied. Otherwise it is one of request.gd REJECT_REASONS,
##     state is the SAME Dictionary that was passed in (nothing changed, same state_version) and
##     events is empty.
##   - An applied request raises state_version by exactly 1, however many events it caused.
##   - apply() never changes ruleset, state or request; an applied request returns a new state.
##
## Checks run in this order; the first that fails is the reject reason:
##   bad_request    request.gd check() finds a problem with the shape.
##   unknown_player player_id matches no Dude.
##   stale_seq      seq is not above that Dude's last_seq.
##   wrong_phase    no fight, or the fight is not in its player phase, or the request type is not a
##                  fight request (pick_dude, vote_node and choose_reward wait for the run flow, task 025).
##   passed_out     the Dude is Passed Out.
##   then per type: play_card -> core/combat/play.gd check() (not_in_hand, unplayable, no_hype,
##                  bad_target); use_brew -> empty_slot, else unplayable (Brews are task 021);
##                  use_bro_move -> core/combat/bro_move.gd check() (not_ready below BRO_METER_MAX,
##                  unplayable, bad_target; task 013).
##
## last_seq: updated to the request's seq ONLY when the request is applied. A rejected request
## changes nothing, last_seq included, so the state stays identical (and a rejected seq may be sent
## again). The schema comment on dude_state.last_seq says "accepted or rejected"; task 007 asks both
## people to confirm this choice and fix that comment in a contract PR.
##
## set_ready sets the Dude's ready flag (ready_changed). When every Dude who is not Passed Out is
## ready, the turn ends and the next one runs to its player phase, all inside this one call
## (core/combat/fight.gd).
##
## Pure and deterministic: no file, clock, network, scene tree or global randomness.
extends RefCounted

const Request := preload("res://core/schema/request.gd")
const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const Fight := preload("res://core/combat/fight.gd")
const Play := preload("res://core/combat/play.gd")
const BroMove := preload("res://core/combat/bro_move.gd")

## Request types that act inside a fight's player phase. Every other type is wrong_phase for now.
const FIGHT_REQUESTS: Array[String] = ["play_card", "set_ready", "use_brew", "use_bro_move"]


## Applies one request. See the file header for the contract and the order of checks.
## ruleset: the read-only content. state: the current run state; not changed.
## request: a request Dictionary (core/schema/request.gd); not changed. Any value is accepted:
## anything that is not a well-formed request (including a non-Dictionary) is bad_request.
## Returns {"state": Dictionary, "events": Array of event Dictionaries, "reject": String}.
static func apply(ruleset: Dictionary, state: Dictionary, request: Variant) -> Dictionary:
	# reason: why the request is refused, or "" when it is legal.
	var reason: String = validate(ruleset, state, request)
	if reason != "":
		return {"state": state, "events": [], "reject": reason}
	# next: the deep, writable copy that becomes the new state.
	var next: Dictionary = state.duplicate(true)
	# events: what happened, in order.
	var events: Array = []
	# index: the requesting Dude's seat, 0-based.
	var index: int = Bodies.dude_index(next, request["player_id"])
	match request["type"]:
		"play_card":
			Play.resolve_in_place(ruleset, next, index, request, events)
			Fight.finish_if_decided_in_place(ruleset, next, events)
		"set_ready":
			_set_ready_in_place(ruleset, next, index, request["ready"], events)
		"use_bro_move":
			# Task 013: empty the Bro Meter and play the Dude's Bro Move.
			BroMove.resolve_in_place(ruleset, next, index, request, events)
			Fight.finish_if_decided_in_place(ruleset, next, events)
	next["dudes"][index]["last_seq"] = request["seq"]
	next["state_version"] = state["state_version"] + 1
	return {"state": next, "events": events, "reject": ""}


## Returns the reason apply() would refuse this request, or "" when it would apply it. Reads only.
## Bots may call it to find legal plays without applying them.
## ruleset: the read-only content. state: the current run state. request: the request to check.
static func validate(ruleset: Dictionary, state: Dictionary, request: Variant) -> String:
	if not Request.check(request).is_empty():
		return "bad_request"
	# index: the requesting Dude's seat, or -1.
	var index: int = Bodies.dude_index(state, request["player_id"])
	if index == -1:
		return "unknown_player"
	# dude: the requesting Dude.
	var dude: Dictionary = state["dudes"][index]
	if request["seq"] <= dude["last_seq"]:
		return "stale_seq"
	if not FIGHT_REQUESTS.has(request["type"]) or state["combat"] == null or state["combat"]["phase"] != "player":
		return "wrong_phase"
	if dude["passed_out"]:
		return "passed_out"
	match request["type"]:
		"play_card":
			return Play.check(ruleset, state, dude, request)
		"use_brew":
			if request["slot"] < 0 or request["slot"] >= dude["brews"].size():
				return "empty_slot"
			return "unplayable"
		"use_bro_move":
			# Task 013.
			return BroMove.check(ruleset, state, dude, request)
	return ""


## Applies set_ready: sets the flag (ready_changed), then ends the player phase if every Dude who is
## not Passed Out is ready.
## ruleset: the read-only content. state: the working copy, changed here. dude_index: the player's
## seat, 0-based. ready: the requested flag. events: the event list, appended to.
static func _set_ready_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, ready: bool, events: Array) -> void:
	state["dudes"][dude_index]["ready"] = ready
	events.append(Event.make("ready_changed", {"player_id": state["dudes"][dude_index]["player_id"], "ready": ready}))
	if ready and Fight.everyone_ready(state):
		Fight.end_player_phase_in_place(ruleset, state, events)
