## Tests for core/run/new_run.gd: a new run from a seed and Dudes by seat (task 025). Lane: run (Agent A).
extends "res://tests/framework/test_case.gd"

const RunFixtures := preload("res://tests/run/fixtures/run_fixtures.gd")
const Helpers := preload("res://tests/run/fixtures/run_helpers.gd")
const NewRun := preload("res://core/run/new_run.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const FloorMap := preload("res://core/run/map/floor_map.gd")
const Party := preload("res://core/combat/party.gd")

## Seed used by these tests. Any seed works; fixed so every run checks the same state.
const SEED: int = 2501


## A new solo run: Tom from data, starter deck with fresh card_uids, starting Gear, G20's Dolla Bills,
## BASE_BREW_SLOTS, floor 1's map, at the entrance, run_phase "map", state_version 0.
func test_new_run_from_seed_and_dudes() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	assert_false(rules.is_empty(), "fixture ruleset builds")
	# started: the new run.
	var started: Dictionary = NewRun.start(rules, SEED, ["tom"])
	assert_eq(started["error"], "")
	assert_eq(Helpers.contract_problems(started), [] as Array[String], "state and events follow the contract")
	# state: the new run's state.
	var state: Dictionary = started["state"]
	# tom: p1.
	var tom: Dictionary = state["dudes"][0]
	assert_eq(state["party_size"], 1)
	assert_eq(tom["player_id"], "p1")
	assert_eq(tom["dude_id"], "tom")
	assert_eq(tom["hp"], 80)
	assert_eq(tom["max_hp"], 80)
	assert_eq(tom["deck"], ["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9", "c10"])
	assert_eq(Helpers.deck_ids(state), RunFixtures.DUDES["tom"]["starter_deck"], "starter deck in definition order")
	for uid: String in tom["deck"]:
		assert_false(tom["cards"][uid]["upgraded"], "%s starts not upgraded" % uid)
	assert_eq(tom["gear"], ["tom_unused_gym_membership"], "starting Gear")
	assert_eq(tom["dolla_bills"], rules["constants"]["START_DOLLA_BILLS"], "G20")
	assert_eq(tom["dolla_bills"], 99)
	assert_eq(tom["brew_slots"], rules["constants"]["BASE_BREW_SLOTS"])
	assert_eq(tom["brews"], [])
	assert_eq(tom["offers"], [])
	assert_eq(state["next_uid"], 11, "next uid after the ten starter cards")
	assert_eq(state["floor"], 1)
	assert_eq(state["map"]["floor"], 1)
	assert_eq(state["map"]["nodes"][0]["type"], FloorMap.NODE_START)
	assert_eq(state["node_index"], 0)
	assert_eq(state["run_phase"], "map")
	assert_eq(state["path"], [])
	assert_eq(state["votes"], {})
	assert_eq(state["encounter_id"], "")
	assert_eq(state["combat"], null)
	assert_eq(state["state_version"], 0)
	assert_eq(state["dumb_options_taken"], 0)
	assert_eq(started["events"], [{"type": "floor_started", "floor": 1}])
	# party: the same party before any map draw.
	var party: Dictionary = Party.build_run_state(rules, SEED, ["tom"])["state"]
	assert_eq(state["map"], FloorMap.generate(rules, party, 1)["map"], "the map is floor_map.gd's for this seed")


## The same seed gives the same new run; another seed a different map.
func test_new_run_is_deterministic() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	assert_eq(Snapshot.state_hash(Helpers.start(rules, SEED)), Snapshot.state_hash(Helpers.start(rules, SEED)))
	assert_ne(Helpers.start(rules, SEED)["map"], Helpers.start(rules, SEED + 1)["map"])


## Co-op ready: one Dude per seat, each with their own streams, seats p1 and p2.
func test_new_run_for_two_seats() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: two Toms.
	var state: Dictionary = Helpers.start(rules, SEED, ["tom", "tom"])
	assert_eq(state["party_size"], 2)
	assert_eq(state["dudes"][1]["player_id"], "p2")
	assert_eq(state["dudes"][1]["deck"][0], "c11", "card_uids continue across seats")
	for key: String in ["rewards:p1", "rewards:p2", "shuffle:p2", "encounters", "side_quest"]:
		assert_true(state["rng"].has(key), "stream %s exists" % key)
	assert_no_errors(RunState.check(state))


## Bad input is refused with an error and no state: an unknown Dude, no Dude, a missing constant.
func test_new_run_refuses_bad_input() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	assert_ne(NewRun.start(rules, SEED, ["cheney"])["error"], "")
	assert_ne(NewRun.start(rules, SEED, [])["error"], "")
	# broken: the fixtures without START_DOLLA_BILLS... replaced by a text value is refused by the
	# ruleset, so a negative number stands in for a broken constant.
	var broken: Dictionary = RunFixtures.ruleset({"START_DOLLA_BILLS": -1})
	# refused: start()'s result.
	var refused: Dictionary = NewRun.start(broken, SEED, ["tom"])
	assert_true(refused["error"].contains("START_DOLLA_BILLS"), refused["error"])
	assert_eq(refused["state"], {})
