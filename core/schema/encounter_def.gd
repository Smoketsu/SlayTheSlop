## Shape of an encounter definition, one JSON file per enemy group in data/encounters/: which enemies
## a fight at a map node puts in front of the party (GDD "Random streams": encounters = "which enemies
## and bosses appear"). Shared contract. [added, task 025: the GDD lists the floor 1 groups only in
## prose; gap G19 gives the list]
##
## When the party enters a fight node, the run lane (core/run/encounters.gd) draws one encounter on
## the "encounters" stream, each equally likely, among those whose floor is the run's floor and whose
## node is the node's kind:
##   brawl: a Brawl. While fewer than EARLY_BRAWL_COUNT Brawls have been fought on the floor, only
##          encounters with "early": true are drawn (G19: "the first two Brawls only use Pledges,
##          Bouncer or Intern"); later Brawls draw from every brawl encounter.
##   rival: a Rival fight.
##   boss:  the floor boss ("each floor rolls one of two").
##   loot:  a Loot node that is a trap (G19: Mimic Cooler replaces a Loot node with chance
##          LOOT_MIMIC_CHANCE). A Loot node with no loot encounter is always plain Loot.
##
## Example (G19, a floor 1 Brawl):
##   {"id": "basement_goblin_pledges", "floor": 1, "node": "brawl", "early": true,
##    "enemies": ["goblin_pledge", "goblin_pledge"]}
##
## Who may change definitions: the content lane. Who may change this shape: a contract PR.
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")

## Values of "node": the map node kinds that hold a fight (core/run/map/floor_map.gd node types).
## Changed only by a contract PR.
const NODES: Array[String] = ["brawl", "rival", "boss", "loot"]

## The one node kind that may use "early".
const EARLY_NODE: String = "brawl"

## Required fields and their types.
const SPEC := {
	# Unique key, snake_case, equal to the file name without ".json". Never changes after merge,
	# because saves refer to it (run_state.encounter_id).
	"id": TYPE_STRING,
	# The floor it appears on, 1..3, or 4 for the final boss (as enemy_def.gd "floor").
	"floor": TYPE_INT,
	# The node kind it is drawn for, one of NODES.
	"node": TYPE_STRING,
	# Enemy definition ids (data/enemies/), left to right, at least one. Escorts named in an enemy's
	# arrives_with are added by the fight itself and are not listed here (Goblin Shot-Caller).
	"enemies": {"list_of": TYPE_STRING},
}

## Fields that may be left out.
const OPTIONAL := {
	# Brawl encounters only: true when it may be one of a floor's first EARLY_BRAWL_COUNT Brawls (G19).
	# Absent or false: drawn only from the floor's later Brawls on.
	"early": TYPE_BOOL,
	# Notes for the content lane, for example the GDD wording it comes from. Not shown to players.
	"text": TYPE_STRING,
}


## Checks an encounter definition. Returns a list of problems; empty means valid. Whether each enemy
## id exists is checked by core/ruleset/ruleset.gd.
## encounter: the parsed definition (after json_values.parse). path: label for messages, usually the file path.
static func check(encounter: Variant, path: String = "encounter") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(encounter, SPEC, path, OPTIONAL)
	if not errors.is_empty():
		return errors
	errors.append_array(Shape.check_one_of(encounter["node"], NODES, path + ".node"))
	if encounter["floor"] < 1:
		errors.append("%s.floor: must be 1 or more" % path)
	if encounter["enemies"].is_empty():
		errors.append("%s.enemies: needs at least one enemy" % path)
	if encounter.has("early") and encounter["node"] != EARLY_NODE:
		errors.append("%s.early: only a \"%s\" encounter may set it" % [path, EARLY_NODE])
	return errors
