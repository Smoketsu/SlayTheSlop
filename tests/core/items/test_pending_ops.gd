## Tests for the Gear and Brews that use ops from tasks 013 and 015 (draw, gain_hype, add_card):
## Backwards Cap, Energy Drink, Special Brownie and Beer Helmet's Hangover (task 021). Lane: core
## (Agent A).
##
## These pass only once tasks 013 and 015 are merged: before that the ops do not exist, so the
## Brews are unplayable and the Gear triggers are skipped. Committed separately for that reason.
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Event := preload("res://core/schema/event.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const ItemFixtures := preload("res://tests/core/items/item_fixtures.gd")
const Fight := preload("res://core/combat/fight.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 21023


## Every slice Gear now passes GearTriggers.check: all their ops exist.
func test_every_slice_gear_can_fire() -> void:
	for id: String in ItemFixtures.GEAR:
		assert_no_errors(GearTriggers.check(ItemFixtures.GEAR[id], id), id)


## Backwards Cap: "Draw 2 extra cards on the first turn of each fight": turn 1's hand is BASE_DRAW + 2,
## drawn after the Refresh.
func test_backwards_cap() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# started: a fight with the cap.
	var started: Dictionary = ItemFixtures.fight(rules, SEED, ["backwards_cap"], [], ["test_dummy"])
	assert_eq(started["state"]["dudes"][0]["hand"].size(), rules["constants"]["BASE_DRAW"] + 2)
	assert_true(started["events"].has(Event.make("gear_triggered", {"player_id": "p1", "gear_id": "backwards_cap",
		"when": "first_turn"})))


## Energy Drink: "Draw 3 cards".
func test_energy_drink() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight with the drink.
	var state: Dictionary = ItemFixtures.fight(rules, SEED, [], ["energy_drink"], ["test_dummy"])["state"]
	# before: the hand size before drinking.
	var before: int = state["dudes"][0]["hand"].size()
	# result: drinking it.
	var result: Dictionary = Core.apply(rules, state, ItemFixtures.drink("p1", 0, 0))
	assert_eq(result["reject"], "")
	assert_eq(result["state"]["dudes"][0]["hand"].size(), before + 3)


## Special Brownie: "Gain 2 Hype. Add a Hangover card to your discard pile".
func test_special_brownie() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight with the brownie.
	var state: Dictionary = ItemFixtures.fight(rules, SEED, [], ["special_brownie"], ["test_dummy"])["state"]
	# result: eating it.
	var result: Dictionary = Core.apply(rules, state, ItemFixtures.drink("p1", 0, 0))
	assert_eq(result["reject"], "")
	# dude: p1 afterwards.
	var dude: Dictionary = result["state"]["dudes"][0]
	assert_eq(dude["hype"], state["dudes"][0]["hype"] + 2)
	assert_eq(dude["cards"][dude["discard_pile"].back()]["def_id"], "junk_hangover")


## Beer Helmet: "+1 Hype per turn. Start each fight with a Hangover card in your draw pile": a
## Hangover copy is created in the draw pile at the start of the fight.
func test_beer_helmet_hangover() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# started: a fight with the helmet.
	var started: Dictionary = ItemFixtures.fight(rules, SEED, ["beer_helmet"], [], ["test_dummy"])
	# created: the cards created at the start of the fight.
	var created: Array = ItemFixtures.of_type(started["events"], "card_created")
	assert_eq(created.size(), 1)
	assert_eq([created[0]["def_id"], created[0]["to"]], ["junk_hangover", "draw_pile"])
	assert_eq(started["state"]["dudes"][0]["hype_per_turn"], rules["constants"]["BASE_HYPE"] + 1)


## Beer Helmet as I7's accepted answer has it (TEST_GEAR test_fight_only_helmet, add_card with lasts
## "fight"; task 033), over two fights: each fight starts with one new Hangover, which is not in the
## run deck and leaves when the fight ends, so the run deck never grows.
func test_fight_only_hangover_lasts_one_fight() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# started: the first fight with the helmet.
	var started: Dictionary = ItemFixtures.fight(rules, SEED, ["test_fight_only_helmet"], [], ["test_dummy"])
	# state: the first fight, turn 1.
	var state: Dictionary = started["state"]
	# deck: the run deck at the first fight's start.
	var deck: Array = state["dudes"][0]["deck"].duplicate()
	# first: the first fight's Hangover.
	var first: String = ItemFixtures.of_type(started["events"], "card_created")[0]["card_uid"]
	assert_false(deck.has(first), "not in the run deck")
	state["combat"]["enemies"][0]["hp"] = 1
	# jab: the Jab that lands the last hit (test setup; it joins the run deck).
	var jab: String = Fixtures.give(state, 0, "neutral_test_jab")
	# won: the first fight won with the 1-HP enemy and the Jab.
	var won: Dictionary = Core.apply(rules, state, Fixtures.play("p1", 0, jab, state["combat"]["enemies"][0]["uid"]))
	assert_eq(won["state"]["combat"]["result"], "won")
	assert_true(won["events"].has(Event.make("card_removed", {"player_id": "p1", "card_uid": first,
		"from": _pile_of(state["dudes"][0], first)})), "the first Hangover leaves when the fight ends")
	assert_eq(won["state"]["dudes"][0]["deck"], deck + [jab], "no Hangover in the run deck")
	# next: the second fight.
	var next: Dictionary = Fight.start_fight(rules, won["state"], ["test_dummy"])
	assert_eq(next["error"], "")
	# second: the second fight's card_created events.
	var second: Array = ItemFixtures.of_type(next["events"], "card_created")
	assert_eq(second.size(), 1, "one new Hangover")
	assert_ne(second[0]["card_uid"], first)
	assert_eq(next["state"]["dudes"][0]["cards"].values().filter(
		func(card: Dictionary) -> bool: return card["def_id"] == "junk_hangover").size(), 1, "only this fight's Hangover")


## Returns the pile ("draw_pile", "hand", "discard_pile" or "tapped_pile") holding a card, or "deck".
## dude: a Dude's state. uid: a card_uid.
func _pile_of(dude: Dictionary, uid: String) -> String:
	for pile: String in ["draw_pile", "hand", "discard_pile", "tapped_pile"]:
		if dude[pile].has(uid):
			return pile
	return "deck"
