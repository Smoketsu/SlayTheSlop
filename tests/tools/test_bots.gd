## Tests for the bots in tools/bots/ (task 022), and the code rules for tools/bots/ and tools/sim/.
## Lane: tools (Agent B).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Party := preload("res://core/combat/party.gd")
const Fight := preload("res://core/combat/fight.gd")
const Bots := preload("res://tools/bots/bots.gd")
const BotMoves := preload("res://tools/bots/bot_moves.gd")
const GreedyBot := preload("res://tools/bots/greedy_bot.gd")
const Fixtures := preload("res://tests/tools/sim_fixtures.gd")
const Purity := preload("res://tests/core/test_purity.gd")
const Documentation := preload("res://tests/core/test_documentation.gd")

## Folders whose scripts the code-rule tests scan.
const TOOL_DIRS: Array[String] = ["res://tools/bots", "res://tools/sim"]

## Folders whose scripts must follow the documentation standard (the core lane's lint, applied here).
const DOCUMENTED_DIRS: Array[String] = ["res://tools/bots", "res://tools/sim", "res://tests/tools"]

## Banned in tools/bots/ and tools/sim/ -> why. PCRE, matched per line of code (comments and string
## contents removed): global randomness and clock reads would make two runs differ.
const BANNED := {
	"(?<![\\w.])(randi|randf|randi_range|randf_range|randfn|randomize|seed|rand_from_seed)\\s*\\(":
		"global random function; a bot uses its own seeded generator",
	"\\bTime\\s*\\.": "reads the clock",
	"\\bOS\\s*\\.\\s*get_(ticks|unix|system_time|datetime|date|time)": "reads the clock",
}

## Banned in tools/bots/ and tools/sim/, matched on code with comments removed but strings kept: any
## access to the run's random streams (run_state.rng). Bots never touch them.
const RNG_ACCESS := "([\"']rng[\"']|\\.rng\\b)"

## How many requests the legality test lets one fight take before it stops checking.
const STEP_LIMIT: int = 400


## Returns a fixture fight state in turn 1's player phase.
## rules: the fixture ruleset. run_seed: the seed. party_size: how many sim_dude seats.
## enemies: enemy ids.
func _fight(rules: Dictionary, run_seed: int, party_size: int, enemies: Array) -> Dictionary:
	# dude_ids: the seats.
	var dude_ids: Array = []
	for _seat: int in party_size:
		dude_ids.append("sim_dude")
	# party: the run state before the fight.
	var party: Dictionary = Party.build_run_state(rules, run_seed, dude_ids)
	return Fight.start_fight(rules, party["state"], enemies)["state"]


## Every request either bot picks is one Core.validate() accepts, choose() leaves the state it is given
## unchanged, and the fight is played to its end through Core.apply() alone.
func test_bots_send_only_legal_requests() -> void:
	# rules: the fixture ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	for bot_name: String in Bots.NAMES:
		# state: a two-seat fight.
		var state: Dictionary = _fight(rules, 3, 2, ["sim_grunt", "sim_brute"])
		# bots: one per seat.
		var bots: Array = [Bots.make(bot_name, 3, "p1"), Bots.make(bot_name, 3, "p2")]
		# steps: requests applied.
		var steps: int = 0
		while state["combat"]["phase"] == "player" and steps < STEP_LIMIT:
			for seat: int in 2:
				if state["combat"]["phase"] != "player" or state["dudes"][seat]["ready"] or state["dudes"][seat]["passed_out"]:
					continue
				# before: a copy of the state, to check choose() changes nothing.
				var before: Dictionary = state.duplicate(true)
				# sent: the bot's request.
				var sent: Dictionary = bots[seat].choose(rules, state, seat)
				assert_eq(strict_diff(state, before, "$"), "", "%s: choose() leaves the state alone" % bot_name)
				assert_eq(Core.validate(rules, state, sent), "", "%s: request is legal: %s" % [bot_name, str(sent)])
				state = Core.apply(rules, state, sent)["state"]
				steps += 1
		assert_eq(state["combat"]["phase"], "over", "%s: the fight ends" % bot_name)


