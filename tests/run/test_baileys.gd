## Tests for core/run/baileys.gd: stock, prices, buying, Shake, removal and leaving (task 025, G21,
## G26, GDD "Prices at Baileys"). Lane: run (Agent A).
extends "res://tests/framework/test_case.gd"

const RunFixtures := preload("res://tests/run/fixtures/run_fixtures.gd")
const Helpers := preload("res://tests/run/fixtures/run_helpers.gd")
const Core := preload("res://core/core.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")
const Pools := preload("res://core/run/pools.gd")
const Offers := preload("res://core/run/offers.gd")
const Baileys := preload("res://core/run/baileys.gd")

## Seed used by these tests.
const SEED: int = 3008


## Returns a solo run that has just entered Baileys, with Tom's Dolla Bills and extra Gear set first
## (test setup).
## rules: the ruleset. dolla_bills: Tom's Dolla Bills. gear_ids: Gear to give Tom first.
func _at_baileys(rules: Dictionary, dolla_bills: int, gear_ids: Array = []) -> Dictionary:
	# state: a run on a one-Baileys map.
	var state: Dictionary = Helpers.use_small_map(Helpers.start(rules, SEED), ["baileys"])
	state["dudes"][0]["dolla_bills"] = dolla_bills
	for gear_id: String in gear_ids:
		GearTriggers.gain_in_place(rules, state["dudes"][0], gear_id, [])
	# result: the vote's result.
	var result: Dictionary = Core.apply(rules, state, Helpers.vote("p1", 0, "r1c0"))
	assert_eq(result["reject"], "")
	assert_eq(Helpers.contract_problems(result), [] as Array[String])
	return result["state"]


## Returns the index of the first option of a kind in an offer, or -1.
## offer: the offer. kind: the option kind.
func _first(offer: Dictionary, kind: String) -> int:
	for i: int in offer["options"].size():
		if offer["options"][i]["kind"] == kind:
			return i
	return -1


## Stock (G21): SHOP_CARD_COUNT cards, SHOP_GEAR_COUNT Gear, SHOP_SHAKE_COUNT Shakes and a removal,
## priced by rarity; every Brew is sold as a "shake" option; the offer can be left (-1).
func test_stock_and_prices() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: at Baileys.
	var state: Dictionary = _at_baileys(rules, 500)
	# offer: Tom's Baileys offer.
	var offer: Dictionary = state["dudes"][0]["offers"][0]
	assert_eq(offer["kind"], "baileys")
	assert_true(offer["skippable"], "-1 leaves")
	# kinds: option kinds in order.
	var kinds: Array = offer["options"].map(func(o: Dictionary) -> String: return o["kind"])
	assert_eq(kinds, ["card", "card", "card", "card", "card", "gear", "gear", "shake", "shake", "remove"])
	# prices: kind -> rarity -> the G21 price.
	var prices: Dictionary = {"card": {"common": 50, "uncommon": 75, "rare": 150},
		"gear": {"common": 150, "uncommon": 225, "rare": 300}, "shake": {"common": 50, "uncommon": 65, "rare": 75}}
	for option: Dictionary in offer["options"]:
		match option["kind"]:
			"card":
				assert_eq(option["price"], prices["card"][rules["cards"][option["card_id"]]["rarity"]], option["card_id"])
			"gear":
				assert_eq(option["price"], prices["gear"][rules["gear"][option["gear_id"]]["rarity"]], option["gear_id"])
				assert_true(Pools.loot_gear(rules, state["dudes"][0]).has(option["gear_id"]), "Gear from the Loot pool")
			"shake":
				assert_eq(option["price"], prices["shake"][rules["brews"][option["brew_id"]]["rarity"]], option["brew_id"])
				assert_false(option.has("card_id") or option.has("gear_id"), "a Shake is a Brew")
			"remove":
				assert_eq(option["price"], 75)
				assert_eq(option["card_uids"], state["dudes"][0]["deck"])
	# left: leaving.
	var left: Dictionary = Core.apply(rules, state, Helpers.choose("p1", 1, offer["id"], -1))
	assert_eq(left["reject"], "")
	assert_eq(left["state"]["dudes"][0]["offers"], [])
	assert_eq(left["state"]["run_phase"], "map")


