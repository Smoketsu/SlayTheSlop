## The "tap_cards" effect operation (task 021). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: card_type (String, one of core/schema/card_def.gd TYPES). Recipient: the actor's own hand
## (a Dude; an enemy actor does nothing). Every card in that hand whose definition has this type is
## Tapped: moved to tapped_pile, removed for the rest of the fight (GDD "Tapped"), in hand order.
## Cards whose definition the ruleset lacks are left in hand.
## Hair of the Dog: "Tap every Junk card in your hand" (card_type "junk").
##
## Events: card_moved (hand -> tapped_pile) for each card.
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const CardDef := preload("res://core/schema/card_def.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## False: the op works on the actor's hand, so an enemy move with it aims at nobody.
const NEEDS_TARGET: bool = false

## Fields a tap_cards effect may have, besides "op", and their types. Required.
const FIELDS := {
	# Which cards to Tap: a card type, one of CardDef.TYPES.
	"card_type": TYPE_STRING,
}


## Returns the problems with a tap_cards effect's fields; empty means it can run.
## effect: one entry of an effects list. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op tap_cards" % [path, field])
	if typeof(effect.get("card_type")) != TYPE_STRING or not CardDef.TYPES.has(effect["card_type"]):
		errors.append("%s.card_type: must be one of %s" % [path, ", ".join(PackedStringArray(CardDef.TYPES))])
	return errors


## Runs a tap_cards effect on the actor's hand (see the file header).
## state: the working copy. effect: a tap_cards effect that passed check().
## context: {"actor_id": whose hand, "ruleset": the read-only content (its cards give each card's
## type); other keys unused}. events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# index: the actor's seat, or -1 for an enemy.
	var index: int = Bodies.dude_index(state, context["actor_id"])
	if index == -1 or state["dudes"][index]["passed_out"]:
		return
	# dude: the actor, inside state.
	var dude: Dictionary = state["dudes"][index]
	# definitions: card id -> definition.
	var definitions: Dictionary = context["ruleset"]["cards"]
	for uid: String in dude["hand"].duplicate():
		# definition: the card's definition, or {} if the ruleset lacks it.
		var definition: Dictionary = definitions.get(dude["cards"][uid]["def_id"], {})
		if definition.get("type", "") != effect["card_type"]:
			continue
		dude["hand"].erase(uid)
		dude["tapped_pile"].append(uid)
		events.append(Event.make("card_moved", {"player_id": dude["player_id"], "card_uid": uid,
			"from": "hand", "to": "tapped_pile"}))
