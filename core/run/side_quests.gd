## Side Quests: a safe option and a dumb option (task 025, GDD "Node types", "Example Side Quests").
## Lane: run (Agent A). Format: core/schema/side_quest_def.gd. Operations: core/run/side_quest_ops.gd.
##
## Entering a Side Quest node draws one Side Quest from the ruleset (sorted ids, each equally likely,
## repeats allowed, gap G55: the GDD has no rule against them) on the "side_quest" stream, and opens one
## "side_quest" offer per Dude (in co-op each player chooses for themselves, GDD "Rules that change in
## co-op"), no skip, options in side_quest_def.gd OPTION_FIELDS order:
##   0 "safe", 1 "dumb". An option with min_dolla_bills is unavailable to a Dude holding less (G23).
## Picking "dumb" adds 1 to run_state.dumb_options_taken (GDD "Run state"). The option's operations
## then run in order on the picking Dude only, every random one on the shared "side_quest" stream:
##   dolla_bills          change_dolla_bills (never below 0).
##   heal / full_heal     heal (never above max HP).
##   add_card             a new copy joins the run deck.
##   random_gear          a Gear from the Dude's Loot pool (G24); nothing when the pool is empty.
##   upgrade_random_cards up to count different random cards that can be upgraded (G15); fewer
##                        when fewer can be (gap G54).
##   next_fight_status    adds to dude_state.pending_statuses (G25; pending_status_added).
##   chance               one roll of percent in 100 (side_quest_rolled), then "then" or "else".
##
## Functions ending in _in_place change the working copy they are given. Pure: randomness only
## through core/run/draws.gd.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const SideQuestDef := preload("res://core/schema/side_quest_def.gd")
const Draws := preload("res://core/run/draws.gd")
const Grants := preload("res://core/run/grants.gd")
const Offers := preload("res://core/run/offers.gd")
const Rewards := preload("res://core/run/rewards.gd")

## The offer kind (core/schema/dude_state.gd OFFER_KINDS).
const KIND: String = "side_quest"

## The stream every Side Quest draw uses (GDD "Random streams": gambles and random outcomes).
const STREAM: String = "side_quest"

## Index of the dumb option in the offer (side_quest_def.gd OPTION_FIELDS).
const DUMB: int = 1


## Returns the Side Quest ids in the ruleset, sorted.
## ruleset: the read-only content.
static func ids(ruleset: Dictionary) -> Array:
	# result: the sorted ids.
	var result: Array = ruleset.get("side_quests", {}).keys()
	result.sort()
	return result


## Draws the node's Side Quest on the side_quest stream and opens its offer for every Dude.
## Does nothing when the ruleset has no Side Quest (vote_node refuses such a node first).
## ruleset: the read-only content. state: the working copy. events: the event list, appended to.
static func enter_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	# picked: the Side Quest id, or null.
	var picked: Variant = Draws.pick_in_place(state, STREAM, ids(ruleset))
	if picked == null:
		return
	for i: int in state["dudes"].size():
		# options: the safe and dumb options for this Dude.
		var options: Array = []
		for field: String in SideQuestDef.OPTION_FIELDS:
			options.append(Offers.option(field, qualifies(state["dudes"][i], ruleset["side_quests"][picked][field])))
		Offers.open_in_place(state, i, KIND, picked, false, options, events)


## True when a Dude may pick a Side Quest option: they hold at least its min_dolla_bills (G23).
## dude: the Dude. option: the definition's safe or dumb option.
static func qualifies(dude: Dictionary, option: Dictionary) -> bool:
	return dude["dolla_bills"] >= option.get("min_dolla_bills", 0)


## Applies a checked choice: counts a dumb option, runs the option's operations, closes the offer.
## ruleset: the read-only content. state: the working copy. dude_index: the Dude's seat, 0-based.
## offer: the Dude's side_quest offer. choice_index: 0 (safe) or 1 (dumb). events: the event list, appended to.
static func choose_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, offer: Dictionary,
		choice_index: int, events: Array) -> void:
	# definition: the Side Quest.
	var definition: Dictionary = ruleset["side_quests"][offer["def_id"]]
	if choice_index == DUMB:
		state["dumb_options_taken"] += 1
	run_in_place(ruleset, state, dude_index, offer["def_id"],
		definition[SideQuestDef.OPTION_FIELDS[choice_index]]["effects"], events)
	Offers.close_in_place(state, dude_index, offer["id"], choice_index, events)


## Runs Side Quest operations in order on one Dude (see the file header). Operations that fail
## core/run/side_quest_ops.gd check() never reach here: the ruleset refuses such files.
## ruleset: the read-only content. state: the working copy. dude_index: the Dude's seat, 0-based.
## side_quest_id: the Side Quest, for side_quest_rolled. effects: the operations.
## events: the event list, appended to.
static func run_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, side_quest_id: String,
		effects: Array, events: Array) -> void:
	# dude: the Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	for effect: Dictionary in effects:
		match effect["op"]:
			"dolla_bills":
				Grants.change_dolla_bills_in_place(state, dude_index, effect["amount"], events)
			"heal":
				Grants.heal_in_place(state, dude_index, effect["amount"], events)
			"full_heal":
				Grants.heal_in_place(state, dude_index, dude["max_hp"], events)
			"add_card":
				Grants.add_card_in_place(ruleset, state, dude_index, effect["card_id"], events)
			"random_gear":
				Rewards.random_gear_in_place(ruleset, state, dude_index, STREAM, events)
			"upgrade_random_cards":
				for uid: String in Draws.pick_distinct_in_place(state, STREAM, Grants.upgradable_cards(ruleset, dude), effect["count"]):
					Grants.upgrade_card_in_place(state, dude_index, uid, events)
			"next_fight_status":
				dude["pending_statuses"][effect["status"]] = dude["pending_statuses"].get(effect["status"], 0) + effect["stacks"]
				events.append(Event.make("pending_status_added", {"player_id": dude["player_id"],
					"status": effect["status"], "stacks": effect["stacks"]}))
			"chance":
				# won: whether the roll hit.
				var won: bool = Draws.percent_in_place(state, STREAM, effect["percent"])
				events.append(Event.make("side_quest_rolled", {"player_id": dude["player_id"],
					"side_quest_id": side_quest_id, "percent": effect["percent"], "won": won}))
				run_in_place(ruleset, state, dude_index, side_quest_id, effect["then"] if won else effect.get("else", []), events)
