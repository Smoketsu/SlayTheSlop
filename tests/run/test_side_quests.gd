## Tests for the Side Quest format and core/run/side_quests.gd: the five GDD Side Quests, safe and dumb
## options, dumb_options_taken, the side_quest stream, G23, G24 and G25 (task 025). Lane: run (Agent A).
extends "res://tests/framework/test_case.gd"

const RunFixtures := preload("res://tests/run/fixtures/run_fixtures.gd")
const Helpers := preload("res://tests/run/fixtures/run_helpers.gd")
const Core := preload("res://core/core.gd")
const Fight := preload("res://core/combat/fight.gd")
const SideQuestDef := preload("res://core/schema/side_quest_def.gd")
const SideQuestOps := preload("res://core/run/side_quest_ops.gd")
const SideQuests := preload("res://core/run/side_quests.gd")
const Pools := preload("res://core/run/pools.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")

## Seed used by these tests.
const SEED: int = 1616


## Returns a solo run that faces this Side Quest (test setup: a ruleset with only that one, so the
## draw cannot pick another), after voting into it, with Tom's HP and Dolla Bills set first.
## quest_id: one of RunFixtures.SIDE_QUESTS. run_seed: the seed. hp: Tom's HP. dolla_bills: his money.
## Returns {"rules": the ruleset, "state": the state after the vote}.
func _facing(quest_id: String, run_seed: int = SEED, hp: int = 80, dolla_bills: int = 99) -> Dictionary:
	# extra: every other Side Quest removed.
	var extra: Dictionary = {}
	for id: String in RunFixtures.SIDE_QUESTS:
		if id != quest_id:
			extra["data/side_quests/%s.json" % id] = null
	# rules: the fixtures with one Side Quest.
	var rules: Dictionary = RunFixtures.ruleset({}, {}, extra)
	# state: a run on a one-Side-Quest map.
	var state: Dictionary = Helpers.use_small_map(Helpers.start(rules, run_seed), ["side_quest"])
	state["dudes"][0]["hp"] = hp
	state["dudes"][0]["dolla_bills"] = dolla_bills
	# result: the vote.
	var result: Dictionary = Core.apply(rules, state, Helpers.vote("p1", 0, "r1c0"))
	assert_eq(result["reject"], "")
	assert_eq(Helpers.contract_problems(result), [] as Array[String])
	return {"rules": rules, "state": result["state"]}


## Picks an option of the open Side Quest and returns apply()'s result (checked).
## setup: _facing()'s result. choice: 0 safe, 1 dumb.
func _pick(setup: Dictionary, choice: int) -> Dictionary:
	# state: the state facing the Side Quest.
	var state: Dictionary = setup["state"]
	# result: the choice.
	var result: Dictionary = Core.apply(setup["rules"], state, Helpers.choose("p1", 1, state["dudes"][0]["offers"][0]["id"], choice))
	assert_eq(result["reject"], "")
	assert_eq(Helpers.contract_problems(result), [] as Array[String])
	return result


## The five fixtures pass the format and the operation check, exactly two options each, the GDD's
## safe labels; the ruleset refuses a bad operation, a bad chance and an unknown card.
func test_format() -> void:
	# labels: the GDD's safe option names.
	var labels: Dictionary = {"beer_pong_table": "Walk away", "gas_station_sushi": "Skip it", "three_am_tattoo": "Go to bed",
		"free_couch_on_the_curb": "Leave it", "unlabeled_brownie": "Politely decline"}
	assert_eq(RunFixtures.SIDE_QUESTS.size(), 5)
	for id: String in RunFixtures.SIDE_QUESTS:
		# quest: one Side Quest.
		var quest: Dictionary = RunFixtures.SIDE_QUESTS[id]
		assert_no_errors(SideQuestDef.check(quest, id))
		for field: String in SideQuestDef.OPTION_FIELDS:
			assert_no_errors(SideQuestOps.check_all(quest[field]["effects"]), "%s.%s" % [id, field])
		assert_eq(quest["safe"]["label"], labels[id])
	assert_false(RunFixtures.ruleset().is_empty(), "the five build")
	# bad: definitions the ruleset must refuse, with what the error says.
	var bad: Array = [
		[{"op": "summon_kegs"}, "unknown Side Quest operation"],
		[{"op": "chance", "percent": 100, "then": []}, "percent"],
		[{"op": "heal"}, "missing"],
		[{"op": "next_fight_status", "status": "ick", "stacks": 1}, "status"],
		[{"op": "add_card", "card_id": "junk_nope"}, "junk_nope"],
		[{"op": "chance", "percent": 50, "then": [{"op": "add_card", "card_id": "junk_nope"}]}, "junk_nope"],
	]
	for entry: Array in bad:
		# quest: a Side Quest whose dumb option has the bad operation.
		var quest: Dictionary = RunFixtures.SIDE_QUESTS["beer_pong_table"].duplicate(true)
		quest["dumb"]["effects"] = [entry[0]]
		# built: build() with it.
		var built: Dictionary = Ruleset.build(RunFixtures.files({}, {}, {"data/side_quests/beer_pong_table.json": quest}))
		assert_false(built["ok"], str(entry[0]))
		assert_true(built["errors"].any(func(e: String) -> bool: return e.begins_with("data/side_quests/beer_pong_table.json") and e.contains(entry[1])),
			"%s: %s" % [str(entry[0]), str(built["errors"])])
	assert_false(SideQuestDef.check({"id": "x", "name": "X", "text": "", "safe": {"label": "a", "text": "", "effects": []}}).is_empty(), "needs both options")


