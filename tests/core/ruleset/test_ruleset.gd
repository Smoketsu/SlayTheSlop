## Tests for core/ruleset/ruleset.gd, the builder that turns content text into the read-only
## ruleset (task 005). Lane: core (Agent A).
##
## Most tests use in-memory text, so they do not depend on what content has been merged.
## One test reads the real data/constants.json from disk; tests may read files, the core may not.
extends "res://tests/framework/test_case.gd"

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const JsonValues := preload("res://core/schema/json_values.gd")

## The real constants file on disk, read by the one test that uses it.
const CONSTANTS_FILE := "res://data/constants.json"


## Returns a small valid set of content, as parsed values keyed by repo path.
## Tests change a copy of it, then turn it into text with _texts().
func _values() -> Dictionary:
	return {
		"data/constants.json": {
			"_doc": "A comment entry; the builder must skip it.",
			"BASE_HYPE": {"value": 3, "unit": "Hype per turn", "meaning": "Hype per turn before Gear."},
			"EXPOSED_MULT": {"value": 1.5, "unit": "multiplier", "meaning": "Damage multiplier against an Exposed target."},
			"NAP_WAKE_ON_ASSIST": {"value": true, "unit": "true or false", "meaning": "Whether an Assist wakes Ethan."},
		},
		"data/cards/tom_punch.json": {"id": "tom_punch", "name": "Punch", "owner": "tom", "type": "attack",
			"rarity": "starter", "cost": 1, "target": "enemy", "effects": [{"op": "damage", "amount": 6, "hits": 1}],
			"keywords": [], "crunch": null, "upgrade": {"effects[0].amount": 9}},
		"data/cards/tom_chest_bump.json": {"id": "tom_chest_bump", "name": "Chest Bump", "owner": "tom", "type": "skill",
			"rarity": "starter", "cost": 0, "target": "self", "effects": [{"op": "gain_guard", "amount": 10}],
			"keywords": [], "crunch": null, "upgrade": {}},
		"data/enemies/goblin_pledge.json": {"id": "goblin_pledge", "name": "Goblin Pledge", "floor": 1, "tier": "normal",
			"max_hp": 12, "arm_count": 2,
			"moves": [{"id": "hit", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 5, "hits": 1}]}]},
		"data/dudes/tom.json": {"id": "tom", "name": "Tom", "title": "the Enforcer", "max_hp": 80,
			"starter_deck": ["tom_punch", "tom_punch"], "starting_gear": ["tom_unused_gym_membership"],
			"bro_move": "tom_chest_bump"},
	}


## Turns parsed values keyed by path into the text map build() takes.
## values: repo path -> JSON-shaped value; each becomes JSON text.
func _texts(values: Dictionary) -> Dictionary:
	# files: repo path -> JSON text.
	var files: Dictionary = {}
	for path: String in values.keys():
		files[path] = JSON.stringify(values[path], "  ")
	return files


## Records a failure unless one error starts with path + ": " and contains fragment.
## errors: build()'s error list. path: the file the error must be about.
## fragment: text the error must contain; "" accepts any error about path.
func _assert_error(errors: Array, path: String, fragment: String) -> void:
	for message: String in errors:
		if message.begins_with(path + ": ") and (fragment == "" or message.contains(fragment)):
			return
	fail("no error for %s containing \"%s\" in %s" % [path, fragment, str(errors)])


## Records a failure for every Dictionary or Array inside value (value included) that is writable.
## value: the value to walk. where: its location, for messages.
func _assert_read_only(value: Variant, where: String) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			assert_true(value.is_read_only(), "%s is writable" % where)
			for key: Variant in value.keys():
				_assert_read_only(value[key], "%s.%s" % [where, str(key)])
		TYPE_ARRAY:
			assert_true(value.is_read_only(), "%s is writable" % where)
			for i: int in value.size():
				_assert_read_only(value[i], "%s[%d]" % [where, i])


## A valid set builds: every kind is keyed by id, definitions are unchanged, constants hold values only.
func test_valid_set_builds() -> void:
	# values: the valid content, kept to compare against the result.
	var values: Dictionary = _values()
	# result: what build() returned.
	var result: Dictionary = Ruleset.build(_texts(values))
	assert_true(result["ok"], "valid set must build")
	assert_eq(result["errors"], [] as Array[String], "errors")
	# ruleset: the built ruleset.
	var ruleset: Dictionary = result["ruleset"]
	assert_eq(ruleset["constants"], {"BASE_HYPE": 3, "EXPOSED_MULT": 1.5, "NAP_WAKE_ON_ASSIST": true}, "constants")
	assert_eq(ruleset["cards"], {
		"tom_punch": values["data/cards/tom_punch.json"],
		"tom_chest_bump": values["data/cards/tom_chest_bump.json"],
	}, "cards")
	assert_eq(ruleset["enemies"], {"goblin_pledge": values["data/enemies/goblin_pledge.json"]}, "enemies")
	assert_eq(ruleset["dudes"], {"tom": values["data/dudes/tom.json"]}, "dudes")


