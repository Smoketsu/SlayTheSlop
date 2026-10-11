## The fixed-seed fight simulation (task 022): plays every seed of a list against every encounter of a
## list, at every party size asked for, with every bot asked for, and reports per bot, per party size
## and per encounter: fights won, lost and stalled, mean and max turns, and mean damage taken per
## Dude. Lane: tools (Agent B). It measures; it never changes a number (CLAUDE.md "Do not fix balance").
##
##   const FightSim := preload("res://tools/sim/fight_sim.gd")
##   var result: Dictionary = FightSim.run(rules, {"bots": ["greedy"], "party_sizes": [1, 2],
##       "seeds": [1, 2, 3], "encounters": ["basement_goblin_pledges"], "dudes": [], "turn_cap": 50})
##   print(result["report"])   # result["error"] is "" or why the simulation stopped
##
## The command that runs it on the real data is tools/sim/run_sim.gd (tools/README.md).
##
## One fight, for one bot, one seed, one party size and one encounter:
##   1. A run state for the party is built with core/combat/party.gd build_run_state(rules, seed,
##      dude ids) and the fight is started with core/combat/fight.gd start_fight() (task 007's
##      fight-start function): full HP, the starter deck, the starting Gear, no Brews.
##   2. One bot per seat, made by tools/bots/bots.gd for that seed and that seat's player_id.
##   3. While the fight is in its player phase, the seats take turns in seat order, one request each
##      per round; a seat that is Passed Out or has pressed Ready is skipped. Each request goes to
##      Core.apply() and nothing else changes the state. The core refuses nothing a bot sends (bots
##      only send what Core.validate() accepts); a refused request stops the simulation with an
##      error and is never counted.
##   4. The fight ends "won" or "lost" (combat.result), or "stalled" when turn turn_cap + 1 begins,
##      or when the bots have sent REQUESTS_PER_SEAT_TURN requests per seat per turn of the cap
##      (a guard against a loop of free cards). A stalled fight counts turn_cap turns.
##   Damage taken by a Dude is the hp_lost of every damage_dealt event aimed at them, whoever dealt
##   it (enemies, Burn, their own cards), from the fight's start events on. Healing does not offset it.
##
## Encounters: each entry is an encounter id from data/encounters/ (its "enemies" are fought), or
## enemy ids joined with "+" (for example "goblin_pledge+dorm_rat"), or "all" for every encounter in
## the ruleset, sorted by id. Each is measured on its own; the simulation never picks a floor's mix
## (G19).
##
## Dudes: seat n gets dudes[n % dudes.size()], so ["tom"] at party size 3 is three Toms. With no
## dudes given, the ruleset's Dude ids, sorted, are used the same way. A repeated Dude is only a way
## to measure party sizes before other Dudes exist; it does not answer the GDD's open question on
## two players picking the same Dude.
##
## Deterministic: the same ruleset and options give a byte-identical report. No clock, no global
## randomness, no unordered keys in the report (rows follow the option lists' order).
extends RefCounted

const Core := preload("res://core/core.gd")
const Party := preload("res://core/combat/party.gd")
const Fight := preload("res://core/combat/fight.gd")
const Bots := preload("res://tools/bots/bots.gd")

## Fight outcomes as the report names them. "won" and "lost" are combat_state.gd RESULTS.
const WON: String = "won"
## Every Dude Passed Out.
const LOST: String = "lost"
## The turn cap or the request cap was reached first.
const STALLED: String = "stalled"

## Turn cap used when the options give none: a fight still running when turn 51 begins is stalled.
## A simulation setting, not game balance; the command's --turn-cap changes it.
const DEFAULT_TURN_CAP: int = 50

## Most requests one seat may send per turn of the cap before the fight is called stalled. A guard
## against a loop of free cards, far above any real turn (a hand of 5 plus draws). Tools lane setting.
const REQUESTS_PER_SEAT_TURN: int = 200

## Encounter entry that means every encounter in the ruleset, sorted by id.
const ALL_ENCOUNTERS: String = "all"

## Separator between enemy ids in an encounter entry that is not an encounter id.
const ENEMY_JOIN: String = "+"

## Label of the summary row of each bot and party size, in the report's encounter column.
const ALL_ROW: String = "(all)"

## First line of every report.
const REPORT_TITLE: String = "Dungeon Dudes fight simulation (task 022)"

## Options the command accepts (options_from_args()), without the leading "--". Tools lane.
const ARG_NAMES: Array[String] = ["bots", "party-sizes", "seeds", "encounters", "dudes", "turn-cap", "out"]

