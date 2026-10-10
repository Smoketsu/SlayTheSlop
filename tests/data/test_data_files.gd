## Checks every content file under data/ on every test run (task 004; Side Quests, task 016). Lane:
## tools (Agent B).
##
## The checks themselves live in core/ruleset/ruleset.gd build() (task 005): JSON parsing, each
## kind's schema check, id equal to the file name, unique ids, card ids starting with their owner,
## unknown folders and files, and Dude references to cards. This file runs them on the real data, so
## a content PR with a mistake fails CI, and proves the failures name the broken file.
extends "res://tests/framework/test_case.gd"

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")
const JsonValues := preload("res://core/schema/json_values.gd")

## A card file that is not valid JSON (missing closing brace).
const BROKEN_JSON := "{\"id\": \"tom_broken\""
## A real Side Quest file, copied into a temporary folder with a bad operation (task 016).
const SIDE_QUEST_FILE := "data/side_quests/beer_pong_table.json"
## Side Quest operations build() must refuse: an op that does not exist, and a card id that does not.
const BAD_SIDE_QUEST_EFFECTS: Array[Dictionary] = [
	{"op": "summon_kegs"},
	{"op": "add_card", "card_id": "junk_nope"},
]


## The real data/ folder builds into a ruleset with no errors.
func test_real_data_is_valid() -> void:
	# built: the build result for every file in the project's data/ folder.
	var built: Dictionary = Ruleset.build(DataFiles.read_all())
	assert_no_errors(built["errors"], "data/ has problems")
	assert_true(built["ok"], "data/ did not build")


## The reader returns repo-relative paths in sorted order, including constants.json.
func test_reader_returns_sorted_repo_paths() -> void:
	# files: every file in the project's data/ folder.
	var files: Dictionary = DataFiles.read_all()
	assert_true(files.has("data/constants.json"), "data/constants.json is missing from %s" % [files.keys()])
	# keys: the paths in the order the reader returned them.
	var keys: Array = files.keys()
	# sorted: the same paths sorted.
	var sorted: Array = keys.duplicate()
	sorted.sort()
	assert_eq(keys, sorted, "paths are in sorted order")
	for path: String in keys:
		assert_true(path.begins_with("data/") and not path.contains("res://"), "repo-relative path: %s" % path)
	assert_eq(files["data/constants.json"], FileAccess.get_file_as_string("res://data/constants.json"), "text is read unchanged")


## A broken file in a temporary data folder fails the build, and the error names that file.
func test_broken_file_is_reported_with_its_path() -> void:
	# root: a temporary folder holding a copy of constants.json and one broken card.
	var root: String = _temp_root({"data/cards/tom_broken.json": BROKEN_JSON})
	# built: the build result for the temporary folder.
	var built: Dictionary = Ruleset.build(DataFiles.read_all(root))
	_remove(root)
	assert_false(built["ok"], "a broken file must fail the build")
	assert_true(built["errors"].any(func(e: String) -> bool: return e.begins_with("data/cards/tom_broken.json")),
		"an error starts with the broken file's path: %s" % [built["errors"]])


## A Side Quest file with an unknown operation or a Junk card that does not exist fails the build, and
## the error names that file (task 016: data/side_quests/ is covered like every other folder).
func test_bad_side_quest_is_reported_with_its_path() -> void:
	# control: the unchanged copy builds, so each failure below is the bad operation's.
	var control: Dictionary = _build_side_quest_copy({})
	assert_no_errors(control["errors"], "the unchanged Side Quest copy builds")
	for effect: Dictionary in BAD_SIDE_QUEST_EFFECTS:
		# built: the build result with the bad operation.
		var built: Dictionary = _build_side_quest_copy(effect)
		assert_false(built["ok"], "%s must fail the build" % str(effect))
		assert_true(built["errors"].any(func(e: String) -> bool: return e.begins_with(SIDE_QUEST_FILE)),
			"an error starts with the Side Quest's path: %s" % [built["errors"]])


