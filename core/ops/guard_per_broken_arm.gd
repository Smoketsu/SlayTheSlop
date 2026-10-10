## The "guard_per_broken_arm" effect operation (task 013). Lane: core (Agent A).
## Catalogue: core/ops/README.md.
##
## Cast Party: "Gain 4 Guard for every Broken Arm on all enemies". Fields: amount (int, 0 or more:
## Guard per Broken Arm). Recipient: the actor. The count is the sum of broken_arms over every enemy
## still in the fight when the effect runs (dead enemies are gone and do not count). The base Guard,
## amount x count, then follows the guard op's rule exactly (core/ops/guard.gd gain_in_place):
## the Dude's Chill is added once, Hungover reduces Guard from cards, rounded down once. With no
## Broken Arms the base is 0, so only Chill is gained (nothing for Tom's base Chill of 0).
##
## Events: guard_changed, only when the Guard changes.
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const GuardOp := preload("res://core/ops/guard.gd")

## False: the Guard goes to the actor, so an enemy move with only this op shows no targets.
const NEEDS_TARGET: bool = false

## Fields a guard_per_broken_arm effect may have, besides "op" and the generic ones in ops.gd.
const FIELDS := {
	# Guard per Broken Arm on all enemies, before Chill. 0 or more.
	"amount": TYPE_INT,
}


## Returns the problems with a guard_per_broken_arm effect's fields; empty means it can run.
## effect: one effect, without the generic fields. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op guard_per_broken_arm" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 0:
		errors.append("%s.amount: must be an int, 0 or more" % path)
	return errors


## Returns the Broken Arms on every enemy still in the fight, 0 outside a fight.
## state: a run state.
static func broken_arms_on_all_enemies(state: Dictionary) -> int:
	# total: the sum so far.
	var total: int = 0
	if state["combat"] != null:
		for enemy: Dictionary in state["combat"]["enemies"]:
			total += enemy["broken_arms"]
	return total


## Runs the effect: the actor gains amount x (Broken Arms on all enemies) Guard, by the guard rule.
## state: the working copy. effect: an effect that passed check().
## context: as for the guard op (actor_id, constants, from_card). events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	GuardOp.gain_in_place(state, effect["amount"] * broken_arms_on_all_enemies(state), context, events)
