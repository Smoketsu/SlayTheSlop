## Shared helpers for the content tests in tests/data/ (tasks 006, 008, 010, 014). Lane: tools
## (Agent B). Not a test file itself (its name does not start with test_).
##
## The slice's content was first written by Agent A as test fixtures, and the core's own tests play
## exactly those. The data files must stay identical to them, so each content test compares every
## data file with its fixture. If a fixture changes on purpose, change the data file in the same PR.
extends RefCounted

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")
const JsonValues := preload("res://core/schema/json_values.gd")


## Returns the real ruleset built from data/, or {} when it does not build (test_data_files.gd
## reports why).
static func real_ruleset() -> Dictionary:
	# built: the build result for the project's data/ folder.
	var built: Dictionary = Ruleset.build(DataFiles.read_all())
	return built["ruleset"] if built["ok"] else {}


## Returns one data file parsed (whole numbers as ints), or {} when it is missing or broken.
## path: the repo path, for example "data/cards/junk_burn.json".
static func load_file(path: String) -> Dictionary:
	# parsed: json_values.parse's result for the file's text.
	var parsed: Dictionary = JsonValues.parse(FileAccess.get_file_as_string("res://" + path))
	return parsed["value"] if parsed["ok"] and typeof(parsed["value"]) == TYPE_DICTIONARY else {}


## Returns a fixture value converted the way the data files are written: through JSON and back with
## json_values.parse, so ints stay ints and the comparison is strict.
## value: a fixture Dictionary from Agent A's tests.
static func as_data(value: Variant) -> Variant:
	return JsonValues.parse(JSON.stringify(value))["value"]


## Returns the file names (without .json) in one data folder, sorted.
## folder: the repo path, for example "data/cards".
static func ids_in(folder: String) -> Array[String]:
	# ids: collected names.
	var ids: Array[String] = []
	for file: String in DirAccess.get_files_at("res://" + folder):
		if file.ends_with(".json"):
			ids.append(file.trim_suffix(".json"))
	ids.sort()
	return ids
