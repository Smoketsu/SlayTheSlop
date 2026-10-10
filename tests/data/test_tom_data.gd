## Tom as data: his 14 GDD cards, Chest Bump and tom.json (task 006). Lane: tools (Agent B).
## GDD "Tom, the Enforcer", "Bro Meter", "Example card definition"; G15, G17, G33.
extends "res://tests/framework/test_case.gd"

const Check := preload("res://tests/data/content_check.gd")
const TomFixtures := preload("res://tests/core/ops/tom_fixtures.gd")

## The GDD's example card definition, exactly ("Example card definition"). The data file may add
## only "text".
const GDD_ARM_BAR := {
	"id": "tom_arm_bar", "name": "Arm Bar", "owner": "tom", "type": "attack", "rarity": "starter",
	"cost": 2, "target": "enemy",
	"effects": [{"op": "damage", "amount": 8, "hits": 1}, {"op": "apply_status", "status": "broken_arm", "stacks": 1}],
	"keywords": [], "crunch": null, "upgrade": {"effects[0].amount": 11},
}


## tom.json: 80 HP, the GDD starter deck, Unused Gym Membership, Chest Bump.
func test_tom_dude_file() -> void:
	# tom: the Dude file.
	var tom: Dictionary = Check.load_file("data/dudes/tom.json")
	assert_eq(tom.get("max_hp"), 80)
	assert_eq(tom.get("starter_deck"), ["tom_punch", "tom_punch", "tom_punch", "tom_punch",
		"tom_flex", "tom_flex", "tom_flex", "tom_flex", "tom_arm_bar", "tom_well_actually"], "4 Punch, 4 Flex, 1 Arm Bar, 1 Well, Actually")
	assert_eq(tom.get("starting_gear"), ["tom_unused_gym_membership"])
	assert_eq(tom.get("bro_move"), "tom_chest_bump")


## Arm Bar matches the GDD's example card exactly, plus its text.
func test_arm_bar_is_the_gdd_example() -> void:
	# card: the data file without its display text.
	var card: Dictionary = Check.load_file("data/cards/tom_arm_bar.json")
	assert_eq(card.get("text", ""), "Deal 8 damage. Break 1 arm")
	card.erase("text")
	assert_eq(card, Check.as_data(GDD_ARM_BAR))


## Every Tom card is exactly the fixture the core's Tom tests play, with ids renamed from
## tom_test_* to tom_*, and Chest Bump's rarity "special" (G17: Bro Moves are never offered).
func test_tom_cards_match_the_core_fixtures() -> void:
	# ids: the 15 Tom card ids in the fixtures (14 GDD cards and Chest Bump).
	var ids: Array[String] = []
	for fixture_id: String in TomFixtures.CARDS:
		if not fixture_id.begins_with("tom_test_"):
			continue
		# expected: the fixture as data, renamed.
		var expected: Dictionary = Check.as_data(JSON.parse_string(JSON.stringify(TomFixtures.CARDS[fixture_id]).replace("tom_test_", "tom_")))
		if expected["id"] == "tom_chest_bump":
			expected["rarity"] = "special"
		ids.append(expected["id"])
		assert_eq(Check.load_file("data/cards/%s.json" % expected["id"]), expected, expected["id"])
	assert_eq(ids.size(), 15, "14 GDD cards and Chest Bump")


## Only Arm Bar has an upgrade until task 012's proposal is answered (G15).
func test_only_arm_bar_upgrades() -> void:
	for id: String in Check.ids_in("data/cards"):
		if id.begins_with("tom_") and id != "tom_arm_bar":
			assert_eq(Check.load_file("data/cards/%s.json" % id).get("upgrade"), {}, id)