## The legal requests are listed in canonical order with set_ready last, and every target kind gets
## its targets: enemies left to right, Dudes by seat, "" for self and all enemies.
func test_legal_requests_order() -> void:
	# rules: the fixture ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a two-seat fight against two grunts.
	var state: Dictionary = _fight(rules, 1, 2, ["sim_grunt", "sim_grunt"])
	# options: p1's legal requests.
	var options: Array = BotMoves.legal_requests(rules, state, 0, 1)
	assert_eq(options[-1]["type"], "set_ready", "Ready is last")
	assert_eq(options[-1]["ready"], true, "Ready is pressed, never released")
	# enemies, dudes: the possible ids.
	var enemies: Array = [state["combat"]["enemies"][0]["uid"], state["combat"]["enemies"][1]["uid"]]
	for request: Dictionary in options:
		assert_eq(Core.validate(rules, state, request), "", "listed request is legal")
		if request["type"] != "play_card":
			continue
		# def_id: the card played.
		var def_id: String = state["dudes"][0]["cards"][request["card_uid"]]["def_id"]
		match Fixtures.CARDS[def_id]["target"]:
			"enemy":
				assert_true(enemies.has(request["target_id"]), "enemy card aims at an enemy")
			"ally":
				assert_true(["p1", "p2"].has(request["target_id"]), "ally card aims at a Dude")
			_:
				assert_eq(request["target_id"], "", "untargeted card")
	# hand_order: the card_uids of the play_card requests, deduplicated, in list order.
	var hand_order: Array = []
	for request: Dictionary in options:
		if request["type"] == "play_card" and not hand_order.has(request["card_uid"]):
			hand_order.append(request["card_uid"])
	# playable: the hand, filtered to cards that appear.
	var playable: Array = state["dudes"][0]["hand"].filter(func(uid: String) -> bool: return hand_order.has(uid))
	assert_eq(hand_order, playable, "cards follow hand order")


## Outside the player phase a bot sends nothing.
func test_bots_wait_outside_the_player_phase() -> void:
	# rules: the fixture ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight marked over (test setup).
	var state: Dictionary = _fight(rules, 1, 1, ["sim_grunt"])
	state["combat"]["phase"] = "over"
	for bot_name: String in Bots.NAMES:
		assert_eq(Bots.make(bot_name, 1, "p1").choose(rules, state, 0), {}, "%s waits" % bot_name)


## The greedy bot takes the play that removes the most enemy HP: against one enemy, Sim Jab (6) beats
## Sim Sweep (3) even though Sweep is first in hand. With only a Guard card, it Guards; with an empty
## hand, it presses Ready.
func test_greedy_heuristic() -> void:
	# rules: the fixture ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: one seat against one grunt (20 HP).
	var state: Dictionary = _fight(rules, 1, 1, ["sim_grunt"])
	# dude: p1.
	var dude: Dictionary = state["dudes"][0]
	# by_def: def_id -> the first card_uid of it in the deck.
	var by_def: Dictionary = {}
	for uid: String in dude["deck"]:
		if not by_def.has(dude["cards"][uid]["def_id"]):
			by_def[dude["cards"][uid]["def_id"]] = uid
	# Test setup: a chosen hand (sweep first, then jab, then brace), as fixtures do with give().
	dude["hand"] = [by_def["neutral_sim_sweep"], by_def["neutral_sim_jab"], by_def["neutral_sim_brace"]]
	_remove_from_piles(dude, dude["hand"])
	# bot: the greedy bot.
	var bot: RefCounted = Bots.make("greedy", 1, "p1")
	# picked: its choice.
	var picked: Dictionary = bot.choose(rules, state, 0)
	assert_eq(picked["card_uid"], by_def["neutral_sim_jab"], "Jab removes 6 HP, Sweep 3 against one enemy")
	dude["hand"] = [by_def["neutral_sim_brace"]]
	assert_eq(bot.choose(rules, state, 0)["card_uid"], by_def["neutral_sim_brace"], "no damage: the most Guard")
	dude["hand"] = []
	assert_eq(bot.choose(rules, state, 0)["type"], "set_ready", "nothing to play: Ready")


## Takes card_uids out of a Dude's draw and discard piles (test setup, so a hand set by hand stays valid).
## dude: the Dude, changed here. uids: the cards now in hand.
func _remove_from_piles(dude: Dictionary, uids: Array) -> void:
	for pile: String in ["draw_pile", "discard_pile"]:
		dude[pile] = dude[pile].filter(func(uid: String) -> bool: return not uids.has(uid))


## The random bot's generator is seeded from the seed and the player_id: the same pair repeats the
## same choices; another seed or seat gives another generator seed.
func test_random_bot_is_seeded() -> void:
	# rules: the fixture ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: one seat against two grunts.
	var state: Dictionary = _fight(rules, 9, 1, ["sim_grunt", "sim_grunt"])
	# first: a random bot for seed 9, seat p1.
	var first: RefCounted = Bots.make("random", 9, "p1")
	# second: another, made the same way.
	var second: RefCounted = Bots.make("random", 9, "p1")
	for _i: int in 20:
		assert_eq(first.choose(rules, state, 0), second.choose(rules, state, 0), "same seed and seat, same choice")
	assert_ne(BotMoves.bot_seed(9, "p1"), BotMoves.bot_seed(9, "p2"), "seats differ")
	assert_ne(BotMoves.bot_seed(9, "p1"), BotMoves.bot_seed(10, "p1"), "seeds differ")
	assert_eq(Bots.make("nobody", 1, "p1"), null, "unknown bot")


