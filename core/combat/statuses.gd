## Statuses in a fight: who can carry which status, wear-off, Foggy at Refresh, and the enemy-phase
## skips for Grossed Out and Armless (task 009). Lane: core (Agent A).
##
## Status ids are core/schema/README.md "Status ids". Applying a status is the apply_status op
## (core/ops/apply_status.gd); this file holds the rules around it, and fight.gd calls into it at
## clearly marked points so the turn flow stays readable.
##
## Rules, from GDD "Statuses" and the answered gaps in docs/proposals/solo-slice-rule-gaps.md:
##   - Exposed and Noodle Arms go on anyone; Hungover and Foggy on Dudes only; Broken Arm and Ick on
##     enemies only (GDD "On" column). Applying one to a body that cannot carry it does nothing.
##   - G1 wear-off, 1 stack per turn (WEAR_PER_TURN): each Dude who is not Passed Out loses a stack
##     of Exposed, Noodle Arms and Hungover at End of turn (step 4); Foggy loses its stack right
##     after the Refresh it affected; each enemy loses a stack of each status right after its slot
##     in the enemy phase (whether it acted or skipped). A status at 0 stacks is removed.
##   - Foggy: the Dude draws FOGGY_DRAW_PER_STACK fewer cards at Refresh per Foggy stack, never
##     below 0 (as the task asks; see task 009's log for the open question this leaves).
##   - G6 Grossed Out: an enemy with grossed_out_skips above 0 skips its next action (its intended
##     move, whatever it is) and the count falls by 1. Event enemy_skipped, reason "grossed_out".
##   - G7 Armless: an enemy with arm_count above 0 and every arm broken, whose armless_used is
##     false, skips its next move that deals damage (a move with a DAMAGING_OPS effect); moves that
##     deal no damage still happen. armless_used becomes true, so it happens once per fight.
##     Events armless, then enemy_skipped, reason "armless". If the enemy is also Grossed Out, the
##     Grossed Out skip is used first and Armless waits for the next damaging move.
##   - G27: DEBUFFS lists what counts as a debuff (for Hair of the Dog and later cards).
##
## Functions ending in _in_place change the working copy they are given (see bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## Every status id the apply_status op accepts (core/schema/README.md "Status ids"). Changes only
## with that table, in the core lane.
const STATUS_IDS: Array[String] = ["broken_arm", "exposed", "foggy", "hungover", "ick", "noodle_arms"]

## Status ids kept as stack counts in a body's statuses map, sorted. They all wear off by
## WEAR_PER_TURN each turn (G1). Broken Arm and Ick have their own enemy fields instead.
const STACKED: Array[String] = ["exposed", "foggy", "hungover", "noodle_arms"]

## Status ids only Dudes carry (GDD "Statuses", "On: Dudes").
const DUDE_ONLY: Array[String] = ["foggy", "hungover"]

## Status ids only enemies carry (GDD "Statuses", "On: Enemies").
const ENEMY_ONLY: Array[String] = ["broken_arm", "ick"]

## Stacked statuses a Dude loses at End of turn (G1), sorted. Foggy is not here: it wears off right
## after the Refresh it affected.
const DUDE_END_OF_TURN_WEAR: Array[String] = ["exposed", "hungover", "noodle_arms"]

## What counts as a debuff (G27, answered "accept"). Broken Arm and Ick never count.
const DEBUFFS: Array[String] = ["exposed", "foggy", "hungover", "noodle_arms"]

## Stacks a wearing status loses per turn. GDD "Statuses": "1 stack per turn". A rule from the
## GDD's text, not a tuning constant (it is not in the "Tuning constants" table).
const WEAR_PER_TURN: int = 1

## Cards fewer drawn at Refresh per stack of Foggy. GDD "Statuses": "Draws 1 fewer card". A rule from
## the GDD's text, not a tuning constant.
const FOGGY_DRAW_PER_STACK: int = 1

## Effect ops that make a move one "that deals damage" for Armless (G7). Changes when a new op that
## deals attack damage is added.
const DAMAGING_OPS: Array[String] = ["damage"]

