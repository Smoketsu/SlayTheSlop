## Shape of a card definition, one JSON file per card in data/cards/ (GDD "Card definition fields").
## Shared contract.
##
## Example: the GDD's tom_arm_bar. Effects are a list of operations; each has an "op" name and
## that operation's own values. Which ops exist and what their values mean is the core lane's
## op catalogue (core/ops/README.md once it exists); this file only checks the outer shape.
##
## Who may change definitions: the content lane. Who may change this shape: a contract PR.
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")

## Card pools, from the GDD table. Ethan is missing from the GDD's list; see docs/proposals/solo-slice-rule-gaps.md.
const OWNERS: Array[String] = ["tom", "cheney", "nate", "grube", "neutral", "junk"]
## Card types, from the GDD table.
const TYPES: Array[String] = ["attack", "skill", "power", "aura", "junk"]
## Rarities, from the GDD table. Set reward odds and shop price.
const RARITIES: Array[String] = ["starter", "common", "uncommon", "rare"]
## What the player must select when playing the card, from the GDD table.
const TARGETS: Array[String] = ["enemy", "all_enemies", "self", "ally", "puppet", "none"]
## Keywords, from the GDD table.
const KEYWORDS: Array[String] = ["tapped", "pocketed", "assist", "tech"]

## Required fields and their types. Meanings are from the GDD table.
const SPEC := {
	# Unique key in the form owner_card_name. Must equal the file name without ".json". Never changes after merge.
	"id": TYPE_STRING,
	# Name shown on the card. May change freely.
	"name": TYPE_STRING,
	# Which pool the card belongs to, one of OWNERS.
	"owner": TYPE_STRING,
	# One of TYPES.
	"type": TYPE_STRING,
	# One of RARITIES.
	"rarity": TYPE_STRING,
	# Hype needed to play, 0 or more. "x" spends all remaining Hype. -1 means unplayable.
	"cost": [TYPE_INT, TYPE_STRING],
	# One of TARGETS.
	"target": TYPE_STRING,
	# Operations run in order. Each is a Dictionary with at least a String "op".
	"effects": {"list_of": TYPE_DICTIONARY},
	# Any of KEYWORDS.
	"keywords": {"list_of": TYPE_STRING},
	# Nate only: {"abs": Abs strained, "effects": operations added when paid}, or null. null for every slice card.
	"crunch": [TYPE_DICTIONARY, TYPE_NIL],
	# Field path -> new value after the card is Lifted at a Tailgate, for example {"effects[0].amount": 11}.
	# {} when the GDD gives no upgrade (see docs/proposals/solo-slice-rule-gaps.md).
	"upgrade": TYPE_DICTIONARY,
}

## Fields that may be left out.
const OPTIONAL := {
	# Ethan only (GDD "Fields added for Ethan"): turns he Naps after the card resolves, or null.
	"crash": [TYPE_INT, TYPE_NIL],
	# [added] Rules text shown on the card, in the GDD's wording. Until the client can build text from
	# effects, this is what the player reads. Must describe the effects exactly.
	"text": TYPE_STRING,
	# [added, task 013] Power cards only (type "power"): what the Power does while it is active, as a
	# list of triggers (see TRIGGER_SPEC). A played Power stays in its Dude's powers list for the rest
	# of the fight (dude_state.gd), and each trigger runs its effects whenever its "when" happens.
	# Meanings of the "when" and "target" values: POWER_WHENS, POWER_TARGETS and core/ops/README.md.
	"power_triggers": {"list_of": TYPE_DICTIONARY},
}

## [added, task 013] Shape of one entry of power_triggers. All three fields are required.
const TRIGGER_SPEC := {
	# When the trigger fires, one of POWER_WHENS.
	"when": TYPE_STRING,
	# Who its effects land on, one of POWER_TARGETS.
	"target": TYPE_STRING,
	# Operations run in order each time it fires, as in "effects". The Dude who played the Power is the actor.
	"effects": {"list_of": TYPE_DICTIONARY},
}

## [added, task 013] When a Power trigger fires. Changes only in a contract PR, with the core lane
## building the new trigger. "turn_start": at the start of each turn, once the Dudes have Refreshed
## (Friend Zone). "enemy_buffed": an enemy gained a buff, that is Guard or Swole (G10; Reply Guy).
## "enemy_grossed_out": an enemy was Grossed Out (Friend Zone's Exposed).
const POWER_WHENS: Array[String] = ["turn_start", "enemy_buffed", "enemy_grossed_out"]

