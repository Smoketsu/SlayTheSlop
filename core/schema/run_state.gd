## Shape of the whole game state for one run (GDD "Run state"). Shared contract.
##
## This Dictionary is the single thing apply() takes and returns, and the thing a save or
## a co-op snapshot contains. It holds only JSON-shaped values (Dictionary with String
## keys, Array, String, int, bool, null; float never), so it can be copied, compared,
## hashed and serialized without custom code.
##
## Serialize with var_to_bytes / bytes_to_var, not JSON: ints above 2^53 (run_seed and the
## random stream states) do not survive JSON. See core/schema/README.md.
##
## Fields marked [added] are not in the GDD table and are listed in docs/changes/2026-10-10-001.md.
## Who may change values: only the rules core, through apply().
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const CombatState := preload("res://core/schema/combat_state.gd")

## Version of this state shape. Raised by 1 by any contract PR that changes the shape, so a
## save from an older shape can be recognized. Saves are not migrated during the solo slice.
## 2: task 011 added enemy_state.move_history. 3: task 009 added enemy_state.grossed_out_skips.
## 4: task 013 added dude_state.powers and dude_state.thorns.
## 5: task 021 added combat_state.fight_stat_changes and combat_state.pass_out_saves.
const SCHEMA_VERSION: int = 5

## Required fields and their types. Comments give meaning, unit and range.
const SPEC := {
	# [added] SCHEMA_VERSION of the code that created this state.
	"schema_version": TYPE_INT,
	# The seed every random stream is derived from. Any 64-bit int. Never changes during a run.
	"run_seed": TYPE_INT,
	# Players in the run, 1..4. Drives all scaling. Equals the length of dudes. 1 in the solo slice.
	"party_size": TYPE_INT,
	# Difficulty level for the run, 0..15. 0 in the solo slice.
	"keg_level": TYPE_INT,
	# Which floor the party is on: 1..3, or 4 for the final boss. 1 in the solo slice.
	"floor": TYPE_INT,
	# Where the party is on the floor map: the index in map.nodes of the node the party is on.
	# 0 is the floor's entrance (map.nodes[0], type "start"), before the first node is chosen;
	# range 0..map.nodes.size() - 1. Meaning is set by the run lane's map format
	# (core/run/map/floor_map.gd); 0 and meaningless while map is {}.
	"node_index": TYPE_INT,
	# The nodes of the current floor and the paths between them. Shape owned by the run lane
	# (core/run/map/floor_map.gd; summary in core/schema/README.md "The floor map"); {} until a map exists.
	# Shape: {"floor": int 1 or more, "nodes": Array of nodes ordered by row, then column}. A node is
	# {"id": String "r<row>c<column>", what vote_node.node_id names;
	#  "row": int 0..MAP_ROWS + 1, 0 the entrance and MAP_ROWS + 1 the boss row;
	#  "column": int 0 or more, its order within the row, left to right;
	#  "type": String, one of "start", "brawl", "rival", "side_quest", "tailgate", "baileys", "loot", "boss";
	#  "links": Array of the ids of the next row's nodes it leads to, in column order; [] for the boss}.
	"map": TYPE_DICTIONARY,
	# Shared Bro Meter, 0..BRO_METER_MAX.
	"bro_meter": TYPE_INT,
	# player_id of the Designated Driver, who breaks map-vote ties this floor. "p1" in solo.
	"designated_driver": TYPE_STRING,
	# player_id who drafts first at the next Gear reward. "p1" in solo.
	"gear_first_pick": TYPE_STRING,
	# Brews used this run, 0 or more. Adds HP to The Hangover.
	"brews_drunk": TYPE_INT,
	# Dumb Side Quest choices this run, 0 or more. Adds Swole to The Hangover.
	"dumb_options_taken": TYPE_INT,
	# Rises by exactly 1 with every applied (not rejected) request. Starts at 0.
	"state_version": TYPE_INT,
	# [added] One Dude state per player, in seat order: dudes[0] is "p1". Length is party_size.
	"dudes": {"list_of": TYPE_DICTIONARY},
	# [added] The fight in progress (see combat_state.gd), or null outside fights.
	"combat": [TYPE_DICTIONARY, TYPE_NIL],
	# [added] Random stream key -> saved generator state. Keys are the GDD stream names
	# ("map", "encounters", "combat_ai", "side_quest") and, for per-player streams,
	# "<stream>:<player_id>" ("shuffle:p1", "rewards:p1", "dice:p1"). Values are opaque to everything but core's RNG code.
	"rng": {"map_of": TYPE_INT},
	# [added] Next number used to make a card_uid ("c" + number) or enemy uid ("e" + number). Rises by 1 per uid made.
	"next_uid": TYPE_INT,
}


## Returns a run state with every field present, the given seed and party, and no map,
## no fight and no random streams yet. The rules core's new-run code fills in the rest.
## run_seed: the run's seed. dudes: one Dude state per player, in seat order.
static func blank(run_seed: int, dudes: Array) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"run_seed": run_seed,
		"party_size": dudes.size(),
		"keg_level": 0,
		"floor": 1,
		"node_index": 0,
		"map": {},
		"bro_meter": 0,
		"designated_driver": dudes[0]["player_id"] if dudes.size() > 0 else "",
		"gear_first_pick": dudes[0]["player_id"] if dudes.size() > 0 else "",
		"brews_drunk": 0,
		"dumb_options_taken": 0,
		"state_version": 0,
		"dudes": dudes,
		"combat": null,
		"rng": {},
		"next_uid": 1,
	}


## Checks a whole run state, including every Dude and the fight. Returns a list of problems.
## state: the value to check. path: label for messages.
static func check(state: Variant, path: String = "state") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(state, SPEC, path)
	if not errors.is_empty():
		return errors
	if state["party_size"] != state["dudes"].size():
		errors.append("%s.party_size: %d but there are %d dudes" % [path, state["party_size"], state["dudes"].size()])
	for i: int in state["dudes"].size():
		errors.append_array(DudeState.check(state["dudes"][i], "%s.dudes[%d]" % [path, i]))
	if state["combat"] != null:
		errors.append_array(CombatState.check(state["combat"], path + ".combat"))
	return errors
