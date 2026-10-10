## The "self_damage" effect operation (tasks 013 and 015). Lane: core (Agent A). Catalogue:
## core/ops/README.md.
##
## Used by Tom's cards ("Tom takes 2 damage", Skull Bash; "Tom takes 3 damage from the response",
## Pickup Line) and by Junk (Bedbugs' on_draw, Burn's on_end_of_turn_in_hand). Tasks 013 and 015
## built it in parallel under the same name; this is the one kept version.
##
## Fields: amount (int, 0 or more: damage taken). Recipient: always the actor (the Dude playing the
## card or holding the Junk; an enemy using it in a move hurts itself), whatever the card's target is.
##
## G3 (answered "accept"): this is not attack damage. It ignores Swole, Noodle Arms, Broken Arm and
## Exposed and deals exactly amount: Guard absorbs it first and is used up (G2), the rest comes off
## HP, HP stops at 0 and a Dude at 0 HP is Passed Out (core/ops/damage.gd deal_in_place). It has no
## attacker, so it never triggers thorns. An amount of 0 does nothing.
##
## Events: damage_dealt with source_id "" (no attacker, as core/schema/event.gd defines), then
## dude_passed_out or enemy_died at 0 HP.
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Damage := preload("res://core/ops/damage.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## False: self_damage lands on the actor, so an enemy move with only self_damage shows no targets.
const NEEDS_TARGET: bool = false

## source_id of the damage_dealt events: "" means no attacker (core/schema/event.gd). Fixed.
const NO_SOURCE: String = ""

## Fields a self_damage effect may have, besides "op" and the generic ones in ops.gd, and their types.
## Anything else is an error.
const FIELDS := {
	# Damage the actor takes, 0 or more, exactly as given (no Swole, no multipliers).
	"amount": TYPE_INT,
}


## Returns the problems with a self_damage effect's fields; empty means it can run.
## effect: one effect, without the generic fields. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op self_damage" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 0:
		errors.append("%s.amount: must be an int, 0 or more" % path)
	return errors


## Runs a self_damage effect: the actor takes amount through Guard, then HP (see the file header).
## Does nothing if amount is 0, the actor is gone (dead or Passed Out), or the fight is decided.
## state: the working copy. effect: a self_damage effect that passed check().
## context: {"actor_id": who takes it; other keys unused}. events: the event list, appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	if effect["amount"] == 0:
		return
	if state["combat"] != null and Bodies.is_decided(state):
		return
	Damage.deal_in_place(state, NO_SOURCE, context["actor_id"], effect["amount"], events)
