## Turns the state into what the fight screen shows (task 018). Lane: client (Agent B).
##
## Pure: reads the ruleset and the state, returns plain values, changes nothing. The screen draws
## only from this, so everything shown comes from the state. Names come from the ruleset by id, so
## no Dude is named in client code.
extends RefCounted

const Messages := preload("res://client/fight/messages.gd")
## [added, task upgraded-card-display] The core's reader of a card copy's effective definition.
const Upgrades := preload("res://core/combat/upgrades.gd")
## [added, task upgraded-card-display] Holds UPGRADED_MARK, the "+" shown after a Lifted copy's name.
const RunText := preload("res://client/run/run_text.gd")
## [added, task 057] The core's read-only helpers for an enemy's intended move and why it would skip it.
const Statuses := preload("res://core/combat/statuses.gd")
## [added, task 057] The core's damage order (hit_amount()), so an attack intent's number is the core's.
const DamageOp := preload("res://core/ops/damage.gd")
## [added, task 057] Effect ops whose "amount" an attack intent shows as its damage number. "damage"
## is exact; "charged_hit" (Goblin King Chad's release) is shown as its most, before its helper cut,
## and marked "up to". Changed only by the client lane, when core/ops/README.md adds an attack op.
const SHOWN_DAMAGE_OPS: Array[String] = ["damage", "charged_hit"]
## [added, task 057] Effect ops of SHOWN_DAMAGE_OPS whose number is a most, not exact ("up to").
## Changed only by the client lane.
const UP_TO_OPS: Array[String] = ["charged_hit"]


## Returns the display model of the fight:
##   "turn": int, "phase": String,
##   "bro_meter": "7 / 10", "bro_ready": bool (meter at BRO_METER_MAX),
##   [added, task 057] "bro_meter_now", "bro_meter_max": the same as ints, for the Bro Meter bar,
##   [added, task 057] "party_size": how many Dudes are in the fight, 1..4 (target markers show
##   only above 1),
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
		"bro_meter_now": state["bro_meter"],
		"bro_meter_max": max_meter,
		"party_size": state["dudes"].size(),
		"dudes": [],
		"hand": [],
		"enemies": [],
	}
	for dude: Dictionary in state["dudes"]:
		model["dudes"].append(_dude(ruleset, dude, player_id))
		model["dudes"][-1]["seat"] = model["dudes"].size() - 1
		if dude["player_id"] == player_id:
			for uid: String in dude["hand"]:
				model["hand"].append(_card(ruleset, dude, uid))
	for enemy: Dictionary in combat["enemies"]:
		model["enemies"].append(_enemy(ruleset, state, enemy))
	return model


## One Dude: {"player_id", "def_id" (dude_state.dude_id, for the sprite), "name", "hp": "58 / 70",
## "hp_now", "hp_max" (the same as ints, for the HP bar), "guard", "hype", "statuses": ["Exposed 1"],
## "brews": "0 / 3", "brew_ids", "draw", "discard", "tapped" (pile counts), "passed_out", "local"}.
## [added, task 057] Also "swole", "chill", "clout" (the stats, 0 or more), "status_stacks" (see
## _status_stacks()), "hype_per_turn", and "seat" (the Dude's place in state.dudes, from 0; set by
## build()).
## ruleset: content. dude: one Dude state. player_id: the local player.
static func _dude(ruleset: Dictionary, dude: Dictionary, player_id: String) -> Dictionary:
	return {
		"player_id": dude["player_id"],
		"def_id": dude["dude_id"],
		"name": _dude_name(ruleset, dude["dude_id"]),
		"hp": "%d / %d" % [dude["hp"], dude["max_hp"]],
		"hp_now": dude["hp"],
		"hp_max": dude["max_hp"],
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
		"swole": dude["swole"],
		"chill": dude["chill"],
		"clout": dude["clout"],
		"status_stacks": _status_stacks(dude["statuses"]),
		"hype_per_turn": dude["hype_per_turn"],
		"seat": 0,
	}


## One card in hand: {"card_uid", "def_id", "name", "cost": "1" / "X" / "-", "text", "target",
## "upgraded"}. Task upgraded-card-display: name, cost, text and target come from the copy's effective
## definition (core/combat/upgrades.gd definition_of(): the upgraded definition for a Lifted copy),
## and a Lifted copy's name ends with RunText.UPGRADED_MARK, as in the run screens' card lists.
## ruleset: content. dude: the card's owner. uid: the card copy.
static func _card(ruleset: Dictionary, dude: Dictionary, uid: String) -> Dictionary:
	# def_id: which card this copy is.
	var def_id: String = dude["cards"][uid]["def_id"]
	# upgraded: true when this copy is Lifted (dude_state cards[uid].upgraded, set by the core only).
	var upgraded: bool = dude["cards"][uid].get("upgraded", false)
	# card: the copy's effective definition, or {} if the ruleset lacks it or a Lifted copy's upgrade
	# does not apply (the core then refuses the card as unplayable).
	var card: Dictionary = Upgrades.definition_of(ruleset, dude, uid)
	# cost: the raw cost.
	var cost: Variant = card.get("cost", -1)
	return {
		"card_uid": uid,
		"def_id": def_id,
		"name": card.get("name", def_id) + (RunText.UPGRADED_MARK if upgraded else ""),
		"cost": "X" if typeof(cost) == TYPE_STRING else ("-" if cost < 0 else str(cost)),
		"text": card.get("text", ""),
		"target": card.get("target", "none"),
		"upgraded": upgraded,
	}


