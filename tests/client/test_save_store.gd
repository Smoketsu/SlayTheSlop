## Tests for the run's save file, client/run/save_store.gd (task 020). Lane: tools/client (Agent B).
## Each test maps to task 020's "Saving" and "corrupt or wrong-version save" acceptance checks.
extends "res://tests/framework/test_case.gd"

const SaveStore := preload("res://client/run/save_store.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const NewRun := preload("res://core/run/new_run.gd")
const Core := preload("res://core/core.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")

## The save file these tests use, so they never touch a player's real save. Deleted before and
## after each test.
const PATH: String = "user://test_save_store.save"
## Seed of the runs saved here. Any int works; fixed so failures repeat.
const SEED: int = 7


## A saved state loads back strictly equal (task 020: "A test saves, loads with from_bytes, and gets
## a strictly equal state"), the temp file is gone after the rename, and a second save replaces the
## first.
func test_save_then_load_is_strictly_equal() -> void:
	SaveStore.delete_save(PATH)
	# ruleset: the real data. first: a new run's first state. second: the state after one vote.
	var ruleset: Dictionary = _ruleset()
	var first: Dictionary = _new_run(ruleset)
	assert_eq(SaveStore.save_state(first, PATH), "", "first save")
	assert_false(FileAccess.file_exists(PATH + SaveStore.TEMP_SUFFIX), "no temp file left behind")
	assert_true(SaveStore.has_save(PATH), "the save exists")
	# loaded: the save read back.
	var loaded: Dictionary = SaveStore.load_state(PATH)
	assert_eq(loaded["error"], "")
	assert_eq(loaded["state"], first, "loaded state")
	# vote: the first move of the run, to get a different state.
	var vote: Dictionary = {"type": "vote_node", "player_id": first["dudes"][0]["player_id"], "seq": 0,
		"node_id": first["map"]["nodes"][0]["links"][0]}
	var second: Dictionary = Core.apply(ruleset, first, vote)["state"]
	assert_eq(SaveStore.save_state(second, PATH), "", "second save over the first")
	assert_false(FileAccess.file_exists(PATH + SaveStore.TEMP_SUFFIX), "no temp file left behind")
	assert_eq(SaveStore.load_state(PATH)["state"], second, "the second save replaced the first")
	SaveStore.delete_save(PATH)


## A truncated save is refused with from_bytes()'s own message and no state.
func test_truncated_save_reports_the_loader_error() -> void:
	# bytes: a whole save cut in half.
	var bytes: PackedByteArray = Snapshot.to_bytes(_new_run(_ruleset()))
	bytes = bytes.slice(0, bytes.size() / 2)
	_write(bytes)
	# loaded: the load result. expected: from_bytes()'s own error for these bytes.
	var loaded: Dictionary = SaveStore.load_state(PATH)
	var expected: String = Snapshot.from_bytes(bytes)["error"]
	assert_ne(expected, "", "the truncated bytes are refused")
	assert_eq(loaded["error"], expected)
	assert_eq(loaded["state"], {})
	SaveStore.delete_save(PATH)


## No file: NO_SAVE. An empty file: from_bytes()'s message. Paths outside user:// are refused.
func test_missing_empty_and_foreign_paths() -> void:
	SaveStore.delete_save(PATH)
	assert_false(SaveStore.has_save(PATH))
	assert_eq(SaveStore.load_state(PATH), {"state": {}, "error": SaveStore.NO_SAVE})
	_write(PackedByteArray())
	assert_ne(SaveStore.load_state(PATH)["error"], "", "an empty file is refused")
	SaveStore.delete_save(PATH)
	assert_false(SaveStore.has_save(PATH), "delete_save removed it")
	# state: something to try to save.
	var state: Dictionary = _new_run(_ruleset())
	assert_ne(SaveStore.save_state(state, "res://not_here.save"), "", "res:// refused")
	assert_false(FileAccess.file_exists("res://not_here.save"), "nothing written outside user://")
	assert_ne(SaveStore.load_state("res://project.godot")["error"], "", "loading outside user:// refused")


## Returns the ruleset built from data/.
func _ruleset() -> Dictionary:
	return Ruleset.build(DataFiles.read_all())["ruleset"]


## Returns a new run's first state on the real data, with the first Dude by id.
## ruleset: the real data.
func _new_run(ruleset: Dictionary) -> Dictionary:
	# dude_ids: the Dudes, sorted.
	var dude_ids: Array = ruleset["dudes"].keys()
	dude_ids.sort()
	return NewRun.start(ruleset, SEED, [dude_ids[0]])["state"]


## Writes raw bytes to PATH, as a damaged save.
## bytes: what the file holds.
func _write(bytes: PackedByteArray) -> void:
	# file: PATH, open for writing.
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
