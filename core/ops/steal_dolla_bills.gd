## The "steal_dolla_bills" effect operation (task 017). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: amount (int, 1 or more: Dolla Bills taken from each target). Dorm Rats (GDD "Floor 1"):
## "Each bite deals 3 and steals 5 Dolla Bills."
## For each target that is a Dude still standing, in order: the actor (an enemy) takes
## min(amount, the Dude's dolla_bills); the Dude's dolla_bills fall by that much (dolla_bills_changed)
## and the enemy's haul for that player rises by it (dolla_bills_stolen). A Dude with no Dolla Bills
## loses nothing and nothing is emitted. The haul goes back when the enemy dies
## (core/combat/enemy_death.gd) and leaves with it when it flees (core/ops/flee.gd).
## Guard does not stop it: the GDD says every bite steals. Nothing happens when the actor is not an
## enemy still in the fight (only enemies carry a haul).
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## True: it takes from the intent's target Dudes, so the move is aimed at a Dude.
const NEEDS_TARGET: bool = true

## Fields a steal_dolla_bills effect may have, besides "op", and their types. Anything else is an error.
const FIELDS := {
	# Dolla Bills taken from each target, 1 or more. Required.
	"amount": TYPE_INT,
}


## Returns the problems with a steal_dolla_bills effect's fields; empty means it can run.
## effect: one entry of a move's effects. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op steal_dolla_bills" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 1:
		errors.append("%s.amount: must be an int, 1 or more" % path)
	return errors


## Runs a steal_dolla_bills effect on every target Dude still standing (see the file header).
## state: the working copy. effect: a steal_dolla_bills effect that passed check().
## context: {"actor_id": the stealing enemy's uid, "targets": Array of ids it steals from}.
## events: the event list, appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	if Bodies.enemy_index(state, context["actor_id"]) == -1:
		return
	# thief: the stealing enemy, inside state.
	var thief: Dictionary = Bodies.find_alive(state, context["actor_id"])
	for target_id: String in context["targets"]:
		# index: the target's seat, or -1 when it is not a Dude.
		var index: int = Bodies.dude_index(state, target_id)
		if index == -1 or state["dudes"][index]["passed_out"]:
			continue
		# dude: the Dude robbed, inside state.
		var dude: Dictionary = state["dudes"][index]
		# taken: Dolla Bills actually taken, never more than the Dude holds.
		var taken: int = mini(effect["amount"], dude["dolla_bills"])
		if taken <= 0:
			continue
		dude["dolla_bills"] -= taken
		thief["haul"][target_id] = thief["haul"].get(target_id, 0) + taken
		events.append(Event.make("dolla_bills_changed", {"player_id": target_id, "delta": -taken,
			"dolla_bills": dude["dolla_bills"]}))
		events.append(Event.make("dolla_bills_stolen", {"enemy_uid": thief["uid"], "player_id": target_id,
			"amount": taken}))