## Options the command cannot run without: the party sizes, seeds and encounters are always chosen by
## the person running it, never defaulted (task 022: party size is an argument, never a literal 1).
const REQUIRED_ARGS: Array[String] = ["party-sizes", "seeds", "encounters"]


## Runs the simulation. Returns {"report": String, "error": String, "rows": Array}. error is "" when
## every fight was played; otherwise it says why the simulation stopped (an unknown bot or encounter,
## a party size the core or the data refuses, a refused request) and report is "".
## rows: one Dictionary per bot, party size and encounter, in report order, without the summary rows:
## {"bot", "party_size", "encounter", "fights", "won", "lost", "stalled", "turns_total", "turns_max",
## "hp_lost": Array of int, one total per seat}.
## rules: the read-only ruleset (core/ruleset/ruleset.gd build()). options: {"bots": Array of bot
## names, "party_sizes": Array of int, "seeds": Array of int, "encounters": Array of encounter
## entries (file header), "dudes": Array of Dude ids or [] for the ruleset's, "turn_cap": int, 1 or
## more}. Missing keys: every bot, no party size, no seed, no encounter, [], DEFAULT_TURN_CAP.
static func run(rules: Dictionary, options: Dictionary) -> Dictionary:
	# bots: the bot names, in report order.
	var bots: Array = options.get("bots", Bots.NAMES)
	# party_sizes: the party sizes, in report order.
	var party_sizes: Array = options.get("party_sizes", [])
	# seeds: the seeds under test, in play order.
	var seeds: Array = options.get("seeds", [])
	# dudes: Dude ids to fill the seats with; the ruleset's, sorted, when empty.
	var dudes: Array = options.get("dudes", [])
	# turn_cap: the last turn a fight may play.
	var turn_cap: int = options.get("turn_cap", DEFAULT_TURN_CAP)
	# error: why the options cannot be run, or "".
	var error: String = _check_options(bots, party_sizes, seeds, turn_cap)
	if error != "":
		return _stop(error)
	# resolved: the encounters as {"name", "enemies"}.
	var resolved: Dictionary = resolve_encounters(rules, options.get("encounters", []))
	if resolved["error"] != "":
		return _stop(resolved["error"])
	# encounters: the resolved list.
	var encounters: Array = resolved["encounters"]
	if dudes.is_empty():
		dudes = rules["dudes"].keys()
		dudes.sort()
	# Check every party size and encounter before the first fight, so a refusal comes at once.
	for party_size: int in party_sizes:
		error = check_party(rules, dudes, party_size, encounters)
		if error != "":
			return _stop(error)
	# rows: the per-encounter results.
	var rows: Array = []
	for bot_name: String in bots:
		for party_size: int in party_sizes:
			# dude_ids: the Dudes by seat.
			var dude_ids: Array = seat_dudes(dudes, party_size)
			for encounter: Dictionary in encounters:
				# row: this encounter's totals.
				var row: Dictionary = _blank_row(bot_name, party_size, encounter["name"])
				for run_seed: int in seeds:
					# fight: one fight's result.
					var fight: Dictionary = play_fight(rules, bot_name, run_seed, dude_ids, encounter["enemies"], turn_cap)
					if fight["error"] != "":
						return _stop("%s, party size %d, %s, seed %d: %s" % [bot_name, party_size, encounter["name"], run_seed, fight["error"]])
					_add_fight(row, fight)
				rows.append(row)
	return {"report": format_report(options_used(bots, party_sizes, seeds, encounters, dudes, turn_cap), rows), "error": "", "rows": rows}


## Returns the inputs as the report header shows them.
## bots, party_sizes, seeds, dudes: as run() used them. encounters: the resolved encounters.
## turn_cap: the turn cap.
static func options_used(bots: Array, party_sizes: Array, seeds: Array, encounters: Array, dudes: Array, turn_cap: int) -> Dictionary:
	# names: the encounter names.
	var names: Array = []
	for encounter: Dictionary in encounters:
		names.append(encounter["name"])
	return {"bots": bots, "party_sizes": party_sizes, "seeds": seeds, "encounters": names, "dudes": dudes, "turn_cap": turn_cap}


