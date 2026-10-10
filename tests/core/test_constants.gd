## Checks data/constants.json against the GDD "Tuning constants" table. Lane: core (Agent A),
## because the rules core is the reader of these values.
##
## Values are NOT pinned here: tuning a number must not need a test change. What is checked is
## that every GDD name exists, has a usable value, and is documented.
extends "res://tests/framework/test_case.gd"

const JsonValues := preload("res://core/schema/json_values.gd")

## The constants file.
const PATH := "res://data/constants.json"

## Every constant name in the GDD "Tuning constants" table and "Fields added for Ethan".
const GDD_NAMES: Array[String] = [
	"BASE_HYPE", "BASE_DRAW", "EXPOSED_MULT", "NOODLE_MULT", "HUNGOVER_MULT",
	"BROKEN_ARM_MAX_REDUCTION", "ICK_BASE_NORMAL", "ICK_BASE_RIVAL", "ICK_BASE_BOSS",
	"ICK_THRESHOLD_STEP", "BRO_METER_MAX", "HP_SCALE_PER_EXTRA_PLAYER", "EXTRA_ENEMY_PARTY_SIZE",
	"MULTI_TARGET_PARTY_SIZE", "REVIVE_HP_FRACTION", "TURN_TIMER_SECONDS", "REJOIN_GRACE_SECONDS",
	"SCAFFOLDING_MAX", "NAP_WAKE_ON_ASSIST",
]


## Returns the parsed constants file, or {} after recording a failure.
func _load() -> Dictionary:
	# parsed: the parse result of the file's text.
	var parsed: Dictionary = JsonValues.parse(FileAccess.get_file_as_string(PATH))
	assert_true(parsed["ok"], "%s does not parse: %s" % [PATH, parsed["error"]])
	return parsed["value"] if parsed["ok"] else {}


## Every GDD constant is present.
func test_every_gdd_constant_exists() -> void:
	# constants: the parsed file.
	var constants: Dictionary = _load()
	for name: String in GDD_NAMES:
		assert_true(constants.has(name), "%s is missing from %s" % [name, PATH])


## Every entry is {value, unit, meaning}, the value is a number or bool, and the docs are non-empty.
## Keys starting with "_" are comments and are skipped.
func test_every_constant_is_documented() -> void:
	# constants: the parsed file.
	var constants: Dictionary = _load()
	for name: String in constants.keys():
		if name.begins_with("_"):
			continue
		# entry: one constant's record.
		var entry: Variant = constants[name]
		if typeof(entry) != TYPE_DICTIONARY:
			fail("%s: expected {value, unit, meaning}" % name)
			continue
		assert_eq(entry.keys().size(), 3, "%s: fields must be exactly value, unit, meaning" % name)
		assert_true([TYPE_INT, TYPE_FLOAT, TYPE_BOOL].has(typeof(entry.get("value"))), "%s: value must be a number or bool" % name)
		for field: String in ["unit", "meaning"]:
			assert_true(typeof(entry.get(field)) == TYPE_STRING and entry[field] != "", "%s: %s must be non-empty text" % [name, field])
		assert_true(name == name.to_upper(), "%s: constant names are UPPER_SNAKE_CASE" % name)


## Whole-number constants load as ints, so the rules can use them in integer math.
func test_whole_numbers_load_as_ints() -> void:
	# constants: the parsed file.
	var constants: Dictionary = _load()
	for name: String in ["BASE_HYPE", "BASE_DRAW", "ICK_BASE_NORMAL", "BRO_METER_MAX"]:
		if constants.has(name):
			assert_eq(typeof(constants[name]["value"]), TYPE_INT, "%s must load as an int" % name)
