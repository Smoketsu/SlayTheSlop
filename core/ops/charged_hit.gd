## The "charged_hit" effect operation (task 019). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: amount (int, 0 or more: base damage of the hit) and cut_per_helper_lost (int, 0 or more).
## The release of a charge (core/ai/charge.gd): Goblin King Chad's Keg Stand "hits one Dude for 30.
## Each Pledge killed during the charge removes 10 damage."
## The hit's base damage is amount - cut_per_helper_lost x the helpers of the actor's charge that are
## no longer in the fight, never below 0. From there it is an ordinary damage effect with one hit
## (core/ops/damage.gd): as an enemy move it is attack damage, so Swole, Noodle Arms, Broken Arm
## (Chad has 2 arms) and Exposed apply in the GDD's damage order. Then the actor's charge is over
## (charge becomes null). An actor that is not charging hits for amount.
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Bodies := preload("res://core/combat/bodies.gd")
const DamageOp := preload("res://core/ops/damage.gd")
const Charge := preload("res://core/ai/charge.gd")

## True: the release is aimed at a Dude.
const NEEDS_TARGET: bool = true

## Fields a charged_hit effect may have, besides "op", and their types. Both are required.
const FIELDS := {
	# Base damage of the hit before any helper is lost, 0 or more (Keg Stand: 30).
	"amount": TYPE_INT,
	# Base damage removed per helper lost during the charge, 0 or more (Keg Stand: 10).
	"cut_per_helper_lost": TYPE_INT,
}


## Returns the problems with a charged_hit effect's fields; empty means it can run.
## effect: one entry of a move's effects. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op charged_hit" % [path, field])
	for field: String in FIELDS.keys():
		if typeof(effect.get(field)) != TYPE_INT or effect[field] < 0:
			errors.append("%s.%s: must be an int, 0 or more" % [path, field])
	return errors


## Runs a charged_hit effect (see the file header).
## state: the working copy, in a fight. effect: a charged_hit effect that passed check().
## context: as for the damage op ({"actor_id", "targets", "constants", "attack"}). events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# actor: the releasing enemy, or {} when it is gone.
	var actor: Dictionary = Bodies.find_alive(state, context["actor_id"])
	# base: the hit's base damage after the cut.
	var base: int = maxi(0, effect["amount"] - effect["cut_per_helper_lost"] * Charge.helpers_lost(state, actor))
	DamageOp.run(state, {"op": "damage", "amount": base}, context, events)
	if not actor.is_empty() and actor.has("charge"):
		actor["charge"] = null