## Buying: pay the price (item_bought), get the item, the option becomes unavailable, Baileys stays
## open. A card goes into the run deck, Gear is gained, a Shake goes into a Brew slot.
func test_buying() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: at Baileys with plenty of Dolla Bills.
	var state: Dictionary = _at_baileys(rules, 2000)
	# offer: the offer.
	var offer: Dictionary = state["dudes"][0]["offers"][0]
	# seq: the next seq.
	var seq: int = 1
	for kind: String in ["card", "gear", "shake"]:
		# index: the option bought.
		var index: int = _first(state["dudes"][0]["offers"][0], kind)
		# option: it, before buying.
		var option: Dictionary = state["dudes"][0]["offers"][0]["options"][index]
		# before: Tom before buying.
		var before: Dictionary = state["dudes"][0]
		# result: the purchase.
		var result: Dictionary = Core.apply(rules, state, Helpers.choose("p1", seq, offer["id"], index))
		seq += 1
		assert_eq(result["reject"], "", kind)
		assert_eq(Helpers.contract_problems(result), [] as Array[String])
		state = result["state"]
		# tom: Tom after.
		var tom: Dictionary = state["dudes"][0]
		assert_eq(tom["dolla_bills"], before["dolla_bills"] - option["price"], kind + " paid")
		assert_eq(Helpers.of_type(result["events"], "item_bought")[0]["price"], option["price"])
		assert_false(tom["offers"][0]["options"][index]["available"], kind + " sold")
		assert_eq(Core.apply(rules, state, Helpers.choose("p1", seq, offer["id"], index))["reject"], "bad_target", "sold out")
		match kind:
			"card":
				assert_eq(Helpers.deck_ids(state).back(), option["card_id"])
			"gear":
				assert_eq(tom["gear"].back(), option["gear_id"])
			"shake":
				assert_eq(tom["brews"], [option["brew_id"]])
				assert_eq(Helpers.of_type(result["events"], "brew_gained")[0]["slot"], 0)
	assert_eq(state["run_phase"], "node", "Baileys stays open until -1")


## Refused as unplayable: an item that costs more than the Dude holds, a Shake with every slot full.
func test_cannot_afford_or_hold() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# poor: at Baileys with 10 Dolla Bills.
	var poor: Dictionary = _at_baileys(rules, 10)
	# offer: the offer.
	var offer: Dictionary = poor["dudes"][0]["offers"][0]
	for i: int in offer["options"].size():
		assert_eq(Core.apply(rules, poor, Helpers.choose("p1", 1, offer["id"], i, "c1" if offer["options"][i]["kind"] == "remove" else ""))["reject"],
			"unplayable", "option %d too expensive" % i)
	# full: at Baileys with money but no free Brew slot (test setup after entering).
	var full: Dictionary = _at_baileys(rules, 2000)
	full["dudes"][0]["brew_slots"] = 0
	assert_eq(Core.apply(rules, full, Helpers.choose("p1", 1, full["dudes"][0]["offers"][0]["id"], _first(offer, "shake")))["reject"], "unplayable")


