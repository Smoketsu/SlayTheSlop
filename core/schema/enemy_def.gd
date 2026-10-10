## Shape of an enemy definition, one JSON file per enemy in data/enemies/ (GDD "Enemy fields",
## the fixed values). Shared contract.
##
## Moves use the same effect operations as cards. Behaviors that are not a plain move are optional
## fields added by task 017 (floor 1): groups (tags), escorts that arrive with it (arrives_with),
## rules that pick a move in certain situations (move_rules), things it does outside its own turn
## (triggers), splitting at low HP (split), statuses on a cycle of turns (periodic_statuses) and
## Brew drops (drops_brews). What each one does in a fight is in core/combat/enemy_behaviors.gd and
## core/ops/README.md; this file only checks the shape. Anything still not expressible is described
## in "text" and listed in a task for the core lane.
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
	# [task 017] An intent picked by move_rules still counts as one entry, so the pattern moves on.
	"pattern": {"list_of": TYPE_STRING},
	# [added, task 017] Groups this enemy belongs to, each a snake_case name, for rules that name a
	# group instead of one enemy: "goblin" for every goblin (Goblin Pledge's "last goblin standing",
	# Goblin Shot-Caller's "all goblins"). No duplicates. Absent: it belongs to no group.
	"tags": {"list_of": TYPE_STRING},
	# [added, task 017] Ids of enemy definitions that start the fight with this enemy (Goblin
	# Shot-Caller "arrives with 2 Goblin Pledges"; Goblin King Chad, G13). They are placed right after
	# it in the left-to-right order, in this order, and are part of fight_started like it. Their own
	# arrives_with is ignored (one level only). Absent or []: it arrives alone.
	"arrives_with": {"list_of": TYPE_STRING},
	# [added, task 017] Rules that choose its next move instead of the pattern or the random choice
	# (see RULE_SPEC). At each intent the rules are tried in order; the first rule whose conditions
	# all hold gives the move. When none holds, the pattern or random choice decides as before.
	# Absent or []: no rules.
	"move_rules": {"list_of": TYPE_DICTIONARY},
	# [added, task 017] Effects it runs outside its own turn when something happens in the fight
	# (see TRIGGER_SPEC): Kobold RA's Noise Complaint, Hall Monitor Golem's Detention, Sewer Gator's
	# Swole on unblocked damage. Absent or []: none.
	"triggers": {"list_of": TYPE_DICTIONARY},
	# [added, task 017] Splitting at low HP (see SPLIT_SPEC): Keg Slime. Absent: it never splits.
	"split": TYPE_DICTIONARY,
	# [added, task 017] Statuses it has on a fixed cycle of turns (see PERIODIC_SPEC): Boo-zer is
	# Faded every other turn. Absent or []: none.
	"periodic_statuses": {"list_of": TYPE_DICTIONARY},
	# [added, task 017] Brews it drops when it dies, 0 or more (Mimic Cooler "always drops a Brew": 1).
	# The core only reports the drop (combat_state.brews_dropped and a brew_dropped event); the run
	# lane grants the Brews. Absent: 0.
	"drops_brews": TYPE_INT,
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

## [added, task 017] Shape of one entry of "move_rules".
const RULE_SPEC := {
	# The move this rule picks: one of this enemy's move ids (weight 0 is usual: "only chosen by a rule").
	"move_id": TYPE_STRING,
	# Conditions that must all hold (see CONDITIONS), at least one.
	"when": {"list_of": TYPE_DICTIONARY},
}

## [added, task 017] Condition kinds a move rule may use: the value of a condition's "if" field ->
## that kind's other fields and their types. Every field listed is required; no others are allowed.
## The fight values they read are those at the moment the intent is chosen (turn flow step 1).
##   "last_of_tag":      no OTHER enemy in the fight has tag "tag" (Goblin Pledge: the last goblin standing).
##   "turn_at_least":    the fight's turn number is "turn" or more (Dorm Rats flee from turn 4). turn: 1 or more.
##   "turn_cycle":       the turn number is "first_turn", first_turn + every, first_turn + 2 x every ...
##                       (Goblin Shot-Caller every other turn: every 2). every, first_turn: 1 or more.
##   "count_below":      fewer than "count" OTHER enemies with definition "def_id" are in the fight
##                       (Goblin Shot-Caller replaces a dead Pledge). count: 1 or more.
##   "count_at_least":   "count" or more OTHER enemies with definition "def_id" are in the fight. count: 1 or more.
##   "hp_below_percent": its HP is below "percent" % of its max_hp (hp x 100 < percent x max_hp).
##                       percent: 1..100.
## Changes only with a contract PR.
const CONDITIONS := {
	"last_of_tag": {"tag": TYPE_STRING},
	"turn_at_least": {"turn": TYPE_INT},
	"turn_cycle": {"every": TYPE_INT, "first_turn": TYPE_INT},
	"count_below": {"def_id": TYPE_STRING, "count": TYPE_INT},
	"count_at_least": {"def_id": TYPE_STRING, "count": TYPE_INT},
	"hp_below_percent": {"percent": TYPE_INT},
}

