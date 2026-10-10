## The effect operation registry (task 007). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Cards and enemy moves list effects; each effect is a Dictionary with an "op" name and that op's
## fields. This file maps op names to the script that checks and runs them. Adding an op: write
## core/ops/<op>.gd with NEEDS_TARGET, check(effect, path) and run(state, effect, context, events),
## add it to OPS, and document it in README.md. Content agents request new ops in a task (CLAUDE.md
## "Content is data").
##
## Pure: no file, clock, network or random access.
extends RefCounted

const DamageOp := preload("res://core/ops/damage.gd")
const GuardOp := preload("res://core/ops/guard.gd")

## Op name (the effect's "op" value) -> the script implementing it. Only the core lane changes this.
const OPS := {
	"damage": DamageOp,
	"guard": GuardOp,
}


## True when op names an operation the core can run.
## op: an effect's "op" value.
static func is_known(op: Variant) -> bool:
	return typeof(op) == TYPE_STRING and OPS.has(op)


## Returns the problems with one effect: an unknown op, or bad fields for a known one. Empty means
## the effect can run. Content tests may call this to check data files.
## effect: one entry of a card's or enemy move's effects. path: label for messages.
static func check(effect: Variant, path: String = "effect") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	if typeof(effect) != TYPE_DICTIONARY:
		errors.append("%s: expected a Dictionary" % path)
		return errors
	if not is_known(effect.get("op")):
		errors.append("%s.op: %s is not an op the core has (see core/ops/README.md)" % [path, var_to_str(effect.get("op"))])
		return errors
	return OPS[effect["op"]].check(effect, path)


## Returns the problems with a whole effects list, each labelled with its index.
## effects: a card's or move's effects list. path: label for messages.
static func check_all(effects: Array, path: String = "effects") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for i: int in effects.size():
		errors.append_array(check(effects[i], "%s[%d]" % [path, i]))
	return errors


## True when an enemy move with these effects aims at Dudes (any of its ops has NEEDS_TARGET).
## Unknown ops count as not needing a target.
## effects: an enemy move's effects list.
static func needs_target(effects: Array) -> bool:
	for effect: Variant in effects:
		if typeof(effect) == TYPE_DICTIONARY and is_known(effect.get("op")) and OPS[effect["op"]].NEEDS_TARGET:
			return true
	return false


## Runs one effect that passed check().
## state: the working copy, changed by the op. effect: the effect.
## context: {"actor_id": String, the player_id or enemy uid using the card or move;
##           "targets": Array of ids the effect lands on, chosen by the card's target or the intent}.
## events: the event list, appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	OPS[effect["op"]].run(state, effect, context, events)