## Greedy forecasts identical copies once: two Jabs at the same enemy share a key; another enemy does not.
func test_forecast_key() -> void:
	# rules: the fixture ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: one seat against two grunts.
	var state: Dictionary = _fight(rules, 1, 1, ["sim_grunt", "sim_grunt"])
	# jabs: the Jab copies in the deck.
	var jabs: Array = state["dudes"][0]["deck"].filter(func(uid: String) -> bool:
		return state["dudes"][0]["cards"][uid]["def_id"] == "neutral_sim_jab")
	# a: the first Jab at target x.
	var a: Dictionary = BotMoves.request("play_card", "p1", 1, {"card_uid": jabs[0], "target_id": "x", "crunch": false})
	# b: the second Jab at target x.
	var b: Dictionary = BotMoves.request("play_card", "p1", 1, {"card_uid": jabs[1], "target_id": "x", "crunch": false})
	# c: the second Jab at target y.
	var c: Dictionary = BotMoves.request("play_card", "p1", 1, {"card_uid": jabs[1], "target_id": "y", "crunch": false})
	assert_eq(GreedyBot.forecast_key(state, 0, a), GreedyBot.forecast_key(state, 0, b), "copies share a key")
	assert_ne(GreedyBot.forecast_key(state, 0, a), GreedyBot.forecast_key(state, 0, c), "targets differ")


## No global random function, no clock read and no access to run_state.rng in tools/bots/ or tools/sim/.
func test_no_global_random_clock_or_streams() -> void:
	# files: every script scanned.
	var files: Array[String] = []
	for dir: String in TOOL_DIRS:
		Purity._find_scripts(dir, files)
	assert_true(files.size() >= 5, "the bot and sim scripts are found")
	# compiled: BANNED compiled, in key order.
	var compiled: Array[RegEx] = []
	for pattern: String in BANNED.keys():
		compiled.append(RegEx.create_from_string(pattern))
	# rng_access: RNG_ACCESS compiled.
	var rng_access: RegEx = RegEx.create_from_string(RNG_ACCESS)
	for path: String in files:
		# source: the file's lines.
		var source: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in source.size():
			# code: the line without comments and string contents.
			var code: String = Purity.strip_comments_and_strings(source[i])
			# with_strings: the line without its comment, strings kept.
			var with_strings: String = source[i].substr(0, code.length())
			for p: int in compiled.size():
				if compiled[p].search(code) != null:
					fail("%s:%d: %s -> %s" % [path, i + 1, source[i].strip_edges(), BANNED.values()[p]])
			if rng_access.search(with_strings) != null:
				fail("%s:%d: %s -> reads the run's random streams" % [path, i + 1, source[i].strip_edges()])


## The checks above catch what they should and ignore comments.
func test_checks_catch_violations() -> void:
	# rand: the global-random pattern.
	var rand: RegEx = RegEx.create_from_string(BANNED.keys()[0])
	# clock: the OS clock pattern.
	var clock: RegEx = RegEx.create_from_string(BANNED.keys()[2])
	# rng: the stream-access pattern.
	var rng: RegEx = RegEx.create_from_string(RNG_ACCESS)
	assert_true(rand.search("var x: int = randi()") != null, "randi()")
	assert_true(rand.search("randomize()") != null, "randomize()")
	assert_true(rand.search("generator.randi_range(0, 3)") == null, "a generator's own method is allowed")
	assert_true(clock.search("var t: int = OS.get_ticks_msec()") != null, "clock")
	assert_true(clock.search("OS.get_cmdline_user_args()") == null, "arguments are allowed")
	assert_true(rng.search("state[\"rng\"]") != null, "stream access")
	assert_true(rng.search("generator.seed = 1") == null, "own generator")


## Every script in tools/bots/, tools/sim/ and tests/tools/ follows the documentation standard, checked
## with the core lane's lint (tests/core/test_documentation.gd).
func test_scripts_are_documented() -> void:
	# files: every script checked.
	var files: Array[String] = []
	for dir: String in DOCUMENTED_DIRS:
		Purity._find_scripts(dir, files)
	for path: String in files:
		for problem: String in Documentation.lint(FileAccess.get_file_as_string(path)):
			fail("%s:%s" % [path, problem])
