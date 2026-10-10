## The five GDD Side Quests as data (task 016), plus each dumb option played through the real core on
## the real data/ folder with a fixed seed. Lane: tools (Agent B).
## GDD "Example Side Quests", "Junk cards", "Run state" (dumb_options_taken); G1, G15, G23–G25, G54
## (all as built by task 025). Format: core/schema/side_quest_def.gd.
extends "res://tests/framework/test_case.gd"

const Check := preload("res://tests/data/content_check.gd")
const RunFixtures := preload("res://tests/run/fixtures/run_fixtures.gd")
const RunHelpers := preload("res://tests/run/fixtures/run_helpers.gd")
const SideQuestDef := preload("res://core/schema/side_quest_def.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")
const Core := preload("res://core/core.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")

## The Side Quest folder, repo-relative.
const FOLDER: String = "data/side_quests"
## GDD "Example Side Quests": Side Quest id -> [name, safe option label]. The ids are task 025's.
const GDD := {
	"beer_pong_table": ["The Beer Pong Table", "Walk away"],
	"gas_station_sushi": ["Gas-Station Sushi", "Skip it"],
	"three_am_tattoo": ["3 a.m. Tattoo", "Go to bed"],
	"free_couch_on_the_curb": ["Free Couch on the Curb", "Leave it"],
	"unlabeled_brownie": ["The Unlabeled Brownie", "Politely decline"],
}
## The fields that are only player-facing text, set aside before comparing a file with its fixture
## (the fixture's prompts and dumb labels are placeholders the content lane replaces).
const TEXT_FIELDS: Array[String] = ["name", "text"]
## Option fields that are only player-facing text.
const OPTION_TEXT_FIELDS: Array[String] = ["label", "text"]
## Words that must never appear in any Side Quest text, lower case (CLAUDE.md: money is Dolla Bills).
const BANNED_WORDS: Array[String] = ["beer money", "beer_money", "gold"]

## Tom's HP and Dolla Bills when he meets each Side Quest (test setup): hurt, and exactly enough for the
## Beer Pong bet (G23 min_dolla_bills 50).
const START_HP: int = 40
## See START_HP.
const START_DOLLA_BILLS: int = 50
## Recorded on Godot 4.7.2-stable with the data as merged in task 016 and the run lane of task 025:
## run seed -> Side Quest id -> outcome of taking its dumb option, in the form
##   [HP after, Dolla Bills after, card ids added to the run deck, card ids upgraded, Gear after,
##    pending_statuses after, dumb_options_taken, each chance roll's "won"].
## Tom starts at START_HP of 80 with START_DOLLA_BILLS, Unused Gym Membership and his 10-card deck.
## The first seed loses every chance roll and the second wins every one, so both branches of each
## chance are played. If a data or rules change alters an outcome on purpose, re-record it and say
## why in the PR.
const RECORDED := {
	20261016: {
		"beer_pong_table": [40, 0, ["junk_hangover"], [], ["tom_unused_gym_membership"], {}, 1, [false]],
		"gas_station_sushi": [65, 50, [], [], ["tom_unused_gym_membership"], {}, 1, [false]],
		"three_am_tattoo": [40, 50, ["junk_regret"], [], ["tom_unused_gym_membership", "lucky_lighter"], {}, 1, []],
		"free_couch_on_the_curb": [80, 50, [], [], ["tom_unused_gym_membership"], {}, 1, [false]],
		"unlabeled_brownie": [40, 50, [], ["tom_arm_bar"], ["tom_unused_gym_membership"], {"foggy": 2}, 1, []],
	},
	1: {
		"beer_pong_table": [40, 100, [], [], ["tom_unused_gym_membership"], {}, 1, [true]],
		"gas_station_sushi": [65, 50, [], [], ["tom_unused_gym_membership"], {"hungover": 3}, 1, [true]],
		"three_am_tattoo": [40, 50, ["junk_regret"], [], ["tom_unused_gym_membership", "lucky_lighter"], {}, 1, []],
		"free_couch_on_the_curb": [80, 50, ["junk_bedbugs"], [], ["tom_unused_gym_membership"], {}, 1, [true]],
		"unlabeled_brownie": [40, 50, [], ["tom_arm_bar"], ["tom_unused_gym_membership"], {"foggy": 2}, 1, []],
	},
}


