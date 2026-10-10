## The "self_damage" effect operation (task 013). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: amount (int, 0 or more: damage taken). Recipient: the actor ("Tom takes 2 damage", Skull
## Bash; "Tom takes 3 damage from the response", Pickup Line), whatever the card's target is.
##
## G3 (answered "accept"): self-damage is not attack damage. It ignores Swole, Noodle Arms, Broken
## Arm and Exposed and deals exactly amount, through the actor's Guard first (G2) and then HP, which
## stops at 0. A Dude at 0 HP is Passed Out (then the fight may be lost); an enemy at 0 HP dies.
## An amount of 0 does nothing.
##
## Events: damage_dealt with source_id = target_id = the actor, then dude_passed_out or enemy_died
## at 0 HP (core/ops/damage.gd deal_in_place).
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Damage := preload("res://core/ops/damage.gd")

## False: self-damage lands on the actor, so an enemy move with only self_damage shows no targets.
const NEEDS_TARGET: bool = false

## Fields a self_damage effect may have, besides "op" and the generic ones in ops.gd, and their types.
const FIELDS := {
	# Damage the actor takes. 0 or more.
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


## Runs a self_damage effect: the actor takes amount damage (see the file header). Does nothing
## if the actor is gone or amount is 0.
## state: the working copy. effect: a self_damage effect that passed check().
## context: {"actor_id": who takes it; other keys unused}. events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	if effect["amount"] == 0:
		return
	Damage.deal_in_place(state, context["actor_id"], context["actor_id"], effect["amount"], events)
