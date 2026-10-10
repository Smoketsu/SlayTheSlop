## What can be offered: card, Gear and Brew pools, rarity odds and Baileys prices (task 025).
## Lane: run (Agent A).
##
## Pools (every list sorted by id, so a draw never depends on Dictionary order):
##   Card pool of a Dude: cards whose owner is the Dude's id ("from their own Dude's pool", GDD
##     "Rules that change in co-op") with rarity common, uncommon or rare. Starter and special
##     (Junk, Bro Moves; G17) cards are never offered or sold. Neutral cards are not offered: the GDD
##     does not say where they appear (gap G56).
##   Loot pool of a Dude (G24, G28): Gear owned by "general" or by the Dude, rarity common, uncommon
##     or rare, that the Dude does not own yet. Used by Loot, Rival rewards, Baileys and 3 a.m. Tattoo.
##   Boss Gear pool of a Dude: Gear owned by "boss" that the Dude does not own yet.
##   Brew pool: every Brew.
##
## Card offers (draw_cards_in_place): each slot first draws a rarity with the REWARD_ODDS_ constants
## (G21), counting only rarities that still have a card not yet in this offer, then one of those cards,
## each equally likely. So an offer never repeats a card, and a pool with no rare cards never shows a
## rare (gap G56). Gear and Brews have no rarity odds in the GDD: they are drawn each equally likely.
##
## Prices (G21, G26): PRICE_<CARD|GEAR|SHAKE>_<RARITY>, then the buyer's Medical Card
## (core/combat/gear_triggers.gd shop_price, rounded down).
##
## Pure: randomness only through core/run/draws.gd.
extends RefCounted

const Scaling := preload("res://core/combat/party_scaling.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")
const Draws := preload("res://core/run/draws.gd")

## Rarities that are offered and sold, in the order of the REWARD_ODDS_ constants (G21). Fixed by the GDD.
const OFFERED_RARITIES: Array[String] = ["common", "uncommon", "rare"]

## Rarity -> the constant with its chance on a card offer (G21). Fixed by the constants file's names.
const ODDS_CONSTANTS := {
	"common": "REWARD_ODDS_COMMON",
	"uncommon": "REWARD_ODDS_UNCOMMON",
	"rare": "REWARD_ODDS_RARE",
}

## Gear owner (core/schema/gear_def.gd OWNERS) that any Dude may find (GDD "General Gear").
const GENERAL_OWNER: String = "general"

## Gear owner of Boss Gear (core/schema/gear_def.gd OWNERS).
const BOSS_OWNER: String = "boss"

## Item kinds that have a Baileys price, as used in the PRICE_ constant names. Fixed by those names.
const PRICED_KINDS: Array[String] = ["card", "gear", "shake"]


## Returns a Dude's card pool by rarity: {"common": [ids], "uncommon": [...], "rare": [...]}, each
## sorted by id (see the file header).
## ruleset: the read-only content. dude_id: the Dude's id, for example "tom".
static func card_pool(ruleset: Dictionary, dude_id: String) -> Dictionary:
	# pool: the result.
	var pool: Dictionary = {}
	for rarity: String in OFFERED_RARITIES:
		pool[rarity] = []
	# ids: every card id, sorted.
	var ids: Array = ruleset["cards"].keys()
	ids.sort()
	for id: String in ids:
		# card: the definition.
		var card: Dictionary = ruleset["cards"][id]
		if card["owner"] == dude_id and pool.has(card["rarity"]):
			pool[card["rarity"]].append(id)
	return pool


## Returns the Loot pool of a Dude (see the file header), sorted by id.
## ruleset: the read-only content. dude: the Dude's state (its dude_id and gear are read).
static func loot_gear(ruleset: Dictionary, dude: Dictionary) -> Array:
	# ids: the result.
	var ids: Array = []
	for id: String in _sorted_gear_ids(ruleset):
		# gear: the definition.
		var gear: Dictionary = ruleset["gear"][id]
		if (gear["owner"] == GENERAL_OWNER or gear["owner"] == dude["dude_id"]) \
				and OFFERED_RARITIES.has(gear["rarity"]) and not dude["gear"].has(id):
			ids.append(id)
	return ids


