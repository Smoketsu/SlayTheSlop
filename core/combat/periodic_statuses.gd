## Statuses an enemy has on a fixed cycle of turns, and what Faded does (task 017). Lane: core (Agent A).
## Shape: core/schema/enemy_def.gd "periodic_statuses".
##
## Boo-zer (GDD "Floor 1"): "Every other turn it is Faded and takes at most 1 damage per hit."
##   - At the start of every turn (turn flow step 1, before intents), update_in_place() gives each
##     enemy with periodic_statuses the status on the turns its entry names (first_turn,
##     first_turn + every, ...) and takes it away on the others. The status is kept in the enemy's
##     statuses map with 1 stack (status_changed +1 / -1), so the client can show it all turn. It is
##     not one of the wearing statuses (core/combat/statuses.gd STACKED), so G1 wear-off leaves it.
##   - An enemy that joins the fight mid-turn (summoned, split) gets its periodic statuses from the
##     next turn's start.
##   - Faded: cap_hit() caps the damage of each hit on a Faded body at FADED_MAX_DAMAGE. It is applied
##     to every hit, attack damage or not, after the damage order's rounding and before Guard
##     (core/ops/damage.gd hit_amount).
##
## Functions ending in _in_place change the working copy they are given (see core/combat/bodies.gd).
## Pure: no file, clock, network or random access.
extends RefCounted

const Statuses := preload("res://core/combat/statuses.gd")

## The Faded status id (core/schema/README.md "Status ids").
const FADED: String = "faded"

## Constant holding the most damage one hit deals to a Faded body (data/constants.json); an int, 0 or more.
const FADED_CONSTANT: String = "FADED_MAX_DAMAGE"

## Stacks a periodic status has while it is on. Not a tuning number: the status is on or off.
const ON_STACKS: int = 1


## Returns why the constants periodic statuses need cannot be used, or "" when they can.
## constants: ruleset.constants.
static func check_constants(constants: Dictionary) -> String:
	if typeof(constants.get(FADED_CONSTANT)) != TYPE_INT or constants[FADED_CONSTANT] < 0:
		return "constant %s is missing or not an int 0 or more" % FADED_CONSTANT
	return ""


## True when a periodic status is on in this turn: turn >= first_turn and (turn - first_turn) is a
## multiple of every.
## turn: the fight's turn number, 1 or more. every: the entry's every, 1 or more.
## first_turn: the entry's first_turn, 1 or more.
static func is_on(turn: int, every: int, first_turn: int) -> bool:
	return turn >= first_turn and (turn - first_turn) % every == 0


## Turn flow step 1: for each enemy, left to right, and each of its periodic_statuses in definition
## order, turns the status on (ON_STACKS) or off for the current turn, with status_changed when it changes.
## ruleset: the read-only content. state: the working copy, in a fight. events: the event list, appended to.
static func update_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	# turn: the turn that is starting.
	var turn: int = state["combat"]["turn"]
	for enemy: Dictionary in state["combat"]["enemies"]:
		for entry: Dictionary in ruleset["enemies"][enemy["def_id"]].get("periodic_statuses", []):
			# want: stacks it should have this turn.
			var want: int = ON_STACKS if is_on(turn, entry["every"], entry["first_turn"]) else 0
			Statuses.change_stacks_in_place(enemy, enemy["uid"], entry["status"],
				want - Statuses.stacks(enemy, entry["status"]), events)


## Returns the damage of one hit after the Faded cap: amount, or FADED_MAX_DAMAGE when the target is
## Faded and amount is larger.
## constants: ruleset.constants; reads FADED_MAX_DAMAGE only when the target is Faded.
## target: the body taking the hit. amount: the hit's damage after rounding, before Guard, 0 or more.
static func cap_hit(constants: Dictionary, target: Dictionary, amount: int) -> int:
	if not target.get("statuses", {}).has(FADED):
		return amount
	return mini(amount, constants[FADED_CONSTANT])
