## Playtest run log (task 053): one line of JSON per finished run, for testers to send back. Lane:
## client (Agent B).
##
## When a run ends (won, lost, or abandoned: a New Run started from the menu while an unfinished run
## was saved) the run screen (client/run/run_screen.gd) appends one record to DEFAULT_PATH. The record
## is built only from what the client already receives: the run states and the events the gateway
## returns from apply(). Nothing is added to core/ or to game state, and the core never writes a file
## (CLAUDE.md "The rules core is pure"); this file and the run screen are the only writers.
##
## How it is fed: the run screen makes one RunLog per run in memory (new() with the run's first
## state, or the state loaded by Continue) and passes it every gateway answer, applied or rejected,
## through observe(). Per-fight and per-reward details come from the events, so a run continued from
## a save only has them from the load on; the record says so with "resumed" true. Run-wide totals
## (path, floor, requests_applied) come from the state and cover the whole run either way.
##
## The file: one JSON object per line ("JSON Lines"), keys sorted at every level, no spaces. It is
## only ever appended to (append_line()); an existing line is never rewritten. The record has no
## wall-clock time except "logged_at", and no personal data (no player name, machine name or path),
## so two runs with the same seed and the same requests give identical lines apart from "logged_at".
## Every value is a String, an int, a bool, an Array or a Dictionary: never a float, so a reader
## that keeps JSON integers gets them back exactly. run_seed is written as a decimal String because
## a seed can be any 64-bit int and JSON readers hold numbers as doubles (core/schema/README.md).
##
## The record's keys (RECORD_VERSION 1). "Dude ids" are player_ids, "p1".."p4".
##   "brews_gained":      player_id -> Brew ids (data/brews/) that went into that Dude's Brew slots
##                        outside fights (rewards, Shake bought at Baileys, dropped Brews), in order;
##                        from brew_gained events. [] for a Dude who gained none.
##   "dudes_at_end":      player_id -> {"dude_id": the Dude's content id (data/dudes/), "hp": HP at the
##                        end, 0..max_hp, "max_hp": max HP at the end, 1 or more}; from the last state.
##   "fights":            every fight seen, in order: {"encounter_id": the encounter fought
##                        (data/encounters/; "" when the state had none), "hp_after": player_id -> HP
##                        in the state returned by the request that ended the fight (after any revive
##                        or reward handed out by that same request), "node_id": the map node
##                        ("r<row>c<column>"; "" when not seen), "node_type": its map type ("brawl",
##                        "rival", "loot", "boss" ...; "" when not seen), "result": "won", "lost", or ""
##                        for a fight still running when the run was abandoned, "turns": turns started
##                        in the fight, 1 or more (the last turn_started event's turn)}.
##   "floor":             the floor the run ended on, 1 or more (run_state.floor).
##   "game_version":      ProjectSettings application/config/version, or UNVERSIONED when it is unset.
##   "gear_gained":       player_id -> Gear ids (data/gear/) gained during the run (rewards, Baileys,
##                        the Boss Gear pick), in order; from gear_gained events. Starting Gear is not
##                        listed. [] for a Dude who gained none.
##   "logged_at":         when the line was written, UTC, "YYYY-MM-DDTHH:MM:SSZ". The only clock value.
##   "node_id":           the map node the run ended on (map.nodes[node_index].id); "" without a map.
##   "node_row":          that node's row, 0 (the entrance) .. MAP_ROWS + 1 (the boss); -1 without a map.
##   "node_type":         that node's type ("start", "brawl" ... "boss"); "" without a map.
##   "path":              ids of the map nodes the party moved onto on the last floor, in order
##                        (run_state.path; the entrance is not listed).
##   "record_version":    RECORD_VERSION: the shape of this record.
##   "requests_applied":  requests the core applied in the whole run, every player's (state_version).
##   "requests_rejected": requests this client sent that the core rejected, since the run was started
##                        or continued in this session (rejects never reach the state).
##   "result":            how the run ended: WON, LOST or ABANDONED.
##   "resumed":           true when this session continued the run from a save (or logged an abandoned
##                        save it did not play), so "fights", "rewards", "gear_gained", "brews_gained"
##                        and "requests_rejected" cover only what happened after the load.
##   "rewards":           every choice answered, in order: {"def_id": the Side Quest id for kind
##                        "side_quest", else "", "kind": the offer kind (card, boss_gear, tailgate,
##                        baileys, side_quest; dude_state.gd OFFER_KINDS), "node_id": the map node it was
##                        on ("" when not seen), "player_id": who chose, "skipped": the options not
##                        taken, "taken": the options taken (one, none for a skipped card reward, or
##                        every purchase at Baileys)}. An option is named by its card_id, gear_id or
##                        brew_id, else by its option kind ("nap", "lift", "remove", "safe", "dumb").
##   "run_seed":          the run's seed (run_state.run_seed) as a decimal String.
##   "schema_version":    run_state.schema_version of the run's state.
##
## Test hooks: record() with a fixed logged_at, encode(), append_line(); open_folder() returns false
## without opening anything in headless runs.
extends RefCounted

