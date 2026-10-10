## The use_bro_move request: empty the Bro Meter to play the Dude's Bro Move (task 013).
## Lane: core (Agent A).
##
## GDD "Bro Meter": "At 10, any one player may empty it to play their Dude's Bro Move for free."
## The Bro Move is the card named by the Dude definition's bro_move (data/dudes/, Tom: Chest Bump,
## "Deal 20 damage. Break 1 arm on every enemy"). It is played "for free": no Hype, not from the
## hand, it does not raise cards_played_this_turn, and no card copy moves (it is in no pile). Only
## its target and effects are read; its cost, type and keywords are ignored.
##
## check() returns, in order: not_ready (meter below BRO_METER_MAX, or that constant unusable),
## unplayable (the Dude's definition or its Bro Move card is missing, or an effect fails Ops.check),
## bad_target (the request's optional target_id is not legal for the card's target, as for
## play_card; "" when missing). resolve_in_place(): the meter goes to 0 (bro_meter_changed), then
## bro_move_used, then each effect in order, as attack damage (G3: Bro Moves are attacks), stopping
## once the fight is decided. Core.apply() then ends the fight if it is decided.
##
## Pure: no file, clock, network or random access.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Ops := preload("res://core/ops/ops.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const Play := preload("res://core/combat/play.gd")
const BroMeter := preload("res://core/combat/bro_meter.gd")


## Returns the reject reason for a use_bro_move request, or "" when it is legal (see the file
## header). Reads only; the caller has already checked shape, player, seq, phase and Passed Out.
## ruleset: the read-only content. state: the run state. dude: the requesting Dude.
## request: a well-formed use_bro_move request.
static func check(ruleset: Dictionary, state: Dictionary, dude: Dictionary, request: Dictionary) -> String:
	# max_meter: BRO_METER_MAX, or null when missing.
	var max_meter: Variant = ruleset["constants"].get(BroMeter.MAX_CONSTANT)
	if typeof(max_meter) != TYPE_INT or state["bro_meter"] < max_meter:
		return "not_ready"
	# card: the Bro Move's definition, or {}.
	var card: Dictionary = card_def(ruleset, dude)
	if card.is_empty() or not Ops.check_all(card["effects"]).is_empty():
		return "unplayable"
	if not Play.targets(state, dude, card, request.get("target_id", ""))["ok"]:
		return "bad_target"
	return ""


## Returns the definition of the Dude's Bro Move card, or {} when the Dude's definition or the card
## is not in the ruleset.
## ruleset: the read-only content. dude: a Dude state.
static func card_def(ruleset: Dictionary, dude: Dictionary) -> Dictionary:
	# definition: the Dude's definition, or {}.
	var definition: Dictionary = ruleset["dudes"].get(dude["dude_id"], {})
	if definition.is_empty():
		return {}
	return ruleset["cards"].get(definition["bro_move"], {})


## Uses the Bro Move that check() accepted (see the file header).
## ruleset: the read-only content. state: the working copy, changed here.
## dude_index: the player's seat, 0-based. request: the use_bro_move request. events: appended to.
static func resolve_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, request: Dictionary, events: Array) -> void:
	# dude: the player's Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# card: the Bro Move.
	var card: Dictionary = card_def(ruleset, dude)
	# target_id: the request's target, "" when missing.
	var target_id: String = request.get("target_id", "")
	# context: the Dude acting on the card's targets; attack damage (G3), from a card (Hungover).
	var context: Dictionary = Ops.make_context(ruleset, dude["player_id"],
		Play.targets(state, dude, card, target_id)["targets"], true, true)
	BroMeter.change_in_place(ruleset, state, -state["bro_meter"], events)
	events.append(Event.make("bro_move_used", {"player_id": dude["player_id"], "def_id": card["id"], "target_id": target_id}))
	for effect: Dictionary in card["effects"]:
		if Bodies.is_decided(state):
			break
		Ops.run(state, effect, context, events)
