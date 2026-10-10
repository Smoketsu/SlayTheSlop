## Shape of a Brew definition, one JSON file per Brew in data/brews/ (GDD "Items": Brews).
## Shared contract. [added, task 021: the GDD has no Brew field table]
##
## A Brew is a single-use item held in a Brew slot. Drinking it is the use_brew request: it costs no
## Hype, can be done at any point in the player phase, empties the slot and adds 1 to brews_drunk.
## Its effects are effect operations like a card's (core/ops/README.md). This file checks the outer
## shape only; whether an op exists and has the right fields is the core lane's check.
##
## At Baileys every Brew is sold under the shop label "Shake" (GDD "Prices at Baileys", G29). That is
## the shop's display only: the definition keeps the Brew's own name and is a normal Brew in a slot.
##
## Solo variants: a Brew whose GDD text has a "Solo:" rule (Smelling Salts) puts it in "solo". The
## core uses "solo" instead of target and effects when party_size is 1, so the data never assumes
## how many Dudes there are.
##
## Example (GDD "Brews"):
##   {"id": "light_beer", "name": "Light Beer", "rarity": "common", "text": "Heal 10 HP.",
##    "target": "self", "effects": [{"op": "heal", "amount": 10}]}
##
## Who may change definitions: the content lane. Who may change this shape: a contract PR.
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")

## Rarities, from the GDD Brews table. Set the Shake price at Baileys (G21).
const RARITIES: Array[String] = ["common", "uncommon", "rare"]

## What the player must select when drinking it (request use_brew target_id), and who the effects
## land on:
##   none:        nothing selected; effects that need targets have none (target_id "").
##   self:        the drinker (target_id "" or the drinker's own player_id).
##   enemy:       one enemy still in the fight (target_id = its uid).
##   all_enemies: every enemy in the fight (target_id "").
##   all_dudes:   every Dude who is not Passed Out, in seat order (target_id ""). Party Bowl.
##   ally:        a teammate (Smelling Salts in co-op). Not built yet: refused as bad_target.
const TARGETS: Array[String] = ["none", "self", "enemy", "all_enemies", "all_dudes", "ally"]

## Required fields and their types.
const SPEC := {
	# Unique key, snake_case, equal to the file name without ".json", for example "light_beer". Never changes after merge.
	"id": TYPE_STRING,
	# Name shown to players, for example "Light Beer". May change freely; Baileys shows it under "Shake".
	"name": TYPE_STRING,
	# One of RARITIES.
	"rarity": TYPE_STRING,
	# Rules text shown to players, in the GDD's wording (both the co-op and the solo rule, if it has one).
	"text": TYPE_STRING,
	# One of TARGETS: what is selected and who the effects land on.
	"target": TYPE_STRING,
	# Effect operations run in order, each a Dictionary with at least a String "op", as on a card.
	"effects": {"list_of": TYPE_DICTIONARY},
}

## Fields that may be left out.
const OPTIONAL := {
	# The GDD's "Solo:" rule, used instead of target and effects when party_size is 1 (see SOLO_SPEC).
	# Absent: the Brew works the same at every party size.
	"solo": TYPE_DICTIONARY,
}

## Shape of "solo".
const SOLO_SPEC := {
	# One of TARGETS, used in solo play instead of the Brew's target.
	"target": TYPE_STRING,
	# Effect operations used in solo play instead of the Brew's effects.
	"effects": {"list_of": TYPE_DICTIONARY},
}


## Checks a Brew definition. Returns a list of problems; empty means valid.
## brew: the parsed definition (after json_values.parse). path: label for messages, usually the file path.
static func check(brew: Variant, path: String = "brew") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(brew, SPEC, path, OPTIONAL)
	if not errors.is_empty():
		return errors
	errors.append_array(Shape.check_one_of(brew["rarity"], RARITIES, path + ".rarity"))
	errors.append_array(_check_use(brew, path))
	if brew.has("solo"):
		# solo_errors: shape problems with the solo variant.
		var solo_errors: Array[String] = Shape.check(brew["solo"], SOLO_SPEC, path + ".solo")
		errors.append_array(solo_errors)
		if solo_errors.is_empty():
			errors.append_array(_check_use(brew["solo"], path + ".solo"))
	return errors


## Checks a target and effects pair (the Brew's own, or its solo variant).
## use: a Dictionary with a String "target" and an Array "effects". path: label for messages.
static func _check_use(use: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check_one_of(use["target"], TARGETS, path + ".target")
	for i: int in use["effects"].size():
		if typeof(use["effects"][i].get("op")) != TYPE_STRING:
			errors.append("%s.effects[%d]: missing String \"op\"" % [path, i])
	return errors