## Multiplier constants the damage order and Hungover read (GDD "Tuning constants"). Each must be a
## number, 0 or more, in ruleset.constants.
const MULTIPLIER_CONSTANTS: Array[String] = ["EXPOSED_MULT", "HUNGOVER_MULT", "NOODLE_MULT"]

## Constant holding the Broken Arm reduction at n of n arms; must be a number from 0 to 1.
const BROKEN_ARM_CONSTANT: String = "BROKEN_ARM_MAX_REDUCTION"

## Constant added to an enemy's Ick threshold each time it is Grossed Out; must be an int, 0 or more.
const ICK_STEP_CONSTANT: String = "ICK_THRESHOLD_STEP"

## Reasons in enemy_skipped events (core/schema/event.gd).
const SKIP_GROSSED_OUT: String = "grossed_out"

## See SKIP_GROSSED_OUT.
const SKIP_ARMLESS: String = "armless"


## Returns why the status constants cannot be used, or "" when they are all usable. Fight.check_start
## calls it, so a fight never starts with a constant the damage order would need missing.
## constants: ruleset.constants.
static func check_constants(constants: Dictionary) -> String:
	for name: String in MULTIPLIER_CONSTANTS:
		if not _is_number(constants.get(name)) or constants[name] < 0:
			return "constant %s is missing or not a number 0 or more" % name
	if not _is_number(constants.get(BROKEN_ARM_CONSTANT)) or constants[BROKEN_ARM_CONSTANT] < 0 \
			or constants[BROKEN_ARM_CONSTANT] > 1:
		return "constant %s is missing or not a number from 0 to 1" % BROKEN_ARM_CONSTANT
	if typeof(constants.get(ICK_STEP_CONSTANT)) != TYPE_INT or constants[ICK_STEP_CONSTANT] < 0:
		return "constant %s is missing or not an int 0 or more" % ICK_STEP_CONSTANT
	return ""


## True when value is an int or a float.
## value: any value.
static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


## True when the body is an enemy state (it has arm_count), false for a Dude state.
## body: a Dude or enemy state.
static func is_enemy(body: Dictionary) -> bool:
	return body.has("arm_count")


## True when a body of this kind can carry the status (GDD "Statuses", "On" column).
## body: a Dude or enemy state. status: a status id.
static func can_carry(body: Dictionary, status: String) -> bool:
	if is_enemy(body):
		return not DUDE_ONLY.has(status)
	return not ENEMY_ONLY.has(status)


## Returns the body's stacks of a stacked status, 0 when it has none.
## body: a Dude or enemy state. status: one of STACKED.
static func stacks(body: Dictionary, status: String) -> int:
	return body["statuses"].get(status, 0)


## True when the debuff list (G27) includes this status id.
## status: a status id.
static func is_debuff(status: String) -> bool:
	return DEBUFFS.has(status)


## Changes a stacked status by delta (never below 0), removes it at 0, and emits status_changed
## (delta = the actual change, stacks = the new total). Emits nothing when nothing changes.
## body: the Dude or enemy, inside state. id: its player_id or uid, for the event.
## status: one of STACKED. delta: stacks to add (negative to remove). events: appended to.
static func change_stacks_in_place(body: Dictionary, id: String, status: String, delta: int, events: Array) -> void:
	# before: stacks before the change.
	var before: int = stacks(body, status)
	# after: stacks after it, never below 0.
	var after: int = maxi(0, before + delta)
	if after == before:
		return
	if after == 0:
		body["statuses"].erase(status)
	else:
		body["statuses"][status] = after
	events.append(Event.make("status_changed", {"target_id": id, "status": status, "delta": after - before, "stacks": after}))


## G1, End of turn (step 4): every Dude who is not Passed Out loses WEAR_PER_TURN of each status in
## DUDE_END_OF_TURN_WEAR, in seat order and sorted status order.
## state: the working copy, in a fight. events: the event list, appended to.
static func end_of_turn_in_place(state: Dictionary, events: Array) -> void:
	for dude: Dictionary in state["dudes"]:
		if dude["passed_out"]:
			continue
		for status: String in DUDE_END_OF_TURN_WEAR:
			change_stacks_in_place(dude, dude["player_id"], status, -WEAR_PER_TURN, events)