## [added, task 017] Shape of one entry of "triggers"; the kind's own fields (TRIGGER_KINDS) come on top.
const TRIGGER_SPEC := {
	# Name of this trigger, snake_case, unique within the enemy, for example "noise_complaint". Sent
	# in the enemy_triggered event so the client can name it.
	"id": TYPE_STRING,
	# What sets it off: one of the keys of TRIGGER_KINDS.
	"on": TYPE_STRING,
	# Operations run in order, as in a move, with this enemy as the actor and the Dude named by the
	# kind as the only target. Damage here is not attack damage (G3): no Swole, Noodle Arms or Exposed.
	"effects": {"list_of": TYPE_DICTIONARY},
}

## [added, task 017] Trigger kinds: the value of a trigger's "on" field -> that kind's extra fields
## and their types (all required).
##   "cards_played":     a player has just finished playing their "cards"-th card this turn (Kobold
##                       RA: 5). With "repeat" true it also fires at every multiple (Hall Monitor
##                       Golem: every third card). Target: that player's Dude. cards: 1 or more.
##   "unblocked_damage": one hit of this enemy's move has just taken HP off a Dude (damage that Guard
##                       did not absorb). Fires once per such hit, after the effect that dealt it
##                       (Sewer Gator: gains 2 Swole). Target: the Dude hit.
## Changes only with a contract PR.
const TRIGGER_KINDS := {
	"cards_played": {"cards": TYPE_INT, "repeat": TYPE_BOOL},
	"unblocked_damage": {},
}

## [added, task 017] Shape of "split" (Keg Slime).
const SPLIT_SPEC := {
	# Id of the enemy definition it splits into, for example "foam_slime". Its max_hp is the new
	# enemies' HP (scaled by party size like any enemy).
	"into": TYPE_STRING,
	# How many enemies it splits into, 1 or more (Keg Slime: 2).
	"count": TYPE_INT,
	# It splits once its HP is at or below this percentage of its max_hp and above 0
	# (hp x 100 <= at_hp_percent x max_hp). 1..99. Keg Slime "at half HP": 50.
	"at_hp_percent": TYPE_INT,
}

## [added, task 017] Shape of one entry of "periodic_statuses".
const PERIODIC_SPEC := {
	# The status it has on those turns: one of PERIODIC_STATUSES.
	"status": TYPE_STRING,
	# Turns between two turns that have it, 1 or more (Boo-zer "every other turn": 2).
	"every": TYPE_INT,
	# The first turn of the fight that has it, 1 or more. It then has it on first_turn + every, and so on.
	"first_turn": TYPE_INT,
}

## [added, task 017] Statuses that periodic_statuses may set (core/schema/README.md "Status ids").
const PERIODIC_STATUSES: Array[String] = ["faded"]


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
	errors.append_array(_check_behaviors(enemy, move_ids, path))
	return errors


