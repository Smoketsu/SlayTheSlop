## What a won fight gives (task 025, GDD "Node types"). Lane: run (Agent A).
##
## After a fight that the run flow started is won, at the end of the same request (after Gear's
## fight_end point, so Unused Gym Membership has healed and Participation Trophy has looked at HP):
##   1. Passed Out Dudes wake at REVIVE_HP_FRACTION of max HP, rounded down, at least 1 (GDD
##      "Passing out": "They wake at 30% HP if the team wins the fight"; dude_revived). Gap G57.
##   2. Each Dude, in seat order, gets the reward of the encounter's kind (encounter_def.gd "node"),
##      every draw on that Dude's own rewards stream (GDD "Random streams"), in this order:
##        brawl: BRAWL_DOLLA_MIN..MAX Dolla Bills; a Brew with chance BRAWL_BREW_CHANCE (any Brew,
##               each equally likely); a card offer of CARD_REWARD_CHOICES cards.
##        rival: RIVAL_DOLLA_MIN..MAX Dolla Bills; a Gear from the Loot pool; a card offer.
##        boss:  a full heal; a Boss Gear offer of BOSS_GEAR_CHOICES ("1 of 3 Boss Gear, full heal").
##        loot:  nothing but its drops (a Mimic Cooler "always drops a Brew"; G19 replaces the Loot,
##               so no Gear). Gap G58.
##      Dolla Bills go through the Dude's fight_dolla_bills_percent Gear (Dad's Platinum Card: 0)
##      after the amount is drawn, so the stream moves the same with or without it.
##      Brews dropped in the fight (combat.brews_dropped, Mimic Cooler) come right after the Dolla
##      Bills: that many Brews for each Dude, each drawn from the Brew pool. Gap G58.
##      A Brew with no free slot is not kept (brew_not_kept). Gap G58.
##   3. The fight is cleared (combat = null).
## Co-op drafting of Rival Gear in turn ("First pick rotates", GDD) is not built: each Dude gets their
## own Gear from their own stream (gap G59).
##
## Functions ending in _in_place change the working copy they are given. Pure: randomness only
## through core/run/draws.gd.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Rng := preload("res://core/rng/rng.gd")
const Ratio := preload("res://core/ops/ratio.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")
const Draws := preload("res://core/run/draws.gd")
const Pools := preload("res://core/run/pools.gd")
const Grants := preload("res://core/run/grants.gd")
const Offers := preload("res://core/run/offers.gd")

## The per-player stream every reward draw uses (GDD "Random streams": rewards, one per player).
const STREAM: String = "rewards"

## Encounter kinds (core/schema/encounter_def.gd NODES) and what they give; see the file header.
const BRAWL: String = "brawl"
## A Rival fight's kind.
const RIVAL: String = "rival"
## A boss fight's kind.
const BOSS: String = "boss"

## Lowest HP a revived Dude wakes with, whatever the fraction gives. Not tuning: a Dude at 0 HP
## would still be Passed Out.
const MIN_REVIVE_HP: int = 1


## Runs steps 1-3 of the file header after a won fight.
## ruleset: the read-only content. state: the working copy, its fight over and won.
## kind: the encounter's kind ("brawl", "rival", "boss" or "loot"). events: the event list, appended to.
static func after_win_in_place(ruleset: Dictionary, state: Dictionary, kind: String, events: Array) -> void:
	revive_in_place(ruleset, state, events)
	# dropped: Brews the fight's enemies dropped (Mimic Cooler), 0 or more.
	var dropped: int = state["combat"]["brews_dropped"]
	for i: int in state["dudes"].size():
		# key: this Dude's rewards stream.
		var key: String = Rng.key_for(STREAM, state["dudes"][i]["player_id"])
		match kind:
			BRAWL:
				_dolla_bills_in_place(ruleset, state, i, key, "BRAWL", events)
				if Draws.chance_in_place(state, key, ruleset["constants"]["BRAWL_BREW_CHANCE"]):
					random_brew_in_place(ruleset, state, i, key, events)
			RIVAL:
				_dolla_bills_in_place(ruleset, state, i, key, "RIVAL", events)
		for drop: int in dropped:
			random_brew_in_place(ruleset, state, i, key, events)
		match kind:
			BRAWL:
				card_offer_in_place(ruleset, state, i, key, events)
			RIVAL:
				random_gear_in_place(ruleset, state, i, key, events)
				card_offer_in_place(ruleset, state, i, key, events)
			BOSS:
				Grants.heal_in_place(state, i, state["dudes"][i]["max_hp"], events)
				boss_gear_offer_in_place(ruleset, state, i, key, events)
	state["combat"] = null


