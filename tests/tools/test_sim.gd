## Tests for the fixed-seed fight simulation, tools/sim/fight_sim.gd (task 022). Lane: tools (Agent B).
##
## The recorded report (sim_expected_report.txt) is the simulation of FIXTURE_OPTIONS on the in-memory
## content of tests/tools/sim_fixtures.gd. If a deliberate rules change alters it, the failure message
## prints the new report: check the change is expected, then replace the file with it in the same PR.
## The real-data test only checks that every fight ends and that two runs agree; it records no numbers,
## so content tuning never breaks it.
extends "res://tests/framework/test_case.gd"

const FightSim := preload("res://tools/sim/fight_sim.gd")
const Fixtures := preload("res://tests/tools/sim_fixtures.gd")
const Check := preload("res://tests/data/content_check.gd")

## The recorded report of FIXTURE_OPTIONS.
const EXPECTED_REPORT := "res://tests/tools/sim_expected_report.txt"

## The small simulation checked against EXPECTED_REPORT: 5 seeds, both bots, two party sizes, an
## encounter file and a "+" group of enemies.
const FIXTURE_OPTIONS := {"bots": ["greedy", "random"], "party_sizes": [1, 2], "seeds": [1, 2, 3, 4, 5],
	"encounters": ["sim_grunts", "sim_brute+sim_grunt"], "dudes": [], "turn_cap": 30}

## The real-data smoke run: 2 seeds of an early Brawl and the floor 1 boss, solo and in pairs.
const REAL_OPTIONS := {"bots": ["greedy", "random"], "party_sizes": [1, 2], "seeds": [1, 2],
	"encounters": ["basement_goblin_pledges", "basement_goblin_king_chad"], "dudes": [], "turn_cap": 50}


## The 5-seed fixture simulation gives exactly the recorded report.
func test_report_matches_recorded() -> void:
	# result: the simulation.
	var result: Dictionary = FightSim.run(Fixtures.ruleset(), FIXTURE_OPTIONS)
	assert_eq(result["error"], "", "the fixture simulation runs")
	# expected: the recorded report.
	var expected: String = FileAccess.get_file_as_string(EXPECTED_REPORT)
	if result["report"] != expected:
		fail("report differs from %s; new report:\n%s" % [EXPECTED_REPORT, result["report"]])


## Two runs with the same seeds give byte-identical reports, on the fixtures and on the real data.
func test_same_seeds_same_bytes() -> void:
	# rules: the fixture ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# first: one run.
	var first: Dictionary = FightSim.run(rules, FIXTURE_OPTIONS)
	# second: the same run again.
	var second: Dictionary = FightSim.run(rules, FIXTURE_OPTIONS)
	assert_true(first["report"] != "", "a report is made")
	assert_true(first["report"].to_utf8_buffer() == second["report"].to_utf8_buffer(), "fixture reports are identical")
	# real: the real ruleset.
	var real: Dictionary = Check.real_ruleset()
	# real_first: one run on the real data.
	var real_first: Dictionary = FightSim.run(real, REAL_OPTIONS)
	# real_second: the same run again.
	var real_second: Dictionary = FightSim.run(real, REAL_OPTIONS)
	assert_eq(real_first["error"], "", "the real-data simulation runs")
	assert_true(real_first["report"].to_utf8_buffer() == real_second["report"].to_utf8_buffer(), "real reports are identical")


## On the real data every fight ends (won, lost or stalled) and every row has its fights.
func test_real_data_fights_all_end() -> void:
	# result: the smoke run.
	var result: Dictionary = FightSim.run(Check.real_ruleset(), REAL_OPTIONS)
	assert_eq(result["error"], "", "the real-data simulation runs")
	assert_eq(result["rows"].size(), 2 * 2 * 2, "one row per bot, party size and encounter")
	for row: Dictionary in result["rows"]:
		assert_eq(row["fights"], 2, "%s %s: one fight per seed" % [row["bot"], row["encounter"]])
		assert_eq(row["won"] + row["lost"] + row["stalled"], row["fights"], "%s %s: every fight has an outcome" % [row["bot"], row["encounter"]])
		assert_eq(row["hp_lost"].size(), row["party_size"], "damage is kept per seat")


## The report has a row per bot, party size and encounter, a summary per bot and party size, and no
## clock or date in it.
func test_report_shape() -> void:
	# result: the fixture run.
	var result: Dictionary = FightSim.run(Fixtures.ruleset(), FIXTURE_OPTIONS)
	assert_eq(result["rows"].size(), 2 * 2 * 2, "rows")
	assert_eq(result["report"].count(FightSim.ALL_ROW), 2 * 2, "one summary per bot and party size")
	assert_true(result["report"].begins_with(FightSim.REPORT_TITLE), "title first")
	assert_true(result["report"].contains("party sizes: 1, 2"), "the party sizes are named")
	assert_true(result["report"].contains("seeds: 5 (1..5)"), "the seeds are named")
	for row: Dictionary in result["rows"]:
		assert_eq(row["won"] + row["lost"] + row["stalled"], 5, "five fights per row")