## Entering: one Side Quest offer per Dude, safe and dumb, no skip; the safe option changes nothing
## and does not count as dumb.
func test_safe_option() -> void:
	# setup: facing the couch.
	var setup: Dictionary = _facing("free_couch_on_the_curb", SEED, 30)
	# offer: Tom's offer.
	var offer: Dictionary = setup["state"]["dudes"][0]["offers"][0]
	assert_eq(offer["kind"], "side_quest")
	assert_eq(offer["def_id"], "free_couch_on_the_curb")
	assert_false(offer["skippable"])
	assert_eq(offer["options"], [{"kind": "safe", "available": true}, {"kind": "dumb", "available": true}])
	assert_eq(Core.apply(setup["rules"], setup["state"], Helpers.choose("p1", 1, offer["id"], -1))["reject"], "bad_target")
	# result: walking away.
	var result: Dictionary = _pick(setup, 0)
	assert_eq(result["state"]["dumb_options_taken"], 0)
	assert_eq(result["state"]["dudes"][0]["hp"], 30)
	assert_eq(result["state"]["run_phase"], "map")


## Free Couch on the Curb: full heal, and 30% Bedbugs; dumb_options_taken counts. Over many seeds both
## outcomes happen, at about 30%.
func test_free_couch() -> void:
	# bugs: runs that got Bedbugs.
	var bugs: int = 0
	# tries: seeds tried.
	var tries: int = 200
	for run_seed: int in tries:
		# result: taking the couch.
		var result: Dictionary = _pick(_facing("free_couch_on_the_curb", run_seed, 30), 1)
		assert_eq(result["state"]["dudes"][0]["hp"], 80, "full heal")
		assert_eq(result["state"]["dumb_options_taken"], 1)
		assert_eq(Helpers.of_type(result["events"], "side_quest_rolled")[0]["percent"], 30)
		if Helpers.deck_ids(result["state"]).has("junk_bedbugs"):
			bugs += 1
	assert_true(bugs > tries * 18 / 100 and bugs < tries * 42 / 100, "Bedbugs %d of %d" % [bugs, tries])


## The Beer Pong Table: 50% double the 50, 50% lose them and gain a Hangover; G23: not offered below
## 50 Dolla Bills.
func test_beer_pong_table() -> void:
	# poor: facing it with 49 Dolla Bills.
	var poor: Dictionary = _facing("beer_pong_table", SEED, 80, 49)
	assert_eq(poor["state"]["dudes"][0]["offers"][0]["options"][1], {"kind": "dumb", "available": false})
	assert_eq(Core.apply(poor["rules"], poor["state"], Helpers.choose("p1", 1, poor["state"]["dudes"][0]["offers"][0]["id"], 1))["reject"], "bad_target")
	# outcomes: Dolla Bills after the bet -> how often.
	var outcomes: Dictionary = {}
	for run_seed: int in 100:
		# result: betting 50 of 50.
		var result: Dictionary = _pick(_facing("beer_pong_table", run_seed, 80, 50), 1)
		# money: Dolla Bills after.
		var money: int = result["state"]["dudes"][0]["dolla_bills"]
		outcomes[money] = outcomes.get(money, 0) + 1
		assert_eq(Helpers.deck_ids(result["state"]).has("junk_hangover"), money == 0, "a Hangover exactly when the bet is lost")
	assert_eq(outcomes.keys().size(), 2, "both outcomes: %s" % str(outcomes))
	assert_true(outcomes.get(100, 0) > 30 and outcomes.get(0, 0) > 30, str(outcomes))


