## The "summon_enemy" effect operation (task 017). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: enemy_id (String: an enemy definition id) and count (int, 1 or more, optional, default
## DEFAULT_COUNT). Adds count new enemies of that definition to the fight, one after another at the
## right end of the left-to-right order, each with enemy_spawned (core/combat/lineup.gd: uid, HP and
## Ick threshold scaled by party size, like every enemy). Lands on nobody, so an enemy move with only
## this op has no targets. Used by Goblin Pledge (the last goblin standing calls one more), Goblin
## Shot-Caller (replaces a dead Pledge) and Goblin King Chad's Rush.
##
## A new enemy has no intent until the next turn's intents (turn flow step 1), so one called in
## during the enemy phase does not act in that phase. Not named "summon": the GDD keeps that name for
## Grube's Puppets.
##
## Nothing happens when context has no ruleset or the ruleset has no such enemy (content checks
## should catch that: Fight.check_start refuses a fight whose enemies summon unknown ids).
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Lineup := preload("res://core/combat/lineup.gd")

## False: the new enemies are not aimed at anyone, so an enemy move with only this op shows no targets.
const NEEDS_TARGET: bool = false

## Enemies summoned when the effect has no "count" field. Not a tuning number: "summon an enemy" means one.
const DEFAULT_COUNT: int = 1

## Fields a summon_enemy effect may have, besides "op", and their types. Anything else is an error.
const FIELDS := {
	# Id of the enemy definition to add, for example "goblin_pledge". Required.
	"enemy_id": TYPE_STRING,
	# How many to add, 1 or more. Optional.
	"count": TYPE_INT,
}


## Returns the problems with a summon_enemy effect's fields; empty means it can run. Does not check
## that enemy_id exists (the ruleset is not available here).
## effect: one entry of a move's effects. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op summon_enemy" % [path, field])
	if typeof(effect.get("enemy_id")) != TYPE_STRING or effect["enemy_id"] == "":
		errors.append("%s.enemy_id: must be an enemy id" % path)
	if effect.has("count") and (typeof(effect["count"]) != TYPE_INT or effect["count"] < 1):
		errors.append("%s.count: must be an int, 1 or more" % path)
	return errors


## Runs a summon_enemy effect: adds count enemies at the right end of the fight (see the file header).
## state: the working copy, in a fight. effect: a summon_enemy effect that passed check().
## context: {"ruleset": the read-only content (core/ops/ops.gd make_context); other keys unused}.
## events: the event list, appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# ruleset: the content, needed for the new enemies' definitions.
	var ruleset: Dictionary = context.get("ruleset", {})
	if ruleset.is_empty() or not ruleset["enemies"].has(effect["enemy_id"]):
		return
	for i: int in effect.get("count", DEFAULT_COUNT):
		Lineup.spawn_in_place(ruleset, state, effect["enemy_id"], state["combat"]["enemies"].size(), events)
