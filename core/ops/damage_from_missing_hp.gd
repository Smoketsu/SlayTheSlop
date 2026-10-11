## The "damage_from_missing_hp" effect operation (task 039). Lane: core (Agent A). Catalogue:
## core/ops/README.md.
##
## Fields: cap (int, 0 or more: the most base damage the hit can have). Nothing to Lose
## (tom_nothing_to_lose, task 012's proposal): "Deal damage equal to the HP Tom is missing, up to 30."
## The hit's base damage is the actor's missing HP, max_hp - hp, read when the effect runs (so after
## the card's earlier effects), never above cap and never below 0. From there it is an ordinary
## damage effect with one hit (core/ops/damage.gd): on an Attack card it is attack damage (G3), so
## Swole, Noodle Arms and Exposed apply in the GDD's damage order and Guard absorbs it. An actor at
## full HP hits with a base of 0, which Swole can still raise, as for any damage effect. An actor
## that is gone (dead or Passed Out) deals nothing.
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Bodies := preload("res://core/combat/bodies.gd")
const DamageOp := preload("res://core/ops/damage.gd")

## True: the hit is aimed at the card's target, so an enemy move using it would show targets.
const NEEDS_TARGET: bool = true

## Fields a damage_from_missing_hp effect may have, besides "op" and the generic ones in ops.gd,
## and their types. "cap" is required.
const FIELDS := {
	# The most base damage the hit can have, 0 or more (Nothing to Lose: 30). Data on the card, not a
	# tuning constant (task 012's proposal).
	"cap": TYPE_INT,
}


## Returns the problems with a damage_from_missing_hp effect's fields; empty means it can run.
## effect: one effect, without the generic fields. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op damage_from_missing_hp" % [path, field])
	if typeof(effect.get("cap")) != TYPE_INT or effect["cap"] < 0:
		errors.append("%s.cap: must be an int, 0 or more" % path)
	return errors


## Returns the base damage the effect would deal now: the actor's missing HP (max_hp - hp), capped at
## cap and never below 0; 0 when the actor is gone. Reads only.
## state: the run state, in a fight. effect: an effect that passed check(). actor_id: who deals it.
static func base_damage(state: Dictionary, effect: Dictionary, actor_id: String) -> int:
	# actor: the body dealing the hit, or {} when it is gone.
	var actor: Dictionary = Bodies.find_alive(state, actor_id)
	if actor.is_empty():
		return 0
	return clampi(actor["max_hp"] - actor["hp"], 0, effect["cap"])


## Runs a damage_from_missing_hp effect: one damage hit of base_damage() on the targets (see the
## file header). Does nothing when the actor is gone.
## state: the working copy, in a fight. effect: an effect that passed check().
## context: as for the damage op ({"actor_id", "targets", "constants", "attack"}). events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	if Bodies.find_alive(state, context["actor_id"]).is_empty():
		return
	DamageOp.run(state, {"op": "damage", "amount": base_damage(state, effect, context["actor_id"])}, context, events)
