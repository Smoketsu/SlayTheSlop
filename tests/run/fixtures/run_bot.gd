## A scripted player for whole-run tests (task 025): picks a path through the map that visits every
## node type it can, and answers every node with a fixed, simple policy. Lane: run (Agent A).
##
## Not a test file (no test_ prefix). Deterministic: it reads only the state, so the same seed always
## gives the same requests. Policy, per offer kind:
##   card: the first card. boss_gear: the first Gear. tailgate: Lift the first card when one can be
##   Lifted and HP is at least half, else Nap. baileys: if nothing is bought yet, the first item it
##   can afford and hold; then, once per run, remove its first removable card if it can afford that;
##   then leave. side_quest: the dumb option when available, else the safe one.
## Fights are played by tests/run/fixtures/run_helpers.gd bot_request().
extends RefCounted

const Core := preload("res://core/core.gd")
const Helpers := preload("res://tests/run/fixtures/run_helpers.gd")
const FloorMap := preload("res://core/run/map/floor_map.gd")

## Most requests one whole run may take before the bot gives up (a guard against a stuck loop).
const RUN_REQUEST_LIMIT: int = 20000


## Returns the ids of a path from the entrance to the boss that visits the most different node types,
## the first such path in depth-first order (links in column order). Reads only.
## map: a floor map (core/run/map/floor_map.gd).
static func best_path(map: Dictionary) -> Array:
	# best: [types visited count, path] of the best path found so far.
	var best: Array = [-1, []]
	_walk(map, map["nodes"][0]["id"], [], {}, best)
	return best[1]


## Depth-first search for best_path(). Updates best when a path to the boss beats it.
## map: the floor map. node_id: the node reached. path: ids visited so far (not the entrance).
## types: node types visited so far, as a set. best: [count, path], changed in place.
static func _walk(map: Dictionary, node_id: String, path: Array, types: Dictionary, best: Array) -> void:
	# node: the node reached.
	var node: Dictionary = map["nodes"][FloorMap.index_of(map, node_id)]
	if node["links"].is_empty():
		if types.size() > best[0]:
			best[0] = types.size()
			best[1] = path.duplicate()
		return
	for link: String in node["links"]:
		# next_types: the types with the linked node's added.
		var next_types: Dictionary = types.duplicate()
		next_types[map["nodes"][FloorMap.index_of(map, link)]["type"]] = true
		_walk(map, link, path + [link], next_types, best)


## Returns the next request of a solo whole run, or {} when the run is over (floor_end or lost).
## rules: the ruleset. state: the run state. plan: the node ids to visit, in order (best_path()).
static func next_request(rules: Dictionary, state: Dictionary, plan: Array) -> Dictionary:
	# seq: the next seq.
	var seq: int = Helpers.next_seq(state)
	match state["run_phase"]:
		"map":
			return Helpers.vote("p1", seq, plan[state["path"].size()])
		"node":
			if state["combat"] != null:
				return Helpers.bot_request(rules, state, 0, seq)
			return _answer(state, state["dudes"][0]["offers"][0], seq)
	return {}


## Returns the request answering one offer (see the file header).
## state: the run state. offer: Tom's first open offer. seq: the seq to send.
static func _answer(state: Dictionary, offer: Dictionary, seq: int) -> Dictionary:
	# tom: p1.
	var tom: Dictionary = state["dudes"][0]
	match offer["kind"]:
		"tailgate":
			if offer["options"][1]["available"] and tom["hp"] * 2 >= tom["max_hp"]:
				return Helpers.choose("p1", seq, offer["id"], 1, offer["options"][1]["card_uids"][0])
			return Helpers.choose("p1", seq, offer["id"], 0)
		"baileys":
			# last: the removal option's index (always last).
			var last: int = offer["options"].size() - 1
			if _bought_nothing_yet(offer):
				for i: int in last:
					# option: one item.
					var option: Dictionary = offer["options"][i]
					if option["available"] and option["price"] <= tom["dolla_bills"] \
							and (option["kind"] != "shake" or tom["brews"].size() < tom["brew_slots"]):
						return Helpers.choose("p1", seq, offer["id"], i)
			# removal: the removal option.
			var removal: Dictionary = offer["options"][last]
			if tom["cards_removed"] == 0 and removal["available"] and removal["price"] <= tom["dolla_bills"]:
				return Helpers.choose("p1", seq, offer["id"], last, removal["card_uids"][0])
			return Helpers.choose("p1", seq, offer["id"], -1)
		"side_quest":
			return Helpers.choose("p1", seq, offer["id"], 1 if offer["options"][1]["available"] else 0)
	return Helpers.choose("p1", seq, offer["id"], 0)


## True when no item of a Baileys offer has been bought yet (every item option still available).
## offer: a Baileys offer.
static func _bought_nothing_yet(offer: Dictionary) -> bool:
	for option: Dictionary in offer["options"]:
		if option["kind"] != "remove" and not option["available"]:
			return false
	return true


## Plays a whole solo run from a new state to its end with next_request(). Returns {"state": the
## final state, "requests": every request sent, "events": every event, "problems": contract problems
## and rejects found, "plan": the planned path}.
## rules: the ruleset. state: a new run's state.
static func play(rules: Dictionary, state: Dictionary) -> Dictionary:
	# plan: the path to follow.
	var plan: Array = best_path(state["map"])
	# requests: what was sent.
	var requests: Array = []
	# events: every event.
	var events: Array = []
	# problems: what went wrong.
	var problems: Array[String] = []
	# current: the state as the run goes on.
	var current: Dictionary = state
	for _step: int in RUN_REQUEST_LIMIT:
		# sent: the next request, or {} at the end.
		var sent: Dictionary = next_request(rules, current, plan)
		if sent.is_empty():
			break
		# result: apply()'s result.
		var result: Dictionary = Core.apply(rules, current, sent)
		if result["reject"] != "":
			problems.append("rejected %s: %s" % [result["reject"], str(sent)])
			break
		problems.append_array(Helpers.contract_problems(result))
		requests.append(sent)
		events.append_array(result["events"])
		current = result["state"]
	return {"state": current, "requests": requests, "events": events, "problems": problems, "plan": plan}