## Task 017: checks the optional behavior fields (tags, move_rules, triggers, split,
## periodic_statuses, drops_brews). Returns a list of problems. Ids of other enemies (arrives_with,
## split.into) are only checked for type here; whether they exist is checked when a fight starts.
## enemy: a definition whose outer shape is valid. move_ids: its move ids, as keys. path: label for messages.
static func _check_behaviors(enemy: Dictionary, move_ids: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	if enemy.has("tags"):
		# seen: tags met so far, to catch duplicates.
		var seen: Dictionary = {}
		for tag: String in enemy["tags"]:
			if tag == "" or seen.has(tag):
				errors.append("%s.tags: %s is empty or listed twice" % [path, var_to_str(tag)])
			seen[tag] = true
	for i: int in enemy.get("move_rules", []).size():
		errors.append_array(_check_rule(enemy["move_rules"][i], move_ids, "%s.move_rules[%d]" % [path, i]))
	# trigger_ids: trigger ids seen so far, to catch duplicates.
	var trigger_ids: Dictionary = {}
	for i: int in enemy.get("triggers", []).size():
		# trigger_path: label for this trigger.
		var trigger_path: String = "%s.triggers[%d]" % [path, i]
		# trigger_errors: problems with this trigger.
		var trigger_errors: Array[String] = _check_kind(enemy["triggers"][i], TRIGGER_SPEC, "on", TRIGGER_KINDS, trigger_path)
		errors.append_array(trigger_errors)
		if not trigger_errors.is_empty():
			continue
		if trigger_ids.has(enemy["triggers"][i]["id"]):
			errors.append("%s.id: duplicate trigger id %s" % [trigger_path, enemy["triggers"][i]["id"]])
		trigger_ids[enemy["triggers"][i]["id"]] = true
		if enemy["triggers"][i].has("cards") and enemy["triggers"][i]["cards"] < 1:
			errors.append("%s.cards: must be 1 or more" % trigger_path)
	if enemy.has("split"):
		# split_errors: shape problems with split.
		var split_errors: Array[String] = Shape.check(enemy["split"], SPLIT_SPEC, path + ".split")
		errors.append_array(split_errors)
		if split_errors.is_empty():
			if enemy["split"]["count"] < 1:
				errors.append("%s.split.count: must be 1 or more" % path)
			if enemy["split"]["at_hp_percent"] < 1 or enemy["split"]["at_hp_percent"] > 99:
				errors.append("%s.split.at_hp_percent: must be 1..99" % path)
	for i: int in enemy.get("periodic_statuses", []).size():
		# periodic_path: label for this entry.
		var periodic_path: String = "%s.periodic_statuses[%d]" % [path, i]
		# periodic: the entry.
		var periodic: Variant = enemy["periodic_statuses"][i]
		# periodic_errors: shape problems with it.
		var periodic_errors: Array[String] = Shape.check(periodic, PERIODIC_SPEC, periodic_path)
		errors.append_array(periodic_errors)
		if periodic_errors.is_empty():
			errors.append_array(Shape.check_one_of(periodic["status"], PERIODIC_STATUSES, periodic_path + ".status"))
			if periodic["every"] < 1 or periodic["first_turn"] < 1:
				errors.append("%s: every and first_turn must be 1 or more" % periodic_path)
	if enemy.get("drops_brews", 0) < 0:
		errors.append("%s.drops_brews: must be 0 or more" % path)
	return errors


## Checks one move rule: its shape, that move_id is one of the enemy's moves, and each condition.
## Returns a list of problems.
## rule: one entry of move_rules. move_ids: the enemy's move ids, as keys. path: label for messages.
static func _check_rule(rule: Variant, move_ids: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(rule, RULE_SPEC, path)
	if not errors.is_empty():
		return errors
	if not move_ids.has(rule["move_id"]):
		errors.append("%s.move_id: %s is not one of this enemy's move ids" % [path, rule["move_id"]])
	if rule["when"].is_empty():
		errors.append("%s.when: needs at least one condition" % path)
	for i: int in rule["when"].size():
		# condition_path: label for this condition.
		var condition_path: String = "%s.when[%d]" % [path, i]
		# condition_errors: problems with this condition's shape.
		var condition_errors: Array[String] = _check_kind(rule["when"][i], {}, "if", CONDITIONS, condition_path)
		errors.append_array(condition_errors)
		if not condition_errors.is_empty():
			continue
		# condition: the valid condition.
		var condition: Dictionary = rule["when"][i]
		for field: String in ["turn", "every", "first_turn", "count"]:
			if condition.has(field) and condition[field] < 1:
				errors.append("%s.%s: must be 1 or more" % [condition_path, field])
		if condition.has("percent") and (condition["percent"] < 1 or condition["percent"] > 100):
			errors.append("%s.percent: must be 1..100" % condition_path)
	return errors


## Checks a Dictionary whose fields depend on a "kind" field: base fields from spec, the kind field
## naming one of kinds, and that kind's own fields. Unknown fields are errors. Returns a list of problems.
## value: the Dictionary to check. spec: fields every kind has. kind_field: the field naming the kind
## ("on", "if"). kinds: kind -> its own fields and types. path: label for messages.
static func _check_kind(value: Variant, spec: Dictionary, kind_field: String, kinds: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s: expected Dictionary, got %s" % [path, type_string(typeof(value))])
		return errors
	# kind: the kind named by value, or null.
	var kind: Variant = value.get(kind_field)
	if typeof(kind) != TYPE_STRING or not kinds.has(kind):
		errors.append("%s.%s: %s is not one of %s" % [path, kind_field, var_to_str(kind), str(kinds.keys())])
		return errors
	# full: spec plus the kind field plus the kind's own fields.
	var full: Dictionary = spec.duplicate()
	full[kind_field] = TYPE_STRING
	full.merge(kinds[kind])
	return Shape.check(value, full, path)
