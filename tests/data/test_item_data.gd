## The slice's 13 Gear and 8 Brews as data (task 014). Lane: tools (Agent B).
## GDD "Items"; formats from task 021 (core/schema/gear_def.gd, brew_def.gd); G16, G26–G29.
extends "res://tests/framework/test_case.gd"

const Check := preload("res://tests/data/content_check.gd")
const ItemFixtures := preload("res://tests/core/items/item_fixtures.gd")


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


## Every Gear and Brew file is exactly the fixture the core's item tests play.
func test_items_match_the_core_fixtures() -> void:
	for id: String in ItemFixtures.GEAR:
		assert_eq(Check.load_file("data/gear/%s.json" % id), Check.as_data(ItemFixtures.GEAR[id]), "gear " + id)
	for id: String in ItemFixtures.BREWS:
		assert_eq(Check.load_file("data/brews/%s.json" % id), Check.as_data(ItemFixtures.BREWS[id]), "brew " + id)


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
