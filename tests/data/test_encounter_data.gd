## Floor 1's encounter groups as data (task 026), plus a fixed-seed run start on the real data/ folder
## that enters the first Brawl. Lane: tools (Agent B).
## GDD "Floor 1: The Basement", "Node types", "Map"; G19 and G61 (docs/proposals/solo-slice-rule-gaps.md);
## format in core/schema/encounter_def.gd (task 025).
extends "res://tests/framework/test_case.gd"

const Check := preload("res://tests/data/content_check.gd")
const RunFixtures := preload("res://tests/run/fixtures/run_fixtures.gd")
const EncounterDef := preload("res://core/schema/encounter_def.gd")
const Core := preload("res://core/core.gd")
const NewRun := preload("res://core/run/new_run.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")

## The encounter folder this task fills.
const FOLDER := "data/encounters"
## The run seed of the real-data run start. Any fixed value; this one is the task's date.
const SEED: int = 20261010
## The enemies G19 allows in a floor's first two Brawls ("only use Pledges, Bouncer or Intern").
## A Brawl made only of these is early (G61, as built in task 025's fixtures).
const EARLY_ENEMIES: Array[String] = ["goblin_pledge", "goblin_bouncer", "skeleton_intern"]
## Recorded on Godot 4.7.2-stable with the data and run flow as of task 026: the encounter the first
## Brawl draws for SEED on the real data. If a data or run-flow change alters it on purpose,
## re-record it and say why in the PR.
const RECORDED_ENCOUNTER: String = "basement_pledge_and_intern"


## Every file in data/encounters/ passes encounter_def.gd's check() and its id is its file name.
func test_every_file_passes_the_schema() -> void:
	# ids: the file names in the folder.
	var ids: Array[String] = Check.ids_in(FOLDER)
	assert_false(ids.is_empty(), "data/encounters/ has files")
	for id: String in ids:
		# encounter: the parsed file.
		var encounter: Dictionary = Check.load_file("%s/%s.json" % [FOLDER, id])
		assert_no_errors(EncounterDef.check(encounter, id), "%s passes encounter_def" % id)
		assert_eq(encounter.get("id"), id, "id equals the file name")


## data/encounters/ holds exactly task 025's ENCOUNTERS fixtures, each file equal to its fixture
## once its "text" note (which the fixtures do not have) is set aside.
func test_encounters_match_the_run_fixtures() -> void:
	# ids: the fixture ids, sorted.
	var ids: Array = RunFixtures.ENCOUNTERS.keys()
	ids.sort()
	assert_eq(Check.ids_in(FOLDER), ids, "encounter files")
	for id: String in RunFixtures.ENCOUNTERS:
		# encounter: the data file, without its note.
		var encounter: Dictionary = Check.load_file("%s/%s.json" % [FOLDER, id])
		encounter.erase("text")
		assert_eq(encounter, Check.as_data(RunFixtures.ENCOUNTERS[id]), id)


## "early" is set only on Brawls, and a Brawl is early exactly when every enemy in it is one of
## EARLY_ENEMIES (G19, G61). At least one early Brawl exists, so a floor can start.
func test_early_only_on_brawls_of_early_enemies() -> void:
	# early_count: how many early encounters there are.
	var early_count: int = 0
	for id: String in Check.ids_in(FOLDER):
		# encounter: the data file.
		var encounter: Dictionary = Check.load_file("%s/%s.json" % [FOLDER, id])
		# early: whether it is marked early.
		var early: bool = encounter.get("early", false)
		if encounter["node"] != EncounterDef.EARLY_NODE:
			assert_false(encounter.has("early"), "%s: only a Brawl sets early" % id)
			continue
		# only_early_enemies: true when every enemy is one G19 allows in early Brawls.
		var only_early_enemies: bool = encounter["enemies"].all(func(e: String) -> bool: return EARLY_ENEMIES.has(e))
		assert_eq(early, only_early_enemies, "%s: early exactly when made of Pledges, a Bouncer or an Intern" % id)
		if early:
			early_count += 1
	assert_eq(early_count, 4, "four early Brawls (G19, G61)")