## Returns the Boss Gear pool of a Dude (see the file header), sorted by id.
## ruleset: the read-only content. dude: the Dude's state (its gear is read).
static func boss_gear(ruleset: Dictionary, dude: Dictionary) -> Array:
	# ids: the result.
	var ids: Array = []
	for id: String in _sorted_gear_ids(ruleset):
		if ruleset["gear"][id]["owner"] == BOSS_OWNER and not dude["gear"].has(id):
			ids.append(id)
	return ids


## Returns every Brew id, sorted.
## ruleset: the read-only content.
static func brews(ruleset: Dictionary) -> Array:
	# ids: the result.
	var ids: Array = ruleset.get("brews", {}).keys()
	ids.sort()
	return ids


## Draws up to count different cards from a Dude's card pool with the G21 rarity odds (see the file
## header). Returns the card ids in the order drawn; fewer when the pool runs out.
## ruleset: the read-only content. state: the working copy; the stream advances. key: the stream
## (the Dude's rewards stream). dude_id: whose pool. count: cards wanted, 0 or more.
static func draw_cards_in_place(ruleset: Dictionary, state: Dictionary, key: String, dude_id: String, count: int) -> Array:
	# pool: rarity -> card ids not offered yet.
	var pool: Dictionary = card_pool(ruleset, dude_id)
	# picked: the result.
	var picked: Array = []
	while picked.size() < count:
		# weights: each rarity's odds in millionths, 0 when none of its cards is left.
		var weights: Array = []
		for rarity: String in OFFERED_RARITIES:
			weights.append(0 if pool[rarity].is_empty() else Scaling.to_millionths(ruleset["constants"][ODDS_CONSTANTS[rarity]]))
		if weights.max() <= 0:
			break
		# drawn: the index of the drawn rarity, -1 when the stream is missing.
		var drawn: int = Draws.weighted_in_place(state, key, weights)
		if drawn < 0:
			break
		# rarity: the drawn rarity.
		var rarity: String = OFFERED_RARITIES[drawn]
		# index: the drawn card's position among that rarity's remaining cards.
		var index: int = Draws.int_in_place(state, key, 0, pool[rarity].size() - 1)
		picked.append(pool[rarity][index])
		pool[rarity].remove_at(index)
	return picked


## Returns the normal Baileys price of an item before Medical Card (G21): PRICE_<KIND>_<RARITY>.
## ruleset: the read-only content. kind: one of PRICED_KINDS. rarity: one of OFFERED_RARITIES.
static func base_price(ruleset: Dictionary, kind: String, rarity: String) -> int:
	return ruleset["constants"]["PRICE_%s_%s" % [kind.to_upper(), rarity.to_upper()]]


## Returns what a Dude pays at Baileys for an item: base_price() with the Dude's Medical Card and the
## like (G26, rounded down). An item whose rarity has no price (never in a pool) costs 0.
## ruleset: the read-only content. dude: the buyer. kind: "card", "gear" or "shake". item_id: its id.
static func item_price(ruleset: Dictionary, dude: Dictionary, kind: String, item_id: String) -> int:
	# folder: the ruleset key holding this kind's definitions.
	var folder: String = {"card": "cards", "gear": "gear", "shake": "brews"}.get(kind, "")
	# rarity: the item's rarity, or "" when unknown.
	var rarity: String = ruleset.get(folder, {}).get(item_id, {}).get("rarity", "")
	if not OFFERED_RARITIES.has(rarity):
		return 0
	return GearTriggers.shop_price(ruleset, dude, base_price(ruleset, kind, rarity))


## Returns what a Dude pays for their next card removal: CARD_REMOVE_BASE + CARD_REMOVE_STEP x
## removals so far (GDD "75, rising by 25 each time"), with Medical Card (G26: removal included).
## ruleset: the read-only content. dude: the Dude.
static func removal_price(ruleset: Dictionary, dude: Dictionary) -> int:
	# constants: the tuning constants.
	var constants: Dictionary = ruleset["constants"]
	return GearTriggers.shop_price(ruleset, dude,
		constants["CARD_REMOVE_BASE"] + constants["CARD_REMOVE_STEP"] * dude["cards_removed"])


## Returns every Gear id in the ruleset, sorted.
## ruleset: the read-only content.
static func _sorted_gear_ids(ruleset: Dictionary) -> Array:
	# ids: the result.
	var ids: Array = ruleset.get("gear", {}).keys()
	ids.sort()
	return ids
