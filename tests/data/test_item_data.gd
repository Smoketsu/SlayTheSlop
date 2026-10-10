## The slice's 13 Gear and 8 Brews as data (task 014). Lane: tools (Agent B).
## GDD "Items"; formats from task 021 (core/schema/gear_def.gd, brew_def.gd); G16, G26–G29.
extends "res://tests/framework/test_case.gd"

const Check := preload("res://tests/data/content_check.gd")
const ItemFixtures := preload("res://tests/core/items/item_fixtures.gd")

## The Brews renamed so Baileys sells only Shake, never drinks (docs/proposals/brew-shake-names.md,
## decided by Person B, steamjgrube, 2026-10-10). Key: the Brew's id (never changes, saves refer to
## it). Value: its display name in data/brews/. Only Person B (content) changes these names; the
## other three Brews keep their GDD names.
const RENAMED_BREWS := {
	"light_beer": "Chill Nug",
	"energy_drink": "Wake and Bake",
	"protein_shake": "Gym Gummy",
	"shot_of_courage": "Hotbox",
	"hair_of_the_dog": "Morning Dab",
}

## Words no Brew name may contain, compared case-insensitively: each names a drink or a drinking
## term, and at Baileys every Brew is shown as Shake (CLAUDE.md: "Baileys sells weed, not drinks").
## "shake" is here too, so no Brew's own name is confused with the shop's "Shake" label (G29).
## Changed only by Person B (content).
const DRINK_WORDS: Array[String] = ["beer", "drink", "shot", "shake", "dog", "wine", "ale", "booze",
		"liquor", "brew"]


## data/gear/ and data/brews/ hold exactly the fixture sets, no more, no fewer.
func test_item_sets_are_complete() -> void:
	# gear_ids, brew_ids: the fixture ids, sorted.
	var gear_ids: Array = ItemFixtures.GEAR.keys()
	gear_ids.sort()
	var brew_ids: Array = ItemFixtures.BREWS.keys()
	brew_ids.sort()
	assert_eq(Check.ids_in("data/gear"), gear_ids, "Gear files")
	assert_eq(Check.ids_in("data/brews"), brew_ids, "Brew files")
	assert_eq(gear_ids.size(), 13, "13 slice Gear (G16)")
	assert_eq(brew_ids.size(), 8, "8 Brews")


## Every Gear file is exactly the fixture the core's item tests play. Every Brew file is that
## fixture except its display name: Brew names are Person B's content decision
## (docs/proposals/brew-shake-names.md), while Agent A's core fixture keeps the GDD's names, and a
## name has no effect on the rules.
func test_items_match_the_core_fixtures() -> void:
	for id: String in ItemFixtures.GEAR:
		assert_eq(Check.load_file("data/gear/%s.json" % id), Check.as_data(ItemFixtures.GEAR[id]), "gear " + id)
	for id: String in ItemFixtures.BREWS:
		# file, fixture: the Brew's data file and its fixture, each without "name".
		var file: Dictionary = Check.load_file("data/brews/%s.json" % id)
		var fixture: Dictionary = Check.as_data(ItemFixtures.BREWS[id])
		file.erase("name")
		fixture.erase("name")
		assert_eq(file, fixture, "brew " + id + " (all but its name)")


## No Brew is named for a drink: Baileys sells weed, not drinks, and shows every Brew as Shake.
func test_brews_are_not_drinks() -> void:
	for id: String in Check.ids_in("data/brews"):
		# brew_name: the Brew's display name, lower-cased for the comparison.
		var brew_name: String = str(Check.load_file("data/brews/%s.json" % id).get("name", "")).to_lower()
		assert_false(brew_name.is_empty(), "brew %s has a name" % id)
		for word: String in DRINK_WORDS:
			assert_false(brew_name.contains(word), "brew %s's name \"%s\" contains \"%s\"" % [id, brew_name, word])


## The five renamed Brews carry exactly the names Person B chose; their ids are unchanged.
func test_renamed_brews_have_their_new_names() -> void:
	for id: String in RENAMED_BREWS:
		assert_eq(Check.load_file("data/brews/%s.json" % id).get("name", ""), RENAMED_BREWS[id], "brew " + id)


## Player-facing item text uses the current themed terms: Medical Card (not Fake ID), Dolla Bills
## (not Beer Money).
func test_item_text_uses_current_names() -> void:
	for folder: String in ["data/gear", "data/brews"]:
		for id: String in Check.ids_in(folder):
			# text: the name and rules text together.
			var item: Dictionary = Check.load_file("%s/%s.json" % [folder, id])
			var text: String = "%s %s" % [item.get("name", ""), item.get("text", "")]
			for old: String in ["Fake ID", "Beer Money"]:
				assert_false(text.contains(old), "%s/%s says %s" % [folder, id, old])
	assert_eq(Check.load_file("data/gear/medical_card.json").get("name", ""), "Medical Card")