## Where the run log is written when no other path is given. Changed only by the client lane.
const DEFAULT_PATH: String = "user://run_log.jsonl"
## The only path prefix the log may use (Godot's per-user data folder). Fixed by the client lane.
const ALLOWED_PREFIX: String = "user://"
## Shape version of one record ("record_version"). Raised by 1 by the client lane whenever a key is
## added, removed or changes meaning, so a reader can tell old lines from new ones.
const RECORD_VERSION: int = 1
## The project setting read for "game_version". Fixed by Godot.
const VERSION_SETTING: String = "application/config/version"
## "game_version" when VERSION_SETTING is unset or empty (no playtest build has set it yet). Changed
## only by the client lane.
const UNVERSIONED: String = "unversioned"
## "result" values. Fixed by the client lane; readers compare against them.
## WON: the floor's boss was beaten (run_phase "floor_end").
const WON: String = "won"
## LOST: every Dude Passed Out (run_phase "lost").
const LOST: String = "lost"
## ABANDONED: a New Run was started from the menu while this run was saved and unfinished.
const ABANDONED: String = "abandoned"

## True when the run's history before this log was made is missing (Continue from a save, or an
## abandoned save logged without being played): see the "resumed" key. Set by new(); read only after.
var resumed: bool = false

## The last run state seen (new()'s state, then each applied result's). Read only; never edited.
var _last: Dictionary = {}
## The fights finished so far, as "fights" entries, in order.
var _fights: Array[Dictionary] = []
## The fight running now, as a "fights" entry still being filled, or {} outside a fight.
var _fight: Dictionary = {}
## The answered choices so far, as "rewards" entries, in order.
var _rewards: Array[Dictionary] = []
## Offer id ("o" + number) -> choice_index values bought from it so far (item_bought at Baileys), in
## order. An entry is removed when its offer closes.
var _bought: Dictionary = {}
## player_id -> Gear ids gained, in order ("gear_gained").
var _gear: Dictionary = {}
## player_id -> Brew ids gained, in order ("brews_gained").
var _brews: Dictionary = {}
## Rejected requests seen since new() ("requests_rejected"), 0 or more.
var _rejected: int = 0
## Id of the map node the party last moved onto (node_entered event), "r<row>c<column>"; "" before any.
var _node_id: String = ""
## That node's map type ("brawl", "baileys" ...), from the same event; "" before any.
var _node_type: String = ""


## Starts the log of one run.
## state: the run's first state (New Run) or the state loaded from a save; read only.
## is_resumed: true when state was loaded from a save, so earlier history is missing ("resumed").
func _init(state: Dictionary, is_resumed: bool = false) -> void:
	_last = state
	resumed = is_resumed
	for dude: Dictionary in state.get("dudes", []):
		_gear[dude["player_id"]] = []
		_brews[dude["player_id"]] = []
	# node: the node the party is on when the log starts, so a choice answered right after Continue
	# still knows its node.
	var node: Dictionary = _current_node(state)
	if not node.is_empty() and state.get("run_phase", "") == "node":
		_node_id = node["id"]
		_node_type = node["type"]


## Takes one gateway answer: counts a reject, or reads an applied result's events and keeps its state.
## before: the state the request was applied to; read only (offers are looked up in it).
## result: the gateway's {"state", "events", "reject"}; read only.
func observe(before: Dictionary, result: Dictionary) -> void:
	if result["reject"] != "":
		_rejected += 1
		return
	# after: the new state.
	var after: Dictionary = result["state"]
	for event: Dictionary in result["events"]:
		match event["type"]:
			"node_entered":
				_node_id = event["node_id"]
				_node_type = event["node_type"]
			"fight_started":
				_fight = _new_fight(after)
			"turn_started":
				if _fight.is_empty():
					_fight = _new_fight(after)
				_fight["turns"] = event["turn"]
			"fight_ended":
				if _fight.is_empty():
					_fight = _new_fight(after)
				_fight["result"] = event["result"]
				_fight["hp_after"] = _hp_by_player(after)
				_fights.append(_fight)
				_fight = {}
			"gear_gained":
				_list_for(_gear, event["player_id"]).append(event["gear_id"])
			"brew_gained":
				_list_for(_brews, event["player_id"]).append(event["brew_id"])
			"item_bought":
				_list_for(_bought, event["reward_id"]).append(event["choice_index"])
			"offer_closed":
				# entry: the "rewards" entry, or {} when the offer is not in before.
				var entry: Dictionary = _reward_entry(before, event)
				if not entry.is_empty():
					_rewards.append(entry)
				_bought.erase(event["reward_id"])
	_last = after