## Gas-Station Sushi: heal 25 now, and 35% Hungover 3 at the start of the next fight (G25), applied
## before turn 1 and worn off one stack per turn (G1).
func test_gas_station_sushi() -> void:
	# sick: a seed whose roll hits, found by trying.
	var sick: Dictionary = {}
	for run_seed: int in 50:
		# result: eating the sushi.
		var result: Dictionary = _pick(_facing("gas_station_sushi", run_seed, 40), 1)
		assert_eq(result["state"]["dudes"][0]["hp"], 65, "heal 25")
		if not result["state"]["dudes"][0]["pending_statuses"].is_empty():
			sick = result
			break
	assert_false(sick.is_empty(), "the 35% hits within 50 seeds")
	assert_eq(sick["state"]["dudes"][0]["pending_statuses"], {"hungover": 3})
	assert_eq(Helpers.of_type(sick["events"], "pending_status_added"),
		[{"type": "pending_status_added", "player_id": "p1", "status": "hungover", "stacks": 3}])
	# fight: the next fight (test setup: started directly).
	var fight: Dictionary = Fight.start_fight(RunFixtures.ruleset(), sick["state"], ["goblin_bouncer"])
	assert_eq(fight["error"], "")
	assert_eq(fight["state"]["dudes"][0]["statuses"], {"hungover": 3})
	assert_eq(fight["state"]["dudes"][0]["pending_statuses"], {}, "used up")
	assert_eq(Helpers.of_type(fight["events"], "status_changed")[0],
		{"type": "status_changed", "target_id": "p1", "status": "hungover", "delta": 3, "stacks": 3})


## The Unlabeled Brownie: upgrade 2 random cards (only Arm Bar can be: gap G54, as many as can be) and
## 2 Foggy at the next fight, which costs turn 1 a card per stack (task 009).
func test_unlabeled_brownie() -> void:
	# result: eating it.
	var result: Dictionary = _pick(_facing("unlabeled_brownie"), 1)
	# tom: Tom after.
	var tom: Dictionary = result["state"]["dudes"][0]
	assert_true(tom["cards"]["c9"]["upgraded"], "Arm Bar upgraded")
	assert_eq(Helpers.of_type(result["events"], "card_upgraded").size(), 1, "only one card can be upgraded")
	assert_eq(tom["pending_statuses"], {"foggy": 2})
	# fight: the next fight.
	var fight: Dictionary = Fight.start_fight(RunFixtures.ruleset(), result["state"], ["goblin_bouncer"])
	assert_eq(fight["state"]["dudes"][0]["hand"].size(), 3, "2 Foggy: 1 fewer card per stack (task 009)")
	# two: a deck with two Arm Bars (test setup) upgrades both.
	var setup: Dictionary = _facing("unlabeled_brownie")
	setup["state"]["dudes"][0]["cards"]["c99"] = {"def_id": "tom_arm_bar", "upgraded": false}
	setup["state"]["dudes"][0]["deck"].append("c99")
	# both: eating it with two Arm Bars.
	var both: Dictionary = _pick(setup, 1)
	assert_true(both["state"]["dudes"][0]["cards"]["c9"]["upgraded"] and both["state"]["dudes"][0]["cards"]["c99"]["upgraded"])


## 3 a.m. Tattoo: a random Gear from the Loot pool on the side_quest stream (G24) and a Regret.
func test_three_am_tattoo() -> void:
	# setup: facing the tattoo parlor.
	var setup: Dictionary = _facing("three_am_tattoo")
	# pool: Tom's Loot pool before.
	var pool: Array = Pools.loot_gear(setup["rules"], setup["state"]["dudes"][0])
	# result: getting the tattoo.
	var result: Dictionary = _pick(setup, 1)
	# tom: Tom after.
	var tom: Dictionary = result["state"]["dudes"][0]
	assert_eq(tom["gear"].size(), 2)
	assert_true(pool.has(tom["gear"][1]), "from the Loot pool")
	assert_eq(Helpers.deck_ids(result["state"]).back(), "junk_regret")
	assert_ne(result["state"]["rng"]["side_quest"], setup["state"]["rng"]["side_quest"], "drawn on the side_quest stream")
	assert_eq(result["state"]["rng"]["rewards:p1"], setup["state"]["rng"]["rewards:p1"], "not on the rewards stream")
	assert_eq(result["state"]["dumb_options_taken"], 1)


## Which Side Quest a node holds is drawn on the side_quest stream from every Side Quest.
func test_side_quest_draw() -> void:
	# rules: all five.
	var rules: Dictionary = RunFixtures.ruleset()
	# seen: Side Quest ids drawn.
	var seen: Dictionary = {}
	for run_seed: int in 100:
		# state: a run on a one-Side-Quest map.
		var state: Dictionary = Helpers.use_small_map(Helpers.start(rules, run_seed), ["side_quest"])
		# after: the vote's state.
		var after: Dictionary = Core.apply(rules, state, Helpers.vote("p1", 0, "r1c0"))["state"]
		seen[after["dudes"][0]["offers"][0]["def_id"]] = true
		assert_ne(after["rng"]["side_quest"], state["rng"]["side_quest"])
	assert_eq(seen.size(), 5, "every Side Quest shows up")
	assert_eq(SideQuests.ids(rules).size(), 5)