## The real ruleset holds every encounter; each enemy id is an enemy in it; an escort named in an
## enemy's arrives_with is not also listed beside it (encounter_def.gd "enemies").
func test_enemies_resolve_and_escorts_are_not_listed() -> void:
	# rules: the real ruleset.
	var rules: Dictionary = Check.real_ruleset()
	assert_false(rules.is_empty(), "data/ builds")
	if rules.is_empty():
		return
	# ids: the encounter ids in the ruleset, sorted.
	var ids: Array = rules["encounters"].keys()
	ids.sort()
	assert_eq(ids, Check.ids_in(FOLDER), "the ruleset has every encounter file")
	for id: String in ids:
		# enemies: the encounter's enemy ids.
		var enemies: Array = rules["encounters"][id]["enemies"]
		for enemy_id: String in enemies:
			assert_true(rules["enemies"].has(enemy_id), "%s: enemy %s exists" % [id, enemy_id])
			if not rules["enemies"].has(enemy_id):
				continue
			for escort: String in rules["enemies"][enemy_id].get("arrives_with", []):
				assert_false(enemies.has(escort) and escort != enemy_id,
					"%s: %s's escort %s is added by the fight, not listed" % [id, enemy_id, escort])


## A run of Tom started on the real data with SEED votes for the first node of row 1 (always a Brawl,
## core/run/map/floor_map.gd): the vote is accepted, the party enters the Brawl and its fight starts
## with an early encounter's enemies, RECORDED_ENCOUNTER for this seed. Every state passes
## run_state.check(), and a replay gives identical snapshot bytes.
func test_fixed_seed_run_enters_the_first_brawl() -> void:
	# first, second: two replays of the same run start.
	var first: Dictionary = _enter_first_brawl()
	var second: Dictionary = _enter_first_brawl()
	if first.is_empty() or second.is_empty():
		return
	assert_eq(Snapshot.to_bytes(second["state"]), Snapshot.to_bytes(first["state"]), "a replay is identical")
	assert_eq(first["state"]["encounter_id"], RECORDED_ENCOUNTER, "recorded encounter for SEED")


## Starts a run on the real data and votes into row 1's first node. Asserts each step and returns
## {"state": the state after the vote}, or {} after recording a failure.
func _enter_first_brawl() -> Dictionary:
	# rules: the real ruleset.
	var rules: Dictionary = Check.real_ruleset()
	assert_false(rules.is_empty(), "data/ builds")
	if rules.is_empty():
		return {}
	# started: the new run.
	var started: Dictionary = NewRun.start(rules, SEED, ["tom"])
	assert_eq(started["error"], "", "NewRun.start")
	if started["error"] != "":
		return {}
	# state: the run at the entrance.
	var state: Dictionary = started["state"]
	assert_no_errors(RunState.check(state), "new run state")
	# node_id: the entrance's first link, a row-1 node.
	var node_id: String = state["map"]["nodes"][0]["links"][0]
	# vote: Tom's vote for it.
	var vote: Dictionary = {"type": "vote_node", "player_id": "p1", "seq": state["dudes"][0]["last_seq"] + 1, "node_id": node_id}
	# result: the core's answer.
	var result: Dictionary = Core.apply(rules, state, vote)
	assert_eq(result["reject"], "", "the vote for the first Brawl is accepted")
	if result["reject"] != "":
		return {}
	state = result["state"]
	assert_no_errors(RunState.check(state), "state after the vote")
	# types: the event types, in order.
	var types: Array = result["events"].map(func(e: Dictionary) -> String: return e["type"])
	assert_eq(types.slice(0, 3), ["vote_cast", "node_entered", "fight_started"], "events")
	assert_eq(result["events"][1].get("node_type"), "brawl", "row 1 is a Brawl")
	assert_eq(state["run_phase"], "node")
	assert_eq(state["path"], [node_id])
	assert_ne(state["combat"], null, "a fight started")
	if state["combat"] == null:
		return {}
	assert_eq(state["combat"]["phase"], "player")
	# encounter: the drawn encounter's definition.
	var encounter: Dictionary = rules["encounters"].get(state["encounter_id"], {})
	assert_true(encounter.get("early", false), "the first Brawl is early: %s" % state["encounter_id"])
	# def_ids: the fight's enemy definition ids, left to right.
	var def_ids: Array = state["combat"]["enemies"].map(func(e: Dictionary) -> String: return e["def_id"])
	assert_eq(def_ids, encounter.get("enemies", []), "the fight holds the encounter's enemies")
	return {"state": state}