## Returns how many cards the Dude draws at Refresh: draw_per_turn minus FOGGY_DRAW_PER_STACK per
## Foggy stack, never below 0.
## dude: a Dude state.
static func refresh_draw_count(dude: Dictionary) -> int:
	return maxi(0, dude["draw_per_turn"] - FOGGY_DRAW_PER_STACK * stacks(dude, "foggy"))


## G1: right after the Refresh it affected, the Dude loses WEAR_PER_TURN Foggy.
## state: the working copy. dude_index: the Dude's seat, 0-based. events: the event list, appended to.
static func after_refresh_in_place(state: Dictionary, dude_index: int, events: Array) -> void:
	# dude: the refreshed Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	change_stacks_in_place(dude, dude["player_id"], "foggy", -WEAR_PER_TURN, events)


## True when the enemy is Armless: it has arms and every one is broken.
## enemy: an enemy state.
static func is_armless(enemy: Dictionary) -> bool:
	return enemy["arm_count"] > 0 and enemy["broken_arms"] == enemy["arm_count"]


## True when a move's effects deal damage (any effect's op is in DAMAGING_OPS), for Armless (G7).
## effects: a move's effects list.
static func deals_damage(effects: Array) -> bool:
	for effect: Variant in effects:
		if typeof(effect) == TYPE_DICTIONARY and DAMAGING_OPS.has(effect.get("op")):
			return true
	return false


## Returns the definition of the move the enemy intends, or {} when it has no intent or the move
## is not in its definition.
## ruleset: the read-only content. enemy: an enemy state.
static func intended_move(ruleset: Dictionary, enemy: Dictionary) -> Dictionary:
	if enemy["intent"] == null:
		return {}
	for move: Dictionary in ruleset["enemies"][enemy["def_id"]]["moves"]:
		if move["id"] == enemy["intent"]["move_id"]:
			return move
	return {}


## Returns why the enemy skips its intended action this enemy phase: SKIP_GROSSED_OUT, SKIP_ARMLESS,
## or "" when it acts. Reads only. An enemy with no intended move skips nothing.
## ruleset: the read-only content. enemy: an enemy state.
static func skip_reason(ruleset: Dictionary, enemy: Dictionary) -> String:
	# move: the intended move, or {}.
	var move: Dictionary = intended_move(ruleset, enemy)
	if move.is_empty():
		return ""
	if enemy["grossed_out_skips"] > 0:
		return SKIP_GROSSED_OUT
	if is_armless(enemy) and not enemy["armless_used"] and deals_damage(move["effects"]):
		return SKIP_ARMLESS
	return ""


## The enemy-phase skip check, called for each enemy before it acts. When skip_reason() is not "",
## uses the skip (Grossed Out: grossed_out_skips - 1; Armless: armless_used = true and an armless
## event), emits enemy_skipped and returns true: the enemy must not act. Returns false otherwise.
## ruleset: the read-only content. enemy: the enemy, inside the working copy. events: appended to.
static func skip_action_in_place(ruleset: Dictionary, enemy: Dictionary, events: Array) -> bool:
	# reason: why it skips, or "".
	var reason: String = skip_reason(ruleset, enemy)
	match reason:
		SKIP_GROSSED_OUT:
			enemy["grossed_out_skips"] -= 1
		SKIP_ARMLESS:
			enemy["armless_used"] = true
			events.append(Event.make("armless", {"enemy_uid": enemy["uid"]}))
		_:
			return false
	events.append(Event.make("enemy_skipped", {"enemy_uid": enemy["uid"], "reason": reason}))
	return true


## G1: right after its slot in the enemy phase (acted or skipped), the enemy loses WEAR_PER_TURN of
## each stacked status it carries, in sorted order. Does nothing if it died during its own action.
## state: the working copy. uid: the enemy's uid. events: the event list, appended to.
static func after_enemy_slot_in_place(state: Dictionary, uid: String, events: Array) -> void:
	# enemy: the enemy, or {} if it is gone.
	var enemy: Dictionary = Bodies.find_alive(state, uid)
	if enemy.is_empty():
		return
	for status: String in STACKED:
		change_stacks_in_place(enemy, uid, status, -WEAR_PER_TURN, events)