## data/side_quests holds exactly the five GDD Side Quests; each passes the schema, has its file name as
## id, the GDD's name and safe label, and the real data/ folder builds with all five in it.
func test_files_match_the_gdd() -> void:
	# ids: the GDD ids, sorted.
	var ids: Array = GDD.keys()
	ids.sort()
	assert_eq(Check.ids_in(FOLDER), ids, "Side Quest files")
	for id: String in GDD:
		# quest: the data file.
		var quest: Dictionary = Check.load_file("%s/%s.json" % [FOLDER, id])
		assert_false(quest.is_empty(), "%s.json is missing or broken" % id)
		if quest.is_empty():
			continue
		assert_no_errors(SideQuestDef.check(quest, id))
		assert_eq(quest.get("id"), id, "id equals the file name")
		assert_eq([quest.get("name"), quest.get("safe", {}).get("label")], GDD[id], id)
		assert_eq(quest.get("safe", {}).get("effects"), [], "%s: the safe option does nothing" % id)
		for field: String in SideQuestDef.OPTION_FIELDS:
			assert_ne(quest[field]["text"], "", "%s.%s has text" % [id, field])
	# rules: the real ruleset.
	var rules: Dictionary = Check.real_ruleset()
	assert_false(rules.is_empty(), "data/ builds")
	if not rules.is_empty():
		# built_ids: the Side Quests the ruleset holds, sorted.
		var built_ids: Array = rules["side_quests"].keys()
		built_ids.sort()
		assert_eq(built_ids, ids, "the ruleset holds the five")


## Each file's rules (everything but player-facing text) are exactly the fixture task 025's run tests
## play, so the GDD's numbers, chances, Junk ids and min_dolla_bills are the ones the core was built on.
func test_rules_match_the_run_fixtures() -> void:
	assert_eq(RunFixtures.SIDE_QUESTS.size(), GDD.size(), "one fixture per GDD Side Quest")
	for id: String in RunFixtures.SIDE_QUESTS:
		assert_eq(_rules_only(Check.load_file("%s/%s.json" % [FOLDER, id])),
			_rules_only(Check.as_data(RunFixtures.SIDE_QUESTS[id])), id)


## No Side Quest text calls money anything but Dolla Bills.
func test_money_is_dolla_bills() -> void:
	for id: String in GDD:
		# text: the whole file, lower case.
		var text: String = FileAccess.get_file_as_string("res://%s/%s.json" % [FOLDER, id]).to_lower()
		for word: String in BANNED_WORDS:
			assert_false(text.contains(word), "%s says \"%s\"" % [id, word])
	assert_true(Check.load_file(FOLDER + "/beer_pong_table.json")["dumb"]["label"].contains("Dolla Bills"),
		"the bet is in Dolla Bills")


## Each dumb option, taken on the real data at each RECORDED seed through Core.apply(), ends as
## RECORDED; every step passes the state, event and snapshot contracts, and a replay gives identical
## snapshot bytes.
func test_fixed_seed_dumb_options_on_real_data() -> void:
	for run_seed: int in RECORDED:
		for id: String in GDD:
			# label: names this case in messages.
			var label: String = "%s at seed %d" % [id, run_seed]
			# first, second: two replays of the same choice.
			var first: Dictionary = _take_dumb_option(id, run_seed)
			var second: Dictionary = _take_dumb_option(id, run_seed)
			if first.is_empty() or second.is_empty():
				continue
			assert_eq(Snapshot.to_bytes(second["state"]), Snapshot.to_bytes(first["state"]), "%s: a replay is identical" % label)
			assert_eq(_outcome(first), RECORDED[run_seed][id], "%s: recorded outcome" % label)


## Returns a Side Quest definition without its player-facing text fields, for comparing rules only.
## quest: a parsed Side Quest definition (not changed).
func _rules_only(quest: Dictionary) -> Dictionary:
	# out: a deep copy with the text fields removed.
	var out: Dictionary = quest.duplicate(true)
	for field: String in TEXT_FIELDS:
		out.erase(field)
	for field: String in SideQuestDef.OPTION_FIELDS:
		if out.get(field) is Dictionary:
			for text_field: String in OPTION_TEXT_FIELDS:
				out[field].erase(text_field)
	return out


