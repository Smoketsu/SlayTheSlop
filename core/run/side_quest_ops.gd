## The Side Quest operation catalogue and its field check (task 025). Lane: run (Agent A).
##
## The operations a Side Quest option may run (format: core/schema/side_quest_def.gd, whose header
## lists them with examples; core/run/side_quests.gd runs them). This file only checks fields, so the
## ruleset builder (core/ruleset/ruleset.gd) can report a broken Side Quest file when content is
## loaded instead of when a player picks the option. Pure: no file, clock, network or random access.
extends RefCounted

const Statuses := preload("res://core/combat/statuses.gd")

## Op name -> its fields and their types; every field listed is required unless named in OPTIONAL.
## No other field is allowed. Changed only by the run lane, together with side_quest_def.gd's header.
const FIELDS := {
	# Gain (positive) or lose (negative) Dolla Bills, never below 0. amount: int, not 0.
	"dolla_bills": {"amount": TYPE_INT},
	# Heal up to amount HP. amount: int, 0 or more.
	"heal": {"amount": TYPE_INT},
	# Heal to max HP.
	"full_heal": {},
	# A new copy of card_id joins the run deck. card_id: a card id (the ruleset checks it exists).
	"add_card": {"card_id": TYPE_STRING},
	# A random Gear from the Dude's Loot pool (G24), on the side_quest stream.
	"random_gear": {},
	# Upgrade up to count random upgradable cards of the run deck, on the side_quest stream. count: 1 or more.
	"upgrade_random_cards": {"count": TYPE_INT},
	# Start the next fight with stacks of status (G25). status: a Dude status (DUDE_STATUSES). stacks: 1 or more.
	"next_fight_status": {"status": TYPE_STRING, "stacks": TYPE_INT},
	# With percent chance (side_quest stream) run "then", otherwise "else". percent: 1..99.
	"chance": {"percent": TYPE_INT, "then": TYPE_ARRAY, "else": TYPE_ARRAY},
}

## Op name -> its fields that may be left out. "else" absent means nothing happens on a miss.
const OPTIONAL := {
	"chance": ["else"],
}

## Statuses next_fight_status may give: the stacked statuses a Dude can carry (core/combat/statuses.gd).
## Derived from that file's lists so a new Dude status is allowed without a change here.
static func dude_statuses() -> Array[String]:
	# result: the allowed status ids.
	var result: Array[String] = []
	for status: String in Statuses.STACKED:
		if not Statuses.ENEMY_ONLY.has(status):
			result.append(status)
	return result


## Lowest and highest percent of a chance: a chance of 0 or 100 is not a gamble, so it is refused.
const MIN_PERCENT: int = 1
## Highest percent of a chance (see MIN_PERCENT).
const MAX_PERCENT: int = 99


## Returns the problems with a list of Side Quest operations, nested chances included; empty means
## every one can run.
## effects: an option's effects list (or a chance's then / else). path: label for messages.
static func check_all(effects: Array, path: String = "effects") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for i: int in effects.size():
		errors.append_array(check(effects[i], "%s[%d]" % [path, i]))
	return errors


## Returns the problems with one Side Quest operation; empty means it can run.
## effect: one entry of an effects list. path: label for messages.
static func check(effect: Variant, path: String = "effect") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	if typeof(effect) != TYPE_DICTIONARY or typeof(effect.get("op")) != TYPE_STRING:
		errors.append("%s: expected a Dictionary with a String \"op\"" % path)
		return errors
	# op: the operation's name.
	var op: String = effect["op"]
	if not FIELDS.has(op):
		errors.append("%s.op: unknown Side Quest operation %s (one of %s)" % [path, op, ", ".join(PackedStringArray(FIELDS.keys()))])
		return errors
	# fields: this op's fields and types.
	var fields: Dictionary = FIELDS[op]
	# keys: the effect's fields, sorted for stable messages.
	var keys: Array = effect.keys()
	keys.sort()
	for field: Variant in keys:
		if field != "op" and not fields.has(field):
			errors.append("%s.%s: unknown field for Side Quest operation %s" % [path, field, op])
	# names: the op's fields, sorted for stable messages.
	var names: Array = fields.keys()
	names.sort()
	for field: String in names:
		if not effect.has(field):
			if not OPTIONAL.get(op, []).has(field):
				errors.append("%s.%s: missing" % [path, field])
		elif typeof(effect[field]) != fields[field]:
			errors.append("%s.%s: expected %s" % [path, field, type_string(fields[field])])
	if not errors.is_empty():
		return errors
	match op:
		"dolla_bills":
			if effect["amount"] == 0:
				errors.append("%s.amount: must not be 0" % path)
		"heal":
			if effect["amount"] < 0:
				errors.append("%s.amount: must be 0 or more" % path)
		"upgrade_random_cards":
			if effect["count"] < 1:
				errors.append("%s.count: must be 1 or more" % path)
		"next_fight_status":
			if not dude_statuses().has(effect["status"]):
				errors.append("%s.status: must be one of %s" % [path, str(dude_statuses())])
			if effect["stacks"] < 1:
				errors.append("%s.stacks: must be 1 or more" % path)
		"chance":
			if effect["percent"] < MIN_PERCENT or effect["percent"] > MAX_PERCENT:
				errors.append("%s.percent: must be %d..%d" % [path, MIN_PERCENT, MAX_PERCENT])
			errors.append_array(check_all(effect["then"], path + ".then"))
			errors.append_array(check_all(effect.get("else", []), path + ".else"))
	return errors
