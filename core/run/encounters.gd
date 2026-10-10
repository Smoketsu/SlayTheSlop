## Which enemies a fight node holds (task 025, gap G19). Lane: run (Agent A).
## Format: core/schema/encounter_def.gd (data/encounters/).
##
## Candidates for a node: the encounters whose floor is run_state.floor and whose node is the node's
## kind, sorted by id. For a Brawl, while fewer than EARLY_BRAWL_COUNT Brawls came before it on this
## floor (counted from run_state.path), only the candidates marked "early" are used (G19: "the first
## two Brawls only use Pledges, Bouncer or Intern"); if no candidate is marked early, all of them are.
## One is drawn on the "encounters" stream, each equally likely. Repeats are allowed (gap G55): the GDD has no
## rule against meeting the same group twice.
##
## Pure: randomness only through core/run/draws.gd.
extends RefCounted

const Draws := preload("res://core/run/draws.gd")
const FloorMap := preload("res://core/run/map/floor_map.gd")
const EncounterDef := preload("res://core/schema/encounter_def.gd")

## The stream every encounter draw uses (GDD "Random streams": which enemies and bosses appear).
const STREAM: String = "encounters"


## Returns the candidate encounter ids for a node kind on the run's current floor (see the file
## header), sorted. [] when the ruleset has none.
## ruleset: the read-only content. state: the run state (floor, path and map are read; for a Brawl,
## path's last entry is taken to be the node being entered when it is a Brawl itself).
## node_type: "brawl", "rival", "boss" or "loot".
static func candidates(ruleset: Dictionary, state: Dictionary, node_type: String) -> Array:
	# all: the matching encounter ids.
	var all: Array = []
	# ids: every encounter id, sorted.
	var ids: Array = ruleset.get("encounters", {}).keys()
	ids.sort()
	for id: String in ids:
		# encounter: the definition.
		var encounter: Dictionary = ruleset["encounters"][id]
		if encounter["floor"] == state["floor"] and encounter["node"] == node_type:
			all.append(id)
	if node_type != EncounterDef.EARLY_NODE or brawls_before(state) >= ruleset["constants"]["EARLY_BRAWL_COUNT"]:
		return all
	# early: the candidates marked early.
	var early: Array = []
	for id: String in all:
		if ruleset["encounters"][id].get("early", false):
			early.append(id)
	return early if not early.is_empty() else all


## Returns how many Brawl nodes the party moved onto on this floor before the node it is on now:
## the Brawls in run_state.path, not counting its last entry.
## state: the run state (path and map are read).
static func brawls_before(state: Dictionary) -> int:
	# count: the result.
	var count: int = 0
	for i: int in maxi(0, state["path"].size() - 1):
		# index: the visited node's position in the map.
		var index: int = FloorMap.index_of(state["map"], state["path"][i])
		if index != -1 and state["map"]["nodes"][index]["type"] == FloorMap.NODE_BRAWL:
			count += 1
	return count


## Draws the encounter for a node kind on the "encounters" stream and returns its id, or "" when there
## is no candidate (nothing is drawn then).
## ruleset: the read-only content. state: the working copy; the stream advances.
## node_type: "brawl", "rival", "boss" or "loot".
static func draw_in_place(ruleset: Dictionary, state: Dictionary, node_type: String) -> String:
	# picked: the drawn id, or null.
	var picked: Variant = Draws.pick_in_place(state, STREAM, candidates(ruleset, state, node_type))
	return "" if picked == null else picked
