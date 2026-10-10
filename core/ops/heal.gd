## The "heal" effect operation (task 021). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: amount (int, 0 or more: HP restored to each target). Recipients: the effect's targets
## (a Brew's or Gear trigger's target, or a card's). Each target that is still standing (a Dude who
## is not Passed Out, an enemy still in the fight) gains up to amount HP, never above its max_hp.
## A Passed Out Dude is not healed: waking is a different rule (GDD "Passing out").
## Used by Light Beer, Party Bowl, Unused Gym Membership and Participation Trophy.
##
## Events: healed (amount = HP actually restored, hp = the new value), only when HP changes.
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## False: an enemy move with this op does not aim at Dudes (it heals its own targets, usually none).
const NEEDS_TARGET: bool = false

## Fields a heal effect may have, besides "op", and their types. Anything else is an error.
const FIELDS := {
	# HP restored to each target, before the max_hp cap. 0 or more.
	"amount": TYPE_INT,
}


## Returns the problems with a heal effect's fields; empty means it can run.
## effect: one entry of an effects list. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op heal" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 0:
		errors.append("%s.amount: must be an int, 0 or more" % path)
	return errors


## Runs a heal effect on every target still standing, in order (see the file header).
## state: the working copy. effect: a heal effect that passed check().
## context: {"targets": Array of ids it lands on; other keys unused}. events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	for target_id: String in context["targets"]:
		# body: the target, inside state, or {} if it is gone or Passed Out.
		var body: Dictionary = Bodies.find_alive(state, target_id)
		if body.is_empty():
			continue
		# restored: HP actually gained, capped at max_hp.
		var restored: int = mini(effect["amount"], maxi(0, body["max_hp"] - body["hp"]))
		if restored == 0:
			continue
		body["hp"] += restored
		events.append(Event.make("healed", {"target_id": target_id, "amount": restored, "hp": body["hp"]}))
