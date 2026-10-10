## Builds a run state for a party of Dudes from their definitions (task 007). Lane: core (Agent A).
##
## A helper for tests, bots and the fight screen until the run flow (task 025) has a real new-run
## request; that task may move or replace it. Each Dude, in seat order "p1".."p4":
##   hp = max_hp = the definition's max_hp; hype_per_turn = BASE_HYPE; draw_per_turn = BASE_DRAW;
##   deck = the starter deck as fresh card_uids from next_uid ("c1", "c2" ...), in definition order;
##   gear = the definition's starting_gear, each gained with core/combat/gear_triggers.gd gain_in_place, so
##   its stats apply (task 021);
##   brew_slots = 0 and dolla_bills = 0, because neither number is a constant yet (G22 and G20 in
##   docs/proposals/solo-slice-rule-gaps.md are unanswered). Everything else is DudeState.blank().
## The random streams come from Rng.with_new_streams.
##
## Pure: no file, clock, network or random access (the streams are derived, not drawn).
extends RefCounted

const RunState := preload("res://core/schema/run_state.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const Rng := preload("res://core/rng/rng.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")

## Most players in a run (GDD "Online multiplayer": 1-4 players). Fixed by the GDD, not tuning.
const MAX_PARTY_SIZE: int = 4

## Prefix of a player_id; seat n (from 1) is "p" + n (core/schema/README.md "Ids").
const PLAYER_ID_PREFIX: String = "p"

## Prefix of a card_uid; the number after it comes from run_state.next_uid (core/schema/README.md "Ids").
const CARD_UID_PREFIX: String = "c"

## Constants this builder reads; each must be an int in ruleset.constants.
const NEEDED_CONSTANTS: Array[String] = ["BASE_HYPE", "BASE_DRAW"]


## Returns a new run state with one Dude per id, in seat order, outside any fight.
## ruleset: the read-only content; every id must be in ruleset.dudes, and each starter card in ruleset.cards.
## run_seed: the run's seed, any 64-bit int. dude_ids: Dude definition ids, 1..MAX_PARTY_SIZE of them
## (the same Dude may appear twice).
## Returns {"state": the run state, "error": ""}, or {"state": {}, "error": why} for bad input.
static func build_run_state(ruleset: Dictionary, run_seed: int, dude_ids: Array) -> Dictionary:
	if dude_ids.is_empty() or dude_ids.size() > MAX_PARTY_SIZE:
		return {"state": {}, "error": "a party has 1 to %d Dudes, got %d" % [MAX_PARTY_SIZE, dude_ids.size()]}
	for name: String in NEEDED_CONSTANTS:
		if typeof(ruleset["constants"].get(name)) != TYPE_INT:
			return {"state": {}, "error": "constant %s is missing or not an int" % name}
	# next_uid: the number the next card_uid gets.
	var next_uid: int = 1
	# dudes: the Dude states, in seat order.
	var dudes: Array = []
	for seat: int in dude_ids.size():
		# dude_id: the definition id for this seat.
		var dude_id: Variant = dude_ids[seat]
		if typeof(dude_id) != TYPE_STRING or not ruleset["dudes"].has(dude_id):
			return {"state": {}, "error": "unknown Dude %s" % var_to_str(dude_id)}
		# definition: the Dude's definition.
		var definition: Dictionary = ruleset["dudes"][dude_id]
		# dude: the new Dude state.
		var dude: Dictionary = DudeState.blank(PLAYER_ID_PREFIX + str(seat + 1), dude_id)
		dude["max_hp"] = definition["max_hp"]
		dude["hp"] = definition["max_hp"]
		dude["hype_per_turn"] = ruleset["constants"]["BASE_HYPE"]
		dude["draw_per_turn"] = ruleset["constants"]["BASE_DRAW"]
		for gear_id: String in definition["starting_gear"]:
			# Task 021: the Gear's stats apply; the events are dropped (building a run is not a request).
			GearTriggers.gain_in_place(ruleset, dude, gear_id, [])
		for card_id: String in definition["starter_deck"]:
			if not ruleset["cards"].has(card_id):
				return {"state": {}, "error": "Dude %s: unknown starter card %s" % [dude_id, card_id]}
			# uid: this copy's card_uid.
			var uid: String = CARD_UID_PREFIX + str(next_uid)
			next_uid += 1
			dude["deck"].append(uid)
			dude["cards"][uid] = {"def_id": card_id, "upgraded": false}
		dudes.append(dude)
	# state: the run around the Dudes.
	var state: Dictionary = RunState.blank(run_seed, dudes)
	state["next_uid"] = next_uid
	return {"state": Rng.with_new_streams(state), "error": ""}