## Returns the record of this run (see the file header for every key). Does not change the log.
## result: how the run ended, WON, LOST or ABANDONED.
## logged_at: the "logged_at" value; now_utc() when writing, a fixed text in tests.
func record(result: String, logged_at: String) -> Dictionary:
	# node: the node the run ended on, or {} without a map.
	var node: Dictionary = _current_node(_last)
	# fights: the finished fights, plus the one still running at an abandon.
	var fights: Array = _fights.duplicate(true)
	if not _fight.is_empty():
		# open: the running fight, with the HP it has now.
		var open: Dictionary = _fight.duplicate(true)
		open["hp_after"] = _hp_by_player(_last)
		fights.append(open)
	# dudes: "dudes_at_end".
	var dudes: Dictionary = {}
	for dude: Dictionary in _last.get("dudes", []):
		dudes[dude["player_id"]] = {"dude_id": dude["dude_id"], "hp": dude["hp"], "max_hp": dude["max_hp"]}
	return {
		"brews_gained": _brews.duplicate(true),
		"dudes_at_end": dudes,
		"fights": fights,
		"floor": _last.get("floor", 0),
		"game_version": game_version(),
		"gear_gained": _gear.duplicate(true),
		"logged_at": logged_at,
		"node_id": node.get("id", ""),
		"node_row": node.get("row", -1),
		"node_type": node.get("type", ""),
		"path": _last.get("path", []).duplicate(),
		"record_version": RECORD_VERSION,
		"requests_applied": _last.get("state_version", 0),
		"requests_rejected": _rejected,
		"result": result,
		"resumed": resumed,
		"rewards": _rewards.duplicate(true),
		"run_seed": str(_last.get("run_seed", 0)),
		"schema_version": _last.get("schema_version", 0),
	}


## Builds the record with logged_at set to now and appends it to the log file.
## result: WON, LOST or ABANDONED. path: the user:// log file.
## Returns "" when the line was written, otherwise why not (the run carries on either way).
func write(result: String, path: String = DEFAULT_PATH) -> String:
	return append_line(encode(record(result, now_utc())), path)


## Returns true when state is a state of the run this log follows (same run_seed, and not older than
## the last state seen), so an abandoned save can be logged with the history kept in memory.
## state: a run state; read only.
func is_run(state: Dictionary) -> bool:
	return state.get("run_seed") == _last.get("run_seed") \
		and state.get("state_version", 0) <= _last.get("state_version", 0)


## Returns a record as one line of JSON: no spaces, no line break, keys sorted at every level,
## integers written without a fraction.
## record: a JSON-shaped value with no floats (record()'s result); not changed.
static func encode(record: Dictionary) -> String:
	return JSON.stringify(_sorted(record), "", true)


## Appends one line (text plus "\n") to the end of the file at path, creating the file if it does
## not exist. Never truncates or rewrites what is already there.
## line: the text, without a line break. path: a user:// file path.
## Returns "" on success, otherwise why the line was not written.
static func append_line(line: String, path: String = DEFAULT_PATH) -> String:
	if not path.begins_with(ALLOWED_PREFIX):
		return "the run log lives under %s only, not %s" % [ALLOWED_PREFIX, path]
	# file: the log, open at its end (READ_WRITE keeps the contents; WRITE only creates a new file).
	var file: FileAccess = null
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not open %s (%s)" % [path, error_string(FileAccess.get_open_error())]
	file.store_string(line + "\n")
	# written: the write's error code, read before closing.
	var written: Error = file.get_error()
	file.close()
	if written != OK:
		return "could not write %s (%s)" % [path, error_string(written)]
	return ""


