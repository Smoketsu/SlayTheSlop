## A stand-in for the rules core, so the fight screen can be built before task 007 exists.
## Lane: client (Agent B).
##
## Same signature as the core's proposed entry point (core/schema/README.md):
##   apply(ruleset, state, request) -> {"state": Dictionary, "events": Array, "reject": String}
## It follows the README's rules: it never changes its arguments, a rejected request returns the
## state unchanged with no events, and an applied one raises state_version by exactly 1.
##
## It is NOT the rules. It does just enough to exercise the screen: spends Hype, moves the card,
## applies plain "damage" and "guard" effects with no damage order, ends the turn by refilling Hype,
## and empties the Bro Meter. Events are built with core/schema/event.gd make(), so only real
## event types appear. Swapping in the real core is one line in client/fight/fight_screen.gd.
extends RefCounted

const Request := preload("res://core/schema/request.gd")
const Event := preload("res://core/schema/event.gd")


## Applies one request, the way the core will. Never changes ruleset, state or request.
## ruleset: the read-only content (core/ruleset/ruleset.gd). state: the current run state.
## request: a request Dictionary (core/schema/request.gd).
func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	if not Request.check(request).is_empty():
		return _reject(state, "bad_request")
	# index: the requesting Dude's position in state.dudes, or -1.
	var index: int = -1
	for i: int in state["dudes"].size():
		if state["dudes"][i]["player_id"] == request["player_id"]:
			index = i
	if index == -1:
		return _reject(state, "unknown_player")
	if request["seq"] <= state["dudes"][index]["last_seq"]:
		return _reject(state, "stale_seq")
	if state["combat"] == null or state["combat"]["phase"] != "player":
		return _reject(state, "wrong_phase")
	# next: a deep, writable copy that becomes the new state.
	var next: Dictionary = state.duplicate(true)
	# dude: the requesting Dude in the copy.
	var dude: Dictionary = next["dudes"][index]
	# events: what happened, in order.
	var events: Array = []
	# reason: a reject code from the request's own handler, or "" when it applied.
	var reason: String = ""
	match request["type"]:
		"play_card":
			reason = _play_card(ruleset, next, dude, request, events)
		"set_ready":
			reason = _set_ready(next, dude, request, events)
		"use_bro_move":
			reason = _use_bro_move(ruleset, next, events)
		"use_brew":
			reason = "empty_slot" if request["slot"] >= dude["brews"].size() else "bad_request"
		_:
			reason = "wrong_phase"
	if reason != "":
		return _reject(state, reason)
	dude["last_seq"] = request["seq"]
	next["state_version"] = state["state_version"] + 1
	return {"state": next, "events": events, "reject": ""}


## Plays a card in the copy. Returns a reject code, or "" when it was played.
## ruleset: content. next: the state copy. dude: the player's Dude in next. request: the play_card
## request. events: receives what happened.
func _play_card(ruleset: Dictionary, next: Dictionary, dude: Dictionary, request: Dictionary, events: Array) -> String:
	# uid: the card copy being played.
	var uid: String = request["card_uid"]
	if not dude["hand"].has(uid):
		return "not_in_hand"
	# card: its definition.
	var card: Dictionary = ruleset["cards"][dude["cards"][uid]["def_id"]]
	# cost: Hype to spend; "x" spends all of it.
	var cost: int = dude["hype"] if typeof(card["cost"]) == TYPE_STRING else card["cost"]
	if cost < 0:
		return "unplayable"
	if cost > dude["hype"]:
		return "no_hype"
	# targets: who the card's effects land on.
	var targets: Array[String] = _targets(next, dude, card, request["target_id"])
	if targets.is_empty():
		return "bad_target"
	dude["hype"] -= cost
	events.append(Event.make("card_played", {"player_id": dude["player_id"], "card_uid": uid, "target_id": request["target_id"]}))
	events.append(Event.make("hype_changed", {"player_id": dude["player_id"], "delta": -cost, "hype": dude["hype"]}))
	for effect: Dictionary in card["effects"]:
		for target_id: String in targets:
			_apply_effect(next, dude, effect, target_id, events)
	# pile: where the card goes after it is played.
	var pile: String = "tapped_pile" if card["keywords"].has("tapped") else "discard_pile"
	dude["hand"].erase(uid)
	dude[pile].append(uid)
	events.append(Event.make("card_moved", {"player_id": dude["player_id"], "card_uid": uid, "from": "hand", "to": pile}))
	return ""