## One enemy: {"uid", "def_id" (for the sprite), "name", "hp": "20 / 20", "hp_now", "hp_max" (the
## same as ints, for the HP bar), "guard", "statuses", "intent" (the move's icon key,
## "" when none), "targets" (Dude names the intent is aimed at), "arms" ("1 of 2 arms broken" or
## "No arms"), "ick": "2 / 5", "alive"}.
## [added, task 057] Also "swole", "status_stacks" (see _status_stacks()), "broken_arms", "arm_count",
## "ick_now", "ick_threshold" (the same values as ints), "target_seats" (the seat of each Dude the
## intent aims at, in target order), "skip" (core/combat/statuses.gd skip_reason(): "" when it will
## act, otherwise why it will skip its intended move) and "intent_damage" (see _intent_damage()).
## ruleset: content. state: the run state, for Dude names. enemy: one enemy state.
static func _enemy(ruleset: Dictionary, state: Dictionary, enemy: Dictionary) -> Dictionary:
	# definition: the enemy's fixed values, or {} if the ruleset lacks it.
	var definition: Dictionary = ruleset["enemies"].get(enemy["def_id"], {})
	# intent: the icon key of the move it will use next.
	var intent: String = ""
	# targets: names of the Dudes it is aiming at.
	var targets: Array[String] = []
	# seats: the seats of those Dudes, in the same order.
	var seats: Array[int] = []
	if enemy["intent"] != null:
		for move: Dictionary in definition.get("moves", []):
			if move["id"] == enemy["intent"]["move_id"]:
				intent = move["intent"]
		for target_id: String in enemy["intent"]["target_ids"]:
			for seat: int in state["dudes"].size():
				if state["dudes"][seat]["player_id"] == target_id:
					targets.append(_dude_name(ruleset, state["dudes"][seat]["dude_id"]))
					seats.append(seat)
	return {
		"uid": enemy["uid"],
		"def_id": enemy["def_id"],
		"name": definition.get("name", enemy["def_id"]),
		"hp": "%d / %d" % [enemy["hp"], enemy["max_hp"]],
		"hp_now": enemy["hp"],
		"hp_max": enemy["max_hp"],
		"guard": enemy["guard"],
		"statuses": _statuses(enemy["statuses"]),
		"intent": intent,
		"targets": targets,
		"arms": "No arms" if enemy["arm_count"] == 0 else "%d of %d arms broken" % [enemy["broken_arms"], enemy["arm_count"]],
		"ick": "%d / %d" % [enemy["ick"], enemy["ick_threshold"]],
		"alive": enemy["hp"] > 0,
		"swole": enemy["swole"],
		"status_stacks": _status_stacks(enemy["statuses"]),
		"broken_arms": enemy["broken_arms"],
		"arm_count": enemy["arm_count"],
		"ick_now": enemy["ick"],
		"ick_threshold": enemy["ick_threshold"],
		"target_seats": seats,
		"skip": Statuses.skip_reason(ruleset, enemy) if definition.has("moves") else "",
		"intent_damage": _intent_damage(ruleset, state, enemy, definition),
	}


## [added, task 057] Returns the damage an enemy's intended move will deal per hit, worked out by the
## core's damage order (core/ops/damage.gd hit_amount(), against the first Dude it aims at, so
## Swole, Noodle Arms, Broken Arm and Exposed count): {"amount": damage of one hit, or -1 when the
## move deals none of SHOWN_DAMAGE_OPS, "hits": how many times it hits, 1 or more, "up_to": true when
## the number is a most (UP_TO_OPS)}. Reads only; the first shown damage effect of the move counts.
## ruleset: content. state: the run state, for the target. enemy: one enemy state. definition: its
## definition, or {}.
static func _intent_damage(ruleset: Dictionary, state: Dictionary, enemy: Dictionary, definition: Dictionary) -> Dictionary:
	# none: the result for a move with no shown damage.
	var none: Dictionary = {"amount": -1, "hits": 1, "up_to": false}
	if enemy["intent"] == null or not definition.has("moves"):
		return none
	# move: the intended move's definition, or {}.
	var move: Dictionary = Statuses.intended_move(ruleset, enemy)
	# target: the first Dude it aims at, or a body with no statuses when it aims at none.
	var target: Dictionary = {"statuses": {}}
	for dude: Dictionary in state["dudes"]:
		if not enemy["intent"]["target_ids"].is_empty() and dude["player_id"] == enemy["intent"]["target_ids"][0]:
			target = dude
	for effect: Dictionary in move.get("effects", []):
		if SHOWN_DAMAGE_OPS.has(effect.get("op", "")):
			return {
				"amount": DamageOp.hit_amount(ruleset["constants"], enemy, target, effect.get("amount", 0), true),
				"hits": effect.get("hits", DamageOp.DEFAULT_HITS),
				"up_to": UP_TO_OPS.has(effect["op"]),
			}
	return none


## [added, task 057] Returns statuses as [status id, stacks] pairs, sorted by id so the order never
## depends on how the Dictionary was filled. Zero stacks are left out.
## statuses: status id -> stacks.
static func _status_stacks(statuses: Dictionary) -> Array:
	# ids: the status ids, sorted.
	var ids: Array = statuses.keys()
	ids.sort()
	# out: the result.
	var out: Array = []
	for id: String in ids:
		if statuses[id] > 0:
			out.append([id, statuses[id]])
	return out


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
