## Shape of the fight in progress, held in run_state.combat. Shared contract. [added]
##
## The GDD describes the turn flow but has no table for fight state; every field here is
## [added] and listed in docs/changes/2026-10-10-001.md.
##
## Who may change values: only the rules core, through apply().
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")
const EnemyState := preload("res://core/schema/enemy_state.gd")

## Turn-flow phases from GDD "Turn flow", in order. "over" means the fight has ended.
## The core only ever stops (returns to the caller) in "player" or "over"; the others
## happen inside a single apply() call and appear in events.
const PHASES: Array[String] = ["intents", "refresh", "player", "end_of_turn", "enemy", "over"]

## Fight results. "" while the fight is running.
const RESULTS: Array[String] = ["", "won", "lost"]

## Required fields and their types.
const SPEC := {
	# Turn number, starting at 1 for the first turn of the fight. 0 only before the first turn starts.
	"turn": TYPE_INT,
	# Current turn-flow phase, one of PHASES.
	"phase": TYPE_STRING,
	# Enemies in the fight, left to right. Enemies act in this order. Dead enemies are removed.
	"enemies": {"list_of": TYPE_DICTIONARY},
	# "" while running, then "won" or "lost". One of RESULTS.
	"result": TYPE_STRING,
}


## Returns an empty fight at turn 0 with no enemies.
static func blank() -> Dictionary:
	return {"turn": 0, "phase": "intents", "enemies": [], "result": ""}


## Checks a fight state, including every enemy in it. Returns a list of problems.
## combat: the value to check. path: label for messages.
static func check(combat: Variant, path: String = "combat") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(combat, SPEC, path)
	if not errors.is_empty():
		return errors
	errors.append_array(Shape.check_one_of(combat["phase"], PHASES, path + ".phase"))
	errors.append_array(Shape.check_one_of(combat["result"], RESULTS, path + ".result"))
	# uids: enemy uids seen so far, to catch duplicates.
	var uids: Dictionary = {}
	for i: int in combat["enemies"].size():
		# enemy: one entry of the enemy list.
		var enemy: Dictionary = combat["enemies"][i]
		errors.append_array(EnemyState.check(enemy, "%s.enemies[%d]" % [path, i]))
		if enemy.has("uid"):
			if uids.has(enemy["uid"]):
				errors.append("%s.enemies[%d]: duplicate uid %s" % [path, i, enemy["uid"]])
			uids[enemy["uid"]] = true
	return errors