## Wakes every Passed Out Dude at REVIVE_HP_FRACTION of max HP, rounded down, at least MIN_REVIVE_HP
## (dude_revived). Solo never reaches this: a Passed Out solo Dude has lost the fight.
## ruleset: the read-only content. state: the working copy. events: the event list, appended to.
static func revive_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	for dude: Dictionary in state["dudes"]:
		if not dude["passed_out"]:
			continue
		dude["passed_out"] = false
		dude["hp"] = maxi(MIN_REVIVE_HP, Ratio.floor_times(dude["max_hp"], Ratio.from_constant(ruleset["constants"]["REVIVE_HP_FRACTION"])))
		events.append(Event.make("dude_revived", {"player_id": dude["player_id"], "hp": dude["hp"]}))


## Opens a card offer for a Dude: CARD_REWARD_CHOICES cards from their pool (core/run/pools.gd), pick
## 1 or skip. Opens nothing when the pool is empty.
## ruleset: the read-only content. state: the working copy. dude_index: the Dude's seat, 0-based.
## key: the Dude's rewards stream. events: the event list, appended to.
static func card_offer_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, key: String, events: Array) -> void:
	# cards: the offered card ids.
	var cards: Array = Pools.draw_cards_in_place(ruleset, state, key, state["dudes"][dude_index]["dude_id"],
		ruleset["constants"]["CARD_REWARD_CHOICES"])
	if cards.is_empty():
		return
	# options: one "card" option per card.
	var options: Array = []
	for card_id: String in cards:
		options.append(Offers.option("card", true, {"card_id": card_id}))
	Offers.open_in_place(state, dude_index, "card", "", true, options, events)


## Opens the Boss Gear pick for a Dude: up to BOSS_GEAR_CHOICES different Boss Gear they do not own,
## pick 1, no skip (gap G55). Opens nothing when they own every Boss Gear.
## ruleset: the read-only content. state: the working copy. dude_index: the Dude's seat, 0-based.
## key: the Dude's rewards stream. events: the event list, appended to.
static func boss_gear_offer_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, key: String, events: Array) -> void:
	# gear_ids: the offered Boss Gear.
	var gear_ids: Array = Draws.pick_distinct_in_place(state, key, Pools.boss_gear(ruleset, state["dudes"][dude_index]),
		ruleset["constants"]["BOSS_GEAR_CHOICES"])
	if gear_ids.is_empty():
		return
	# options: one "gear" option per Gear.
	var options: Array = []
	for gear_id: String in gear_ids:
		options.append(Offers.option("gear", true, {"gear_id": gear_id}))
	Offers.open_in_place(state, dude_index, "boss_gear", "", false, options, events)


## Gives a Dude one Gear from their Loot pool, drawn on the given stream (Loot, Rival rewards, and with
## the side_quest stream 3 a.m. Tattoo). Gives nothing when the pool is empty. Returns the Gear id or "".
## ruleset: the read-only content. state: the working copy. dude_index: the Dude's seat, 0-based.
## key: the stream to draw on. events: the event list, appended to.
static func random_gear_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, key: String, events: Array) -> String:
	# picked: the Gear id, or null.
	var picked: Variant = Draws.pick_in_place(state, key, Pools.loot_gear(ruleset, state["dudes"][dude_index]))
	if picked == null:
		return ""
	GearTriggers.gain_in_place(ruleset, state["dudes"][dude_index], picked, events)
	return picked


## Gives a Dude one Brew from the Brew pool, drawn on the given stream, into a free slot (or not kept).
## ruleset: the read-only content. state: the working copy. dude_index: the Dude's seat, 0-based.
## key: the stream to draw on. events: the event list, appended to.
static func random_brew_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, key: String, events: Array) -> void:
	# picked: the Brew id, or null when there are no Brews.
	var picked: Variant = Draws.pick_in_place(state, key, Pools.brews(ruleset))
	if picked != null:
		Grants.gain_brew_in_place(state, dude_index, picked, events)


## Gives a Dude a fight's Dolla Bills: <prefix>_DOLLA_MIN..MAX, then their fight_dolla_bills_percent Gear.
## ruleset: the read-only content. state: the working copy. dude_index: the Dude's seat, 0-based.
## key: the Dude's rewards stream. prefix: "BRAWL" or "RIVAL". events: the event list, appended to.
static func _dolla_bills_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, key: String, prefix: String,
		events: Array) -> void:
	# constants: the tuning constants.
	var constants: Dictionary = ruleset["constants"]
	# amount: the drawn reward before Gear.
	var amount: int = Draws.int_in_place(state, key, constants[prefix + "_DOLLA_MIN"], constants[prefix + "_DOLLA_MAX"])
	Grants.change_dolla_bills_in_place(state, dude_index,
		GearTriggers.fight_dolla_bills(ruleset, state["dudes"][dude_index], amount), events)