## [added, task 013] Who a Power trigger's effects land on. "subject": the enemy the trigger is
## about (enemy_buffed and enemy_grossed_out only). "all_enemies": every enemy in the fight when it
## fires, left to right. "self": the Dude who played the Power.
const POWER_TARGETS: Array[String] = ["subject", "all_enemies", "self"]

## [added, task 013] The POWER_WHENS values that have a subject enemy, so may use target "subject".
const WHENS_WITH_SUBJECT: Array[String] = ["enemy_buffed", "enemy_grossed_out"]

## [added, task 013] The card type whose cards may have power_triggers and become active when played.
const POWER_TYPE: String = "power"


## Checks a card definition. Returns a list of problems; empty means valid.
## card: the parsed definition (after json_values.parse). path: label for messages, usually the file path.
static func check(card: Variant, path: String = "card") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(card, SPEC, path, OPTIONAL)
	if not errors.is_empty():
		return errors
	errors.append_array(Shape.check_one_of(card["owner"], OWNERS, path + ".owner"))
	errors.append_array(Shape.check_one_of(card["type"], TYPES, path + ".type"))
	errors.append_array(Shape.check_one_of(card["rarity"], RARITIES, path + ".rarity"))
	errors.append_array(Shape.check_one_of(card["target"], TARGETS, path + ".target"))
	for keyword: String in card["keywords"]:
		errors.append_array(Shape.check_one_of(keyword, KEYWORDS, path + ".keywords"))
	# cost: the cost field, which is an int or the text "x".
	var cost: Variant = card["cost"]
	if typeof(cost) == TYPE_STRING and cost != "x":
		errors.append("%s.cost: text cost must be \"x\", got %s" % [path, cost])
	if typeof(cost) == TYPE_INT and cost < -1:
		errors.append("%s.cost: %d is below -1" % [path, cost])
	for i: int in card["effects"].size():
		if typeof(card["effects"][i].get("op")) != TYPE_STRING:
			errors.append("%s.effects[%d]: missing String \"op\"" % [path, i])
	if not card["id"].begins_with(card["owner"] + "_"):
		errors.append("%s.id: %s must start with its owner \"%s_\"" % [path, card["id"], card["owner"]])
	if card.has("power_triggers"):
		errors.append_array(check_power_triggers(card, path))
	return errors


## [added, task 013] Checks a card's power_triggers: only on a card of type POWER_TYPE, each entry
## shaped like TRIGGER_SPEC, "when" in POWER_WHENS, "target" in POWER_TARGETS ("subject" only for
## WHENS_WITH_SUBJECT), and every effect with a String "op". Which ops exist is the core's check
## (core/ops/ops.gd), as for "effects". Returns the problems; empty means valid.
## card: a card definition whose outer shape already passed. path: label for messages.
static func check_power_triggers(card: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	if card["type"] != POWER_TYPE:
		errors.append("%s.power_triggers: only a card of type \"%s\" may have power_triggers" % [path, POWER_TYPE])
	for i: int in card["power_triggers"].size():
		# trigger: one entry.
		var trigger: Dictionary = card["power_triggers"][i]
		# label: the entry's path in messages.
		var label: String = "%s.power_triggers[%d]" % [path, i]
		# found: shape problems with this entry.
		var found: Array[String] = Shape.check(trigger, TRIGGER_SPEC, label)
		if not found.is_empty():
			errors.append_array(found)
			continue
		errors.append_array(Shape.check_one_of(trigger["when"], POWER_WHENS, label + ".when"))
		errors.append_array(Shape.check_one_of(trigger["target"], POWER_TARGETS, label + ".target"))
		if trigger["target"] == "subject" and POWER_WHENS.has(trigger["when"]) \
				and not WHENS_WITH_SUBJECT.has(trigger["when"]):
			errors.append("%s.target: \"subject\" needs a when of %s" % [label, str(WHENS_WITH_SUBJECT)])
		for j: int in trigger["effects"].size():
			if typeof(trigger["effects"][j].get("op")) != TYPE_STRING:
				errors.append("%s.effects[%d]: missing String \"op\"" % [label, j])
	return errors