## Returns why these options cannot run, or "".
## bots: bot names. party_sizes: party sizes. seeds: seeds. turn_cap: the turn cap.
static func _check_options(bots: Array, party_sizes: Array, seeds: Array, turn_cap: int) -> String:
	if bots.is_empty():
		return "no bot given"
	for bot_name: Variant in bots:
		if typeof(bot_name) != TYPE_STRING or not Bots.SCRIPTS.has(bot_name):
			return "unknown bot %s (bots: %s)" % [str(bot_name), ", ".join(Bots.NAMES)]
	if party_sizes.is_empty():
		return "no party size given"
	for party_size: Variant in party_sizes:
		if typeof(party_size) != TYPE_INT:
			return "party size %s is not a whole number" % str(party_size)
	if seeds.is_empty():
		return "no seed given"
	for run_seed: Variant in seeds:
		if typeof(run_seed) != TYPE_INT:
			return "seed %s is not a whole number" % str(run_seed)
	if turn_cap < 1:
		return "turn cap %d is below 1" % turn_cap
	return ""


## Returns {"encounters": Array of {"name": String, "enemies": Array of enemy ids}, "error": ""}, or
## {"encounters": [], "error": why} when an entry is neither an encounter id nor known enemy ids.
## rules: the read-only ruleset. entries: encounter entries (file header), in report order.
static func resolve_encounters(rules: Dictionary, entries: Array) -> Dictionary:
	# encounters: the result.
	var encounters: Array = []
	if entries.is_empty():
		return {"encounters": [], "error": "no encounter given"}
	for entry: Variant in entries:
		if typeof(entry) != TYPE_STRING or entry == "":
			return {"encounters": [], "error": "encounter entry %s is not a name" % str(entry)}
		if entry == ALL_ENCOUNTERS:
			# ids: every encounter id, sorted.
			var ids: Array = rules.get("encounters", {}).keys()
			ids.sort()
			for id: String in ids:
				encounters.append({"name": id, "enemies": rules["encounters"][id]["enemies"]})
		elif rules.get("encounters", {}).has(entry):
			encounters.append({"name": entry, "enemies": rules["encounters"][entry]["enemies"]})
		else:
			# enemies: the enemy ids named.
			var enemies: Array = Array(entry.split(ENEMY_JOIN))
			for enemy_id: String in enemies:
				if not rules["enemies"].has(enemy_id):
					return {"encounters": [], "error": "unknown encounter or enemy %s in %s" % [enemy_id, entry]}
			encounters.append({"name": entry, "enemies": enemies})
	return {"encounters": encounters, "error": ""}


## Returns the Dude ids by seat for a party size: seat n gets dudes[n % dudes.size()]. [] when dudes
## is empty or party_size is below 1.
## dudes: Dude ids to fill the seats with, in order. party_size: how many seats.
static func seat_dudes(dudes: Array, party_size: int) -> Array:
	# ids: the result.
	var ids: Array = []
	if dudes.is_empty():
		return ids
	for seat: int in maxi(party_size, 0):
		ids.append(dudes[seat % dudes.size()])
	return ids


## Returns why the core or the data refuses this party size, or "": a run state is built for it and
## every encounter's fight is checked with Fight.check_start(). The message names the party size.
## rules: the read-only ruleset. dudes: Dude ids to fill the seats. party_size: the party size.
## encounters: resolved encounters.
static func check_party(rules: Dictionary, dudes: Array, party_size: int, encounters: Array) -> String:
	if dudes.is_empty():
		return "party size %d refused: the ruleset has no Dude" % party_size
	# built: build_run_state()'s result for this party.
	var built: Dictionary = Party.build_run_state(rules, 0, seat_dudes(dudes, party_size))
	if built["error"] != "":
		return "party size %d refused by the core: %s" % [party_size, built["error"]]
	for encounter: Dictionary in encounters:
		# error: why this fight cannot start at this party size, or "".
		var error: String = Fight.check_start(rules, built["state"], encounter["enemies"])
		if error != "":
			return "party size %d refused for %s: %s" % [party_size, encounter["name"], error]
	return ""


