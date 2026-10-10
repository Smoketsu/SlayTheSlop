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
## Rarities, from the GDD table, plus "special" (gap G17, answered "accept"; task 015): Junk and
## Bro Move cards, which are never offered as rewards or sold in the shop. Set reward odds and shop price.
const RARITIES: Array[String] = ["starter", "common", "uncommon", "rare", "special"]
## [added] Values of the optional "lasts" field (task 015, GDD "Junk cards" column "Lasts").
## "run": the copy stays in the Dude's run deck. "fight": the copy is removed from the Dude's cards,
## deck and piles when the fight ends. Changed only by a contract PR.
const LASTS: Array[String] = ["run", "fight"]

## [added] What a card without a "lasts" field means: it is part of the run deck. Changed only by a
## contract PR, because every existing card relies on it.
const DEFAULT_LASTS: String = "run"

## [added] Optional fields that hold an effects list run by a trigger rather than by playing the
## card (task 015). Each entry needs a String "op", like "effects". Changed only by a contract PR.
const TRIGGER_FIELDS: Array[String] = ["on_draw", "on_end_of_turn_in_hand"]

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
	# [added] Task 015 (GDD "Junk cards"). Operations run, in order, right after this copy is drawn
	# into its owner's hand (Hangover: lose 1 Hype; Bedbugs: take 1 damage). Same op format as
	# "effects"; the owner is the actor and the target. Left out or [] means nothing happens on draw.
	"on_draw": {"list_of": TYPE_DICTIONARY},
	# [added] Task 015. Operations run, in order, at End of turn if this copy is in its owner's hand,
	# before the hand is discarded (Burn: take 2 damage). Same op format as "effects"; the owner is
	# the actor and the target. Left out or [] means nothing happens.
	"on_end_of_turn_in_hand": {"list_of": TYPE_DICTIONARY},
	# [added] Task 015. While this copy is in its owner's hand, that Dude may play at most this many
	# cards this turn (counted by cards_played_this_turn); further plays are rejected "unplayable"
	# (Detention: 4). Int, 0 or more. Left out means no limit.
	"play_limit_in_hand": TYPE_INT,
	# [added] Task 015. One of LASTS: "run" (DEFAULT_LASTS, when left out) or "fight" (Paperwork,
	# Detention, Burn: removed from the Dude's cards, deck and piles when the fight ends).
	"lasts": TYPE_STRING,
	# [added] Task 015. false means the card cannot be removed at Baileys (Regret). Left out means
	# true. Read by the run lane's Baileys (task 025); the fight rules ignore it.
	"removable": TYPE_BOOL,
}


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
	# Task 015: trigger effect lists, the play limit and lasts.
	for field: String in TRIGGER_FIELDS:
		for i: int in card.get(field, []).size():
			if typeof(card[field][i].get("op")) != TYPE_STRING:
				errors.append("%s.%s[%d]: missing String \"op\"" % [path, field, i])
	if card.has("play_limit_in_hand") and card["play_limit_in_hand"] < 0:
		errors.append("%s.play_limit_in_hand: %d is below 0" % [path, card["play_limit_in_hand"]])
	if card.has("lasts"):
		errors.append_array(Shape.check_one_of(card["lasts"], LASTS, path + ".lasts"))
	if not card["id"].begins_with(card["owner"] + "_"):
		errors.append("%s.id: %s must start with its owner \"%s_\"" % [path, card["id"], card["owner"]])
	return errors
