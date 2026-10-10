## Shape of a Side Quest definition, one JSON file per Side Quest in data/side_quests/ (GDD "Node
## types": "A short choice with a safe option and a dumb option"; "Example Side Quests"). Shared
## contract. [added, task 025: the GDD has no Side Quest field table]
##
## Every Side Quest has exactly two options, "safe" and "dumb", so which one is dumb is part of the
## shape: picking "dumb" adds 1 to run_state.dumb_options_taken (GDD "Run state"). In co-op each
## player picks for themselves (GDD "Rules that change in co-op"), and an option's effects land on
## the player who picked it only.
##
## An option's effects are Side Quest operations, run in order outside a fight. They are the run
## lane's catalogue (core/run/side_quests.gd, which also checks their fields; this file checks only
## that each has a String "op"). Today:
##   {"op": "dolla_bills", "amount": int, not 0}   gain Dolla Bills, or lose them when negative
##                                                  (never below 0).
##   {"op": "heal", "amount": int, 0 or more}       heal that much, up to max HP.
##   {"op": "full_heal"}                            heal to max HP.
##   {"op": "add_card", "card_id": card id}         a new copy joins the run deck (Hangover, Regret ...).
##   {"op": "random_gear"}                          a random Gear from the Loot pool (G24): general Gear
##                                                  and the Dude's own, not starting or Boss Gear,
##                                                  nothing already owned; drawn on the side_quest stream.
##   {"op": "upgrade_random_cards", "count": int, 1 or more}
##                                                  upgrade that many random cards of the run deck
##                                                  that can be upgraded (G15), on the side_quest stream.
##   {"op": "next_fight_status", "status": a Dude status id, "stacks": int, 1 or more}
##                                                  start the next fight with that status (G25).
##   {"op": "chance", "percent": int, 1..99, "then": [effects], "else": [effects] (optional)}
##                                                  roll on the side_quest stream: "then" runs with
##                                                  that percent chance, "else" otherwise.
##
## Example (GDD "The Beer Pong Table"; G23: the bet is not offered below 50 Dolla Bills):
##   {"id": "beer_pong_table", "name": "The Beer Pong Table",
##    "text": "A beer pong table, a stranger, and a bet nobody asked for.",
##    "safe": {"label": "Walk away", "text": "Nothing happens.", "effects": []},
##    "dumb": {"label": "Bet 50 Dolla Bills", "min_dolla_bills": 50,
##             "text": "50% to double them, 50% to lose them and gain a Hangover card.",
##             "effects": [{"op": "chance", "percent": 50,
##                          "then": [{"op": "dolla_bills", "amount": 50}],
##                          "else": [{"op": "dolla_bills", "amount": -50},
##                                   {"op": "add_card", "card_id": "junk_hangover"}]}]}}
##
## Who may change definitions: the content lane. Who may change this shape: a contract PR.
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")

## The two option fields every Side Quest has, in the order the run lane offers them: index 0 is
## "safe", index 1 is "dumb" (choose_reward's choice_index). Changed only by a contract PR.
const OPTION_FIELDS: Array[String] = ["safe", "dumb"]

## Required fields and their types.
const SPEC := {
	# Unique key, snake_case, equal to the file name without ".json", for example "beer_pong_table".
	# Never changes after merge, because saves refer to it.
	"id": TYPE_STRING,
	# Name shown to players, in the GDD's wording, for example "The Beer Pong Table". May change freely.
	"name": TYPE_STRING,
	# The prompt shown to players. Follows the GDD "Rules for writers". May change freely.
	"text": TYPE_STRING,
	# The safe option (see OPTION_SPEC). Picking it does not count as a dumb option.
	"safe": TYPE_DICTIONARY,
	# The dumb option (see OPTION_SPEC). Picking it adds 1 to run_state.dumb_options_taken.
	"dumb": TYPE_DICTIONARY,
}

## Required fields of one option.
const OPTION_SPEC := {
	# The option's name shown on its button, in the GDD's wording ("Walk away", "Skip it", "Go to bed",
	# "Leave it", "Politely decline" for the safe options). May change freely.
	"label": TYPE_STRING,
	# What the option does, shown to players. Must describe the effects exactly.
	"text": TYPE_STRING,
	# Side Quest operations run in order when the option is picked (see the file header). [] does nothing.
	"effects": {"list_of": TYPE_DICTIONARY},
}

## Fields an option may have.
const OPTION_OPTIONAL := {
	# The option is offered only to a Dude holding at least this many Dolla Bills, 1 or more (G23: the
	# Beer Pong Table's 50 Dolla Bill bet). Absent: always offered.
	"min_dolla_bills": TYPE_INT,
}


## Checks a Side Quest definition. Returns a list of problems; empty means valid.
## side_quest: the parsed definition (after json_values.parse). path: label for messages, usually the file path.
static func check(side_quest: Variant, path: String = "side_quest") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(side_quest, SPEC, path)
	if not errors.is_empty():
		return errors
	for field: String in OPTION_FIELDS:
		errors.append_array(_check_option(side_quest[field], "%s.%s" % [path, field]))
	return errors


## Checks one option. Returns a list of problems; empty means valid.
## option: the safe or dumb option. path: label for messages.
static func _check_option(option: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(option, OPTION_SPEC, path, OPTION_OPTIONAL)
	if not errors.is_empty():
		return errors
	if option.has("min_dolla_bills") and option["min_dolla_bills"] < 1:
		errors.append("%s.min_dolla_bills: must be 1 or more" % path)
	for i: int in option["effects"].size():
		if typeof(option["effects"][i].get("op")) != TYPE_STRING:
			errors.append("%s.effects[%d]: missing String \"op\"" % [path, i])
	return errors
