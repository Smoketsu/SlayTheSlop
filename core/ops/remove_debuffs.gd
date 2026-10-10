## The "remove_debuffs" effect operation (task 021). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## No fields. Recipients: the effect's targets. Each target still standing loses every stack of
## every debuff it carries. Debuffs are core/combat/statuses.gd DEBUFFS (G27: Exposed, Noodle Arms,
## Hungover, Foggy; Broken Arm and Ick never count), removed in that sorted order.
## Hair of the Dog: "Remove all your debuffs" (target self).
##
## Events: status_changed for each debuff removed (delta = -stacks, stacks = 0).
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Bodies := preload("res://core/combat/bodies.gd")
const Statuses := preload("res://core/combat/statuses.gd")

## False: an enemy move with this op does not aim at Dudes.
const NEEDS_TARGET: bool = false


## Returns the problems with a remove_debuffs effect's fields (it has none); empty means it can run.
## effect: one entry of an effects list. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op":
			errors.append("%s.%s: unknown field for op remove_debuffs" % [path, field])
	return errors


## Runs a remove_debuffs effect on every target still standing (see the file header).
## state: the working copy. effect: a remove_debuffs effect that passed check() (no fields used).
## context: {"targets": Array of ids it lands on; other keys unused}. events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	for target_id: String in context["targets"]:
		# body: the target, inside state, or {} if it is gone.
		var body: Dictionary = Bodies.find_alive(state, target_id)
		if body.is_empty():
			continue
		for status: String in Statuses.DEBUFFS:
			Statuses.change_stacks_in_place(body, target_id, status, -Statuses.stacks(body, status), events)
