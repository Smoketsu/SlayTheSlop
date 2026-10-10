## Tests for Gear (core/combat/gear_triggers.gd, task 021): one per slice Gear whose ops exist, the trigger
## points, the card filter, and the never-half-run rule. Lane: core (Agent A).
##
## Uses tests/core/items/item_fixtures.gd (the GDD's Gear written as task 014 must write them) until
## task 014's real data merges. Backwards Cap and Beer Helmet's Hangover wait on tasks 013 and 015;
## their tests are listed in the task 021 log, not here.
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")
const GearDef := preload("res://core/schema/gear_def.gd")
const BrewDef := preload("res://core/schema/brew_def.gd")
const Party := preload("res://core/combat/party.gd")
const Fight := preload("res://core/combat/fight.gd")
const Event := preload("res://core/schema/event.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const ItemFixtures := preload("res://tests/core/items/item_fixtures.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 21021


## Returns a solo fight against one Dummy (20 HP, 2 arms, hits for 5) with p1 holding gear_ids.
## rules: the item ruleset. gear_ids: Gear for p1, after test_dude's starting Gear.
func _fight(rules: Dictionary, gear_ids: Array) -> Dictionary:
	return ItemFixtures.fight(rules, SEED, gear_ids, [], ["test_dummy"])["state"]


## Applies a request that must be applied, checks every event and the new state, and returns the result.
## rules: the ruleset. state: the state. request: the request.
func _apply(rules: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], "", "request %s should apply" % var_to_str(request))
	for event: Variant in result["events"]:
		assert_no_errors(Event.check(event), "event %s" % var_to_str(event))
	if result["reject"] == "":
		assert_no_errors(RunState.check(result["state"]), "state after %s" % request["type"])
	return result


## Wins the fight with one Jab on an enemy left at 1 HP. Returns the applied result.
## rules: the ruleset. state: a fight in the player phase with one enemy; changed (test setup).
## seq: the request's seq.
func _win(rules: Dictionary, state: Dictionary, seq: int) -> Dictionary:
	state["combat"]["enemies"][0]["hp"] = 1
	# jab: a Jab put in hand to land the last hit.
	var jab: String = Fixtures.give(state, 0, "neutral_test_jab")
	return _apply(rules, state, Fixtures.play("p1", seq, jab, state["combat"]["enemies"][0]["uid"]))


## Returns the index of the first event of this type in events, or -1.
## events: an event list. type: the type wanted.
func _index_of(events: Array, type: String) -> int:
	for i: int in events.size():
		if events[i]["type"] == type:
			return i
	return -1


## The item fixtures build, and every slice Gear and Brew passes its schema; every Gear whose ops
## exist also passes GearTriggers.check (its ops and fields).
func test_fixtures_are_valid() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	assert_false(rules.is_empty(), "item ruleset builds")
	assert_eq(ItemFixtures.GEAR.size(), 13, "10 G16 Gear plus 3 Boss Gear")
	assert_eq(ItemFixtures.BREWS.size(), 8, "the GDD's 8 Brews")
	for id: String in ItemFixtures.GEAR:
		assert_no_errors(GearDef.check(ItemFixtures.GEAR[id], id), id)
		if not ItemFixtures.PENDING.has(id) and id != "beer_helmet":
			assert_no_errors(GearTriggers.check(ItemFixtures.GEAR[id], id), id + " ops")
	for id: String in ItemFixtures.BREWS:
		assert_no_errors(BrewDef.check(ItemFixtures.BREWS[id], id), id)
	# broken: GearTriggers.check finds the op the core lacks.
	var broken: Array[String] = GearTriggers.check(ItemFixtures.TEST_GEAR["test_broken_trigger"], "broken")
	assert_eq(broken.size(), 1, str(broken))
	assert_true(broken[0].begins_with("broken.triggers[0].effects[1].op"), broken[0])


