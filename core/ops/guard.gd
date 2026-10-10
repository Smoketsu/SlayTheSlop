## The "guard" effect operation (tasks 007 and 009). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: amount (int, 0 or more: base Guard gained). Recipient: always the actor, the Dude playing
## the card or the enemy using the move, whatever the card's target is. A Dude adds their Chill
## ("Added to Guard gained from each card", GDD "Stats"); Chill is added once per guard effect,
## because an effect's amount is "base size of the effect before Swole, Chill or Clout" (GDD card
## fields). Enemies have no Chill.
##
## Hungover (task 009, G4 answered "accept"): a Hungover Dude "gains 25% less Guard from cards":
## when context "from_card" is true, Guard = (amount + Chill) x HUNGOVER_MULT, rounded down once,
## using an exact ratio (core/ops/ratio.gd). Guard not from a card (later: Gear, Brews) is not reduced.
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const Statuses := preload("res://core/combat/statuses.gd")
const Ratio := preload("res://core/ops/ratio.gd")

## False: a guard effect lands on the actor, so an enemy move with only guard shows no targets.
const NEEDS_TARGET: bool = false

## Fields a guard effect may have, besides "op", and their types. Anything else is an error.
const FIELDS := {
	# Base Guard gained, before Chill. 0 or more.
	"amount": TYPE_INT,
}


## Returns the problems with a guard effect's fields; empty means it can run.
## effect: one entry of a card's or move's effects. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op guard" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 0:
		errors.append("%s.amount: must be an int, 0 or more" % path)
	return errors


## Runs a guard effect: the actor gains amount + Chill (Dudes) Guard, reduced by Hungover for Guard
## from cards (see the file header). Emits guard_changed when the Guard actually changes. Does
## nothing if the actor is gone.
## state: the working copy. effect: a guard effect that passed check().
## context: {"actor_id": who gains it, "targets": unused here, "constants": ruleset.constants,
##           "from_card": true when a card's effect, false or missing otherwise}. events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	gain_in_place(state, effect["amount"], context, events)


## Task 013: the guard rule for any base amount, shared with guard_per_broken_arm: the actor gains
## base + Chill (Dudes) Guard, reduced by Hungover for Guard from cards. Emits guard_changed when
## the Guard actually changes. Does nothing if the actor is gone. An enemy's Guard gain is a buff
## (G10), which Reply Guy reacts to through the guard_changed event (core/combat/powers.gd).
## state: the working copy. base: Guard before Chill, 0 or more.
## context: as for run(). events: appended to.
static func gain_in_place(state: Dictionary, base: int, context: Dictionary, events: Array) -> void:
	# body: the actor, inside state.
	var body: Dictionary = Bodies.find_alive(state, context["actor_id"])
	if body.is_empty():
		return
	# gain: Guard gained; Chill exists on Dudes only, so enemies add 0.
	var gain: int = maxi(0, base + body.get("chill", 0))
	if context.get("from_card", false) and Statuses.stacks(body, "hungover") > 0:
		gain = Ratio.floor_times(gain, Ratio.from_constant(context["constants"]["HUNGOVER_MULT"]))
	if gain == 0:
		return
	body["guard"] += gain
	events.append(Event.make("guard_changed", {"target_id": context["actor_id"], "delta": gain, "guard": body["guard"]}))
