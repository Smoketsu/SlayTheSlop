## Tests for task 025's contract additions: offers, the run fields, choose_reward's card_uid, the run
## events, the encounter format and the ruleset's new folders. Lane: run (Agent A).
extends "res://tests/framework/test_case.gd"

const RunFixtures := preload("res://tests/run/fixtures/run_fixtures.gd")
const RunState := preload("res://core/schema/run_state.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const Request := preload("res://core/schema/request.gd")
const Event := preload("res://core/schema/event.gd")
const EncounterDef := preload("res://core/schema/encounter_def.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")
const RunConstants := preload("res://core/run/run_constants.gd")


## blank() states carry the run fields and pass check(); a bad run_phase and bad offers are refused.
func test_run_fields_and_offers() -> void:
	# dude: a blank Dude.
	var dude: Dictionary = DudeState.blank("p1", "tom")
	# state: a blank run around it.
	var state: Dictionary = RunState.blank(1, [dude])
	assert_no_errors(RunState.check(state))
	assert_eq(state["run_phase"], "map")
	state["run_phase"] = "shopping"
	assert_false(RunState.check(state).is_empty(), "unknown run_phase")
	state["run_phase"] = "node"
	dude["offers"] = [{"id": "o1", "kind": "card", "def_id": "", "skippable": true,
		"options": [{"kind": "card", "available": true, "card_id": "tom_punch"}]}]
	assert_no_errors(RunState.check(state), "a valid offer")
	dude["offers"].append(dude["offers"][0].duplicate(true))
	assert_false(DudeState.check(dude).is_empty(), "duplicate offer id")
	dude["offers"] = [{"id": "o1", "kind": "raffle", "def_id": "", "skippable": true, "options": []}]
	assert_false(DudeState.check(dude).is_empty(), "unknown offer kind")
	dude["offers"] = [{"id": "o1", "kind": "card", "def_id": "", "skippable": true, "options": [{"kind": "card"}]}]
	assert_false(DudeState.check(dude).is_empty(), "option without available")
	dude["offers"] = [{"id": "o1", "kind": "card", "def_id": "", "skippable": true,
		"options": [{"kind": "card", "available": true, "price": "free"}]}]
	assert_false(DudeState.check(dude).is_empty(), "mistyped option field")
	dude["offers"] = []
	dude["pending_statuses"] = {"foggy": 0}
	assert_false(DudeState.check(dude).is_empty(), "pending stacks must be 1 or more")
	dude["pending_statuses"] = {}
	dude["cards_removed"] = -1
	assert_false(DudeState.check(dude).is_empty(), "cards_removed below 0")


## choose_reward may carry card_uid (a String); vote_node and choose_reward are well-formed requests;
## no reject code was added (the client needs a message for each, tests/client).
func test_requests() -> void:
	assert_no_errors(Request.check({"type": "choose_reward", "player_id": "p1", "seq": 0, "reward_id": "o3", "choice_index": 1}))
	assert_no_errors(Request.check({"type": "choose_reward", "player_id": "p1", "seq": 0, "reward_id": "o3", "choice_index": 1, "card_uid": "c9"}))
	assert_false(Request.check({"type": "choose_reward", "player_id": "p1", "seq": 0, "reward_id": "o3", "choice_index": 1, "card_uid": 9}).is_empty())
	assert_no_errors(Request.check({"type": "vote_node", "player_id": "p1", "seq": 0, "node_id": "r1c0"}))
	assert_eq(Request.REJECT_REASONS.size(), 11, "no new reject code")


## Every run event type is in the catalogue and checks.
func test_events() -> void:
	# samples: one event of each new type.
	var samples: Array = [
		{"type": "floor_started", "floor": 1}, {"type": "vote_cast", "player_id": "p1", "node_id": "r1c0"},
		{"type": "node_entered", "node_id": "r1c0", "node_type": "brawl"},
		{"type": "offer_opened", "player_id": "p1", "reward_id": "o1", "kind": "card"},
		{"type": "offer_closed", "player_id": "p1", "reward_id": "o1", "choice_index": -1},
		{"type": "item_bought", "player_id": "p1", "reward_id": "o1", "choice_index": 0, "price": 50},
		{"type": "card_upgraded", "player_id": "p1", "card_uid": "c9"},
		{"type": "brew_gained", "player_id": "p1", "brew_id": "light_beer", "slot": 0},
		{"type": "brew_not_kept", "player_id": "p1", "brew_id": "light_beer"},
		{"type": "side_quest_rolled", "player_id": "p1", "side_quest_id": "x", "percent": 30, "won": true},
		{"type": "pending_status_added", "player_id": "p1", "status": "foggy", "stacks": 2},
		{"type": "dude_revived", "player_id": "p2", "hp": 24}, {"type": "floor_ended", "floor": 1},
		{"type": "run_ended", "result": "lost"},
	]
	for event: Dictionary in samples:
		assert_no_errors(Event.check(event), event["type"])


## The encounter format: G19's fixtures pass; bad ones are refused; the ruleset checks enemy ids.
func test_encounter_format() -> void:
	for id: String in RunFixtures.ENCOUNTERS:
		assert_no_errors(EncounterDef.check(RunFixtures.ENCOUNTERS[id], id))
	assert_false(EncounterDef.check({"id": "x", "floor": 1, "node": "shop", "enemies": ["a"]}).is_empty(), "unknown node")
	assert_false(EncounterDef.check({"id": "x", "floor": 1, "node": "brawl", "enemies": []}).is_empty(), "no enemy")
	assert_false(EncounterDef.check({"id": "x", "floor": 0, "node": "brawl", "enemies": ["a"]}).is_empty(), "floor 0")
	assert_false(EncounterDef.check({"id": "x", "floor": 1, "node": "rival", "early": true, "enemies": ["a"]}).is_empty(), "early on a Rival")
	# built: a ruleset with an encounter naming an unknown enemy.
	var built: Dictionary = Ruleset.build(RunFixtures.files({}, {}, {"data/encounters/basement_ghosts.json":
		{"id": "basement_ghosts", "floor": 1, "node": "brawl", "enemies": ["boo_zer", "ghost_of_rush_week"]}}))
	assert_false(built["ok"])
	# named: whether an error names the file and the unknown enemy.
	var named: bool = false
	for error: String in built["errors"]:
		named = named or (error.begins_with("data/encounters/basement_ghosts.json") and error.contains("ghost_of_rush_week"))
	assert_true(named, str(built["errors"]))
	assert_eq(RunFixtures.ruleset()["encounters"].size(), RunFixtures.ENCOUNTERS.size())


## The run constants (G19-G22, task 025) are all in data/constants.json and usable.
func test_run_constants() -> void:
	# rules: the fixtures, with the real constants file.
	var rules: Dictionary = RunFixtures.ruleset()
	assert_eq(RunConstants.check(rules["constants"]), "")
	assert_eq(rules["constants"]["LOOT_MIMIC_CHANCE"], 0.25)
	assert_eq(rules["constants"]["EARLY_BRAWL_COUNT"], 2)
	assert_eq(rules["constants"]["BOSS_GEAR_CHOICES"], 3)
	assert_ne(RunConstants.check({}), "")
	assert_true(RunConstants.check(RunFixtures.ruleset({"BRAWL_DOLLA_MIN": 30})["constants"]).contains("BRAWL_DOLLA_MIN"))
	assert_true(RunConstants.check(RunFixtures.ruleset({"LOOT_MIMIC_CHANCE": 2})["constants"]).contains("LOOT_MIMIC_CHANCE"))
