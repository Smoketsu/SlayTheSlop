## The "damage" effect operation (task 007). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: amount (int, 0 or more: base damage of one hit) and hits (int, 1 or more, optional,
## default DEFAULT_HITS: how many times the hit repeats). Recipients: the effect's targets, that is
## the card's chosen target(s) or the enemy intent's target_ids.
##
## Damage order (GDD "Combat rules"), as far as task 007 goes:
##   step 1: base amount + the attacker's Swole, per hit (never below 0);
##   steps 2-4 (Noodle Arms, Broken Arm, Exposed): NOT YET, task 009;
##   step 5: Guard absorbs the damage and is reduced by what it absorbed (G2, answered "accept"),
##           the rest comes off HP, HP never goes below 0, and a body at 0 HP dies or Passes Out.
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## True: an enemy move with this op needs Dudes to aim at, so its intent shows targets.
const NEEDS_TARGET: bool = true

## Hits per damage effect when the effect has no "hits" field. Not a tuning number: "one hit" is
## what a damage effect without repeats means.
const DEFAULT_HITS: int = 1

## Fields a damage effect may have, besides "op", and their types. Anything else is an error.
const FIELDS := {
	# Base damage of one hit, before Swole. 0 or more.
	"amount": TYPE_INT,
	# How many times the hit repeats. 1 or more. Optional.
	"hits": TYPE_INT,
}


## Returns the problems with a damage effect's fields; empty means it can run.
## effect: one entry of a card's or move's effects. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op damage" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 0:
		errors.append("%s.amount: must be an int, 0 or more" % path)
	if effect.has("hits") and (typeof(effect["hits"]) != TYPE_INT or effect["hits"] < 1):
		errors.append("%s.hits: must be an int, 1 or more" % path)
	return errors


## Runs a damage effect: for each hit in turn, every target still alive takes one hit (hit 1 lands
## on every target, then hit 2 ...). Stops as soon as the fight is decided. Swole is read from the
## attacker before each hit.
## state: the working copy. effect: a damage effect that passed check().
## context: {"actor_id": who deals it, "targets": Array of ids it lands on}. events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# hits: how many times to repeat the hit.
	var hits: int = effect.get("hits", DEFAULT_HITS)
	for hit: int in hits:
		for target_id: String in context["targets"]:
			if Bodies.is_decided(state):
				return
			if Bodies.find_alive(state, target_id).is_empty():
				continue
			# attacker: the body dealing the hit, or {} if it is gone.
			var attacker: Dictionary = Bodies.find_alive(state, context["actor_id"])
			# swole: the attacker's Swole, added to every hit (GDD "Stats").
			var swole: int = attacker.get("swole", 0)
			deal_in_place(state, context["actor_id"], target_id, maxi(0, effect["amount"] + swole), events)


## Damage order step 5 for one hit of final size amount: Guard absorbs and is used up, the rest
## comes off HP (never below 0), then a body at 0 HP dies or Passes Out. Emits damage_dealt (and
## enemy_died or dude_passed_out). Guard lost here gets no guard_changed event: damage_dealt.blocked
## says it. Does nothing if target_id names no living body.
## state: the working copy. source_id: who deals it ("" for no attacker). target_id: who takes it.
## amount: damage after steps 1-4, 0 or more. events: the event list, appended to.
static func deal_in_place(state: Dictionary, source_id: String, target_id: String, amount: int, events: Array) -> void:
	# body: the target, inside state.
	var body: Dictionary = Bodies.find_alive(state, target_id)
	if body.is_empty():
		return
	# blocked: damage Guard absorbs.
	var blocked: int = mini(body["guard"], amount)
	body["guard"] -= blocked
	# hp_lost: damage that reaches HP, capped at what HP is left.
	var hp_lost: int = mini(body["hp"], amount - blocked)
	body["hp"] -= hp_lost
	events.append(Event.make("damage_dealt", {"source_id": source_id, "target_id": target_id,
		"amount": amount, "blocked": blocked, "hp_lost": hp_lost}))
	if body["hp"] == 0:
		Bodies.knock_out_in_place(state, target_id, events)
