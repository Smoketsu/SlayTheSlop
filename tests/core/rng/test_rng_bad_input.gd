## Tests for bad input to core/rng/rng.gd (task 029). Lane: core (Agent A).
##
## Every check in rng.gd must also run in a release build, where assert() is removed, so bad input
## is reported through the "error" field of the result, never by assert or push_error (the test
## runner fails a test on any engine error, so an engine error here would fail the test too).
## For each bad input: the state comes back unchanged (the same object, no stream advanced), the
## value is the documented safe value, and error is a non-empty text. Valid input still gives
## error "" and the recorded fixed-seed values of tests/core/rng/test_rng.gd.
extends "res://tests/framework/test_case.gd"

const Rng := preload("res://core/rng/rng.gd")
const RunState := preload("res://core/schema/run_state.gd")
const DudeState := preload("res://core/schema/dude_state.gd")

## The fixed seed used by tests/core/rng/test_rng.gd, so the recorded values can be reused.
const FIXED_SEED: int = 12345


## Returns a solo run state (player "p1") on FIXED_SEED with every stream created.
func _solo() -> Dictionary:
	return Rng.with_new_streams(RunState.blank(FIXED_SEED, [DudeState.blank("p1", "tom")]))


## Checks that result is a bad-input result: state is the given state, unchanged, value is
## expected_value, and error is a non-empty String that names the function.
## result: what the draw function returned. state: the state passed to it.
## before: a deep copy of state taken before the call. expected_value: the documented safe value.
## function_name: the draw function's name, which the error text must start with.
## label: names the case in failure messages.
func _assert_failed(result: Dictionary, state: Dictionary, before: Dictionary, expected_value: Variant,
		function_name: String, label: String) -> void:
	assert_eq(result.keys().size(), 3, "%s: result has state, value and error" % label)
	assert_true(is_same(result["state"], state), "%s: the input state itself is returned" % label)
	assert_eq(result["state"], before, "%s: no stream advanced" % label)
	assert_eq(result["value"], expected_value, "%s: safe value" % label)
	assert_true(result["error"] is String and result["error"] != "", "%s: error is a non-empty String" % label)
	assert_true(String(result["error"]).begins_with(function_name + ": "), "%s: error names %s, got '%s'" % [label, function_name, result["error"]])


## All-zero, empty and negative weights, a non-int weight and an overflowing total each return
## NO_INDEX (-1), the unchanged state and an error; none reaches % 0.
func test_weighted_index_bad_weights() -> void:
	# state: a solo run.
	var state: Dictionary = _solo()
	# before: a deep copy to compare against.
	var before: Dictionary = state.duplicate(true)
	# cases: label -> bad weights.
	var cases: Dictionary = {
		"all-zero weights": [0, 0, 0],
		"empty weights": [],
		"negative weight": [3, -1, 2],
		"float weight (as JSON gives)": [1, 2.0],
		"total above INT64_MAX": [Rng.INT64_MAX, 1],
	}
	assert_eq(Rng.NO_INDEX, -1, "documented safe index")
	for label: String in cases:
		_assert_failed(Rng.weighted_index(state, "combat_ai", cases[label]), state, before, Rng.NO_INDEX,
			"weighted_index", label)


## next_int with hi < lo, or a range wider than 2^63 - 2, returns lo, the unchanged state and an error.
func test_next_int_bad_range() -> void:
	# state: a solo run.
	var state: Dictionary = _solo()
	# before: a deep copy to compare against.
	var before: Dictionary = state.duplicate(true)
	_assert_failed(Rng.next_int(state, "dice:p1", 6, 1), state, before, 6, "next_int", "hi < lo")
	_assert_failed(Rng.next_int(state, "dice:p1", 0, -1), state, before, 0, "next_int", "hi one below lo")
	_assert_failed(Rng.next_int(state, "dice:p1", 0, Rng.INT64_MAX), state, before, 0, "next_int", "range too wide")
	_assert_failed(Rng.next_int(state, "dice:p1", -5, Rng.INT64_MAX), state, before, -5, "next_int",
		"range wraps past INT64_MAX")


## key_for returns NO_KEY ("") for an unknown shared stream, an unknown per-player stream, a
## per-player stream without a player_id and a shared stream with one; drawing with NO_KEY is an error.
func test_key_for_unknown_stream() -> void:
	assert_eq(Rng.NO_KEY, "", "documented sentinel")
	assert_eq(Rng.key_for("loot"), Rng.NO_KEY, "unknown shared stream")
	assert_eq(Rng.key_for("loot", "p1"), Rng.NO_KEY, "unknown per-player stream")
	assert_eq(Rng.key_for("dice"), Rng.NO_KEY, "per-player stream without a player_id")
	assert_eq(Rng.key_for("map", "p1"), Rng.NO_KEY, "shared stream with a player_id")
	# Valid names are unchanged.
	assert_eq(Rng.key_for("map"), "map")
	assert_eq(Rng.key_for("dice", "p1"), "dice:p1")
	# state: a solo run.
	var state: Dictionary = _solo()
	# before: a deep copy to compare against.
	var before: Dictionary = state.duplicate(true)
	# key: what key_for gives for an unknown stream.
	var key: String = Rng.key_for("loot")
	_assert_failed(Rng.next_u64(state, key), state, before, 0, "next_u64", "next_u64 with NO_KEY")
	_assert_failed(Rng.next_int(state, key, 1, 20), state, before, 1, "next_int", "next_int with NO_KEY")
	_assert_failed(Rng.weighted_index(state, key, [1, 2]), state, before, Rng.NO_INDEX, "weighted_index",
		"weighted_index with NO_KEY")
	_assert_failed(Rng.shuffle(state, key, ["c1", "c2", "c3"]), state, before, ["c1", "c2", "c3"], "shuffle",
		"shuffle with NO_KEY")
	assert_false(state["rng"].has(""), "no stream was created for NO_KEY")


