## Shape of one enemy in a fight (GDD "Enemy fields", the per-fight values). Shared contract.
##
## The fixed values (name, floor, tier, moves) live in the enemy's definition in
## data/enemies/ and are looked up through def_id; see enemy_def.gd.
## Fields marked [added] are not in the GDD table and are listed in docs/changes/2026-10-10-001.md.
##
## Who may change values: only the rules core, through apply().
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")

## Required fields and their types. Comments give meaning, unit and range.
const SPEC := {
	# [added] Identifies this enemy in this fight: "e" followed by a number, from run_state.next_uid.
	# Two Goblin Pledges have different uids. Requests and events target enemies by uid.
	"uid": TYPE_STRING,
	# [added] Id of the enemy definition in data/enemies/, for example "goblin_pledge".
	"def_id": TYPE_STRING,
	# Current hit points, 0..max_hp. The enemy dies at 0.
	"hp": TYPE_INT,
	# Hit points this fight: the definition's solo max_hp times the party-size multiplier, rounded as the core decides.
	"max_hp": TYPE_INT,
	# Damage absorbed before HP. 0 or more.
	"guard": TYPE_INT,
	# [added] Added to every hit of this enemy's attacks, as for Dudes. Base 0. Goblin Shot-Caller and Sewer Gator raise it.
	"swole": TYPE_INT,
	# Status id -> stack count, as for Dudes. Ick and Broken Arm are NOT here; they have their own fields below.
	"statuses": {"map_of": TYPE_INT},
	# How many arms can be broken, copied from the definition. 0 makes it immune to Broken Arm.
	"arm_count": TYPE_INT,
	# Arms broken so far, 0..arm_count.
	"broken_arms": TYPE_INT,
	# True once the enemy has lost an attack to being Armless, so it happens only once per fight.
	"armless_used": TYPE_BOOL,
	# Current Ick, 0 or more. Reset to 0 when the enemy is Grossed Out.
	"ick": TYPE_INT,
	# Ick value at which the enemy is Grossed Out. Starts at ICK_BASE_NORMAL / _RIVAL / _BOSS by tier.
	"ick_threshold": TYPE_INT,
	# [added, task 009] Actions this enemy will skip because it was Grossed Out, 0 or more. Each
	# Grossed Out adds 1 (G6); each action it skips in the enemy phase uses 1. While above 0 the
	# client shows the enemy's intent as skipped. Changed only by the rules core.
	"grossed_out_skips": TYPE_INT,
	# What the enemy will do next (see INTENT_SPEC), or null before the first intent is chosen.
	"intent": [TYPE_DICTIONARY, TYPE_NIL],
	# [added, task 011] Move id of every intent this enemy has chosen in this fight, oldest first: one
	# entry per intent_set, appended when the intent is chosen (a move it later skips still counts).
	# [] until its first intent. Used for the "never the same move three times in a row" rule and to
	# find its place in a scripted pattern (enemy_def.gd "pattern"). Grows by 1 per turn.
	"move_history": {"list_of": TYPE_STRING},
	# [added, task 017] Dolla Bills this enemy has stolen and still carries: player_id -> amount, each
	# 1 or more; {} when it carries nothing. Raised by the steal_dolla_bills op (Dorm Rats). When the
	# enemy dies every player gets their part back; when it flees the haul leaves with it. Changed
	# only by the rules core.
	"haul": {"map_of": TYPE_INT},
	# [added, task 017] Brews it drops when it dies, 0 or more, copied from its definition's
	# drops_brews when it joins the fight (Mimic Cooler: 1), so the death can be reported without the
	# content data. Changed only by the rules core.
	"drops_brews": TYPE_INT,
	# [added, task 019] The charge in progress (enemy_def.gd CHARGE_DEF_SPEC; see CHARGE_SPEC), or
	# null when it is not charging. Goblin King Chad's Keg Stand. Changed only by the rules core.
	"charge": [TYPE_DICTIONARY, TYPE_NIL],
	# [added, task 019] Actions this enemy will skip because it fell (every helper of its charge died),
	# 0 or more. Each fall adds 1; each action it skips in the enemy phase uses 1 (enemy_skipped,
	# reason "fallen"). Changed only by the rules core.
	"fallen_skips": TYPE_INT,
}

## [added, task 019] Shape of a charge in progress (enemy "charge").
const CHARGE_SPEC := {
	# Intents it has shown with the charge's move_id so far, 1..the definition's turns.
	"turns_charged": TYPE_INT,
	# Uids of the enemies holding the charge up, chosen when it started. One that is no longer in the
	# fight was killed during the charge.
	"helper_uids": {"list_of": TYPE_STRING},
	# Exposed stacks it gains if it falls, copied from the definition when the charge starts, so the
	# fall can happen where the content data is not available. 0 or more.
	"fall_exposed": TYPE_INT,
}

## Shape of an intent (GDD "intent").
const INTENT_SPEC := {
	# Id of the move it will use next, one of the definition's moves.
	"move_id": TYPE_STRING,
	# Who it is aimed at: player_ids of Dudes (or, later, Puppet ids). Empty for moves with no target.
	"target_ids": {"list_of": TYPE_STRING},
}


## Returns an enemy state with every field present and zero or empty values.
## The rules core fills in HP, arm_count and ick_threshold from the definition and constants.
## uid: this enemy's id in the fight, for example "e7". def_id: its definition id.
static func blank(uid: String, def_id: String) -> Dictionary:
	return {
		"uid": uid,
		"def_id": def_id,
		"hp": 0,
		"max_hp": 0,
		"guard": 0,
		"swole": 0,
		"statuses": {},
		"arm_count": 0,
		"broken_arms": 0,
		"armless_used": false,
		"ick": 0,
		"ick_threshold": 0,
		"grossed_out_skips": 0,
		"intent": null,
		"move_history": [],
		"haul": {},
		"drops_brews": 0,
		"charge": null,
		"fallen_skips": 0,
	}


## Checks an enemy state. Returns a list of problems; empty means valid.
## enemy: the value to check. path: label for messages, for example "combat.enemies[1]".
static func check(enemy: Variant, path: String = "enemy") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(enemy, SPEC, path)
	if not errors.is_empty():
		return errors
	if enemy["intent"] != null:
		errors.append_array(Shape.check(enemy["intent"], INTENT_SPEC, path + ".intent"))
	if enemy["broken_arms"] < 0 or enemy["broken_arms"] > enemy["arm_count"]:
		errors.append("%s.broken_arms: %d is outside 0..arm_count (%d)" % [path, enemy["broken_arms"], enemy["arm_count"]])
	if enemy["grossed_out_skips"] < 0:
		errors.append("%s.grossed_out_skips: %d is below 0" % [path, enemy["grossed_out_skips"]])
	if enemy["charge"] != null:
		errors.append_array(Shape.check(enemy["charge"], CHARGE_SPEC, path + ".charge"))
	if enemy["fallen_skips"] < 0:
		errors.append("%s.fallen_skips: %d is below 0" % [path, enemy["fallen_skips"]])
	if enemy["drops_brews"] < 0:
		errors.append("%s.drops_brews: %d is below 0" % [path, enemy["drops_brews"]])
	for player_id: String in enemy["haul"].keys():
		if enemy["haul"][player_id] <= 0:
			errors.append("%s.haul.%s: amounts must be 1 or more" % [path, player_id])
	for status: String in enemy["statuses"].keys():
		if enemy["statuses"][status] <= 0:
			errors.append("%s.statuses.%s: stacks must be 1 or more" % [path, status])
	return errors
