## The "flee" effect operation (task 017). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## No fields. The actor, an enemy, leaves the fight alive: it is removed from combat.enemies and
## enemy_fled is emitted. It does not die: there is no enemy_died, its haul leaves with it (Dorm
## Rats "flee on turn 4 with what they stole") and it drops nothing. Lands on nobody, so an enemy
## move with only this op has no targets. Nothing happens when the actor is not an enemy in the fight.
## When the last enemy flees, the fight ends as won (core/combat/fight.gd finish_if_decided_in_place:
## no enemies are left), and the run lane decides what that is worth.
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## False: fleeing is aimed at nobody, so an enemy move with only this op shows no targets.
const NEEDS_TARGET: bool = false


## Returns the problems with a flee effect's fields; empty means it can run. It takes no fields.
## effect: one entry of a move's effects. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op":
			errors.append("%s.%s: unknown field for op flee (it takes none)" % [path, field])
	return errors


## Runs a flee effect: the acting enemy leaves the fight (see the file header).
## state: the working copy, in a fight. effect: a flee effect that passed check() (unused beyond that).
## context: {"actor_id": the fleeing enemy's uid}. events: the event list, appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# index: the actor's position in the fight, or -1 when it is not an enemy in it.
	var index: int = Bodies.enemy_index(state, context["actor_id"])
	if index == -1:
		return
	state["combat"]["enemies"].remove_at(index)
	events.append(Event.make("enemy_fled", {"enemy_uid": context["actor_id"]}))
