## Starts a fight on the real data for the fight screen when nothing else has (task 024).
## Lane: client (Agent B).
##
## A placeholder entry until task 020's run screens start fights from the map. It uses only the
## core's own builders (core/combat/party.gd, core/combat/fight.gd), so the client still never
## writes game state itself. The Dude is the first one in data/dudes/ by id, so no client code
## names a Dude.
extends RefCounted

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")
const Party := preload("res://core/combat/party.gd")
const Fight := preload("res://core/combat/fight.gd")

## The run seed of the placeholder fight. Changed only by the client lane.
const SEED: int = 20261010
## The placeholder fight's enemies, left to right: two floor 1 goblins. Ids from data/enemies/.
const FOES: Array[String] = ["goblin_pledge", "goblin_bouncer"]


## Returns {"ruleset", "state", "player_id", "error"}: the ruleset built from data/, a run state in
## turn 1's player phase against FOES, and the local player's id. error is "" on success, otherwise
## why it failed (the other fields are then empty).
static func start() -> Dictionary:
	# built: the ruleset build result for data/.
	var built: Dictionary = Ruleset.build(DataFiles.read_all())
	if not built["ok"]:
		return _fail("data/ does not build: " + "; ".join(built["errors"]))
	# dude_ids: every Dude in the data, sorted, so the pick is stable.
	var dude_ids: Array = built["ruleset"]["dudes"].keys()
	dude_ids.sort()
	if dude_ids.is_empty():
		return _fail("data/dudes/ is empty")
	# party: the run state with one Dude.
	var party: Dictionary = Party.build_run_state(built["ruleset"], SEED, [dude_ids[0]])
	if party["error"] != "":
		return _fail(party["error"])
	# started: the fight.
	var started: Dictionary = Fight.start_fight(built["ruleset"], party["state"], FOES)
	if started["error"] != "":
		return _fail(started["error"])
	return {"ruleset": built["ruleset"], "state": started["state"], "player_id": started["state"]["dudes"][0]["player_id"], "error": ""}


## Returns a failed start() result.
## error: why.
static func _fail(error: String) -> Dictionary:
	return {"ruleset": {}, "state": {}, "player_id": "", "error": error}
