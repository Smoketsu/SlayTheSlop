## The "lose_hype" effect operation (task 015). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: amount (int, 0 or more: Hype lost). Recipient: always the actor, when it is a Dude
## (Hangover's on_draw: "When drawn, lose 1 Hype"). Hype never goes below 0, so a Dude with less
## Hype than amount loses what they have. Enemies have no Hype: nothing happens.
##
## Events: hype_changed (delta = minus the Hype actually lost), only when Hype changes.
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## False: lose_hype lands on the actor, so an enemy move with only lose_hype shows no targets.
const NEEDS_TARGET: bool = false

## Fields a lose_hype effect may have, besides "op", and their types. Anything else is an error.
const FIELDS := {
	# Hype lost, 0 or more. Hype stops at 0.
	"amount": TYPE_INT,
}


## Returns the problems with a lose_hype effect's fields; empty means it can run.
## effect: one entry of a card's or move's effects. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op lose_hype" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 0:
		errors.append("%s.amount: must be an int, 0 or more" % path)
	return errors


## Runs a lose_hype effect: the actor, if a Dude who is not Passed Out, loses up to amount Hype.
## state: the working copy. effect: a lose_hype effect that passed check().
## context: {"actor_id": who loses it; other keys unused}. events: the event list, appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# index: the actor's seat, or -1 when the actor is not a Dude.
	var index: int = Bodies.dude_index(state, context["actor_id"])
	if index == -1 or state["dudes"][index]["passed_out"]:
		return
	# dude: the actor, inside state.
	var dude: Dictionary = state["dudes"][index]
	# lost: Hype actually lost, never more than the Dude has.
	var lost: int = mini(effect["amount"], dude["hype"])
	if lost == 0:
		return
	dude["hype"] -= lost
	events.append(Event.make("hype_changed", {"player_id": dude["player_id"], "delta": -lost, "hype": dude["hype"]}))
