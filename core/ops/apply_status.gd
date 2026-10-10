## The "apply_status" effect operation (task 009). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: status (String, one of core/combat/statuses.gd STATUS_IDS) and stacks (int, 1 or more).
## Recipients: the effect's targets, that is the card's chosen target(s) or the enemy intent's
## target_ids. A target that cannot carry the status (Hungover or Foggy on an enemy, Broken Arm or
## Ick on a Dude) is left alone. Per target:
##   - exposed, noodle_arms, hungover, foggy: stacks are added to the target's statuses map.
##   - broken_arm: broken_arms rises by stacks, capped at arm_count; an enemy with arm_count 0 is
##     unaffected, and breaks past the count do nothing (G7).
##   - ick: Ick rises by stacks + the actor's Clout, once per application (G5); Clout is 0 for an
##     actor without it (enemies). Then, if Ick is at or above ick_threshold, the enemy is Grossed
##     Out (G6): Ick resets to 0, the threshold rises by ICK_THRESHOLD_STEP, and grossed_out_skips
##     rises by 1, so it skips its next action in the enemy phase (core/combat/statuses.gd).
## Events: status_changed for every change, with delta = the actual change and stacks = the new
## total (0 when cleared). A Grossed Out target gets, in order: status_changed (Ick added),
## grossed_out (new_threshold), status_changed (Ick back to 0). Nothing is emitted when nothing
## changes (a capped Broken Arm, an Ick application of 0).
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const Statuses := preload("res://core/combat/statuses.gd")

## True: an enemy move with this op aims at Dudes (Goblin Bouncer's Noodle Arms lands on its target).
const NEEDS_TARGET: bool = true

## Fields an apply_status effect may have, besides "op", and their types. Both are required.
const FIELDS := {
	# Which status: one of core/combat/statuses.gd STATUS_IDS.
	"status": TYPE_STRING,
	# How many stacks to apply (Broken Arm: arms to break; Ick: Ick before Clout). 1 or more.
	"stacks": TYPE_INT,
}

## Grossed Out skips added each time an enemy is Grossed Out (GDD: "it skips its next action").
## A rule from the GDD's text, not a tuning constant.
const SKIPS_PER_GROSSED_OUT: int = 1


## Returns the problems with an apply_status effect's fields; empty means it can run.
## effect: one entry of a card's or move's effects. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op apply_status" % [path, field])
	if typeof(effect.get("status")) != TYPE_STRING or not Statuses.STATUS_IDS.has(effect["status"]):
		errors.append("%s.status: must be one of %s" % [path, ", ".join(PackedStringArray(Statuses.STATUS_IDS))])
	if typeof(effect.get("stacks")) != TYPE_INT or effect["stacks"] < 1:
		errors.append("%s.stacks: must be an int, 1 or more" % path)
	return errors


## Runs an apply_status effect on every target still in the fight, in order (see the file header).
## state: the working copy. effect: an apply_status effect that passed check().
## context: {"actor_id": who applies it (for Clout), "targets": Array of ids it lands on,
##           "constants": ruleset.constants}. events: the event list, appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	for target_id: String in context["targets"]:
		# body: the target, inside state, or {} if it is gone.
		var body: Dictionary = Bodies.find_alive(state, target_id)
		if body.is_empty() or not Statuses.can_carry(body, effect["status"]):
			continue
		match effect["status"]:
			"broken_arm":
				_break_arms_in_place(body, effect["stacks"], events)
			"ick":
				# actor: the body applying the Ick, or {} if it is gone; only its Clout is read.
				var actor: Dictionary = Bodies.find_alive(state, context["actor_id"])
				_add_ick_in_place(body, effect["stacks"] + actor.get("clout", 0), context["constants"], events)
			_:
				Statuses.change_stacks_in_place(body, target_id, effect["status"], effect["stacks"], events)


## Breaks up to count more arms on an enemy, capped at its arm_count (G7). Emits status_changed
## "broken_arm" when at least one arm breaks.
## enemy: the enemy, inside state. count: arms to break, 1 or more. events: appended to.
static func _break_arms_in_place(enemy: Dictionary, count: int, events: Array) -> void:
	# after: broken arms after the break, never above arm_count.
	var after: int = mini(enemy["arm_count"], enemy["broken_arms"] + count)
	# delta: arms actually broken now.
	var delta: int = after - enemy["broken_arms"]
	if delta <= 0:
		return
	enemy["broken_arms"] = after
	events.append(Event.make("status_changed", {"target_id": enemy["uid"], "status": "broken_arm", "delta": delta, "stacks": after}))


## Adds amount Ick to an enemy and Grosses it Out at its threshold (G6; see the file header).
## enemy: the enemy, inside state. amount: Ick to add, stacks + Clout; nothing happens at 0 or less.
## constants: ruleset.constants; reads ICK_THRESHOLD_STEP. events: the event list, appended to.
static func _add_ick_in_place(enemy: Dictionary, amount: int, constants: Dictionary, events: Array) -> void:
	if amount <= 0:
		return
	enemy["ick"] += amount
	events.append(Event.make("status_changed", {"target_id": enemy["uid"], "status": "ick", "delta": amount, "stacks": enemy["ick"]}))
	if enemy["ick"] < enemy["ick_threshold"]:
		return
	# cleared: the Ick removed by the reset.
	var cleared: int = enemy["ick"]
	enemy["ick"] = 0
	enemy["ick_threshold"] += constants[Statuses.ICK_STEP_CONSTANT]
	enemy["grossed_out_skips"] += SKIPS_PER_GROSSED_OUT
	events.append(Event.make("grossed_out", {"enemy_uid": enemy["uid"], "new_threshold": enemy["ick_threshold"]}))
	events.append(Event.make("status_changed", {"target_id": enemy["uid"], "status": "ick", "delta": -cleared, "stacks": 0}))
