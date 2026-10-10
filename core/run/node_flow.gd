## The run flow: moving across a floor map and resolving each node (task 025). Lane: run (Agent A).
##
## Core.apply() (core/core.gd) routes the two run requests here, and calls after_request_in_place()
## after every applied request. The state's run_phase (core/schema/run_state.gd RUN_PHASES) says
## where the run is; the full picture is in core/schema/README.md "The run flow". GDD "The loop":
## choose the next node, resolve it, take the reward, repeat until the floor boss, pick a Boss Gear.
##
## vote_node (run_phase "map"): the player's vote goes into run_state.votes (vote_cast). Once every
## Dude has voted, the node with the most votes wins; a tie goes to the designated_driver's vote (GDD
## "Map path": "Ties go to the Designated Driver"; when every Dude votes, the Driver's node is always
## among the tied ones). Then, in the same request, the party moves onto it (node_index, path,
## run_phase "node", node_entered) and the node is resolved:
##   brawl, rival, boss  an encounter is drawn (core/run/encounters.gd) and its fight starts
##                       (core/combat/fight.gd start_fight_in_place); requests then play it as usual.
##   loot                a Mimic roll (core/run/loot.gd): a fight, or free Gear for everyone.
##   side_quest          a Side Quest offer for every Dude (core/run/side_quests.gd).
##   tailgate            a Tailgate offer for every Dude (core/run/tailgate.gd).
##   baileys             a Baileys offer for every Dude (core/run/baileys.gd).
## A node with nothing left to choose is finished at once (finish_node_in_place).
##
## A fight the run flow started ends inside some request; after_request_in_place() then, after Gear's
## fight_end point: "lost" ends the run (run_phase "lost", run_ended); "won" gives the encounter's
## rewards (core/run/rewards.gd) and finishes the node when nobody has a choice to make.
##
## choose_reward (run_phase "node", no fight running): answers one open offer (core/run/offers.gd),
## by kind: "card" takes a card or skips; "boss_gear" gains the Gear; "tailgate", "baileys" and
## "side_quest" go to their files. When no Dude has an open offer left, the node is finished: back to
## run_phase "map", or after the boss "floor_end" (floor_ended; descending is not built, the slice ends).
##
## Rejects (no new reject code, core/schema/request.gd): wrong_phase, bad_target, unplayable; see
## check(). A node the ruleset has nothing for (no encounter, no Side Quest) is refused at the vote.
##
## Functions ending in _in_place change the working copy they are given. Pure: randomness only
## through core/run/draws.gd and the files above.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const FloorMap := preload("res://core/run/map/floor_map.gd")
const Fight := preload("res://core/combat/fight.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")
const Offers := preload("res://core/run/offers.gd")
const Grants := preload("res://core/run/grants.gd")
const Encounters := preload("res://core/run/encounters.gd")
const Rewards := preload("res://core/run/rewards.gd")
const Tailgate := preload("res://core/run/tailgate.gd")
const Baileys := preload("res://core/run/baileys.gd")
const SideQuests := preload("res://core/run/side_quests.gd")
const Loot := preload("res://core/run/loot.gd")

## Request types this file handles (core/schema/request.gd TYPES). Core.apply() routes them here.
const REQUESTS: Array[String] = ["vote_node", "choose_reward"]

## Map node types that hold a fight (core/run/map/floor_map.gd); each is also an encounter kind.
const FIGHT_NODES: Array[String] = ["brawl", "rival", "boss"]

## Option kinds whose choice names a card in choose_reward's card_uid (core/schema/dude_state.gd).
const CARD_OPTION_KINDS: Array[String] = ["lift", "remove"]

## run_phase values (core/schema/run_state.gd RUN_PHASES), named for the code below.
const PHASE_MAP: String = "map"
## The party is on a node (see RUN_PHASES).
const PHASE_NODE: String = "node"
## The floor's boss is beaten and every Boss Gear pick made.
const PHASE_FLOOR_END: String = "floor_end"
## The run is lost.
const PHASE_LOST: String = "lost"

## Fight result that ends the run (core/schema/combat_state.gd RESULTS).
const LOST: String = "lost"


