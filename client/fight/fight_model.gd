## Turns the state into what the fight screen shows (task 018). Lane: client (Agent B).
##
## Pure: reads the ruleset and the state, returns plain values, changes nothing. The screen draws
## only from this, so everything shown comes from the state. Names come from the ruleset by id, so
## no Dude is named in client code.
extends RefCounted

const Messages := preload("res://client/fight/messages.gd")


## Returns the display model of the fight:
##   "turn": int, "phase": String,
##   "bro_meter": "7 / 10", "bro_ready": bool (meter at BRO_METER_MAX),
##   "dudes":   one entry per Dude, see _dude(),
##   "hand":    the local player's hand, left to right, see _card(),
##   "enemies": left to right, see _enemy().
## ruleset: read-only content. state: a run state with a fight in it. player_id: the local player.
static func build(ruleset: Dictionary, state: Dictionary, player_id: String) -> Dictionary:
	# combat: the fight.
	var combat: Dictionary = state["combat"]
	# max_meter: Bro Meter value needed for a Bro Move.
	var max_meter: int = ruleset["constants"]["BRO_METER_MAX"]
	# model: the result.
	var model: Dictionary = {
		"turn": combat["turn"],
		"phase": combat["phase"],
		"bro_meter": "%d / %d" % [state["bro_meter"], max_meter],
		"bro_ready": state["bro_meter"] >= max_meter,
		"dudes": [],
		"hand": [],
		"enemies": [],
	}
	for dude: Dictionary in state["dudes"]:
		model["dudes"].append(_dude(ruleset, dude, player_id))
		if dude["player_id"] == player_id:
			for uid: String in dude["hand"]:
				model["hand"].append(_card(ruleset, dude, uid))
	for enemy: Dictionary in combat["enemies"]:
		model["enemies"].append(_enemy(ruleset, state, enemy))
	return model


## One Dude: {"player_id", "name", "hp": "58 / 70", "guard", "hype", "statuses": ["Exposed 1"],
## "brews": "0 / 3", "brew_ids", "draw", "discard", "tapped" (pile counts), "passed_out", "local"}.
## ruleset: content. dude: one Dude state. player_id: the local player.
static func _dude(ruleset: Dictionary, dude: Dictionary, player_id: String) -> Dictionary:
	return {
		"player_id": dude["player_id"],
		"name": _dude_name(ruleset, dude["dude_id"]),
		"hp": "%d / %d" % [dude["hp"], dude["max_hp"]],
		"guard": dude["guard"],
		"hype": dude["hype"],
		"statuses": _statuses(dude["statuses"]),
		"brews": "%d / %d" % [dude["brews"].size(), dude["brew_slots"]],
		"brew_ids": dude["brews"].duplicate(),
		"draw": dude["draw_pile"].size(),
		"discard": dude["discard_pile"].size(),
		"tapped": dude["tapped_pile"].size(),
		"passed_out": dude["passed_out"],
		"local": dude["player_id"] == player_id,
	}


## One card in hand: {"card_uid", "def_id", "name", "cost": "1" / "X" / "-", "text", "target"}.
## ruleset: content. dude: the card's owner. uid: the card copy.
static func _card(ruleset: Dictionary, dude: Dictionary, uid: String) -> Dictionary:
	# def_id: which card this copy is.
	var def_id: String = dude["cards"][uid]["def_id"]
	# card: its definition, or {} if the ruleset lacks it.
	var card: Dictionary = ruleset["cards"].get(def_id, {})
	# cost: the raw cost.
	var cost: Variant = card.get("cost", -1)
	return {
		"card_uid": uid,
		"def_id": def_id,
		"name": card.get("name", def_id),
		"cost": "X" if typeof(cost) == TYPE_STRING else ("-" if cost < 0 else str(cost)),
		"text": card.get("text", ""),
		"target": card.get("target", "none"),
	}


## One enemy: {"uid", "name", "hp": "20 / 20", "guard", "statuses", "intent" (the move's icon key,
## "" when none), "targets" (Dude names the intent is aimed at), "arms" ("1 of 2 arms broken" or
## "No arms"), "ick": "2 / 5", "alive"}.
## ruleset: content. state: the run state, for Dude names. enemy: one enemy state.
static func _enemy(ruleset: Dictionary, state: Dictionary, enemy: Dictionary) -> Dictionary:
	# definition: the enemy's fixed values, or {} if the ruleset lacks it.
	var definition: Dictionary = ruleset["enemies"].get(enemy["def_id"], {})
	# intent: the icon key of the move it will use next.
	var intent: String = ""
	# targets: names of the Dudes it is aiming at.
	var targets: Array[String] = []
	if enemy["intent"] != null:
		for move: Dictionary in definition.get("moves", []):
			if move["id"] == enemy["intent"]["move_id"]:
				intent = move["intent"]
		for target_id: String in enemy["intent"]["target_ids"]:
			for dude: Dictionary in state["dudes"]:
				if dude["player_id"] == target_id:
					targets.append(_dude_name(ruleset, dude["dude_id"]))
	return {
		"uid": enemy["uid"],
		"name": definition.get("name", enemy["def_id"]),
		"hp": "%d / %d" % [enemy["hp"], enemy["max_hp"]],
		"guard": enemy["guard"],
		"statuses": _statuses(enemy["statuses"]),
		"intent": intent,
		"targets": targets,
		"arms": "No arms" if enemy["arm_count"] == 0 else "%d of %d arms broken" % [enemy["broken_arms"], enemy["arm_count"]],
		"ick": "%d / %d" % [enemy["ick"], enemy["ick_threshold"]],
		"alive": enemy["hp"] > 0,
	}


## Returns statuses as display text, "Name stacks", sorted by id so the order never depends on how
## the Dictionary was filled. Zero stacks are left out.
## statuses: status id -> stacks.
static func _statuses(statuses: Dictionary) -> Array[String]:
	# ids: the status ids, sorted.
	var ids: Array = statuses.keys()
	ids.sort()
	# out: the result.
	var out: Array[String] = []
	for id: String in ids:
		if statuses[id] > 0:
			out.append("%s %d" % [Messages.status_name(id), statuses[id]])
	return out


## Returns a Dude's display name from the ruleset, or the id when it is missing.
## ruleset: content. dude_id: a Dude definition id.
static func _dude_name(ruleset: Dictionary, dude_id: String) -> String:
	return ruleset["dudes"].get(dude_id, {}).get("name", dude_id)