## Unused Gym Membership: "Heal 6 HP after every fight", right after the fight is won.
func test_unused_gym_membership() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight with Tom's starting Gear, p1 at 20 of 30 HP.
	var state: Dictionary = _fight(rules, ["tom_unused_gym_membership"])
	state["dudes"][0]["hp"] = 20
	# result: the winning play.
	var result: Dictionary = _win(rules, state, 0)
	assert_eq(result["state"]["dudes"][0]["hp"], 26, "20 + 6")
	# events: the winning play's events.
	var events: Array = result["events"]
	# ended: where fight_ended is.
	var ended: int = _index_of(events, "fight_ended")
	assert_true(ended != -1, "the fight ended")
	assert_eq(events.slice(ended + 1), [
		Event.make("gear_triggered", {"player_id": "p1", "gear_id": "tom_unused_gym_membership", "when": "fight_end"}),
		Event.make("healed", {"target_id": "p1", "amount": 6, "hp": 26}),
	], "heal right after the fight ends")
	# capped: the same at 28 HP heals only to max HP.
	var capped: Dictionary = _fight(rules, ["tom_unused_gym_membership"])
	capped["dudes"][0]["hp"] = 28
	assert_eq(_win(rules, capped, 0)["state"]["dudes"][0]["hp"], 30, "never above max HP")