## Opens the folder holding the log in the system's file browser. Does nothing in a headless run
## (tests, servers), where there is no file browser.
## path: the user:// log file whose folder is opened.
## Returns true when the folder was handed to the system to open.
static func open_folder(path: String = DEFAULT_PATH) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return OS.shell_open(ProjectSettings.globalize_path(path.get_base_dir())) == OK


## Returns "game_version": the project's version setting, or UNVERSIONED when it is unset or empty.
static func game_version() -> String:
	# version: the setting's text, "" when unset.
	var version: String = str(ProjectSettings.get_setting(VERSION_SETTING, ""))
	return version if version != "" else UNVERSIONED


## Returns the time now as "logged_at": UTC, "YYYY-MM-DDTHH:MM:SSZ". The only clock read of the log.
static func now_utc() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


## Returns a new "fights" entry for the fight in state, at the node last entered, with no turns yet.
## state: the state holding the new fight; read only.
func _new_fight(state: Dictionary) -> Dictionary:
	return {"encounter_id": state.get("encounter_id", ""), "hp_after": {}, "node_id": _node_id,
		"node_type": _node_type, "result": "", "turns": 0}


## Returns the "rewards" entry for an offer_closed event, or {} when the offer is not in before.
## before: the state the closing request was applied to; read only. event: the offer_closed event.
func _reward_entry(before: Dictionary, event: Dictionary) -> Dictionary:
	# offer: the closed offer as it stood before the request, or {}.
	var offer: Dictionary = {}
	for dude: Dictionary in before.get("dudes", []):
		if dude["player_id"] != event["player_id"]:
			continue
		for open: Dictionary in dude["offers"]:
			if open["id"] == event["reward_id"]:
				offer = open
	if offer.is_empty():
		return {}
	# chosen: indexes of the options taken: Baileys purchases, then the closing choice (-1 is none).
	var chosen: Array = _bought.get(event["reward_id"], []).duplicate()
	if event["choice_index"] >= 0 and not chosen.has(event["choice_index"]):
		chosen.append(event["choice_index"])
	# taken, skipped: option names, in the order taken and in display order.
	var taken: Array = []
	var skipped: Array = []
	for index: int in chosen:
		if index < offer["options"].size():
			taken.append(_option_name(offer["options"][index]))
	for i: int in offer["options"].size():
		if not chosen.has(i):
			skipped.append(_option_name(offer["options"][i]))
	return {"def_id": offer["def_id"], "kind": offer["kind"], "node_id": _node_id,
		"player_id": event["player_id"], "skipped": skipped, "taken": taken}


## Returns an option's name in "taken" and "skipped": its card_id, gear_id or brew_id, else its kind.
## option: one offer option (dude_state.gd OPTION_SPEC); read only.
static func _option_name(option: Dictionary) -> String:
	for key: String in ["card_id", "gear_id", "brew_id"]:
		if option.has(key):
			return option[key]
	return option["kind"]


## Returns player_id -> HP for every Dude in state.
## state: a run state; read only.
static func _hp_by_player(state: Dictionary) -> Dictionary:
	# hp: the result.
	var hp: Dictionary = {}
	for dude: Dictionary in state.get("dudes", []):
		hp[dude["player_id"]] = dude["hp"]
	return hp


## Returns the map node the party is on in state (map.nodes[node_index]), or {} without a map.
## state: a run state; read only.
static func _current_node(state: Dictionary) -> Dictionary:
	# nodes: the floor map's nodes, [] without a map.
	var nodes: Array = state.get("map", {}).get("nodes", [])
	# index: the party's node index.
	var index: int = state.get("node_index", 0)
	if index < 0 or index >= nodes.size():
		return {}
	return nodes[index]


## Returns the Array under key in lists, creating an empty one first when missing.
## lists: a map of key -> Array; may gain a key. key: the key wanted.
static func _list_for(lists: Dictionary, key: Variant) -> Array:
	if not lists.has(key):
		lists[key] = []
	return lists[key]


## Returns a deep copy of value with every Dictionary's keys inserted in sorted order, so the JSON
## text is the same whatever order the keys were added in (JSON.stringify's sort_keys does the same;
## this keeps it true even if that default changes).
## value: a JSON-shaped value; not changed.
static func _sorted(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			# keys: the keys, sorted. out: the copy.
			var keys: Array = value.keys()
			keys.sort()
			var out: Dictionary = {}
			for key: Variant in keys:
				out[key] = _sorted(value[key])
			return out
		TYPE_ARRAY:
			# items: the copied elements.
			var items: Array = []
			for item: Variant in value:
				items.append(_sorted(item))
			return items
	return value