## Removal: 75, then 100 (rising by 25), the named card leaves the deck; Regret cannot be removed.
func test_removal() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: at Baileys with a Regret in the deck (test setup before entering).
	var state: Dictionary = Helpers.use_small_map(Helpers.start(rules, SEED), ["baileys"])
	state["dudes"][0]["dolla_bills"] = 500
	state["dudes"][0]["cards"]["c99"] = {"def_id": "junk_regret", "upgraded": false}
	state["dudes"][0]["deck"].append("c99")
	state = Core.apply(rules, state, Helpers.vote("p1", 0, "r1c0"))["state"]
	# offer: the offer.
	var offer: Dictionary = state["dudes"][0]["offers"][0]
	# remove: the removal option's index.
	var remove: int = _first(offer, "remove")
	assert_false(offer["options"][remove]["card_uids"].has("c99"), "Regret is not removable")
	assert_eq(Core.apply(rules, state, Helpers.choose("p1", 1, offer["id"], remove, "c99"))["reject"], "bad_target")
	assert_eq(Core.apply(rules, state, Helpers.choose("p1", 1, offer["id"], remove))["reject"], "bad_target", "needs a card_uid")
	# first: remove a Punch for 75.
	var first: Dictionary = Core.apply(rules, state, Helpers.choose("p1", 1, offer["id"], remove, "c1"))
	assert_eq(first["reject"], "")
	assert_eq(Helpers.contract_problems(first), [] as Array[String])
	assert_eq(first["state"]["dudes"][0]["dolla_bills"], 425)
	assert_false(first["state"]["dudes"][0]["deck"].has("c1"))
	assert_false(first["state"]["dudes"][0]["cards"].has("c1"))
	assert_eq(Helpers.of_type(first["events"], "card_removed"), [{"type": "card_removed", "player_id": "p1", "card_uid": "c1", "from": "deck"}])
	assert_eq(first["state"]["dudes"][0]["cards_removed"], 1)
	assert_eq(first["state"]["dudes"][0]["offers"][0]["options"][remove]["price"], 100, "rising by 25")
	# second: remove another for 100.
	var second: Dictionary = Core.apply(rules, first["state"], Helpers.choose("p1", 2, offer["id"], remove, "c2"))
	assert_eq(second["reject"], "")
	assert_eq(second["state"]["dudes"][0]["dolla_bills"], 325)


## Medical Card (G26): every Baileys price, removal included, is 80%, rounded down; buying it at this
## Baileys lowers the other prices at once.
func test_medical_card() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: at Baileys with Medical Card.
	var state: Dictionary = _at_baileys(rules, 500, ["medical_card"])
	for option: Dictionary in state["dudes"][0]["offers"][0]["options"]:
		match option["kind"]:
			"card":
				assert_eq(option["price"], Pools.base_price(rules, "card", rules["cards"][option["card_id"]]["rarity"]) * 80 / 100)
			"shake":
				assert_eq(option["price"], Pools.base_price(rules, "shake", rules["brews"][option["brew_id"]]["rarity"]) * 80 / 100)
			"remove":
				assert_eq(option["price"], 60, "75 x 80%")
	assert_eq(Pools.removal_price(rules, {"gear": ["medical_card"], "cards_removed": 1}), 80, "100 x 80%")
	assert_eq(GearTriggers.shop_price(rules, {"gear": ["medical_card"]}, 65), 52, "an uncommon Shake")
	assert_eq(GearTriggers.shop_price(rules, {"gear": ["medical_card"]}, 33), 26, "26.4 rounds down")
	# shop: a run with a hand-made Baileys offer holding Medical Card and a common card (test setup).
	var shop: Dictionary = Helpers.start(rules, SEED)
	shop["dudes"][0]["dolla_bills"] = 1000
	# offer: that offer.
	var offer: Dictionary = Offers.open_in_place(shop, 0, "baileys", "", true, [
		Offers.option("gear", true, {"gear_id": "medical_card"}), Offers.option("card", true, {"card_id": "tom_wrist_lock"}),
		Offers.option("remove", true, {"card_uids": []})], [])
	Baileys.refresh(rules, shop["dudes"][0], offer)
	assert_eq(offer["options"][1]["price"], 50)
	Baileys.choose_in_place(rules, shop, 0, offer, 0, "", [])
	assert_eq(shop["dudes"][0]["dolla_bills"], 775, "Medical Card cost 225")
	assert_eq(offer["options"][1]["price"], 40, "the rest is cheaper at once")
	assert_eq(offer["options"][2]["price"], 60)