## Plays one Side Quest's dumb option on the real data: a new solo run of Tom at run_seed on a hand-made
## one-node map (test setup), with every other Side Quest left out of data/ so this one is drawn, Tom
## at START_HP and START_DOLLA_BILLS, a vote into the node, then choice 1 (dumb).
## Returns {"state": after the choice, "events": the choice's events}, or {} after recording a failure.
## quest_id: the Side Quest to play. run_seed: the run seed.
func _take_dumb_option(quest_id: String, run_seed: int) -> Dictionary:
	# files: the real data/ folder without the other Side Quests.
	var files: Dictionary = DataFiles.read_all()
	for id: String in GDD:
		if id != quest_id:
			files.erase("%s/%s.json" % [FOLDER, id])
	# built: the ruleset with one Side Quest.
	var built: Dictionary = Ruleset.build(files)
	assert_no_errors(built["errors"], "%s: data/ builds" % quest_id)
	if not built["ok"]:
		return {}
	# rules: the ruleset.
	var rules: Dictionary = built["ruleset"]
	# state: a new run on a one-Side-Quest map.
	var state: Dictionary = RunHelpers.start(rules, run_seed)
	assert_false(state.is_empty(), "%s: the run starts" % quest_id)
	if state.is_empty():
		return {}
	state = RunHelpers.use_small_map(state, ["side_quest"])
	state["dudes"][0]["hp"] = START_HP
	state["dudes"][0]["dolla_bills"] = START_DOLLA_BILLS
	# voted: entering the node.
	var voted: Dictionary = Core.apply(rules, state, RunHelpers.vote("p1", RunHelpers.next_seq(state), "r1c0"))
	assert_eq(voted["reject"], "", "%s: the vote" % quest_id)
	if voted["reject"] != "":
		return {}
	assert_no_errors(RunHelpers.contract_problems(voted), "%s: after the vote" % quest_id)
	# offer: Tom's Side Quest offer.
	var offer: Dictionary = voted["state"]["dudes"][0]["offers"][0]
	assert_eq([offer["kind"], offer["def_id"]], ["side_quest", quest_id], "%s: the offer" % quest_id)
	assert_eq(offer["options"], [{"kind": "safe", "available": true}, {"kind": "dumb", "available": true}],
		"%s: both options on offer" % quest_id)
	# chose: taking the dumb option.
	var chose: Dictionary = Core.apply(rules, voted["state"],
		RunHelpers.choose("p1", RunHelpers.next_seq(voted["state"]), offer["id"], 1))
	assert_eq(chose["reject"], "", "%s: the dumb option" % quest_id)
	if chose["reject"] != "":
		return {}
	assert_no_errors(RunHelpers.contract_problems(chose), "%s: after the choice" % quest_id)
	return {"state": chose["state"], "events": chose["events"]}


## Returns the outcome of one dumb option in RECORDED's form.
## played: _take_dumb_option()'s result.
func _outcome(played: Dictionary) -> Array:
	# tom: Tom after the choice.
	var tom: Dictionary = played["state"]["dudes"][0]
	# deck: the run deck's card ids, in deck order; the first 10 are the starter deck.
	var deck: Array = RunHelpers.deck_ids(played["state"])
	# rolls: each chance roll's result, in order.
	var rolls: Array = []
	for event: Dictionary in RunHelpers.of_type(played["events"], "side_quest_rolled"):
		rolls.append(event["won"])
	# upgraded: the card ids the choice upgraded, in event order.
	var upgraded: Array = []
	for event: Dictionary in RunHelpers.of_type(played["events"], "card_upgraded"):
		upgraded.append(tom["cards"][event["card_uid"]]["def_id"])
	return [tom["hp"], tom["dolla_bills"], deck.slice(10), upgraded, tom["gear"], tom["pending_statuses"],
		played["state"]["dumb_options_taken"], rolls]