## Fixed case: whole-number constants come out as ints and multipliers as floats, so the core can
## do integer math and only multiply where the GDD's damage order says.
func test_constant_value_types() -> void:
	# ruleset: a built valid ruleset.
	var ruleset: Dictionary = Ruleset.build(_texts(_values()))["ruleset"]
	assert_eq(typeof(ruleset["constants"]["BASE_HYPE"]), TYPE_INT, "BASE_HYPE")
	assert_eq(typeof(ruleset["constants"]["EXPOSED_MULT"]), TYPE_FLOAT, "EXPOSED_MULT")
	assert_eq(typeof(ruleset["constants"]["NAP_WAKE_ON_ASSIST"]), TYPE_BOOL, "NAP_WAKE_ON_ASSIST")
	assert_eq(ruleset["cards"]["tom_punch"]["cost"], 1, "a card's cost must be an int after parsing")


## Every Dictionary and Array in the ruleset is read-only, nested ones included (make_read_only()
## alone is shallow). Checked with is_read_only(), because an actual write raises an engine error.
func test_ruleset_is_read_only_at_every_level() -> void:
	# ruleset: a built valid ruleset.
	var ruleset: Dictionary = Ruleset.build(_texts(_values()))["ruleset"]
	_assert_read_only(ruleset, "ruleset")
	# deepest: an effect inside a card, three containers down, checked by name so the walk above
	# cannot pass by skipping it.
	var deepest: Dictionary = ruleset["cards"]["tom_punch"]["effects"][0]
	assert_true(deepest.is_read_only(), "card effect must be read-only")
	assert_true(ruleset["cards"]["tom_punch"]["effects"].is_read_only(), "effects list must be read-only")


## freeze() reaches every level of a nested value.
func test_freeze_is_deep() -> void:
	# value: nested Dictionaries and Arrays, writable before freeze().
	var value: Dictionary = {"a": [1, {"b": [2, 3]}], "c": {"d": {}}}
	Ruleset.freeze(value)
	_assert_read_only(value, "value")


## Invalid JSON is reported with the file path and the parser's line.
func test_invalid_json_is_reported() -> void:
	# files: the valid set with one card's text broken.
	var files: Dictionary = _texts(_values())
	files["data/cards/tom_punch.json"] = '{"id": }'
	# result: what build() returned.
	var result: Dictionary = Ruleset.build(files)
	assert_false(result["ok"], "broken JSON must fail")
	_assert_error(result["errors"], "data/cards/tom_punch.json", "line ")


## A definition that fails its schema is reported with the file path, for each kind.
func test_schema_errors_are_reported() -> void:
	# values: the valid set broken once per kind.
	var values: Dictionary = _values()
	values["data/cards/tom_punch.json"]["cost"] = "y"
	values["data/enemies/goblin_pledge.json"]["max_hp"] = 0
	values["data/dudes/tom.json"].erase("title")
	# errors: what build() found.
	var errors: Array = Ruleset.build(_texts(values))["errors"]
	_assert_error(errors, "data/cards/tom_punch.json", "card.cost")
	_assert_error(errors, "data/enemies/goblin_pledge.json", "enemy.max_hp")
	_assert_error(errors, "data/dudes/tom.json", "dude.title: missing")


## A float where the schema wants an int is caught after parsing (1.5 stays a float).
func test_float_in_int_field_is_reported() -> void:
	# values: the valid set with a fractional enemy HP.
	var values: Dictionary = _values()
	values["data/enemies/goblin_pledge.json"]["max_hp"] = 12.5
	_assert_error(Ruleset.build(_texts(values))["errors"], "data/enemies/goblin_pledge.json", "enemy.max_hp: expected int")


## The id must equal the file name.
func test_id_must_equal_file_name() -> void:
	# files: the valid set with an enemy stored under the wrong file name.
	var files: Dictionary = _texts(_values())
	files["data/enemies/pledge.json"] = files["data/enemies/goblin_pledge.json"]
	files.erase("data/enemies/goblin_pledge.json")
	# result: what build() returned.
	var result: Dictionary = Ruleset.build(files)
	assert_false(result["ok"], "id mismatch must fail")
	_assert_error(result["errors"], "data/enemies/pledge.json", "must equal the file name \"pledge\"")


