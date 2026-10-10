## The "draw" effect operation (task 013). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: amount (int, 1 or more: cards to draw). Recipient: the actor, who must be a Dude that is
## not Passed Out; for any other actor (an enemy) it does nothing. Draws from the top of the draw
## pile with the G8 reshuffle (core/combat/piles.gd): shuffle the discard pile into the draw pile
## when it runs out, stop when both are empty. No hand size limit (G8).
##
## Task 015: each drawn copy's on_draw trigger runs right after it is drawn (Hangover, Bedbugs), via
## core/combat/card_triggers.gd draw_in_place, the same draw Refresh uses; drawing stops early if a
## trigger Passes Out the Dude or decides the fight.
##
## Events: deck_shuffled and card_moved (draw_pile -> hand), as at Refresh, plus any on_draw events.
## Changes the working copy it is given (see core/combat/bodies.gd). Pure: randomness only through
## the player's shuffle stream, via piles.gd.
extends RefCounted

const Bodies := preload("res://core/combat/bodies.gd")
const CardTriggers := preload("res://core/combat/card_triggers.gd")

## False: a draw lands on the actor, so an enemy move with only draw shows no targets.
const NEEDS_TARGET: bool = false

## Fields a draw effect may have, besides "op" and the generic ones in ops.gd, and their types.
const FIELDS := {
	# Cards to draw. 1 or more.
	"amount": TYPE_INT,
}


## Returns the problems with a draw effect's fields; empty means it can run.
## effect: one effect, without the generic fields. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op draw" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 1:
		errors.append("%s.amount: must be an int, 1 or more" % path)
	return errors


## Runs a draw effect: the acting Dude draws amount cards (see the file header).
## state: the working copy. effect: a draw effect that passed check().
## context: {"actor_id": the Dude who draws; other keys unused}. events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# index: the actor's seat, or -1 when the actor is not a Dude.
	var index: int = Bodies.dude_index(state, context["actor_id"])
	if index == -1 or state["dudes"][index]["passed_out"]:
		return
	# Task 015: the context stands in for the ruleset (card_triggers.gd accepts either).
	CardTriggers.draw_in_place(context, state, index, effect["amount"], events)