## Builds a temporary data folder holding constants.json, the Hangover card and a copy of
## SIDE_QUEST_FILE, and returns build()'s result.
## bad_effect: replaces the copy's dumb effects when not empty; {} keeps the file unchanged.
func _build_side_quest_copy(bad_effect: Dictionary) -> Dictionary:
	# quest: the real Beer Pong Table, parsed with whole numbers kept as ints.
	var quest: Dictionary = JsonValues.parse(FileAccess.get_file_as_string("res://" + SIDE_QUEST_FILE))["value"]
	if not bad_effect.is_empty():
		quest["dumb"]["effects"] = [bad_effect]
	# root: the temporary folder.
	var root: String = _temp_root({SIDE_QUEST_FILE: JSON.stringify(quest),
		"data/cards/junk_hangover.json": FileAccess.get_file_as_string("res://data/cards/junk_hangover.json")})
	# built: the build result for the temporary folder.
	var built: Dictionary = Ruleset.build(DataFiles.read_all(root))
	_remove(root)
	return built


## A folder build() has no schema for fails, so a new kind of data needs a schema first.
func test_unknown_folder_is_reported() -> void:
	# root: a temporary folder with a file in a folder that has no schema.
	var root: String = _temp_root({"data/potions/light_beer.json": "{}"})
	# built: the build result for the temporary folder.
	var built: Dictionary = Ruleset.build(DataFiles.read_all(root))
	_remove(root)
	assert_false(built["ok"], "an unknown folder must fail the build")
	assert_true(built["errors"].any(func(e: String) -> bool: return e.begins_with("data/potions/")),
		"an error names the unknown folder: %s" % [built["errors"]])


## Hidden files are skipped; a stray non-JSON file is returned so build() can report it.
func test_reader_skips_hidden_files_only() -> void:
	# root: a temporary folder with a hidden file and a stray text file.
	var root: String = _temp_root({"data/.DS_Store": "x", "data/cards/notes.txt": "x"})
	# files: what the reader returned.
	var files: Dictionary = DataFiles.read_all(root)
	_remove(root)
	assert_false(files.has("data/.DS_Store"), "hidden file skipped")
	assert_true(files.has("data/cards/notes.txt"), "stray file returned so build() can report it")


## A root with no data/ folder reads as empty.
func test_missing_data_folder_reads_empty() -> void:
	# root: a temporary folder with nothing in it.
	var root: String = _temp_root({}, false)
	assert_eq(DataFiles.read_all(root), {}, "no data/ folder")
	_remove(root)


## Makes a temporary folder in the user data folder and returns its absolute path.
## files: repo-relative path -> text to write. with_constants: also copy data/constants.json in, so
##   the only problems are the ones a test adds.
func _temp_root(files: Dictionary, with_constants: bool = true) -> String:
	# root: unique per call, so tests never see each other's files.
	var root: String = OS.get_user_data_dir().path_join("data_files_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(root)
	# all: the files to write, constants first if asked for.
	var all: Dictionary = {}
	if with_constants:
		all["data/constants.json"] = FileAccess.get_file_as_string("res://data/constants.json")
	all.merge(files)
	for path: String in all:
		DirAccess.make_dir_recursive_absolute(root.path_join(path).get_base_dir())
		# file: the open file, closed when it goes out of scope.
		var file: FileAccess = FileAccess.open(root.path_join(path), FileAccess.WRITE)
		file.store_string(all[path])
	return root


## Deletes a folder and everything in it, hidden files included.
## path: an absolute folder path inside the user data folder.
func _remove(path: String) -> void:
	# dir: lists the folder, hidden entries included.
	var dir: DirAccess = DirAccess.open(path)
	dir.include_hidden = true
	for sub: String in dir.get_directories():
		_remove(path.path_join(sub))
	for file: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