## Plays one fight (file header). Returns {"outcome": WON, LOST or STALLED, "turns": turns played,
## "hp_lost": Array of int, damage taken per seat, "requests": requests applied, "error": ""}, or
## the same with "error" saying why the fight could not be played.
## rules: the read-only ruleset. bot_name: a Bots name. run_seed: the seed under test.
## dude_ids: Dude ids by seat. enemies: enemy ids, left to right. turn_cap: the last turn played.
static func play_fight(rules: Dictionary, bot_name: String, run_seed: int, dude_ids: Array, enemies: Array, turn_cap: int) -> Dictionary:
	# out: the result being filled.
	var out: Dictionary = {"outcome": STALLED, "turns": 0, "hp_lost": [], "requests": 0, "error": ""}
	# party: the run state before the fight.
	var party: Dictionary = Party.build_run_state(rules, run_seed, dude_ids)
	if party["error"] != "":
		out["error"] = "party size %d refused by the core: %s" % [dude_ids.size(), party["error"]]
		return out
	# started: start_fight()'s result.
	var started: Dictionary = Fight.start_fight(rules, party["state"], enemies)
	if started["error"] != "":
		out["error"] = "the fight could not start at party size %d: %s" % [dude_ids.size(), started["error"]]
		return out
	# state: the state as the fight goes on.
	var state: Dictionary = started["state"]
	# seats: player_id -> seat index, for counting damage.
	var seats: Dictionary = {}
	# bots: one bot per seat.
	var bots: Array = []
	for seat: int in state["dudes"].size():
		seats[state["dudes"][seat]["player_id"]] = seat
		bots.append(Bots.make(bot_name, run_seed, state["dudes"][seat]["player_id"]))
		out["hp_lost"].append(0)
	_count_damage(started["events"], seats, out["hp_lost"])
	# request_cap: the most requests this fight may take.
	var request_cap: int = turn_cap * state["dudes"].size() * REQUESTS_PER_SEAT_TURN
	while true:
		# combat: the fight.
		var combat: Dictionary = state["combat"]
		if combat["phase"] == "over":
			out["outcome"] = combat["result"]
			out["turns"] = combat["turn"]
			break
		if combat["turn"] > turn_cap or out["requests"] >= request_cap:
			out["outcome"] = STALLED
			out["turns"] = turn_cap
			break
		# acted: true when some seat sent a request this round.
		var acted: bool = false
		for seat: int in state["dudes"].size():
			if state["combat"]["phase"] != "player":
				break
			# dude: the seat's Dude.
			var dude: Dictionary = state["dudes"][seat]
			if dude["passed_out"] or dude["ready"]:
				continue
			# sent: the bot's request, or {} when it has none.
			var sent: Dictionary = bots[seat].choose(rules, state, seat)
			if sent.is_empty():
				continue
			# result: apply()'s result.
			var result: Dictionary = Core.apply(rules, state, sent)
			if result["reject"] != "":
				out["error"] = "bot %s sent a request the core refused (%s): %s" % [bot_name, result["reject"], str(sent)]
				return out
			out["requests"] += 1
			_count_damage(result["events"], seats, out["hp_lost"])
			state = result["state"]
			acted = true
		if not acted and state["combat"]["phase"] == "player":
			out["error"] = "no bot could send a request in turn %d" % state["combat"]["turn"]
			return out
	return out


## Adds the hp_lost of every damage_dealt event aimed at a Dude to that Dude's total.
## events: events from the core. seats: player_id -> seat index. hp_lost: per-seat totals, changed here.
static func _count_damage(events: Array, seats: Dictionary, hp_lost: Array) -> void:
	for event: Dictionary in events:
		if event["type"] == "damage_dealt" and seats.has(event["target_id"]):
			hp_lost[seats[event["target_id"]]] += event["hp_lost"]


## Returns an empty row.
## bot_name: the bot. party_size: the party size. encounter: the encounter's name.
static func _blank_row(bot_name: String, party_size: int, encounter: String) -> Dictionary:
	# hp_lost: one zero per seat.
	var hp_lost: Array = []
	hp_lost.resize(party_size)
	hp_lost.fill(0)
	return {"bot": bot_name, "party_size": party_size, "encounter": encounter, "fights": 0, "won": 0, "lost": 0,
		"stalled": 0, "turns_total": 0, "turns_max": 0, "hp_lost": hp_lost}


## Adds one fight to a row.
## row: the row, changed here. fight: play_fight()'s result, without error.
static func _add_fight(row: Dictionary, fight: Dictionary) -> void:
	row["fights"] += 1
	row[fight["outcome"]] += 1
	row["turns_total"] += fight["turns"]
	row["turns_max"] = maxi(row["turns_max"], fight["turns"])
	for seat: int in fight["hp_lost"].size():
		row["hp_lost"][seat] += fight["hp_lost"][seat]


