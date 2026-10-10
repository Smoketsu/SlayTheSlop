## Checks data/constants.json against the GDD "Tuning constants" table. Lane: core (Agent A),
## because the rules core is the reader of these values.
##
## Values are NOT pinned here: tuning a number must not need a test change. What is checked is
## that every GDD name exists, has a usable value, and is documented.
extends "res://tests/framework/test_case.gd"

const JsonValues := preload("res://core/schema/json_values.gd")

## The constants file.
const PATH := "res://data/constants.json"

## Regex for a line that starts a top-level key in a two-space-indented JSON object: exactly two
## spaces, a quoted key (captured), optional spaces, then a colon. Shared by both key checkers.
const TOP_LEVEL_KEY_PATTERN := "^  \"([^\"]+)\"\\s*:"

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


## No constant name appears twice in the file. Godot's JSON parser silently keeps only the last of
## two equal keys, so a duplicate (for example from a git auto-merge that added the same constant in
## two places) would never be noticed by the other tests. Checked on the raw text.
func test_no_duplicate_constant_names() -> void:
	# names: every top-level key in the raw text, in file order. Top-level keys are the lines indented
	# by exactly two spaces that open an object or a string value.
	var names: Array[String] = duplicate_top_level_keys(FileAccess.get_file_as_string(PATH))
	assert_eq(names, [] as Array[String], "constant names defined more than once")


## The duplicate check really sees every constant. It reads only lines indented by exactly two
## spaces, so if the file were re-indented (tabs, four spaces) it would find no keys and pass
## silently. This fails instead: the raw text must show at least one top-level key line per key
## in the parsed file.
func test_duplicate_check_sees_every_key() -> void:
	# text: the raw file text, as the duplicate check reads it.
	var text: String = FileAccess.get_file_as_string(PATH)
	# key_lines: how many lines the duplicate check recognises as top-level keys.
	var key_lines: int = top_level_key_count(text)
	# parsed_keys: how many distinct top-level keys the parser found, comments ("_" keys) included.
	var parsed_keys: int = _load().size()
	assert_true(key_lines >= parsed_keys, "%s: the duplicate check saw %d top-level key lines but the file has %d keys; keep two-space indentation" % [PATH, key_lines, parsed_keys])


## The checker finds a key written twice and ignores nested keys with the same name.
func test_duplicate_checker_finds_repeats() -> void:
	# text: a small file with A twice at top level and "value" repeated only inside objects.
	var text: String = "{\n  \"A\": {\n    \"value\": 1\n  },\n  \"B\": {\n    \"value\": 2\n  },\n  \"A\": {\n    \"value\": 3\n  }\n}\n"
	assert_eq(duplicate_top_level_keys(text), ["A"] as Array[String])


## The key-line counter counts only two-space-indented keys, so a re-indented file counts zero.
func test_key_line_counter_ignores_other_indentation() -> void:
	# two_space: three top-level keys at two spaces, with nested keys at four.
	var two_space: String = "{\n  \"A\": {\n    \"value\": 1\n  },\n  \"B\": 2,\n  \"C\": 3\n}\n"
	# four_space: the same keys indented by four spaces, which the checker does not read.
	var four_space: String = "{\n    \"A\": 1,\n    \"B\": 2\n}\n"
	assert_eq(top_level_key_count(two_space), 3)
	assert_eq(top_level_key_count(four_space), 0)


## Returns how many lines of the text start a top-level key, by the same rule as
## duplicate_top_level_keys. Static so other tests can reuse it.
## text: the raw JSON text, formatted with two-space indentation (as data/constants.json is).
static func top_level_key_count(text: String) -> int:
	# key_line: a line that starts a top-level key: exactly two spaces, then a quoted key and a colon.
	var key_line: RegEx = RegEx.create_from_string(TOP_LEVEL_KEY_PATTERN)
	# count: key lines found so far.
	var count: int = 0
	for line: String in text.split("\n"):
		if key_line.search(line) != null:
			count += 1
	return count


## Returns, in first-repeat order, each top-level key of a two-space-indented JSON object that
## appears more than once. Static so other tests can reuse it.
## text: the raw JSON text, formatted with two-space indentation (as data/constants.json is).
static func duplicate_top_level_keys(text: String) -> Array[String]:
	# key_line: a line that starts a top-level key: exactly two spaces, then a quoted key and a colon.
	var key_line: RegEx = RegEx.create_from_string(TOP_LEVEL_KEY_PATTERN)
	# seen: keys found so far.
	var seen: Dictionary = {}
	# repeats: keys found a second time, each listed once.
	var repeats: Array[String] = []
	for line: String in text.split("\n"):
		# found: the match on this line, or null when it does not start a top-level key.
		var found: RegExMatch = key_line.search(line)
		if found == null:
			continue
		# key: the key's text.
		var key: String = found.get_string(1)
		if seen.has(key) and not repeats.has(key):
			repeats.append(key)
		seen[key] = true
	return repeats
