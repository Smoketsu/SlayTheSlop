## Starting a new run (task 025). Lane: run (Agent A).
##
## A new run is not a request: there is no state to apply one to yet. The client (task 020), bots and
## tests call start() with the seed and the Dudes picked by seat (GDD "The loop", step 1), then send
## every later choice through Core.apply(). The new state:
##   - Dudes from data/dudes/ in seat order "p1".."p4" (core/combat/party.gd build_run_state): max HP,
##     BASE_HYPE, BASE_DRAW, the starter deck as fresh card_uids "c1", "c2" ... in definition order,
##     and the starting Gear gained (its stats apply);
##   - each Dude's Dolla Bills set to START_DOLLA_BILLS (G20) and BASE_BREW_SLOTS added to their Brew
##     slots (on top of any slots their starting Gear gives);
##   - every random stream derived from the seed (core/rng/rng.gd);
##   - floor 1's map from the "map" stream (core/run/map/floor_map.gd), the party at its entrance
##     (node_index 0), run_phase "map", state_version 0.
## Events: floor_started.
##
## Every constant the run flow reads is checked here once (core/run/run_constants.gd), so a run never
## starts with one missing. The map and fight constants are checked by their own files.
##
## Pure: no file, clock, network or random access (streams are derived, the map is drawn from them).
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Party := preload("res://core/combat/party.gd")
const FloorMap := preload("res://core/run/map/floor_map.gd")
const RunConstants := preload("res://core/run/run_constants.gd")

## The floor a run starts on (GDD "Floors": The Basement is floor 1). Fixed by the GDD.
const FIRST_FLOOR: int = 1


## Returns a new run's first state (see the file header).
## ruleset: the read-only content (core/ruleset/ruleset.gd build()). run_seed: the run's seed, any
## 64-bit int. dude_ids: Dude ids from data/dudes/, one per seat, 1..4 of them.
## Returns {"state": the run state, "events": Array, "error": ""}, or {"state": {}, "events": [],
## "error": why} for bad input (a missing or bad constant, an unknown Dude, a bad party size).
static func start(ruleset: Dictionary, run_seed: int, dude_ids: Array) -> Dictionary:
	# error: why the run cannot start, or "".
	var error: String = RunConstants.check(ruleset.get("constants", {}))
	if error != "":
		return _refuse(error)
	# built: the party, from build_run_state().
	var built: Dictionary = Party.build_run_state(ruleset, run_seed, dude_ids)
	if built["error"] != "":
		return _refuse(built["error"])
	# state: the new run.
	var state: Dictionary = built["state"]
	for dude: Dictionary in state["dudes"]:
		dude["dolla_bills"] = ruleset["constants"]["START_DOLLA_BILLS"]
		dude["brew_slots"] += ruleset["constants"]["BASE_BREW_SLOTS"]
	state["floor"] = FIRST_FLOOR
	# generated: the floor map and the state with the map stream advanced.
	var generated: Dictionary = FloorMap.generate(ruleset, state, FIRST_FLOOR)
	if generated["error"] != "":
		return _refuse(generated["error"])
	state = generated["state"]
	state["map"] = generated["map"]
	state["node_index"] = 0
	state["run_phase"] = "map"
	return {"state": state, "events": [Event.make("floor_started", {"floor": FIRST_FLOOR})], "error": ""}


## Returns start()'s result for bad input.
## error: why the run could not start.
static func _refuse(error: String) -> Dictionary:
	return {"state": {}, "events": [], "error": error}
