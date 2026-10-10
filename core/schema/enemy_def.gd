## Shape of an enemy definition, one JSON file per enemy in data/enemies/ (GDD "Enemy fields",
## the fixed values). Shared contract.
##
## Moves use the same effect operations as cards. Behaviors that are not a move (Keg Slime
## splitting at half HP, the last Goblin Pledge calling for help, Dorm Rats fleeing on turn 4)
## need fields this shape does not have yet; the core lane adds them additively when it builds
## those rules. Until then, content describes them in "text" and the task lists the needed field.
##
## Who may change definitions: the content lane. Who may change this shape: a contract PR.
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")

## Enemy tiers, from the GDD. Set rewards and the base Ick threshold.
const TIERS: Array[String] = ["normal", "rival", "boss"]

## Required fields and their types.
const SPEC := {
	# Unique key, snake_case, equal to the file name without ".json", for example "goblin_pledge". Never changes after merge.
	"id": TYPE_STRING,
	# Display name.
	"name": TYPE_STRING,
	# Which floor it appears on, 1..3, or 4 for the final boss.
	"floor": TYPE_INT,
	# One of TIERS.
	"tier": TYPE_STRING,
	# Solo hit points before the party-size multiplier. 1 or more.
	"max_hp": TYPE_INT,
	# How many arms can be broken. 0 makes it immune to Broken Arm.
	"arm_count": TYPE_INT,
	# The moves it can choose from (see MOVE_SPEC). At least one.
	"moves": {"list_of": TYPE_DICTIONARY},
}

## Fields that may be left out.
const OPTIONAL := {
	# [added] The GDD's behavior text for this enemy, kept with the data so the next agent can see
	# what is not yet expressed as moves. Not shown to players.
	"text": TYPE_STRING,
	# [added, task 011] A scripted move order: move ids of this enemy, at least one. When present the
	# enemy ignores weights and uses these moves in this order, starting from the first and cycling
	# back to it after the last, one entry per intent it chooses in the fight. Followed exactly; the
	# "never three times in a row" rule does not apply to it (G11). Entries may name weight-0 moves.
	# Absent: every intent is a weighted random choice. Goblin Bouncer: ["guard_up", "hit"] or similar.
	"pattern": {"list_of": TYPE_STRING},
}

## Shape of one move.
const MOVE_SPEC := {
	# Move key, unique within this enemy, for example "bite".
	"id": TYPE_STRING,
	# Relative chance of being chosen, 0 or more. 0 means "only chosen by a rule, never at random".
	"weight": TYPE_INT,
	# Intent icon key the client shows, for example "attack", "defend", "debuff", "buff", "summon", "unknown".
	"intent": TYPE_STRING,
	# Operations run in order, as on cards.
	"effects": {"list_of": TYPE_DICTIONARY},
}

## [added, task 011] Who a move's effects that need a target are aimed at (values of a move's
## optional "target" field, see MOVE_OPTIONAL). Changes only with a contract PR.
##   "dude":      a single-target attack: 1 Dude, or MULTI_TARGET_COUNT different Dudes once the
##                party has MULTI_TARGET_PARTY_SIZE players (GDD "Difficulty scaling"). Chosen at
##                random among Dudes who are not Passed Out.
##   "all_dudes": an area attack: every Dude who is not Passed Out ("Area attacks hit everyone").
##   "none":      no Dude targets (Guard, buffs on itself).
const MOVE_TARGETS: Array[String] = ["dude", "all_dudes", "none"]

## Fields of a move that may be left out.
const MOVE_OPTIONAL := {
	# [added, task 011] One of MOVE_TARGETS. When absent, the core decides from the effects: a move
	# with an op that needs a target (core/ops/README.md, for example "damage") is aimed as "dude",
	# any other move as "none".
	"target": TYPE_STRING,
}


## Checks an enemy definition. Returns a list of problems; empty means valid.
## enemy: the parsed definition. path: label for messages, usually the file path.
static func check(enemy: Variant, path: String = "enemy") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(enemy, SPEC, path, OPTIONAL)
	if not errors.is_empty():
		return errors
	errors.append_array(Shape.check_one_of(enemy["tier"], TIERS, path + ".tier"))
	if enemy["max_hp"] < 1:
		errors.append("%s.max_hp: must be 1 or more" % path)
	if enemy["arm_count"] < 0:
		errors.append("%s.arm_count: must be 0 or more" % path)
	if enemy["moves"].is_empty():
		errors.append("%s.moves: needs at least one move" % path)
	# move_ids: move ids seen so far, to catch duplicates.
	var move_ids: Dictionary = {}
	for i: int in enemy["moves"].size():
		# move_path: label for this move in messages.
		var move_path: String = "%s.moves[%d]" % [path, i]
		# move_errors: shape problems with this move.
		var move_errors: Array[String] = Shape.check(enemy["moves"][i], MOVE_SPEC, move_path, MOVE_OPTIONAL)
		errors.append_array(move_errors)
		if move_errors.is_empty():
			if move_ids.has(enemy["moves"][i]["id"]):
				errors.append("%s.id: duplicate move id %s" % [move_path, enemy["moves"][i]["id"]])
			move_ids[enemy["moves"][i]["id"]] = true
			if enemy["moves"][i]["weight"] < 0:
				errors.append("%s.weight: must be 0 or more" % move_path)
			if enemy["moves"][i].has("target"):
				errors.append_array(Shape.check_one_of(enemy["moves"][i]["target"], MOVE_TARGETS, move_path + ".target"))
	if enemy.has("pattern"):
		if enemy["pattern"].is_empty():
			errors.append("%s.pattern: needs at least one move id when present" % path)
		for i: int in enemy["pattern"].size():
			if not move_ids.has(enemy["pattern"][i]):
				errors.append("%s.pattern[%d]: %s is not one of this enemy's move ids" % [path, i, enemy["pattern"][i]])
	return errors
