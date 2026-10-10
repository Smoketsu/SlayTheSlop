## Shape of a Dude definition, one JSON file per Dude in data/dudes/. Shared contract. [added]
##
## The GDD gives each Dude's numbers in prose tables ("Tom, the Enforcer"); this is where they
## live as data, so nothing outside a Dude's data files needs to know which Dude is playing.
##
## Who may change definitions: the content lane. Who may change this shape: a contract PR.
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")

## Required fields and their types.
const SPEC := {
	# Unique key, equal to the file name without ".json" and to the card owner name, for example "tom".
	"id": TYPE_STRING,
	# Display name, for example "Tom".
	"name": TYPE_STRING,
	# Title shown after the name, for example "the Enforcer".
	"title": TYPE_STRING,
	# Max HP at the start of a run (GDD attribute table). Tom: 80.
	"max_hp": TYPE_INT,
	# Card ids of the starter deck, one entry per copy, for example four "tom_punch".
	"starter_deck": {"list_of": TYPE_STRING},
	# Gear ids the Dude starts with, for example ["tom_unused_gym_membership"].
	"starting_gear": {"list_of": TYPE_STRING},
	# Card id of the Dude's Bro Move, defined as a card in data/cards/ with cost 0.
	"bro_move": TYPE_STRING,
}


## Checks a Dude definition. Returns a list of problems; empty means valid.
## dude: the parsed definition. path: label for messages, usually the file path.
static func check(dude: Variant, path: String = "dude") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(dude, SPEC, path)
	if errors.is_empty() and dude["max_hp"] < 1:
		errors.append("%s.max_hp: must be 1 or more" % path)
	return errors