## Two files with the same id are reported, naming the file that used it first.
func test_duplicate_ids_are_reported() -> void:
	# files: the valid set plus a second card file whose id is tom_punch.
	var files: Dictionary = _texts(_values())
	files["data/cards/tom_punch_copy.json"] = files["data/cards/tom_punch.json"]
	# errors: what build() found.
	var errors: Array = Ruleset.build(files)["errors"]
	_assert_error(errors, "data/cards/tom_punch_copy.json", "duplicate id \"tom_punch\", already used by data/cards/tom_punch.json")
	_assert_error(errors, "data/cards/tom_punch_copy.json", "must equal the file name")


## Files outside the known folders are errors: an unknown kind (Gear has no format yet), a
## sub-folder, a file outside data/, and a file without the .json extension.
func test_unknown_folders_and_files_are_reported() -> void:
	# files: the valid set plus four files the builder must refuse.
	var files: Dictionary = _texts(_values())
	files["data/gear/tom_unused_gym_membership.json"] = '{"id": "tom_unused_gym_membership"}'
	files["data/cards/old/tom_kick.json"] = "{}"
	files["docs/tom.json"] = "{}"
	files["data/cards/tom_punch.txt"] = "{}"
	# errors: what build() found.
	var errors: Array = Ruleset.build(files)["errors"]
	_assert_error(errors, "data/gear/tom_unused_gym_membership.json", "not in a known data folder")
	_assert_error(errors, "data/cards/old/tom_kick.json", "not in a known data folder")
	_assert_error(errors, "docs/tom.json", "not in a known data folder")
	_assert_error(errors, "data/cards/tom_punch.txt", "must end in .json")
	assert_eq(errors.size(), 4, "exactly the four bad files: %s" % str(errors))


## Every ruleset needs data/constants.json.
func test_missing_constants_file_is_reported() -> void:
	# files: the valid set without its constants.
	var files: Dictionary = _texts(_values())
	files.erase("data/constants.json")
	_assert_error(Ruleset.build(files)["errors"], "data/constants.json", "missing")


## A constants file that is not an object, an entry with no value, and a text value are reported.
func test_bad_constants_are_reported() -> void:
	# files: the valid set with constants text replaced, three ways.
	var files: Dictionary = _texts(_values())
	files["data/constants.json"] = "[1, 2]"
	_assert_error(Ruleset.build(files)["errors"], "data/constants.json", "expected a JSON object")
	files["data/constants.json"] = JSON.stringify({"BASE_HYPE": 3, "BASE_DRAW": {"value": "five"}})
	# errors: what build() found in the second version.
	var errors: Array = Ruleset.build(files)["errors"]
	_assert_error(errors, "data/constants.json", "BASE_HYPE: expected {value, unit, meaning}")
	_assert_error(errors, "data/constants.json", "BASE_DRAW: value must be a number or true/false")


## A Dude's starter_deck and bro_move must name cards that exist.
func test_broken_dude_references_are_reported() -> void:
	# values: the valid set with Tom pointing at two cards that do not exist.
	var values: Dictionary = _values()
	values["data/dudes/tom.json"]["starter_deck"] = ["tom_punch", "tom_kick"]
	values["data/dudes/tom.json"]["bro_move"] = "tom_backflip"
	# result: what build() returned.
	var result: Dictionary = Ruleset.build(_texts(values))
	assert_false(result["ok"], "broken references must fail")
	_assert_error(result["errors"], "data/dudes/tom.json", "starter_deck[1]: card \"tom_kick\"")
	_assert_error(result["errors"], "data/dudes/tom.json", "bro_move: card \"tom_backflip\"")
	assert_eq(result["errors"].size(), 2, "only the two bad references: %s" % str(result["errors"]))


## A reference to a card whose own file is broken is reported as well as the broken card.
func test_reference_to_invalid_card_is_reported() -> void:
	# values: the valid set with the Bro Move card failing its schema.
	var values: Dictionary = _values()
	values["data/cards/tom_chest_bump.json"]["target"] = "everyone"
	# errors: what build() found.
	var errors: Array = Ruleset.build(_texts(values))["errors"]
	_assert_error(errors, "data/cards/tom_chest_bump.json", "card.target")
	_assert_error(errors, "data/dudes/tom.json", "bro_move: card \"tom_chest_bump\"")


## starting_gear is NOT checked yet: no Gear format exists until task 021. This test pins that
## gap so task 021 changes it on purpose (it should then expect an error here).
func test_starting_gear_is_not_checked_yet() -> void:
	# values: the valid set, whose Tom names a Gear id that no file defines.
	var values: Dictionary = _values()
	values["data/dudes/tom.json"]["starting_gear"] = ["no_such_gear"]
	assert_true(Ruleset.build(_texts(values))["ok"], "unknown Gear ids are accepted until task 021")


