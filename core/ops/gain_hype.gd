## The "gain_hype" effect operation (task 013). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: amount (int, 1 or more: Hype gained). Recipient: the actor, who must be a Dude that is
## not Passed Out; for any other actor (an enemy) it does nothing. Hype has no cap (the GDD gives
## none); unspent Hype is reset at the next Refresh as usual.
##
## Events: hype_changed (delta = amount, hype = the new value).
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## False: Hype is gained by the actor, so an enemy move with only gain_hype shows no targets.
const NEEDS_TARGET: bool = false

## Fields a gain_hype effect may have, besides "op" and the generic ones in ops.gd, and their types.
const FIELDS := {
	# Hype gained. 1 or more.
	"amount": TYPE_INT,
}


## Returns the problems with a gain_hype effect's fields; empty means it can run.
## effect: one effect, without the generic fields. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op gain_hype" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 1:
		errors.append("%s.amount: must be an int, 1 or more" % path)
	return errors


## Runs a gain_hype effect: the acting Dude gains amount Hype.
## state: the working copy. effect: a gain_hype effect that passed check().
## context: {"actor_id": the Dude who gains it; other keys unused}. events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# index: the actor's seat, or -1 when the actor is not a Dude.
	var index: int = Bodies.dude_index(state, context["actor_id"])
	if index == -1 or state["dudes"][index]["passed_out"]:
		return
	# dude: the actor, inside state.
	var dude: Dictionary = state["dudes"][index]
	dude["hype"] += effect["amount"]
	events.append(Event.make("hype_changed", {"player_id": dude["player_id"], "delta": effect["amount"], "hype": dude["hype"]}))