## Returns the summary row of some rows of one bot and party size.
## rows: rows of the same bot and party size. bot_name: the bot. party_size: the party size.
static func _summary(rows: Array, bot_name: String, party_size: int) -> Dictionary:
	# total: the summary.
	var total: Dictionary = _blank_row(bot_name, party_size, ALL_ROW)
	for row: Dictionary in rows:
		for key: String in ["fights", "won", "lost", "stalled", "turns_total"]:
			total[key] += row[key]
		total["turns_max"] = maxi(total["turns_max"], row["turns_max"])
		for seat: int in party_size:
			total["hp_lost"][seat] += row["hp_lost"][seat]
	return total


## Returns the report text: a header with the inputs, then one line per bot, party size and
## encounter, each bot and party size closed by an ALL_ROW line. Ends with a newline.
## used: options_used()'s result. rows: run()'s rows.
static func format_report(used: Dictionary, rows: Array) -> String:
	# lines: the report's lines.
	var lines: Array[String] = [REPORT_TITLE]
	lines.append("bots: %s" % ", ".join(PackedStringArray(used["bots"])))
	lines.append("party sizes: %s" % ", ".join(PackedStringArray(used["party_sizes"].map(func(n: int) -> String: return str(n)))))
	lines.append("dudes by seat: %s (repeated to fill the seats)" % ", ".join(PackedStringArray(used["dudes"])))
	lines.append("seeds: %d (%s)" % [used["seeds"].size(), compress_seeds(used["seeds"])])
	lines.append("encounters: %s" % ", ".join(PackedStringArray(used["encounters"])))
	lines.append("turn cap: %d" % used["turn_cap"])
	lines.append("turns: mean and max per fight (a stalled fight counts the cap); dmg/dude: mean HP lost to hits per Dude per fight")
	lines.append("")
	# width: the encounter column's width.
	var width: int = ALL_ROW.length()
	for name: String in used["encounters"]:
		width = maxi(width, name.length())
	# columns: the line format, encounter column padded to width.
	var columns: String = "%-8s %5s  %-" + str(width) + "s %6s %5s %5s %7s %6s %10s %9s %9s  %s"
	lines.append(columns % ["bot", "party", "encounter", "fights", "won", "lost", "stalled", "win%",
		"turns_mean", "turns_max", "dmg/dude", "dmg by seat"])
	# start: index of the first row of the current bot and party size.
	var start: int = 0
	for i: int in rows.size():
		lines.append(_row_line(columns, rows[i]))
		if i == rows.size() - 1 or rows[i + 1]["bot"] != rows[i]["bot"] or rows[i + 1]["party_size"] != rows[i]["party_size"]:
			lines.append(_row_line(columns, _summary(rows.slice(start, i + 1), rows[i]["bot"], rows[i]["party_size"])))
			lines.append("")
			start = i + 1
	return "\n".join(PackedStringArray(lines)) + "\n"


## Returns one report line.
## columns: the line format. row: a row or summary row.
static func _row_line(columns: String, row: Dictionary) -> String:
	# seats: "p1 12.3" per seat.
	var seats: Array[String] = []
	# hp_total: HP lost by every seat.
	var hp_total: int = 0
	for seat: int in row["hp_lost"].size():
		seats.append("p%d %s" % [seat + 1, tenths(row["hp_lost"][seat], row["fights"])])
		hp_total += row["hp_lost"][seat]
	return columns % [row["bot"], str(row["party_size"]), row["encounter"], str(row["fights"]), str(row["won"]),
		str(row["lost"]), str(row["stalled"]), tenths(row["won"] * 100, row["fights"]),
		tenths(row["turns_total"], row["fights"]), str(row["turns_max"]),
		tenths(hp_total, row["fights"] * row["party_size"]), ", ".join(PackedStringArray(seats))]


## Returns numerator / denominator with one decimal, rounded half up, using only integers so the text
## never depends on float printing, for example tenths(7, 2) = "3.5". "-" when denominator is 0.
## numerator: 0 or more. denominator: 0 or more.
static func tenths(numerator: int, denominator: int) -> String:
	if denominator <= 0:
		return "-"
	# scaled: the value in tenths, rounded half up.
	var scaled: int = (numerator * 20 + denominator) / (denominator * 2)
	return "%d.%d" % [scaled / 10, scaled % 10]


## Returns the seed list as text with runs of consecutive seeds joined, for example [1, 2, 3, 7] ->
## "1..3, 7". Keeps the list's order.
## seeds: the seeds, in the order played.
static func compress_seeds(seeds: Array) -> String:
	# parts: one text per run.
	var parts: Array[String] = []
	# i: index of the run's first seed.
	var i: int = 0
	while i < seeds.size():
		# j: index of the run's last seed.
		var j: int = i
		while j + 1 < seeds.size() and seeds[j + 1] == seeds[j] + 1:
			j += 1
		parts.append(str(seeds[i]) if j == i else "%d..%d" % [seeds[i], seeds[j]])
		i = j + 1
	return ", ".join(PackedStringArray(parts))