## Party size is an argument: a size the core refuses stops the simulation with a message naming it.
func test_refused_party_size_is_named() -> void:
	# rules: the fixture ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	for party_size: int in [0, 5]:
		# options: the fixture options at this size.
		var options: Dictionary = FIXTURE_OPTIONS.duplicate(true)
		options["party_sizes"] = [1, party_size]
		# result: the run.
		var result: Dictionary = FightSim.run(rules, options)
		assert_true(result["error"].contains("party size %d" % party_size), "names party size %d: %s" % [party_size, result["error"]])
		assert_eq(result["report"], "", "no report when stopped")
	# unknown: Dudes the data does not have.
	var unknown: Dictionary = FIXTURE_OPTIONS.duplicate(true)
	unknown["dudes"] = ["nobody"]
	assert_true(FightSim.run(rules, unknown)["error"].contains("party size 1"), "an unknown Dude refuses the party")


## Party sizes above 1 play with one bot per seat and keep damage per seat.
func test_party_of_three() -> void:
	# options: three seats, one encounter.
	var options: Dictionary = FIXTURE_OPTIONS.duplicate(true)
	options["party_sizes"] = [3]
	options["encounters"] = ["sim_grunts"]
	# result: the run.
	var result: Dictionary = FightSim.run(Fixtures.ruleset(), options)
	assert_eq(result["error"], "", "a party of three runs")
	for row: Dictionary in result["rows"]:
		assert_eq(row["hp_lost"].size(), 3, "three seats")
	assert_true(result["report"].contains("p3 "), "seat 3 is reported")


## A fight that cannot finish within the turn cap is reported as stalled, with the cap as its turns.
func test_turn_cap_stalls() -> void:
	# options: the wall, a 3-turn cap.
	var options: Dictionary = FIXTURE_OPTIONS.duplicate(true)
	options["encounters"] = ["sim_wall"]
	options["party_sizes"] = [1]
	options["turn_cap"] = 3
	# result: the run.
	var result: Dictionary = FightSim.run(Fixtures.ruleset(), options)
	assert_eq(result["error"], "", "runs")
	for row: Dictionary in result["rows"]:
		assert_eq(row["stalled"], 5, "%s: every fight stalls" % row["bot"])
		assert_eq(row["turns_max"], 3, "%s: a stalled fight counts the cap" % row["bot"])


## Bad options stop the simulation with a reason.
func test_bad_options() -> void:
	# rules: the fixture ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	for pair: Array in [["bots", ["cheater"], "unknown bot"], ["encounters", ["nothing_here"], "unknown encounter"],
			["seeds", [], "no seed"], ["party_sizes", [], "no party size"], ["turn_cap", 0, "turn cap"]]:
		# options: the fixture options with one bad value.
		var options: Dictionary = FIXTURE_OPTIONS.duplicate(true)
		options[pair[0]] = pair[1]
		assert_true(FightSim.run(rules, options)["error"].contains(pair[2]), "%s refused" % pair[0])


## "all" expands to every encounter of the ruleset, sorted; "+" joins enemy ids.
func test_resolve_encounters() -> void:
	# rules: the fixture ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# resolved: "all" and a group.
	var resolved: Dictionary = FightSim.resolve_encounters(rules, ["all", "sim_wall+sim_grunt"])
	assert_eq(resolved["error"], "", "resolves")
	assert_eq(resolved["encounters"], [{"name": "sim_grunts", "enemies": ["sim_grunt", "sim_grunt"]},
		{"name": "sim_wall+sim_grunt", "enemies": ["sim_wall", "sim_grunt"]}], "encounters")


## The command's arguments become run() options; required ones must be given.
func test_options_from_args() -> void:
	# parsed: a full command line.
	var parsed: Dictionary = FightSim.options_from_args(PackedStringArray(["--party-sizes", "1,3",
		"--seeds=1..3, 7", "--encounters", "all", "--bots", "greedy", "--turn-cap", "20", "--out", "r.txt"]))
	assert_eq(parsed["error"], "", "parses")
	assert_eq(parsed["options"]["party_sizes"], [1, 3], "party sizes")
	assert_eq(parsed["options"]["seeds"], [1, 2, 3, 7], "seeds")
	assert_eq(parsed["options"]["encounters"], ["all"], "encounters")
	assert_eq(parsed["options"]["bots"], ["greedy"], "bots")
	assert_eq(parsed["options"]["turn_cap"], 20, "turn cap")
	assert_eq(parsed["out"], "r.txt", "out")
	assert_true(FightSim.options_from_args(PackedStringArray(["--seeds", "1", "--encounters", "all"]))["error"].contains("party-sizes"),
		"party size is required")
	assert_true(FightSim.options_from_args(PackedStringArray(["--party-sizes", "1", "--seeds", "x", "--encounters", "all"]))["error"] != "",
		"bad seeds refused")
	assert_true(FightSim.options_from_args(PackedStringArray(["--party-sizes", "1", "--seeds", "1", "--encounters", "all", "--speed", "9"]))["error"].contains("speed"),
		"unknown option refused")


## Number formatting uses integers only and keeps one decimal.
func test_number_text() -> void:
	assert_eq(FightSim.tenths(7, 2), "3.5", "7 / 2")
	assert_eq(FightSim.tenths(2, 3), "0.7", "2 / 3 rounds half up")
	assert_eq(FightSim.tenths(100, 1), "100.0", "whole")
	assert_eq(FightSim.tenths(5, 0), "-", "no fights")
	assert_eq(FightSim.compress_seeds([1, 2, 3, 7, 9, 10]), "1..3, 7, 9..10", "seed runs")
