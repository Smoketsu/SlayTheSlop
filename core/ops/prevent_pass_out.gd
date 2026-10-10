## The "prevent_pass_out" effect operation (task 021). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: hp (int, 1 or more). Recipients: the effect's targets that are Dudes who are not Passed
## Out. For each, combat.pass_out_saves[player_id] = hp: the next time that Dude would pass out in
## this fight, they stay at hp (capped at max_hp) instead, and the save is used up
## (core/combat/bodies.gd knock_out_in_place, event pass_out_prevented). A second use before it is
## spent replaces the first; saves do not stack. Outside a fight it does nothing.
## Smelling Salts, solo: "the next time you would pass out this fight, stay at 1 HP instead".
##
## Events: none when used (the save shows in state); pass_out_prevented when it saves the Dude.
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Bodies := preload("res://core/combat/bodies.gd")

## False: an enemy move with this op does not aim at Dudes.
const NEEDS_TARGET: bool = false

## Fields a prevent_pass_out effect may have, besides "op", and their types. Required.
const FIELDS := {
	# HP the Dude is left at instead of passing out. 1 or more.
	"hp": TYPE_INT,
}


## Returns the problems with a prevent_pass_out effect's fields; empty means it can run.
## effect: one entry of an effects list. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op prevent_pass_out" % [path, field])
	if typeof(effect.get("hp")) != TYPE_INT or effect["hp"] < 1:
		errors.append("%s.hp: must be an int, 1 or more" % path)
	return errors


## Runs a prevent_pass_out effect (see the file header).
## state: the working copy. effect: a prevent_pass_out effect that passed check().
## context: {"targets": Array of ids it lands on; other keys unused}. events: unused (see header).
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	if state["combat"] == null:
		return
	for target_id: String in context["targets"]:
		# index: the target's seat, or -1 when it is not a Dude.
		var index: int = Bodies.dude_index(state, target_id)
		if index == -1 or state["dudes"][index]["passed_out"]:
			continue
		state["combat"]["pass_out_saves"][target_id] = effect["hp"]