## Parses an integer list such as "1..100" or "1, 4, 10..12" (ranges inclusive, ascending). Returns
## {"values": Array of int, "error": ""}, or {"values": [], "error": why}.
## text: the list. label: what the list is, for messages ("seeds", "party sizes").
static func parse_ints(text: String, label: String) -> Dictionary:
	# values: the result.
	var values: Array = []
	for part: String in text.split(",", false):
		# item: one entry, trimmed.
		var item: String = part.strip_edges()
		# ends: the range's two ends, or one value.
		var ends: PackedStringArray = item.split("..")
		if ends.size() == 1 and item.is_valid_int():
			values.append(item.to_int())
		elif ends.size() == 2 and ends[0].strip_edges().is_valid_int() and ends[1].strip_edges().is_valid_int() \
				and ends[0].to_int() <= ends[1].to_int():
			for value: int in range(ends[0].to_int(), ends[1].to_int() + 1):
				values.append(value)
		else:
			return {"values": [], "error": "%s: cannot read %s (use 1..100 or 1, 2, 5)" % [label, item]}
	if values.is_empty():
		return {"values": [], "error": "%s: none given" % label}
	return {"values": values, "error": ""}


## Returns a comma-separated list as trimmed, non-empty Strings.
## text: the list, for example "greedy, random".
static func parse_names(text: String) -> Array:
	# names: the result.
	var names: Array = []
	for part: String in text.split(",", false):
		if part.strip_edges() != "":
			names.append(part.strip_edges())
	return names


## Reads the command's arguments (tools/README.md) into run() options. Each option is "--name value"
## or "--name=value": --bots, --party-sizes, --seeds, --encounters (required except --bots), --dudes,
## --turn-cap, --out. Returns {"options": Dictionary for run(), "out": the --out path or "",
## "error": ""}, or {"options": {}, "out": "", "error": why}.
## args: the user arguments, as OS.get_cmdline_user_args() gives them.
static func options_from_args(args: PackedStringArray) -> Dictionary:
	# values: option name (without "--") -> its text.
	var values: Dictionary = {}
	# i: index of the argument being read.
	var i: int = 0
	while i < args.size():
		# arg: the argument.
		var arg: String = args[i]
		if not arg.begins_with("--"):
			return _bad_args("unexpected argument %s" % arg)
		if arg.contains("="):
			values[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
		elif i + 1 < args.size():
			values[arg.substr(2)] = args[i + 1]
			i += 1
		else:
			return _bad_args("%s needs a value" % arg)
		i += 1
	for name: String in values:
		if not ARG_NAMES.has(name):
			return _bad_args("unknown option --%s (options: --%s)" % [name, ", --".join(ARG_NAMES)])
	for name: String in REQUIRED_ARGS:
		if not values.has(name):
			return _bad_args("--%s is required" % name)
	# options: the result.
	var options: Dictionary = {"bots": Bots.NAMES, "dudes": [], "turn_cap": DEFAULT_TURN_CAP}
	if values.has("bots"):
		options["bots"] = parse_names(values["bots"])
	if values.has("dudes"):
		options["dudes"] = parse_names(values["dudes"])
	options["encounters"] = parse_names(values["encounters"])
	for pair: Array in [["party-sizes", "party_sizes"], ["seeds", "seeds"]]:
		# parsed: the integer list.
		var parsed: Dictionary = parse_ints(values[pair[0]], pair[0])
		if parsed["error"] != "":
			return _bad_args(parsed["error"])
		options[pair[1]] = parsed["values"]
	if values.has("turn-cap"):
		if not values["turn-cap"].is_valid_int():
			return _bad_args("turn-cap: %s is not a whole number" % values["turn-cap"])
		options["turn_cap"] = values["turn-cap"].to_int()
	return {"options": options, "out": values.get("out", ""), "error": ""}


## Returns options_from_args()'s result for bad arguments.
## error: what is wrong.
static func _bad_args(error: String) -> Dictionary:
	return {"options": {}, "out": "", "error": error}


## Returns run()'s result for a simulation that stopped.
## error: why it stopped.
static func _stop(error: String) -> Dictionary:
	return {"report": "", "error": error, "rows": []}