## Every problem in every file comes back from one call, and a failed build returns no ruleset.
func test_all_errors_are_collected_together() -> void:
	# files: the valid set broken in four different files.
	var files: Dictionary = _texts(_values())
	files["data/cards/tom_punch.json"] = "not json"
	files["data/enemies/goblin_pledge.json"] = "{}"
	files["data/gear/x.json"] = "{}"
	files["data/constants.json"] = "7"
	# result: what build() returned.
	var result: Dictionary = Ruleset.build(files)
	assert_false(result["ok"], "broken set must fail")
	assert_eq(result["ruleset"], {}, "no ruleset from a broken set")
	assert_true(result["ruleset"].is_read_only(), "even the empty ruleset is read-only")
	for path: String in ["data/cards/tom_punch.json", "data/enemies/goblin_pledge.json", "data/gear/x.json",
			"data/constants.json", "data/dudes/tom.json"]:
		_assert_error(result["errors"], path, "")


## Non-String paths and non-String text are reported instead of crashing.
func test_bad_input_types_are_reported() -> void:
	# files: the valid set plus an int key and a card whose text is not a String.
	var files: Dictionary = _texts(_values())
	files[7] = "{}"
	files["data/cards/tom_jab.json"] = {"id": "tom_jab"}
	# errors: what build() found.
	var errors: Array = Ruleset.build(files)["errors"]
	_assert_error(errors, "7", "file path must be a String")
	_assert_error(errors, "data/cards/tom_jab.json", "file text must be a String")


## Fixed input gives the same result every time, whatever order the caller inserted the files in,
## including the order of ids inside each map.
func test_build_is_deterministic() -> void:
	# forward: the valid text map.
	var forward: Dictionary = _texts(_values())
	# backward: the same files inserted in reverse order.
	var backward: Dictionary = {}
	# paths: forward's paths, reversed.
	var paths: Array = forward.keys()
	paths.reverse()
	for path: String in paths:
		backward[path] = forward[path]
	# a: the result for forward.
	var a: Dictionary = Ruleset.build(forward)
	# b: the result for backward.
	var b: Dictionary = Ruleset.build(backward)
	assert_eq(a, b, "same files, different insertion order")
	assert_eq(a["ruleset"]["cards"].keys(), b["ruleset"]["cards"].keys(), "card id order")
	assert_eq(var_to_bytes(a["ruleset"]), var_to_bytes(b["ruleset"]), "byte-identical ruleset")


## The real data/constants.json, read from disk, builds a ruleset on its own. Values are not
## pinned (tuning must not need a test change), but types are: the GDD's whole numbers are ints
## and its multipliers and fractions are floats.
func test_real_constants_file_builds() -> void:
	# text: the constants file as committed.
	var text: String = FileAccess.get_file_as_string(CONSTANTS_FILE)
	assert_ne(text, "", "%s could not be read" % CONSTANTS_FILE)
	# result: the ruleset built from the constants file alone.
	var result: Dictionary = Ruleset.build({"data/constants.json": text})
	assert_no_errors(result["errors"], "real constants")
	# constants: the built constants map.
	var constants: Dictionary = result["ruleset"].get("constants", {})
	# raw: the file parsed directly, to check no constant was dropped.
	var raw: Dictionary = JsonValues.parse(text)["value"]
	for name: String in raw.keys():
		if not name.begins_with("_"):
			assert_true(constants.has(name), "%s missing from the ruleset" % name)
	assert_false(constants.has("_doc"), "_doc must be skipped")
	for name: String in ["BASE_HYPE", "BASE_DRAW", "ICK_BASE_NORMAL", "ICK_THRESHOLD_STEP", "BRO_METER_MAX"]:
		assert_eq(typeof(constants.get(name)), TYPE_INT, "%s must be an int" % name)
	for name: String in ["EXPOSED_MULT", "NOODLE_MULT", "HUNGOVER_MULT", "BROKEN_ARM_MAX_REDUCTION",
			"HP_SCALE_PER_EXTRA_PLAYER", "REVIVE_HP_FRACTION"]:
		assert_eq(typeof(constants.get(name)), TYPE_FLOAT, "%s must be a float" % name)
	assert_eq(typeof(constants.get("NAP_WAKE_ON_ASSIST")), TYPE_BOOL, "NAP_WAKE_ON_ASSIST must be a bool")
	assert_eq(result["ruleset"].get("cards"), {}, "no cards from constants alone")