## Returns the reject reason for a run request, or "" when it is legal. Reads only. Core.apply() has
## already checked the request's shape, player and seq.
## ruleset: the read-only content. state: the current run state. dude_index: the sender's seat, 0-based.
## request: a well-formed vote_node or choose_reward request.
static func check(ruleset: Dictionary, state: Dictionary, dude_index: int, request: Dictionary) -> String:
	if request["type"] == "vote_node":
		return _check_vote(ruleset, state, request["node_id"])
	return _check_choice(state, dude_index, request)


## Applies a run request that check() accepted. Returns "" or, when the node cannot be resolved after
## all (the ruleset lacks what the fight needs), a reject reason; Core.apply() then drops the working copy.
## ruleset: the read-only content. state: the working copy. dude_index: the sender's seat, 0-based.
## request: the vote_node or choose_reward request. events: the event list, appended to.
static func apply_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, request: Dictionary, events: Array) -> String:
	# player_id: the sender.
	var player_id: String = request["player_id"]
	if request["type"] == "vote_node":
		state["votes"][player_id] = request["node_id"]
		events.append(Event.make("vote_cast", {"player_id": player_id, "node_id": request["node_id"]}))
		for dude: Dictionary in state["dudes"]:
			if not state["votes"].has(dude["player_id"]):
				return ""
		return move_in_place(ruleset, state, tally(state), events)
	_choose_in_place(ruleset, state, dude_index, request, events)
	if not Offers.anyone_choosing(state):
		finish_node_in_place(state, events)
	return ""


## Called by Core.apply() after every applied request: when a fight the run flow started has just
## ended, a loss ends the run and a win hands out the rewards (see the file header). Does nothing for
## a fight started outside the run flow (run_phase is not "node").
## ruleset: the read-only content. state: the working copy after the request. events: appended to.
static func after_request_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	if state["run_phase"] != PHASE_NODE or state["combat"] == null or state["combat"]["phase"] != "over":
		return
	if state["combat"]["result"] == LOST:
		state["run_phase"] = PHASE_LOST
		events.append(Event.make("run_ended", {"result": LOST}))
		return
	Rewards.after_win_in_place(ruleset, state, _encounter_kind(ruleset, state), events)
	if not Offers.anyone_choosing(state):
		finish_node_in_place(state, events)


## Returns the node id the votes choose: the most votes; a tie goes to the designated_driver's vote
## when it is among the tied nodes, otherwise to the tied node first in map order. Reads only.
## state: a run state whose votes hold every Dude's vote.
static func tally(state: Dictionary) -> String:
	# counts: node id -> votes.
	var counts: Dictionary = {}
	# players: the voters, sorted so the count never depends on the map's order.
	var players: Array = state["votes"].keys()
	players.sort()
	for player_id: String in players:
		counts[state["votes"][player_id]] = counts.get(state["votes"][player_id], 0) + 1
	# best: the highest count.
	var best: int = counts.values().max()
	# tied: the nodes with the highest count, in map order.
	var tied: Array = []
	for node: Dictionary in state["map"]["nodes"]:
		if counts.get(node["id"], 0) == best:
			tied.append(node["id"])
	# driver_vote: the Designated Driver's vote, or "".
	var driver_vote: String = state["votes"].get(state["designated_driver"], "")
	return driver_vote if tied.has(driver_vote) else tied[0]


## Moves the party onto a node and resolves it (see the file header). Returns "" or a reject reason
## when its fight cannot start.
## ruleset: the read-only content. state: the working copy. node_id: a node of the map.
## events: the event list, appended to.
static func move_in_place(ruleset: Dictionary, state: Dictionary, node_id: String, events: Array) -> String:
	# index: the node's position in the map.
	var index: int = FloorMap.index_of(state["map"], node_id)
	# node_type: what the node is.
	var node_type: String = state["map"]["nodes"][index]["type"]
	state["votes"] = {}
	state["node_index"] = index
	state["path"].append(node_id)
	state["run_phase"] = PHASE_NODE
	state["encounter_id"] = ""
	events.append(Event.make("node_entered", {"node_id": node_id, "node_type": node_type}))
	if FIGHT_NODES.has(node_type):
		return _start_encounter_in_place(ruleset, state, node_type, events)
	match node_type:
		FloorMap.NODE_LOOT:
			if Loot.is_mimic_in_place(ruleset, state) and not Encounters.candidates(ruleset, state, FloorMap.NODE_LOOT).is_empty():
				return _start_encounter_in_place(ruleset, state, FloorMap.NODE_LOOT, events)
			Loot.give_gear_in_place(ruleset, state, events)
		FloorMap.NODE_SIDE_QUEST:
			SideQuests.enter_in_place(ruleset, state, events)
		FloorMap.NODE_TAILGATE:
			Tailgate.enter_in_place(ruleset, state, events)
		FloorMap.NODE_BAILEYS:
			Baileys.enter_in_place(ruleset, state, events)
	if not Offers.anyone_choosing(state):
		finish_node_in_place(state, events)
	return ""


