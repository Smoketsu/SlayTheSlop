## Helpers for the run flow tests (task 025): requests, small hand-made maps, a simple fight bot and
## the contract checks every step must pass. Lane: run (Agent A).
##
## Not a test file (no test_ prefix). Everything goes through the real Core.apply(); nothing here
## changes a state the core returned, except the hand-made maps, which tests put in place before the
## first vote (test setup, as tests/core/combat/fixtures.gd give() does for cards).
extends RefCounted

const Core := preload("res://core/core.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")
const Request := preload("res://core/schema/request.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const NewRun := preload("res://core/run/new_run.gd")
const Upgrades := preload("res://core/combat/upgrades.gd")
const FloorMap := preload("res://core/run/map/floor_map.gd")

## Most requests the fight bot sends in one fight before it gives up (a guard against a stuck loop).
const BOT_REQUEST_LIMIT: int = 2000

## Below this percent of max HP the bot drinks a Brew when it can. A bot setting, not game balance.
const BOT_DRINK_PERCENT: int = 50


## Returns a new solo run of Tom, or {} if it cannot start.
## rules: the ruleset. run_seed: the seed. dude_ids: Dude ids by seat (default Tom alone).
static func start(rules: Dictionary, run_seed: int, dude_ids: Array = ["tom"]) -> Dictionary:
	# started: NewRun.start()'s result.
	var started: Dictionary = NewRun.start(rules, run_seed, dude_ids)
	return started["state"]


## Returns a request Dictionary with the common fields.
## type: the request type. player_id: the sender. seq: its seq. fields: the type's own fields.
static func request(type: String, player_id: String, seq: int, fields: Dictionary = {}) -> Dictionary:
	# out: the result.
	var out: Dictionary = fields.duplicate()
	out["type"] = type
	out["player_id"] = player_id
	out["seq"] = seq
	return out


## Returns a vote_node request.
## player_id: the sender. seq: its seq. node_id: the node voted for.
static func vote(player_id: String, seq: int, node_id: String) -> Dictionary:
	return request("vote_node", player_id, seq, {"node_id": node_id})


## Returns a choose_reward request; card_uid is added only when not "".
## player_id: the sender. seq: its seq. reward_id: the offer id. choice_index: the option or -1.
## card_uid: the card for a lift or remove option, or "".
static func choose(player_id: String, seq: int, reward_id: String, choice_index: int, card_uid: String = "") -> Dictionary:
	# fields: the type's fields.
	var fields: Dictionary = {"reward_id": reward_id, "choice_index": choice_index}
	if card_uid != "":
		fields["card_uid"] = card_uid
	return request("choose_reward", player_id, seq, fields)


## Returns the next seq a player should send: one above their Dude's last_seq.
## state: the run state. player_index: the Dude's seat, 0-based.
static func next_seq(state: Dictionary, player_index: int = 0) -> int:
	return state["dudes"][player_index]["last_seq"] + 1


## Returns a hand-made floor map: the entrance linked to one row-1 node per type (columns in order),
## each linked to a boss node in row 2. Shape as core/run/map/floor_map.gd.
## types: node types for row 1, for example ["brawl", "tailgate"].
static func small_map(types: Array) -> Dictionary:
	# row_ids: the row-1 node ids.
	var row_ids: Array = []
	for column: int in types.size():
		row_ids.append(FloorMap.node_id(1, column))
	# nodes: the map's nodes, entrance first.
	var nodes: Array = [{"id": FloorMap.node_id(0, 0), "row": 0, "column": 0, "type": FloorMap.NODE_START, "links": row_ids}]
	for column: int in types.size():
		nodes.append({"id": row_ids[column], "row": 1, "column": column, "type": types[column],
			"links": [FloorMap.node_id(2, 0)]})
	nodes.append({"id": FloorMap.node_id(2, 0), "row": 2, "column": 0, "type": FloorMap.NODE_BOSS, "links": []})
	return {"floor": 1, "nodes": nodes}


## Puts a small_map() with one node of each given type in a fresh state (test setup) and returns it.
## state: a new run's state, changed here. types: the row-1 node types.
static func use_small_map(state: Dictionary, types: Array) -> Dictionary:
	state["map"] = small_map(types)
	state["node_index"] = 0
	return state


## Returns the problems with one apply() result: every event must pass Event.check() and the state
## RunState.check(), and the state must survive a Snapshot round trip unchanged.
## result: Core.apply()'s result (or NewRun.start()'s).
static func contract_problems(result: Dictionary) -> Array[String]:
	# problems: what was found.
	var problems: Array[String] = []
	for i: int in result["events"].size():
		problems.append_array(Event.check(result["events"][i], "events[%d]" % i))
	problems.append_array(RunState.check(result["state"]))
	# loaded: the state after a save and load.
	var loaded: Dictionary = Snapshot.from_bytes(Snapshot.to_bytes(result["state"]))
	if not loaded["ok"]:
		problems.append("snapshot refused: %s" % loaded["error"])
	elif Snapshot.state_hash(loaded["state"]) != Snapshot.state_hash(result["state"]):
		problems.append("snapshot round trip changed the state")
	return problems


## Returns the uid of the enemy with the least HP (the leftmost on a tie), or "" with no enemy.
## state: a run state in a fight.
static func weakest_enemy(state: Dictionary) -> String:
	# best: the chosen enemy, or {}.
	var best: Dictionary = {}
	for enemy: Dictionary in state["combat"]["enemies"]:
		if best.is_empty() or enemy["hp"] < best["hp"]:
			best = enemy
	return "" if best.is_empty() else best["uid"]


## Returns the next request a simple bot sends in a fight for one player: a Brew when below
## BOT_DRINK_PERCENT HP, the Bro Move when full, else the first playable card in hand (attacks and
## debuffs at the weakest enemy), else set_ready. Uses Core.validate() to find legal requests.
## rules: the ruleset. state: the run state, in the player phase. player_index: the Dude's seat.
## seq: the seq to send.
static func bot_request(rules: Dictionary, state: Dictionary, player_index: int, seq: int) -> Dictionary:
	# dude: the bot's Dude.
	var dude: Dictionary = state["dudes"][player_index]
	# player_id: its id.
	var player_id: String = dude["player_id"]
	# enemy: the bot's target.
	var enemy: String = weakest_enemy(state)
	# candidates: requests to try, in order.
	var candidates: Array = []
	if dude["hp"] * 100 < dude["max_hp"] * BOT_DRINK_PERCENT:
		for slot: int in dude["brews"].size():
			candidates.append(request("use_brew", player_id, seq, {"slot": slot, "target_id": ""}))
			candidates.append(request("use_brew", player_id, seq, {"slot": slot, "target_id": enemy}))
	candidates.append(request("use_bro_move", player_id, seq, {"target_id": enemy}))
	for uid: String in dude["hand"]:
		# card: the copy's definition (upgraded when Lifted), or {}.
		var card: Dictionary = Upgrades.definition_of(rules, dude, uid)
		# target: the target this card needs.
		var target: String = enemy if card.get("target", "") == "enemy" else ""
		candidates.append(request("play_card", player_id, seq, {"card_uid": uid, "target_id": target, "crunch": false}))
	for candidate: Dictionary in candidates:
		if Core.validate(rules, state, candidate) == "":
			return candidate
	return request("set_ready", player_id, seq, {"ready": true})


## Plays the current fight with bot_request() until it is no longer in a player phase (won and
## cleared, or over). Returns {"state", "events": every event, "problems": contract problems found,
## "requests": the requests sent}.
## rules: the ruleset. state: a run state in a fight's player phase.
static func bot_fight(rules: Dictionary, state: Dictionary) -> Dictionary:
	# events: every event of the fight.
	var events: Array = []
	# problems: contract problems found on the way.
	var problems: Array[String] = []
	# requests: what the bot sent.
	var requests: Array = []
	# current: the state as the fight goes on.
	var current: Dictionary = state
	for _step: int in BOT_REQUEST_LIMIT:
		if current["combat"] == null or current["combat"]["phase"] != "player":
			break
		# sent: the bot's next request.
		var sent: Dictionary = bot_request(rules, current, 0, next_seq(current))
		# result: apply()'s result.
		var result: Dictionary = Core.apply(rules, current, sent)
		if result["reject"] != "":
			problems.append("bot request rejected: %s %s" % [result["reject"], str(sent)])
			break
		problems.append_array(contract_problems(result))
		requests.append(sent)
		events.append_array(result["events"])
		current = result["state"]
	return {"state": current, "events": events, "problems": problems, "requests": requests}


## Returns the events of one type from a list.
## events: the events. type: the event type.
static func of_type(events: Array, type: String) -> Array:
	# found: the matching events.
	var found: Array = []
	for event: Dictionary in events:
		if event["type"] == type:
			found.append(event)
	return found


## Returns the def_ids of a Dude's run deck, in deck order.
## state: a run state. player_index: the Dude's seat, 0-based.
static func deck_ids(state: Dictionary, player_index: int = 0) -> Array:
	# ids: the result.
	var ids: Array = []
	for uid: String in state["dudes"][player_index]["deck"]:
		ids.append(state["dudes"][player_index]["cards"][uid]["def_id"])
	return ids