## A well-formed key for a stream the run does not have (a per-player key for a player who is not
## in the run, or an unknown name typed by hand) is an error for every draw function, even a
## shuffle of 0 or 1 items, and creates no stream.
func test_unknown_stream_key() -> void:
	# state: a solo run (player p1 only).
	var state: Dictionary = _solo()
	# before: a deep copy to compare against.
	var before: Dictionary = state.duplicate(true)
	for key: String in ["dice:p2", "shuffle:p9", "loot"]:
		_assert_failed(Rng.next_u64(state, key), state, before, 0, "next_u64", "next_u64 %s" % key)
		_assert_failed(Rng.next_int(state, key, 3, 8), state, before, 3, "next_int", "next_int %s" % key)
		_assert_failed(Rng.weighted_index(state, key, [1]), state, before, Rng.NO_INDEX, "weighted_index",
			"weighted_index %s" % key)
		_assert_failed(Rng.shuffle(state, key, ["c1", "c2"]), state, before, ["c1", "c2"], "shuffle",
			"shuffle %s" % key)
		_assert_failed(Rng.shuffle(state, key, []), state, before, [], "shuffle", "empty shuffle %s" % key)
		_assert_failed(Rng.shuffle(state, key, ["c1"]), state, before, ["c1"], "shuffle", "one-item shuffle %s" % key)
		assert_false(state["rng"].has(key), "%s was not created" % key)


## A state with no rng map, or with a stream that is not an int (for example a float from a bad
## JSON load), is an error, not a crash.
func test_missing_or_broken_streams() -> void:
	# no_rng: a state with no rng field at all.
	var no_rng: Dictionary = {"run_seed": FIXED_SEED}
	_assert_failed(Rng.next_u64(no_rng, "map"), no_rng, no_rng.duplicate(true), 0, "next_u64", "no rng field")
	# broken: a state whose map stream holds a float.
	var broken: Dictionary = {"rng": {"map": 1.5}}
	_assert_failed(Rng.next_int(broken, "map", 1, 6), broken, broken.duplicate(true), 1, "next_int", "float stream")


## create_streams gives no stream to a player_id that is "" or not a String, so it never creates
## the "" key, and still creates every stream for the valid players.
func test_create_streams_skips_bad_player_ids() -> void:
	# rng: streams for one valid player and two bad entries.
	var rng: Dictionary = Rng.create_streams(FIXED_SEED, ["p1", "", 7])
	# keys: the keys created, sorted.
	var keys: Array = rng.keys()
	keys.sort()
	assert_eq(keys, ["combat_ai", "dice:p1", "encounters", "map", "rewards:p1", "shuffle:p1", "side_quest"])
	assert_eq(rng, Rng.create_streams(FIXED_SEED, ["p1"]), "same streams as the valid players alone")


## Valid input returns error "" with exactly the values recorded in test_rng.gd for seed 12345.
func test_valid_input_reports_no_error() -> void:
	# state: a solo run.
	var state: Dictionary = _solo()
	# roll: the first d20 roll (recorded value 2).
	var roll: Dictionary = Rng.next_int(state, "dice:p1", 1, 20)
	assert_eq(roll["error"], Rng.NO_ERROR)
	assert_eq(roll["value"], 2, "recorded first d20 roll")
	# raw: the first raw draw on map (recorded value).
	var raw: Dictionary = Rng.next_u64(state, "map")
	assert_eq(raw["error"], "")
	assert_eq(raw["value"], 8589654046835553445, "recorded first map draw")
	# pick: the first weighted pick (recorded value 3).
	var pick: Dictionary = Rng.weighted_index(state, "combat_ai", [3, 1, 0, 6])
	assert_eq(pick["error"], "")
	assert_eq(pick["value"], 3, "recorded first weighted pick")
	# shuffled: the recorded shuffle of 0..9.
	var shuffled: Dictionary = Rng.shuffle(state, "shuffle:p1", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
	assert_eq(shuffled["error"], "")
	assert_eq(shuffled["value"], [2, 0, 9, 5, 7, 3, 1, 4, 8, 6], "recorded shuffle")
	assert_eq(Rng.shuffle(state, "shuffle:p1", [])["error"], "", "empty shuffle of a real stream is fine")
	# Edge ranges that are valid stay valid.
	assert_eq(Rng.next_int(state, "map", 7, 7)["error"], "", "one-value range")
	assert_eq(Rng.next_int(state, "map", 0, Rng.INT64_MAX - 1)["error"], "", "widest allowed range")
	assert_eq(Rng.weighted_index(state, "combat_ai", [0, 0, 9])["value"], 2, "zeros beside a positive weight")


## shift_right_logical accepts any bits: 0 or below returns x, 64 or above returns 0, so a bad
## shift cannot raise an engine error.
func test_shift_right_logical_out_of_range() -> void:
	assert_eq(Rng.shift_right_logical(-8, 0), -8, "shift by 0")
	assert_eq(Rng.shift_right_logical(5, -3), 5, "negative shift")
	assert_eq(Rng.shift_right_logical(-1, 64), 0, "shift by 64")
	assert_eq(Rng.shift_right_logical(12345, 200), 0, "shift by 200")