## Finishes the current node: no encounter or fight is left, and the party goes back to the map, or,
## after the boss, the floor ends (floor_ended).
## state: the working copy. events: the event list, appended to.
static func finish_node_in_place(state: Dictionary, events: Array) -> void:
	state["encounter_id"] = ""
	state["combat"] = null
	if state["map"]["nodes"][state["node_index"]]["type"] == FloorMap.NODE_BOSS:
		state["run_phase"] = PHASE_FLOOR_END
		events.append(Event.make("floor_ended", {"floor": state["floor"]}))
	else:
		state["run_phase"] = PHASE_MAP


## Returns why the ruleset cannot resolve a node of this type now, or "" when it can: a fight node
## with no encounter for this floor, an encounter whose fight could not start, or a Side Quest node
## with no Side Quest. A Loot node is always fine (with no loot encounter it is plain Loot). Reads only.
## ruleset: the read-only content. state: the run state. node_type: a map node type.
static func content_error(ruleset: Dictionary, state: Dictionary, node_type: String) -> String:
	if FIGHT_NODES.has(node_type):
		# ids: the encounters the node could hold.
		# Not entered yet: content_error checks a node before the party moves onto it (a vote).
		var ids: Array = Encounters.candidates(ruleset, state, node_type, false)
		if ids.is_empty():
			return "no %s encounter for floor %d" % [node_type, state["floor"]]
		return _fights_error(ruleset, state, ids)
	if node_type == FloorMap.NODE_LOOT:
		return _fights_error(ruleset, state, Encounters.candidates(ruleset, state, node_type, false))
	if node_type == FloorMap.NODE_SIDE_QUEST and SideQuests.ids(ruleset).is_empty():
		return "no Side Quest in the ruleset"
	return ""


## vote_node's checks: wrong_phase outside "map" or with no map; bad_target for a node that is not a
## link of the party's node or that the ruleset cannot resolve. Reads only.
## ruleset: the read-only content. state: the run state. node_id: the voted node.
static func _check_vote(ruleset: Dictionary, state: Dictionary, node_id: String) -> String:
	if state["run_phase"] != PHASE_MAP or state["map"].is_empty():
		return "wrong_phase"
	if not state["map"]["nodes"][state["node_index"]]["links"].has(node_id):
		return "bad_target"
	# index: the voted node's position, -1 if the map has no such node.
	var index: int = FloorMap.index_of(state["map"], node_id)
	if index == -1 or content_error(ruleset, state, state["map"]["nodes"][index]["type"]) != "":
		return "bad_target"
	return ""


## choose_reward's checks (core/schema/request.gd): wrong_phase outside "node", during a fight, or for
## an offer this player does not have; bad_target for a bad index, -1 on an offer that cannot be
## skipped, an unavailable option or a bad card_uid; unplayable for Baileys money or slots. Reads only.
## state: the run state. dude_index: the sender's seat. request: the choose_reward request.
static func _check_choice(state: Dictionary, dude_index: int, request: Dictionary) -> String:
	if state["run_phase"] != PHASE_NODE or (state["combat"] != null and state["combat"]["phase"] != "over"):
		return "wrong_phase"
	# dude: the sender's Dude.
	var dude: Dictionary = state["dudes"][dude_index]
	# offer_index: the offer's position, -1 if this player has no such offer.
	var offer_index: int = Offers.find(dude, request["reward_id"])
	if offer_index == -1:
		return "wrong_phase"
	# offer: the offer answered.
	var offer: Dictionary = dude["offers"][offer_index]
	# choice: the picked option index, or -1.
	var choice: int = request["choice_index"]
	# card_uid: the named card, "" when none.
	var card_uid: String = request.get("card_uid", "")
	if choice == Offers.SKIP:
		return "" if offer["skippable"] and card_uid == "" else "bad_target"
	if choice < 0 or choice >= offer["options"].size():
		return "bad_target"
	# option: the picked option.
	var option: Dictionary = offer["options"][choice]
	if not option["available"]:
		return "bad_target"
	if CARD_OPTION_KINDS.has(option["kind"]):
		if not option.get("card_uids", []).has(card_uid):
			return "bad_target"
	elif card_uid != "":
		return "bad_target"
	if offer["kind"] == Baileys.KIND:
		return Baileys.check(dude, option)
	return ""


