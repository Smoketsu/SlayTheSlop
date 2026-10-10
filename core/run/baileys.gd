## Baileys, the shop: buy cards, Gear and Shake; pay to remove a card (task 025, GDD "Prices at
## Baileys"). Lane: run (Agent A).
##
## Baileys sells weed, not drinks: every Brew in stock is an option of kind "shake", which the client
## labels "Shake" (with the Brew's own name and effect, G29). Once bought it is a normal Brew in a
## Brew slot (GDD). Nothing here names a drink.
##
## Entering Baileys opens one "baileys" offer per Dude (Dolla Bills are per player, GDD "Rules that
## change in co-op"), with stock drawn on that Dude's rewards stream, in this order (G21):
##   SHOP_CARD_COUNT "card" options from their card pool, with the card offer's rarity odds (gap G56);
##   SHOP_GEAR_COUNT "gear" options from their Loot pool, each equally likely, all different;
##   SHOP_SHAKE_COUNT "shake" options from every Brew, each equally likely, all different;
##   one "remove" option: the cards Baileys may remove (not Regret), card_uids.
## Each option's price is what this Dude pays now (core/run/pools.gd): PRICE_ constants, removal
## CARD_REMOVE_BASE + CARD_REMOVE_STEP x removals so far, all after Medical Card (G26).
##
## choose_reward on the offer:
##   -1 leaves Baileys (the offer closes).
##   an item: refused (unplayable) when it costs more than the Dude holds, or for a Shake when every
##            Brew slot is full; else the Dude pays (item_bought), gets it, and the option becomes
##            unavailable. The offer stays open.
##   "remove": the named card_uid leaves the deck (card_removed); cards_removed rises by 1, so the next
##            removal costs CARD_REMOVE_STEP more. As written in the GDD, a Dude may remove again at
##            the same visit, at the new price (gap G60).
## After every purchase each option's price and the removal's cards are worked out again, so a Medical
## Card bought here lowers the prices of the rest at once.
##
## Functions ending in _in_place change the working copy they are given. Pure: randomness only through
## core/run/draws.gd.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Rng := preload("res://core/rng/rng.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")
const Draws := preload("res://core/run/draws.gd")
const Pools := preload("res://core/run/pools.gd")
const Grants := preload("res://core/run/grants.gd")
const Offers := preload("res://core/run/offers.gd")

## The offer kind (core/schema/dude_state.gd OFFER_KINDS).
const KIND: String = "baileys"

## The per-player stream Baileys stock is drawn on (GDD "Random streams": card, Gear and Brew offers).
const STREAM: String = "rewards"

## Option kinds Baileys sells (they cost Dolla Bills and become unavailable once bought).
const ITEM_KINDS: Array[String] = ["card", "gear", "shake"]

## Option kind of the card removal.
const REMOVE: String = "remove"


## Opens a Baileys offer for every Dude, in seat order, with stock from their own rewards stream.
## ruleset: the read-only content. state: the working copy. events: the event list, appended to.
static func enter_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	# constants: the tuning constants.
	var constants: Dictionary = ruleset["constants"]
	for i: int in state["dudes"].size():
		# dude: this Dude, inside state.
		var dude: Dictionary = state["dudes"][i]
		# key: the Dude's rewards stream.
		var key: String = Rng.key_for(STREAM, dude["player_id"])
		# options: the stock, then the removal.
		var options: Array = []
		for card_id: String in Pools.draw_cards_in_place(ruleset, state, key, dude["dude_id"], constants["SHOP_CARD_COUNT"]):
			options.append(Offers.option("card", true, {"card_id": card_id}))
		for gear_id: String in Draws.pick_distinct_in_place(state, key, Pools.loot_gear(ruleset, dude), constants["SHOP_GEAR_COUNT"]):
			options.append(Offers.option("gear", true, {"gear_id": gear_id}))
		for brew_id: String in Draws.pick_distinct_in_place(state, key, Pools.brews(ruleset), constants["SHOP_SHAKE_COUNT"]):
			options.append(Offers.option("shake", true, {"brew_id": brew_id}))
		options.append(Offers.option(REMOVE, true, {"card_uids": []}))
		# offer: the new offer, inside state.
		var offer: Dictionary = Offers.open_in_place(state, i, KIND, "", true, options, events)
		refresh(ruleset, dude, offer)


## Works out every option's price for this Dude now, and the removal's cards and availability. Sold
## items stay unavailable. Changes the offer in place.
## ruleset: the read-only content. dude: the Dude. offer: their Baileys offer.
static func refresh(ruleset: Dictionary, dude: Dictionary, offer: Dictionary) -> void:
	for option: Dictionary in offer["options"]:
		match option["kind"]:
			"card":
				option["price"] = Pools.item_price(ruleset, dude, "card", option["card_id"])
			"gear":
				option["price"] = Pools.item_price(ruleset, dude, "gear", option["gear_id"])
			"shake":
				option["price"] = Pools.item_price(ruleset, dude, "shake", option["brew_id"])
			REMOVE:
				option["price"] = Pools.removal_price(ruleset, dude)
				option["card_uids"] = Grants.removable_cards(ruleset, dude)
				option["available"] = not option["card_uids"].is_empty()


## Returns why a Dude cannot take a Baileys option now ("unplayable"), or "" when they can: it costs
## more than they hold, or it is a Shake and every Brew slot is full. The caller has checked the index,
## availability and card_uid. Reads only.
## dude: the Dude. option: the picked option.
static func check(dude: Dictionary, option: Dictionary) -> String:
	if option["price"] > dude["dolla_bills"]:
		return "unplayable"
	if option["kind"] == "shake" and dude["brews"].size() >= dude["brew_slots"]:
		return "unplayable"
	return ""


## Applies a checked choice (see the file header): leave, buy an item or remove a card.
## ruleset: the read-only content. state: the working copy. dude_index: the Dude's seat, 0-based.
## offer: the Dude's Baileys offer, inside state. choice_index: -1 or an option index.
## card_uid: the card to remove, for "remove". events: the event list, appended to.
static func choose_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, offer: Dictionary,
		choice_index: int, card_uid: String, events: Array) -> void:
	if choice_index == Offers.SKIP:
		Offers.close_in_place(state, dude_index, offer["id"], choice_index, events)
		return
	# dude: the buyer, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# option: the picked option, inside the offer.
	var option: Dictionary = offer["options"][choice_index]
	Grants.change_dolla_bills_in_place(state, dude_index, -option["price"], events)
	events.append(Event.make("item_bought", {"player_id": dude["player_id"], "reward_id": offer["id"],
		"choice_index": choice_index, "price": option["price"]}))
	match option["kind"]:
		"card":
			Grants.add_card_in_place(ruleset, state, dude_index, option["card_id"], events)
		"gear":
			GearTriggers.gain_in_place(ruleset, dude, option["gear_id"], events)
		"shake":
			Grants.gain_brew_in_place(state, dude_index, option["brew_id"], events)
		REMOVE:
			Grants.remove_card_in_place(state, dude_index, card_uid, events)
			dude["cards_removed"] += 1
	if ITEM_KINDS.has(option["kind"]):
		option["available"] = false
	refresh(ruleset, dude, offer)
