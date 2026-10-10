## Move rules: moves an enemy uses in certain situations instead of its pattern or random choice
## (task 017). Lane: core (Agent A). Shape: core/schema/enemy_def.gd "move_rules" and CONDITIONS.
##
## core/ai/intents.gd asks ruled_move() first at every intent (turn flow step 1). The rules are tried
## in the definition's order; the first rule whose conditions ALL hold gives the move. When none
## holds, the answer is "" and the pattern or weighted random choice decides as before
## (core/ai/move_choice.gd). A rule never draws from a random stream. An intent picked by a rule is
## recorded in move_history like any other, so a pattern moves on by one step and the no-three rule
## sees it.
##
## Conditions, read at the moment the intent is chosen ("other" enemies exclude the enemy itself):
##   last_of_tag {tag}:               no other enemy in the fight has the tag (definition "tags").
##   turn_at_least {turn}:            combat.turn >= turn.
##   turn_cycle {every, first_turn}:  combat.turn >= first_turn and (combat.turn - first_turn) is a
##                                    multiple of every.
##   count_below {def_id, count}:     fewer than count other enemies with that definition are in the fight.
##   count_at_least {def_id, count}:  count or more other enemies with that definition are in the fight.
##   hp_below_percent {percent}:      hp x 100 < percent x max_hp (integers, no rounding).
## An unknown condition kind never holds, so a bad rule is skipped rather than guessed at (content
## checks reject it first: enemy_def.gd check()).
##
## Pure and deterministic: no random draws, no file, clock or network access; enemies are walked in
## the fight's left-to-right order.
extends RefCounted


## Returns the move id the enemy's first matching rule picks, or "" when it has no rules or none matches.
## ruleset: the read-only content. state: the run state, in a fight. enemy: the enemy choosing, inside state.
static func ruled_move(ruleset: Dictionary, state: Dictionary, enemy: Dictionary) -> String:
	for rule: Dictionary in ruleset["enemies"][enemy["def_id"]].get("move_rules", []):
		# all_hold: false once one of the rule's conditions fails.
		var all_hold: bool = true
		for condition: Dictionary in rule["when"]:
			if not holds(ruleset, state, enemy, condition):
				all_hold = false
				break
		if all_hold and not rule["when"].is_empty():
			return rule["move_id"]
	return ""


## True when one condition holds for this enemy now (see the file header).
## ruleset: the read-only content. state: the run state, in a fight. enemy: the enemy, inside state.
## condition: one entry of a rule's "when".
static func holds(ruleset: Dictionary, state: Dictionary, enemy: Dictionary, condition: Dictionary) -> bool:
	# turn: the fight's current turn number.
	var turn: int = state["combat"]["turn"]
	match condition.get("if"):
		"last_of_tag":
			return others_with_tag(ruleset, state, enemy["uid"], condition["tag"]) == 0
		"turn_at_least":
			return turn >= condition["turn"]
		"turn_cycle":
			return turn >= condition["first_turn"] and (turn - condition["first_turn"]) % condition["every"] == 0
		"count_below":
			return others_with_def(state, enemy["uid"], condition["def_id"]) < condition["count"]
		"count_at_least":
			return others_with_def(state, enemy["uid"], condition["def_id"]) >= condition["count"]
		"hp_below_percent":
			return enemy["hp"] * 100 < condition["percent"] * enemy["max_hp"]
	return false


## Returns how many enemies in the fight, other than the one with uid, have this tag in their definition.
## ruleset: the read-only content. state: the run state, in a fight. uid: the enemy to leave out. tag: a group name.
static func others_with_tag(ruleset: Dictionary, state: Dictionary, uid: String, tag: String) -> int:
	# count: the result.
	var count: int = 0
	for other: Dictionary in state["combat"]["enemies"]:
		if other["uid"] != uid and has_tag(ruleset, other["def_id"], tag):
			count += 1
	return count


## Returns how many enemies in the fight, other than the one with uid, have this definition.
## state: the run state, in a fight. uid: the enemy to leave out. def_id: the definition id to count.
static func others_with_def(state: Dictionary, uid: String, def_id: String) -> int:
	# count: the result.
	var count: int = 0
	for other: Dictionary in state["combat"]["enemies"]:
		if other["uid"] != uid and other["def_id"] == def_id:
			count += 1
	return count


## True when the enemy definition lists this tag. False for an unknown definition.
## ruleset: the read-only content. def_id: an enemy definition id. tag: a group name.
static func has_tag(ruleset: Dictionary, def_id: String, tag: String) -> bool:
	return ruleset["enemies"].has(def_id) and ruleset["enemies"][def_id].get("tags", []).has(tag)
