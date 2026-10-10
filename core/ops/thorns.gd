## The "thorns" effect operation, and the rest of the thorns rule (task 013). Lane: core (Agent A).
## Catalogue: core/ops/README.md.
##
## Chrome Dome: "This turn, enemies that hit Tom take 3 damage from the glare." Fields: amount (int,
## 1 or more). Recipient: the actor, who must be a Dude that is not Passed Out (anything else: does
## nothing). The Dude's thorns (dude_state.thorns) rise by amount; two Chrome Domes in one turn
## make 6.
##
## While thorns is above 0, every hit of an enemy's damage effect that lands on that Dude deals
## thorns damage back to the enemy that landed it, once per hit (G9: Death Roll's 3 hits take 9),
## even when the Dude's Guard absorbs the whole hit. That damage is not attack damage (G3: no Swole,
## no multipliers); it goes through the enemy's Guard, then HP, and can kill it, which stops the
## rest of its attack. core/ops/damage.gd runs it. thorns drops to 0 at the Dude's next Refresh
## (reset_in_place, called by core/combat/fight.gd), so it covers "this turn": the player phase and
## the enemy phase after it.
##
## Events: thorns_changed (delta, thorns = the new value).
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## False: thorns go on the actor, so an enemy move with only thorns shows no targets.
const NEEDS_TARGET: bool = false

## Fields a thorns effect may have, besides "op" and the generic ones in ops.gd, and their types.
const FIELDS := {
	# Damage dealt back per enemy hit, added to the Dude's thorns. 1 or more.
	"amount": TYPE_INT,
}


## Returns the problems with a thorns effect's fields; empty means it can run.
## effect: one effect, without the generic fields. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op thorns" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 1:
		errors.append("%s.amount: must be an int, 1 or more" % path)
	return errors


## Runs a thorns effect: the acting Dude's thorns rise by amount.
## state: the working copy. effect: a thorns effect that passed check().
## context: {"actor_id": the Dude; other keys unused}. events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# index: the actor's seat, or -1 when the actor is not a Dude.
	var index: int = Bodies.dude_index(state, context["actor_id"])
	if index == -1 or state["dudes"][index]["passed_out"]:
		return
	# dude: the actor, inside state.
	var dude: Dictionary = state["dudes"][index]
	dude["thorns"] += effect["amount"]
	events.append(Event.make("thorns_changed", {"target_id": dude["player_id"], "delta": effect["amount"], "thorns": dude["thorns"]}))


## At the Dude's Refresh: thorns drop to 0, with thorns_changed, only when they were above 0.
## dude: the Dude, inside the working copy. events: appended to.
static func reset_in_place(dude: Dictionary, events: Array) -> void:
	if dude["thorns"] == 0:
		return
	events.append(Event.make("thorns_changed", {"target_id": dude["player_id"], "delta": -dude["thorns"], "thorns": 0}))
	dude["thorns"] = 0
