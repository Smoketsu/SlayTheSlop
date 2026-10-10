## The six Junk cards as data (task 008). Lane: tools (Agent B).
## GDD "Junk cards"; rarity "special" per G17; rules as built in task 015.
extends "res://tests/framework/test_case.gd"

const Check := preload("res://tests/data/content_check.gd")
const JunkFixtures := preload("res://tests/core/combat/junk_fixtures.gd")

## The GDD's Junk table: card id -> [name, cost, rules text].
const GDD := {
	"junk_hangover": ["Hangover", -1, "Unplayable. When drawn, lose 1 Hype"],
	"junk_regret": ["Regret", -1, "Unplayable. Cannot be removed at Baileys"],
	"junk_bedbugs": ["Bedbugs", -1, "Unplayable. When drawn, take 1 damage"],
	"junk_paperwork": ["Paperwork", 1, "Costs 1 Hype. Does nothing. Tapped"],
	"junk_detention": ["Detention", -1, "Unplayable. While it is in your hand, you can play at most 4 cards this turn"],
	"junk_burn": ["Burn", -1, "Unplayable. If it is in your hand at end of turn, take 2 damage"],
}


## Each Junk card file has the GDD's name, cost and text, owner and type junk, rarity special.
func test_junk_cards_match_the_gdd() -> void:
	for id: String in GDD:
		# card: the data file.
		var card: Dictionary = Check.load_file("data/cards/%s.json" % id)
		assert_false(card.is_empty(), "%s.json is missing" % id)
		if card.is_empty():
			continue
		assert_eq([card["name"], card["cost"], card.get("text", "")], GDD[id], id)
		assert_eq([card["owner"], card["type"], card["rarity"]], ["junk", "junk", "special"], id)


## Each Junk card's rules are exactly the fixture the core's Junk tests play (only "text" is added).
func test_junk_cards_match_the_core_fixtures() -> void:
	for id: String in JunkFixtures.JUNK:
		# card: the data file, without the display text the fixture lacks.
		var card: Dictionary = Check.load_file("data/cards/%s.json" % id)
		card.erase("text")
		assert_eq(card, Check.as_data(JunkFixtures.JUNK[id]), id)
