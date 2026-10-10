## Shape of a Gear definition, one JSON file per Gear in data/gear/ (GDD "Items": General Gear,
## Boss Gear, Dude Gear). Shared contract. [added, task 021: the GDD has no Gear field table]
##
## Gear is permanent for the run. A definition says what the Gear does in three ways, each optional
## (an empty map or list means "none"):
##   - stats:     stat changes that hold while the Gear is owned ("+1 Swole", "+8 Max HP").
##   - triggers:  effects that run at a trigger point ("heal 6 HP after every fight").
##   - modifiers: numbers other rules read ("Prices at Baileys are 20% lower").
## Effects inside triggers are effect operations like a card's (core/ops/README.md lists them and
## says which trigger points and targets exist). This file checks the outer shape only; whether an
## op exists and has the right fields is the core lane's check (core/combat/gear_triggers.gd check()).
##
## Example (GDD "Tom, the Enforcer", starting Gear):
##   {"id": "tom_unused_gym_membership", "name": "Unused Gym Membership", "owner": "tom",
##    "rarity": "starter", "text": "Heal 6 HP after every fight.", "stats": {},
##    "triggers": [{"when": "fight_end", "target": "self", "effects": [{"op": "heal", "amount": 6}]}],
##    "modifiers": []}
##
## Who may change definitions: the content lane. Who may change this shape: a contract PR.
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")
const CardDef := preload("res://core/schema/card_def.gd")

## Dudes who can own Dude Gear (GDD "Dude Gear" table). Dude Gear only appears for its owner and its
## id starts with "<owner>_". Changes only when the GDD adds a Dude.
const DUDE_OWNERS: Array[String] = ["tom", "cheney", "nate", "grube", "ethan"]

## Every owner value: a Dude (Dude Gear), "general" (GDD "General Gear": any Dude can find it) or
## "boss" (GDD "Boss Gear": offered only after a floor boss).
const OWNERS: Array[String] = ["tom", "cheney", "nate", "grube", "ethan", "general", "boss"]

## Rarities. common / uncommon / rare are the GDD's and set Baileys prices (G21). "starter" is for
## starting Gear and "boss" for Boss Gear (G28); neither is ever offered at Baileys or as Loot.
const RARITIES: Array[String] = ["starter", "common", "uncommon", "rare", "boss"]

## Dude stats a Gear's "stats" map may change (GDD "Stats" and "Dude state"). The value is added to
## the Dude's field of the same name when the Gear is gained.
const STATS: Array[String] = ["swole", "chill", "clout", "max_hp", "hype_per_turn", "draw_per_turn", "brew_slots"]

## Trigger points ("when" of a trigger). Meanings, and exactly when each fires, are in
## core/ops/README.md "Gear trigger points"; in short:
##   fight_start: once per fight, after the enemies are in place and the draw piles shuffled, before
##                turn 1's intents and Refresh (so before Hype is filled and the first hand drawn).
##   first_turn:  once per fight, right after turn 1's Refresh of every Dude (Hype already filled,
##                first hand already drawn), before the player phase takes requests.
##   fight_end:   once per fight that is won, right after it ends.
##   card_played: after the owner plays a card (optionally only cards of one type or cost).
##   ick_applied: each time the owner applies Ick to an enemy (Whole Can of Body Spray).
const WHENS: Array[String] = ["fight_start", "first_turn", "fight_end", "card_played", "ick_applied"]

## Who a trigger's effects land on ("target" of a trigger):
##   self:           the Gear's owner.
##   all_enemies:    every enemy in the fight, left to right.
##   all_dudes:      every Dude who is not Passed Out, in seat order.
##   trigger_target: what the trigger was about: the enemy the Ick landed on (ick_applied), or
##                   the played card's targets (card_played). Only for those two trigger points.
const TRIGGER_TARGETS: Array[String] = ["self", "all_enemies", "all_dudes", "trigger_target"]

## Trigger points that have a trigger_target.
const WHENS_WITH_TRIGGER_TARGET: Array[String] = ["card_played", "ick_applied"]

