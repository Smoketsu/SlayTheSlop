## The "gain_swole" effect operation (task 017). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: amount (int, 1 or more: Swole gained) and tag (String, optional). Swole is "added to every
## hit of every attack" (GDD "Stats"); enemies have it too (core/schema/enemy_state.gd swole).
##   - Without tag: the actor gains amount Swole (Sewer Gator's trigger "gains 2 Swole whenever it
##     deals unblocked damage"; works for a Dude's card as well).
##   - With tag: every enemy in the fight whose definition has that tag gains it, left to right,
##     the actor included if it has the tag (Goblin Shot-Caller "gives all goblins 2 Swole").
## Events: stat_changed (stat "swole", delta, value = new swole; task 021's event, used instead of
## a separate Swole event at the merge) for each body that gains. Swole an enemy gains is a buff
## (G10). Lands on the actor or the tagged enemies, never on the intent's targets, so an enemy move
## with only this op has no targets. Bodies that are gone are skipped.
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## The stat_changed "stat" value for Swole (core/schema/gear_def.gd STATS). Fixed.
const SWOLE_STAT: String = "swole"

## False: it lands on the actor or on tagged enemies, so an enemy move with only this op shows no targets.
const NEEDS_TARGET: bool = false

## Fields a gain_swole effect may have, besides "op", and their types. Anything else is an error.
const FIELDS := {
	# Swole gained, 1 or more. Required.
	"amount": TYPE_INT,
	# Optional enemy group (enemy_def.gd "tags"): when present, every enemy with it gains instead of the actor.
	"tag": TYPE_STRING,
}


## Returns the problems with a gain_swole effect's fields; empty means it can run.
## effect: one entry of a card's or move's effects. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op gain_swole" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 1:
		errors.append("%s.amount: must be an int, 1 or more" % path)
	if effect.has("tag") and (typeof(effect["tag"]) != TYPE_STRING or effect["tag"] == ""):
		errors.append("%s.tag: must be a group name" % path)
	return errors


## Runs a gain_swole effect (see the file header).
## state: the working copy. effect: a gain_swole effect that passed check().
## context: {"actor_id": who uses it, "ruleset": the read-only content, needed only with "tag"}.
## events: the event list, appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# ids: who gains, in order.
	var ids: Array = [context["actor_id"]]
	if effect.has("tag"):
		ids = []
		# enemies: the content's enemy definitions, or {} without a ruleset.
		var enemies: Dictionary = context.get("ruleset", {}).get("enemies", {})
		for enemy: Dictionary in state["combat"]["enemies"]:
			if enemies.get(enemy["def_id"], {}).get("tags", []).has(effect["tag"]):
				ids.append(enemy["uid"])
	for id: String in ids:
		# body: who gains, inside state, or {} when gone.
		var body: Dictionary = Bodies.find_alive(state, id)
		if body.is_empty():
			continue
		body["swole"] += effect["amount"]
		events.append(Event.make("stat_changed", {"target_id": id, "stat": SWOLE_STAT, "delta": effect["amount"], "value": body["swole"]}))