## Returns the ids a card's effects land on, or [] when target_id is not legal for it.
## next: the state copy. dude: the player's Dude. card: the card definition. target_id: from the request.
func _targets(next: Dictionary, dude: Dictionary, card: Dictionary, target_id: String) -> Array[String]:
	# alive: uids of enemies still standing, left to right.
	var alive: Array[String] = []
	for enemy: Dictionary in next["combat"]["enemies"]:
		if enemy["hp"] > 0:
			alive.append(enemy["uid"])
	# out: the result; stays empty when the target is not legal.
	var out: Array[String] = []
	match card["target"]:
		"enemy":
			if alive.has(target_id):
				out.append(target_id)
		"all_enemies":
			out = alive
		"ally":
			for other: Dictionary in next["dudes"]:
				if other["player_id"] == target_id and not other["passed_out"]:
					out.append(target_id)
		_:
			out.append(dude["player_id"])
	return out


## Applies one plain effect to one target. Only "damage" and "guard" do anything here.
## next: the state copy. dude: the acting Dude. effect: one entry of the card's effects.
## target_id: a player id or enemy uid. events: receives what happened.
func _apply_effect(next: Dictionary, dude: Dictionary, effect: Dictionary, target_id: String, events: Array) -> void:
	# body: the Dictionary of whoever is hit, a Dude or an enemy.
	var body: Dictionary = _find(next, target_id)
	match effect["op"]:
		"damage":
			for hit: int in effect.get("hits", 1):
				# blocked: how much Guard soaks up.
				var blocked: int = mini(body["guard"], effect["amount"])
				# lost: what comes off HP.
				var lost: int = mini(body["hp"], effect["amount"] - blocked)
				body["guard"] -= blocked
				body["hp"] -= lost
				events.append(Event.make("damage_dealt", {"source_id": dude["player_id"], "target_id": target_id,
					"amount": effect["amount"], "blocked": blocked, "hp_lost": lost}))
				if body["hp"] == 0 and body.has("uid"):
					events.append(Event.make("enemy_died", {"enemy_uid": target_id}))
					break
		"guard":
			body["guard"] += effect["amount"]
			events.append(Event.make("guard_changed", {"target_id": target_id, "delta": effect["amount"], "guard": body["guard"]}))


## Ends the player phase on Ready: a canned new turn with Hype refilled. Returns "" (never rejects).
## next: the state copy. dude: the player's Dude. request: the set_ready request. events: receives
## what happened.
func _set_ready(next: Dictionary, dude: Dictionary, request: Dictionary, events: Array) -> String:
	events.append(Event.make("ready_changed", {"player_id": dude["player_id"], "ready": request["ready"]}))
	if not request["ready"]:
		return ""
	next["combat"]["turn"] += 1
	events.append(Event.make("turn_started", {"turn": next["combat"]["turn"]}))
	# refill: Hype gained back.
	var refill: int = dude["hype_per_turn"] - dude["hype"]
	dude["hype"] = dude["hype_per_turn"]
	events.append(Event.make("hype_changed", {"player_id": dude["player_id"], "delta": refill, "hype": dude["hype"]}))
	return ""


## Empties a full Bro Meter. Returns "not_ready" when it is below BRO_METER_MAX.
## ruleset: content, for the constant. next: the state copy. events: receives what happened.
func _use_bro_move(ruleset: Dictionary, next: Dictionary, events: Array) -> String:
	if next["bro_meter"] < ruleset["constants"]["BRO_METER_MAX"]:
		return "not_ready"
	events.append(Event.make("bro_meter_changed", {"delta": -next["bro_meter"], "bro_meter": 0}))
	next["bro_meter"] = 0
	return ""


## Returns the Dude or enemy Dictionary in state with this player id or uid.
## state: a run state. id: a player id ("p1") or an enemy uid ("e7").
func _find(state: Dictionary, id: String) -> Dictionary:
	for dude: Dictionary in state["dudes"]:
		if dude["player_id"] == id:
			return dude
	for enemy: Dictionary in state["combat"]["enemies"]:
		if enemy["uid"] == id:
			return enemy
	return {}


## Returns a rejection: the original state unchanged and no events.
## state: the state as received. reason: one of request.gd REJECT_REASONS.
func _reject(state: Dictionary, reason: String) -> Dictionary:
	return {"state": state, "events": [], "reject": reason}