## Modifier kinds ("kind" of a modifier). What "amount" means for each:
##   card_damage:               added to the base damage of every hit of each damage effect on a card
##                              the owner plays that matches card_type / min_cost (Championship Ring).
##   shop_price_percent:        every Baileys price is this percent of normal, rounded down (Medical
##                              Card 80; G26: card removal included). Read by the run lane.
##   fight_dolla_bills_percent: Dolla Bills earned from fights are this percent of normal, rounded
##                              down (Dad's Platinum Card 0). Read by the run lane.
const MODIFIER_KINDS: Array[String] = ["card_damage", "shop_price_percent", "fight_dolla_bills_percent"]

## Modifier kinds that may carry the card filters card_type and min_cost.
const CARD_MODIFIER_KINDS: Array[String] = ["card_damage"]

## Required fields and their types.
const SPEC := {
	# Unique key, snake_case, equal to the file name without ".json". Dude Gear starts with its owner
	# ("tom_arm_wrestling_table"); general and Boss Gear have no prefix ("medical_card"). Never changes after merge.
	"id": TYPE_STRING,
	# Name shown to players, for example "Lifting Belt". May change freely.
	"name": TYPE_STRING,
	# One of OWNERS.
	"owner": TYPE_STRING,
	# One of RARITIES. "boss" exactly when owner is "boss".
	"rarity": TYPE_STRING,
	# Rules text shown to players, in the GDD's wording. Boss Gear states both the upside and the downside.
	"text": TYPE_STRING,
	# Stat (one of STATS) -> amount added while the Gear is owned, any non-zero int ("swole": 1,
	# "chill": -1). {} for none. Applied once when the Gear is gained.
	"stats": {"map_of": TYPE_INT},
	# Triggers, in the order they run at the same trigger point (see TRIGGER_SPEC). [] for none.
	"triggers": {"list_of": TYPE_DICTIONARY},
	# Modifiers (see MODIFIER_SPEC). [] for none.
	"modifiers": {"list_of": TYPE_DICTIONARY},
}

## Required fields of one trigger.
const TRIGGER_SPEC := {
	# The trigger point, one of WHENS.
	"when": TYPE_STRING,
	# Who the effects land on, one of TRIGGER_TARGETS.
	"target": TYPE_STRING,
	# Effect operations run in order, each a Dictionary with at least a String "op", as on a card.
	"effects": {"list_of": TYPE_DICTIONARY},
}

## Fields a trigger may have. Each narrows when it fires or scales its effects.
const TRIGGER_OPTIONAL := {
	# card_played only: fire only for cards of this type (one of card_def.gd TYPES).
	"card_type": TYPE_STRING,
	# card_played only: fire only for cards whose cost is an int at least this, 0 or more.
	"min_cost": TYPE_INT,
	# Fire only while the owner's HP is below this percent of their max HP, 1..100
	# (Participation Trophy: 50 means "below 50% HP").
	"hp_below_percent": TYPE_INT,
	# ick_applied only: true multiplies each effect's "amount" by the Ick that was applied
	# (Whole Can of Body Spray: 2 damage per stack). false or absent: amounts are used as written.
	"amount_per_stack": TYPE_BOOL,
}

## Required fields of one modifier.
const MODIFIER_SPEC := {
	# What it changes, one of MODIFIER_KINDS.
	"kind": TYPE_STRING,
	# Its size, 0 or more; the unit depends on kind (damage, or percent of normal).
	"amount": TYPE_INT,
}

## Fields a modifier may have (CARD_MODIFIER_KINDS only): the card filter, as for triggers.
const MODIFIER_OPTIONAL := {
	# Only cards of this type (one of card_def.gd TYPES).
	"card_type": TYPE_STRING,
	# Only cards whose cost is an int at least this, 0 or more (Championship Ring: 2).
	"min_cost": TYPE_INT,
}

## Highest value of hp_below_percent: 100 percent of max HP.
const MAX_PERCENT: int = 100


