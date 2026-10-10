## The tuning constants the run flow reads, and their check (task 025). Lane: run (Agent A).
##
## Every number the run lane uses comes from data/constants.json (CLAUDE.md "Every balance number
## lives in data/constants.json"). core/run/new_run.gd checks them all once, when a run starts, so
## the rest of the run lane can read them without checking again. The map's own constants are
## checked by core/run/map/floor_map.gd, and the fight's by core/combat/fight.gd.
##
## Pure: no file, clock, network or random access.
extends RefCounted

## Constants that must be whole numbers, 0 or more. Meanings are in data/constants.json:
##   START_DOLLA_BILLS (G20), BASE_BREW_SLOTS, CARD_REWARD_CHOICES, BRAWL_DOLLA_MIN / _MAX,
##   RIVAL_DOLLA_MIN / _MAX, CARD_REMOVE_BASE / _STEP (G22); the PRICE_ and SHOP_ constants (G21);
##   EARLY_BRAWL_COUNT and BOSS_GEAR_CHOICES (task 025).
const INT_CONSTANTS: Array[String] = [
	"START_DOLLA_BILLS", "BASE_BREW_SLOTS", "CARD_REWARD_CHOICES",
	"BRAWL_DOLLA_MIN", "BRAWL_DOLLA_MAX", "RIVAL_DOLLA_MIN", "RIVAL_DOLLA_MAX",
	"CARD_REMOVE_BASE", "CARD_REMOVE_STEP",
	"PRICE_CARD_COMMON", "PRICE_CARD_UNCOMMON", "PRICE_CARD_RARE",
	"PRICE_GEAR_COMMON", "PRICE_GEAR_UNCOMMON", "PRICE_GEAR_RARE",
	"PRICE_SHAKE_COMMON", "PRICE_SHAKE_UNCOMMON", "PRICE_SHAKE_RARE",
	"SHOP_CARD_COUNT", "SHOP_GEAR_COUNT", "SHOP_SHAKE_COUNT",
	"EARLY_BRAWL_COUNT", "BOSS_GEAR_CHOICES",
]

## Constants that are fractions from 0 to 1 (a probability or a fraction of max HP), int or float:
##   BRAWL_BREW_CHANCE, TAILGATE_NAP_HEAL (G22); the REWARD_ODDS_ constants (G21);
##   LOOT_MIMIC_CHANCE (G19); REVIVE_HP_FRACTION (GDD "Tuning constants").
const FRACTION_CONSTANTS: Array[String] = [
	"BRAWL_BREW_CHANCE", "TAILGATE_NAP_HEAL", "REWARD_ODDS_COMMON", "REWARD_ODDS_UNCOMMON",
	"REWARD_ODDS_RARE", "LOOT_MIMIC_CHANCE", "REVIVE_HP_FRACTION",
]

## Pairs [smallest, largest] of range constants: the first must not be above the second.
const RANGES: Array = [["BRAWL_DOLLA_MIN", "BRAWL_DOLLA_MAX"], ["RIVAL_DOLLA_MIN", "RIVAL_DOLLA_MAX"]]


## Returns why the run constants cannot be used, or "" when they all can.
## constants: ruleset.constants.
static func check(constants: Dictionary) -> String:
	for name: String in INT_CONSTANTS:
		if typeof(constants.get(name)) != TYPE_INT or constants[name] < 0:
			return "constant %s is missing or not a whole number 0 or more" % name
	for name: String in FRACTION_CONSTANTS:
		if not [TYPE_INT, TYPE_FLOAT].has(typeof(constants.get(name))) or constants[name] < 0 or constants[name] > 1:
			return "constant %s is missing or not a number from 0 to 1" % name
	for pair: Array in RANGES:
		if constants[pair[0]] > constants[pair[1]]:
			return "constant %s is above %s" % [pair[0], pair[1]]
	return ""