## Applies a checked choose_reward to its offer (see the file header).
## ruleset: the read-only content. state: the working copy. dude_index: the sender's seat, 0-based.
## request: the choose_reward request. events: the event list, appended to.
static func _choose_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, request: Dictionary, events: Array) -> void:
	# offer: the answered offer, inside state.
	var offer: Dictionary = state["dudes"][dude_index]["offers"][Offers.find(state["dudes"][dude_index], request["reward_id"])]
	# choice: the picked option index, or -1.
	var choice: int = request["choice_index"]
	# card_uid: the named card, "" when none.
	var card_uid: String = request.get("card_uid", "")
	match offer["kind"]:
		"card":
			if choice != Offers.SKIP:
				Grants.add_card_in_place(ruleset, state, dude_index, offer["options"][choice]["card_id"], events)
			Offers.close_in_place(state, dude_index, offer["id"], choice, events)
		"boss_gear":
			GearTriggers.gain_in_place(ruleset, state["dudes"][dude_index], offer["options"][choice]["gear_id"], events)
			Offers.close_in_place(state, dude_index, offer["id"], choice, events)
		Tailgate.KIND:
			Tailgate.choose_in_place(ruleset, state, dude_index, offer, choice, card_uid, events)
		Baileys.KIND:
			Baileys.choose_in_place(ruleset, state, dude_index, offer, choice, card_uid, events)
		SideQuests.KIND:
			SideQuests.choose_in_place(ruleset, state, dude_index, offer, choice, events)


## Draws the encounter for a fight node and starts its fight. Returns "" or "bad_target" when there is
## no encounter or its fight cannot start (vote_node's check normally refuses such a node first).
## ruleset: the read-only content. state: the working copy. kind: the encounter kind.
## events: the event list, appended to.
static func _start_encounter_in_place(ruleset: Dictionary, state: Dictionary, kind: String, events: Array) -> String:
	# id: the drawn encounter.
	var id: String = Encounters.draw_in_place(ruleset, state, kind)
	if id == "":
		return "bad_target"
	# enemies: its enemies, left to right.
	var enemies: Array = ruleset["encounters"][id]["enemies"]
	state["combat"] = null
	if Fight.check_start(ruleset, state, enemies) != "":
		return "bad_target"
	state["encounter_id"] = id
	Fight.start_fight_in_place(ruleset, state, enemies, events)
	return ""


## Returns the first reason any of these encounters' fights could not start now, or "". Reads only.
## ruleset: the read-only content. state: the run state. ids: encounter ids.
static func _fights_error(ruleset: Dictionary, state: Dictionary, ids: Array) -> String:
	# probe: a shallow copy of the state outside any fight, for Fight.check_start.
	var probe: Dictionary = state.duplicate()
	probe["combat"] = null
	for id: String in ids:
		# error: why this encounter's fight could not start, or "".
		var error: String = Fight.check_start(ruleset, probe, ruleset["encounters"][id]["enemies"])
		if error != "":
			return "encounter %s: %s" % [id, error]
	return ""


## Returns the kind of the fight being fought: its encounter's node, or the map node's type when the
## encounter is unknown.
## ruleset: the read-only content. state: the run state.
static func _encounter_kind(ruleset: Dictionary, state: Dictionary) -> String:
	# encounter: the encounter, or {}.
	var encounter: Dictionary = ruleset.get("encounters", {}).get(state["encounter_id"], {})
	if not encounter.is_empty():
		return encounter["node"]
	return state["map"]["nodes"][state["node_index"]]["type"]