## Checks a Gear definition. Returns a list of problems; empty means valid.
## gear: the parsed definition (after json_values.parse). path: label for messages, usually the file path.
static func check(gear: Variant, path: String = "gear") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(gear, SPEC, path)
	if not errors.is_empty():
		return errors
	errors.append_array(Shape.check_one_of(gear["owner"], OWNERS, path + ".owner"))
	errors.append_array(Shape.check_one_of(gear["rarity"], RARITIES, path + ".rarity"))
	if (gear["owner"] == "boss") != (gear["rarity"] == "boss"):
		errors.append("%s.rarity: must be \"boss\" exactly when owner is \"boss\" (G28)" % path)
	if DUDE_OWNERS.has(gear["owner"]) and not gear["id"].begins_with(gear["owner"] + "_"):
		errors.append("%s.id: %s must start with its owner \"%s_\"" % [path, gear["id"], gear["owner"]])
	# stat_names: the stats map's keys, sorted for stable messages.
	var stat_names: Array = gear["stats"].keys()
	stat_names.sort()
	for stat: String in stat_names:
		errors.append_array(Shape.check_one_of(stat, STATS, "%s.stats" % path))
		if gear["stats"][stat] == 0:
			errors.append("%s.stats.%s: must not be 0" % [path, stat])
	for i: int in gear["triggers"].size():
		errors.append_array(_check_trigger(gear["triggers"][i], "%s.triggers[%d]" % [path, i]))
	for i: int in gear["modifiers"].size():
		errors.append_array(_check_modifier(gear["modifiers"][i], "%s.modifiers[%d]" % [path, i]))
	return errors


## Checks one trigger. Returns a list of problems; empty means valid.
## trigger: one entry of a definition's triggers. path: label for messages.
static func _check_trigger(trigger: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(trigger, TRIGGER_SPEC, path, TRIGGER_OPTIONAL)
	if not errors.is_empty():
		return errors
	errors.append_array(Shape.check_one_of(trigger["when"], WHENS, path + ".when"))
	errors.append_array(Shape.check_one_of(trigger["target"], TRIGGER_TARGETS, path + ".target"))
	if trigger["target"] == "trigger_target" and not WHENS_WITH_TRIGGER_TARGET.has(trigger["when"]):
		errors.append("%s.target: trigger_target only works with %s" % [path, str(WHENS_WITH_TRIGGER_TARGET)])
	if (trigger.has("card_type") or trigger.has("min_cost")) and trigger["when"] != "card_played":
		errors.append("%s: card_type and min_cost only work with when \"card_played\"" % path)
	if trigger.has("amount_per_stack") and trigger["when"] != "ick_applied":
		errors.append("%s.amount_per_stack: only works with when \"ick_applied\"" % path)
	if trigger.has("hp_below_percent") and (trigger["hp_below_percent"] < 1 or trigger["hp_below_percent"] > MAX_PERCENT):
		errors.append("%s.hp_below_percent: must be 1..%d" % [path, MAX_PERCENT])
	errors.append_array(_check_card_filter(trigger, path))
	errors.append_array(_check_effects(trigger["effects"], path + ".effects"))
	return errors


## Checks one modifier. Returns a list of problems; empty means valid.
## modifier: one entry of a definition's modifiers. path: label for messages.
static func _check_modifier(modifier: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(modifier, MODIFIER_SPEC, path, MODIFIER_OPTIONAL)
	if not errors.is_empty():
		return errors
	errors.append_array(Shape.check_one_of(modifier["kind"], MODIFIER_KINDS, path + ".kind"))
	if modifier["amount"] < 0:
		errors.append("%s.amount: must be 0 or more" % path)
	if (modifier.has("card_type") or modifier.has("min_cost")) and not CARD_MODIFIER_KINDS.has(modifier["kind"]):
		errors.append("%s: card_type and min_cost only work with kind %s" % [path, str(CARD_MODIFIER_KINDS)])
	errors.append_array(_check_card_filter(modifier, path))
	return errors


## Checks the optional card filter fields (card_type, min_cost) of a trigger or modifier.
## entry: the trigger or modifier. path: label for messages.
static func _check_card_filter(entry: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	if entry.has("card_type"):
		errors.append_array(Shape.check_one_of(entry["card_type"], CardDef.TYPES, path + ".card_type"))
	if entry.has("min_cost") and entry["min_cost"] < 0:
		errors.append("%s.min_cost: must be 0 or more" % path)
	return errors


## Checks that every effect has a String "op" (the op's own fields are the core lane's check).
## effects: an effects list. path: label for messages.
static func _check_effects(effects: Array, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for i: int in effects.size():
		if typeof(effects[i].get("op")) != TYPE_STRING:
			errors.append("%s[%d]: missing String \"op\"" % [path, i])
	return errors