## A lost fight fires no fight_end Gear (the run ends).
func test_no_fight_end_gear_after_a_loss() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight against a Brute that hits for 50; p1 has 30 HP.
	var state: Dictionary = ItemFixtures.fight(rules, SEED, ["tom_unused_gym_membership"], [], ["test_brute"])["state"]
	# result: ending the turn, so the Brute knocks p1 out.
	var result: Dictionary = _apply(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq(result["state"]["combat"]["result"], "lost")
	assert_eq(ItemFixtures.of_type(result["events"], "gear_triggered"), [], "no Gear fires after a loss")
	assert_eq(result["state"]["dudes"][0]["hp"], 0)


## Arm Wrestling Table: "Every enemy starts the fight with 1 Broken Arm", before turn 1; a 0-arm
## enemy is immune; the Dummy's 5-damage swing becomes 4 (1 - 0.4 x 1/2).
func test_arm_wrestling_table() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# started: a fight against a Dummy (2 arms) and a Turtle (0 arms).
	var started: Dictionary = ItemFixtures.fight(rules, SEED, ["tom_arm_wrestling_table"], [], ["test_dummy", "test_turtle"])
	# state: the fight in turn 1.
	var state: Dictionary = started["state"]
	assert_eq(state["combat"]["enemies"][0]["broken_arms"], 1, "Dummy")
	assert_eq(state["combat"]["enemies"][1]["broken_arms"], 0, "Turtle has no arms")
	# events: the fight start's events.
	var events: Array = started["events"]
	# fired: where the Gear fired.
	var fired: int = events.find(Event.make("gear_triggered", {"player_id": "p1", "gear_id": "tom_arm_wrestling_table",
		"when": "fight_start"}))
	assert_true(fired > _index_of(events, "fight_started") and fired < _index_of(events, "turn_started"),
		"fires after fight_started and before turn 1")
	assert_eq(events[fired + 1], Event.make("status_changed", {"target_id": "e11", "status": "broken_arm",
		"delta": 1, "stacks": 1}))
	# after: the state after ending turn 1; the Dummy swings at p1.
	var after: Dictionary = _apply(rules, state, Fixtures.set_ready("p1", 0))["state"]
	assert_eq(after["dudes"][0]["hp"], 26, "5 x 0.8 = 4 damage")


## Whole Can of Body Spray: "When Tom applies Ick, the target takes 2 damage per stack applied".
## Stacks applied include Clout (G5); the damage is not attack damage (Exposed does not raise it);
## it lands even when the Ick Grosses the enemy Out; without the Gear nothing happens.
func test_whole_can_of_body_spray() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a Dummy fight; p1 has 1 Clout and the Dummy is Exposed.
	var state: Dictionary = _fight(rules, ["tom_whole_can_of_body_spray"])
	state["dudes"][0]["clout"] = 1
	state["combat"]["enemies"][0]["statuses"] = {"exposed": 1}
	# well: Well, Actually (apply 2 Ick, cost 0).
	var well: String = Fixtures.give(state, 0, "neutral_test_well_actually")
	# result: playing it on the Dummy.
	var result: Dictionary = _apply(rules, state, Fixtures.play("p1", 0, well, "e11"))
	assert_eq(result["state"]["combat"]["enemies"][0]["ick"], 3, "2 + 1 Clout")
	assert_eq(result["state"]["combat"]["enemies"][0]["hp"], 14, "2 x 3 stacks = 6, not raised by Exposed")
	# events: the play's events.
	var events: Array = result["events"]
	# ick: where the Ick was applied.
	var ick: int = events.find(Event.make("status_changed", {"target_id": "e11", "status": "ick", "delta": 3, "stacks": 3}))
	assert_true(ick != -1, "Ick applied")
	assert_eq(events.slice(ick + 1, ick + 3), [
		Event.make("gear_triggered", {"player_id": "p1", "gear_id": "tom_whole_can_of_body_spray", "when": "ick_applied"}),
		Event.make("damage_dealt", {"source_id": "p1", "target_id": "e11", "amount": 6, "blocked": 0, "hp_lost": 6}),
	])
	# plain: the same play without the Gear.
	var plain: Dictionary = _fight(rules, [])
	# plain_well: Well, Actually in that fight.
	var plain_well: String = Fixtures.give(plain, 0, "neutral_test_well_actually")
	assert_eq(_apply(rules, plain, Fixtures.play("p1", 0, plain_well, "e11"))["state"]["combat"]["enemies"][0]["hp"], 20)


## Body Spray with an all-enemies Ick card: each enemy takes its own damage, including one that is
## Grossed Out by the Ick (threshold 5 reached by 4 + 1 Clout).
func test_body_spray_on_every_enemy() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight against a Dummy and a Turtle, p1 with 1 Clout.
	var state: Dictionary = ItemFixtures.fight(rules, SEED, ["tom_whole_can_of_body_spray"], [],
		["test_dummy", "test_turtle"])["state"]
	state["dudes"][0]["clout"] = 1
	# pickup: apply 4 Ick to all enemies.
	var pickup: String = Fixtures.give(state, 0, "neutral_test_pickup")
	# result: playing it.
	var result: Dictionary = _apply(rules, state, Fixtures.play("p1", 0, pickup, ""))
	# enemies: both enemies after the play.
	var enemies: Array = result["state"]["combat"]["enemies"]
	assert_eq([enemies[0]["hp"], enemies[1]["hp"]], [10, 4], "Dummy 20 - 10, Turtle 14 - 10")
	assert_eq(ItemFixtures.of_type(result["events"], "grossed_out").size(), 2, "both Grossed Out")
	assert_eq(ItemFixtures.of_type(result["events"], "gear_triggered").size(), 2, "one trigger per enemy")


## Lifting Belt: "+1 Swole" while owned: gaining it emits gear_gained and stat_changed, and a Jab
## deals 6 + 1.
func test_lifting_belt() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# dude: a fresh Dude, given the Gear directly.
	var dude: Dictionary = Party.build_run_state(rules, SEED, ["test_dude"])["state"]["dudes"][0]
	# events: what gaining it emitted.
	var events: Array = []
	GearTriggers.gain_in_place(rules, dude, "lifting_belt", events)
	assert_eq(dude["gear"], ["test_gear", "lifting_belt"])
	assert_eq(events, [Event.make("gear_gained", {"player_id": "p1", "gear_id": "lifting_belt"}),
		Event.make("stat_changed", {"target_id": "p1", "stat": "swole", "delta": 1, "value": 1})])
	# state: a fight with the belt.
	var state: Dictionary = _fight(rules, ["lifting_belt"])
	# jab: a Jab in hand.
	var jab: String = Fixtures.give(state, 0, "neutral_test_jab")
	assert_eq(_apply(rules, state, Fixtures.play("p1", 0, jab, "e11"))["state"]["combat"]["enemies"][0]["hp"], 13)


## Lucky Lighter: "+1 Chill": a 5-Guard card gives 6.
func test_lucky_lighter() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight with the lighter.
	var state: Dictionary = _fight(rules, ["lucky_lighter"])
	assert_eq(state["dudes"][0]["chill"], 1)
	# brace: gain 5 Guard.
	var brace: String = Fixtures.give(state, 0, "neutral_test_brace")
	assert_eq(_apply(rules, state, Fixtures.play("p1", 0, brace, ""))["state"]["dudes"][0]["guard"], 6)


## Gallon Jug: "+8 Max HP" raises max_hp; HP itself is unchanged (the GDD does not say it heals;
## task 021 log).
func test_gallon_jug() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight with the jug; test_dude has 30 max HP.
	var state: Dictionary = _fight(rules, ["gallon_jug"])
	assert_eq([state["dudes"][0]["hp"], state["dudes"][0]["max_hp"]], [30, 38])


## Participation Trophy: "If you end a fight below 50% HP, heal 8". 14 of 30 is below; 15 is not.
## Gear fires in the order gained, so Tom's starting Gear heals first: 8 + 6 = 14, then 14 + 8.
func test_participation_trophy() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# cases: [Gear, HP before the win, HP after].
	var cases: Array = [
		[["participation_trophy"], 14, 22],
		[["participation_trophy"], 15, 15],
		[["tom_unused_gym_membership", "participation_trophy"], 8, 22],
		[["tom_unused_gym_membership", "participation_trophy"], 10, 16],
	]
	for entry: Array in cases:
		# state: a fight with the case's Gear and HP.
		var state: Dictionary = _fight(rules, entry[0])
		state["dudes"][0]["hp"] = entry[1]
		assert_eq(_win(rules, state, 0)["state"]["dudes"][0]["hp"], entry[2], "%s from %d" % [str(entry[0]), entry[1]])


## Championship Ring: "Attacks that cost 2 or more Hype deal 4 more damage", per hit, before the
## damage order. A 2-cost 4x2 Attack deals 8 + 8; a 1-cost Attack and a 2-cost Skill are unchanged.
func test_championship_ring() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# cases: [card, Dummy HP after it].
	var cases: Array = [["neutral_test_double", 4], ["neutral_test_jab", 14], ["neutral_test_heavy_skill", 14]]
	for entry: Array in cases:
		# state: a fight with the ring and Hype to spare.
		var state: Dictionary = _fight(rules, ["championship_ring"])
		state["dudes"][0]["hype"] = 5
		# card: the card under test.
		var card: String = Fixtures.give(state, 0, entry[0])
		assert_eq(_apply(rules, state, Fixtures.play("p1", 0, card, "e11"))["state"]["combat"]["enemies"][0]["hp"],
			entry[1], entry[0])
	# effects: the raised effects do not change the read-only card definition.
	var effects: Array = GearTriggers.card_effects(rules, _fight(rules, ["championship_ring"])["dudes"][0],
		rules["cards"]["neutral_test_double"])
	assert_eq(effects[0]["amount"], 8, "raised copy")
	assert_eq(rules["cards"]["neutral_test_double"]["effects"][0]["amount"], 4, "definition unchanged")


## Medical Card: "Prices at Baileys are 20% lower", every price including card removal (G26),
## rounded down. Without it, prices are unchanged.
func test_medical_card() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# dude: a Dude holding the card.
	var dude: Dictionary = Party.build_run_state(rules, SEED, ["test_dude"])["state"]["dudes"][0]
	# plain: the same Dude without it.
	var plain: Dictionary = dude.duplicate(true)
	GearTriggers.gain_in_place(rules, dude, "medical_card", [])
	# prices: normal price -> with the card (cards 50/75/150, Gear 225, Shake 65, removal 75/100, an odd 77).
	var prices: Dictionary = {50: 40, 75: 60, 150: 120, 225: 180, 65: 52, 100: 80, 77: 61, 0: 0}
	for price: int in prices:
		assert_eq(GearTriggers.shop_price(rules, dude, price), prices[price], "price %d" % price)
		assert_eq(GearTriggers.shop_price(rules, plain, price), price, "no card, price %d" % price)


## Beer Helmet: "+1 Hype per turn": turn 1 starts with 4 Hype. (Its Hangover waits on task 015.)
func test_beer_helmet_hype() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight with the helmet.
	var state: Dictionary = _fight(rules, ["beer_helmet"])
	assert_eq(state["dudes"][0]["hype_per_turn"], rules["constants"]["BASE_HYPE"] + 1)
	assert_eq(state["dudes"][0]["hype"], rules["constants"]["BASE_HYPE"] + 1)


## Dad's Platinum Card: "+1 Hype per turn. You no longer earn Dolla Bills from fights".
func test_dads_platinum_card() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight with the card.
	var state: Dictionary = _fight(rules, ["dads_platinum_card"])
	assert_eq(state["dudes"][0]["hype"], rules["constants"]["BASE_HYPE"] + 1)
	assert_eq(GearTriggers.fight_dolla_bills(rules, state["dudes"][0], 15), 0, "no Dolla Bills from fights")
	assert_eq(GearTriggers.fight_dolla_bills(rules, _fight(rules, [])["dudes"][0], 15), 15, "normal without it")


## Cursed Intramural Trophy: "+1 Draw per turn. Every enemy starts each fight with 1 Swole": turn 1
## draws 6, the Dummy has 1 Swole and swings for 6.
func test_cursed_intramural_trophy() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# started: a fight with the trophy.
	var started: Dictionary = ItemFixtures.fight(rules, SEED, ["cursed_intramural_trophy"], [], ["test_dummy"])
	# state: the fight in turn 1.
	var state: Dictionary = started["state"]
	assert_eq(state["dudes"][0]["hand"].size(), rules["constants"]["BASE_DRAW"] + 1)
	assert_eq(state["combat"]["enemies"][0]["swole"], 1)
	assert_true(started["events"].has(Event.make("stat_changed", {"target_id": "e11", "stat": "swole", "delta": 1,
		"value": 1})), "enemy Swole event")
	assert_eq(_apply(rules, state, Fixtures.set_ready("p1", 0))["state"]["dudes"][0]["hp"], 24, "5 + 1 Swole")


## card_played triggers fire after the card has gone to its pile, only for matching cards
## (test Gear: Attacks costing 2 or more apply 1 Exposed to their target).
func test_card_played_trigger_by_kind() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# cases: [card, Exposed stacks on the Dummy after it].
	var cases: Array = [["neutral_test_double", 1], ["neutral_test_jab", 0], ["neutral_test_heavy_skill", 0]]
	for entry: Array in cases:
		# state: a fight with the test Gear and Hype to spare.
		var state: Dictionary = _fight(rules, ["test_card_counter"])
		state["dudes"][0]["hype"] = 5
		# card: the card under test.
		var card: String = Fixtures.give(state, 0, entry[0])
		# result: playing it on the Dummy.
		var result: Dictionary = _apply(rules, state, Fixtures.play("p1", 0, card, "e11"))
		assert_eq(result["state"]["combat"]["enemies"][0]["statuses"].get("exposed", 0), entry[1], entry[0])
		if entry[1] > 0:
			# moved: where the card went to its pile.
			var moved: int = _index_of(result["events"], "card_moved")
			assert_eq(result["events"][moved + 1]["type"], "gear_triggered", "after the card is in its pile")


## A trigger with an op the core lacks is skipped whole: its heal does not happen either, and no
## gear_triggered is emitted.
func test_broken_trigger_is_skipped_whole() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a run whose Dude is hurt before the fight starts.
	var state: Dictionary = Party.build_run_state(rules, SEED, ["test_dude"])["state"]
	state["dudes"][0]["hp"] = 20
	GearTriggers.gain_in_place(rules, state["dudes"][0], "test_broken_trigger", [])
	# started: the fight.
	var started: Dictionary = Fight.start_fight(rules, state, ["test_dummy"])
	assert_eq(started["error"], "")
	assert_eq(started["state"]["dudes"][0]["hp"], 20, "no half-run heal")
	assert_eq(ItemFixtures.of_type(started["events"], "gear_triggered"), [])


## Gaining a Gear the ruleset does not have adds its id and does nothing else.
func test_unknown_gear_is_inert() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# dude: a fresh Dude.
	var dude: Dictionary = Party.build_run_state(rules, SEED, ["test_dude"])["state"]["dudes"][0]
	# before: the Dude before.
	var before: Dictionary = dude.duplicate(true)
	# events: what gaining it emitted.
	var events: Array = []
	GearTriggers.gain_in_place(rules, dude, "no_such_gear", events)
	before["gear"].append("no_such_gear")
	assert_eq(dude, before)
	assert_eq(events, [Event.make("gear_gained", {"player_id": "p1", "gear_id": "no_such_gear"})])


## Starting Gear goes through GearTriggers.gain_in_place, so a Dude whose starting Gear has stats starts
## with them.
func test_starting_gear_stats_apply() -> void:
	# files: the item ruleset's files, with a Dude starting with the Lifting Belt.
	var rules: Dictionary = ItemFixtures.ruleset()
	# dudes: test_dude with a different starting Gear.
	var dudes: Dictionary = rules["dudes"].duplicate(true)
	dudes["test_dude"]["starting_gear"] = ["lifting_belt"]
	# changed: the ruleset with that Dude (built by hand from the read-only one).
	var changed: Dictionary = rules.duplicate()
	changed["dudes"] = dudes
	# dude: the built Dude.
	var dude: Dictionary = Party.build_run_state(changed, SEED, ["test_dude"])["state"]["dudes"][0]
	assert_eq([dude["gear"], dude["swole"]], [["lifting_belt"], 1])
