## Tests for core/run/save/snapshot.gd: save/load round trips, refusing bad bytes, and the state
## hash (task 027). Lane: run (Agent A).
##
## Built against hand-made states from the merged schema only; task 007's fixed-seed fight does
## not exist yet, so its every-step round trip is still to be added (see the task file).
extends "res://tests/framework/test_case.gd"

const Snapshot := preload("res://core/run/save/snapshot.gd")
const RunState := preload("res://core/schema/run_state.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const EnemyState := preload("res://core/schema/enemy_state.gd")
const CombatState := preload("res://core/schema/combat_state.gd")

## A seed above 2^53, the largest int a double holds exactly, so a JSON round trip would change it.
const BIG_SEED: int = 1152921504606846977

## state_hash(_sample_state()) recorded on Godot 4.7.2-stable. If an engine upgrade changes
## var_to_bytes, this test fails: saves and co-op hashes from the old version would no longer
## match. Re-record it only after deciding, with both people, what to do about old saves.
const SAMPLE_HASH: String = "bb08fa20cb0673873e8638eaadc446ab75b2d04b2ba55eeaa5a5b07c90007fb7"

## Seed for the RandomNumberGenerator that makes the garbage inputs. Fixed so every run tests the same bytes.
const GARBAGE_SEED: int = 27

## How many random garbage buffers each garbage test tries.
const GARBAGE_ROUNDS: int = 300


## Builds a small but complete mid-fight state: one Dude with three cards, two enemies, a seed
## above 2^53 and a negative random stream state. Fixed values, the same on every run.
func _sample_state() -> Dictionary:
	# dude: the single player's Dude, holding one card in each of three piles.
	var dude: Dictionary = DudeState.blank("p1", "tom")
	dude["hp"] = 80
	dude["max_hp"] = 80
	dude["cards"] = {
		"c1": {"def_id": "tom_punch", "upgraded": false},
		"c2": {"def_id": "tom_flex", "upgraded": true},
		"c3": {"def_id": "tom_arm_bar", "upgraded": false},
	}
	dude["deck"] = ["c1", "c2", "c3"]
	dude["draw_pile"] = ["c1"]
	dude["hand"] = ["c2"]
	dude["discard_pile"] = ["c3"]
	dude["statuses"] = {"exposed": 2}
	dude["last_seq"] = 4
	# state: the run around that Dude.
	var state: Dictionary = RunState.blank(BIG_SEED, [dude])
	# pledge: an enemy with a broken arm and an intent aimed at p1.
	var pledge: Dictionary = EnemyState.blank("e4", "goblin_pledge")
	pledge["hp"] = 12
	pledge["max_hp"] = 12
	pledge["arm_count"] = 2
	pledge["broken_arms"] = 1
	pledge["intent"] = {"move_id": "hit", "target_ids": ["p1"]}
	# bouncer: a second enemy left at blank values.
	var bouncer: Dictionary = EnemyState.blank("e5", "goblin_bouncer")
	state["combat"] = CombatState.blank()
	state["combat"]["enemies"] = [pledge, bouncer]
	state["combat"]["phase"] = "player"
	state["combat"]["turn"] = 1
	state["rng"] = {"shuffle:p1": -7046029254386353131, "combat_ai": 42}
	state["next_uid"] = 6
	state["state_version"] = 9
	return state


## Builds a two-player state outside a fight, with the extreme 64-bit ints, a map holding
## multi-byte UTF-8 text, and nested lists, to stress the encoding.
func _edge_state() -> Dictionary:
	# state: two blank Dudes in a run with the largest possible seed.
	var state: Dictionary = RunState.blank(9223372036854775807,
		[DudeState.blank("p1", "tom"), DudeState.blank("p2", "tom")])
	state["rng"] = {"map": -9223372036854775807 - 1, "dice:p2": -1, "shuffle:p2": 2147483648, "rewards:p1": -2147483649}
	state["map"] = {"nodes": [{"kind": "tailgate", "label": "Baileys é ☕ 🍺"}, {"kind": "fight", "label": ""}],
		"paths": [[0, 1], []], "visited": null}
	state["node_index"] = 1
	return state


## Returns a deep copy of value with every Dictionary's keys inserted in reverse sorted order,
## so it equals value but var_to_bytes() of it gives different bytes.
## value: any state value.
func _reordered(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			# keys: value's keys, sorted then reversed.
			var keys: Array = value.keys()
			keys.sort()
			keys.reverse()
			# out: the rebuilt Dictionary.
			var out: Dictionary = {}
			for key: Variant in keys:
				out[key] = _reordered(value[key])
			return out
		TYPE_ARRAY:
			# out: the rebuilt Array, same order.
			var out: Array = []
			for item: Variant in value:
				out.append(_reordered(item))
			return out
		_:
			return value


## Asserts that from_bytes refuses bytes with an error, and returns that error ("" if accepted).
## bytes: the input. label: names the case in failure messages.
func _assert_refused(bytes: PackedByteArray, label: String) -> String:
	# result: what from_bytes returned.
	var result: Dictionary = Snapshot.from_bytes(bytes)
	assert_false(result["ok"], label + ": should be refused")
	assert_eq(result["state"], null, label + ": state should be null")
	assert_true(result["error"] != "", label + ": error should say why")
	return result["error"]


## Asserts that from_bytes either refuses bytes with a message, or returns a state that passes
## RunState.check(). Used for corrupted input, where either outcome is allowed but nothing else is.
## bytes: the input. label: names the case in failure messages.
func _assert_refused_or_valid(bytes: PackedByteArray, label: String) -> void:
	# result: what from_bytes returned.
	var result: Dictionary = Snapshot.from_bytes(bytes)
	if result["ok"]:
		assert_no_errors(RunState.check(result["state"]), label)
	else:
		assert_true(result["error"] != "" and result["state"] == null, label + ": refusal needs an error and a null state")


## The test states are valid, so the round trips below test real states.
func test_test_states_are_valid() -> void:
	assert_no_errors(RunState.check(_sample_state()), "sample state")
	assert_no_errors(RunState.check(_edge_state()), "edge state")


## Saving and loading gives back a strictly equal state: blank, mid-fight, and edge cases
## (seed above 2^53, int64 minimum and maximum, negative stream states, multi-byte text).
func test_round_trip_is_identical() -> void:
	# states: label -> state to round-trip.
	var states: Dictionary = {
		"blank": RunState.blank(1, [DudeState.blank("p1", "tom")]),
		"mid-fight": _sample_state(),
		"edge": _edge_state(),
	}
	for label: String in states.keys():
		# result: the loaded snapshot.
		var result: Dictionary = Snapshot.from_bytes(Snapshot.to_bytes(states[label]))
		assert_true(result["ok"], "%s: %s" % [label, result["error"]])
		assert_eq(result["error"], "", label)
		assert_eq(result["state"], states[label], label)


## A loaded state saves to the same bytes again, so save -> load -> save is stable.
func test_second_save_gives_same_bytes() -> void:
	# first: bytes of the sample state.
	var first: PackedByteArray = Snapshot.to_bytes(_sample_state())
	assert_eq(Snapshot.to_bytes(Snapshot.from_bytes(first)["state"]), first)


## to_bytes and state_hash do not modify the state they are given.
func test_saving_does_not_modify_the_state() -> void:
	# state: the sample, saved and hashed below.
	var state: Dictionary = _sample_state()
	Snapshot.to_bytes(state)
	Snapshot.state_hash(state)
	assert_eq(state, _sample_state())


## Equal states filled in different Dictionary orders give the same snapshot bytes and hash,
## although plain var_to_bytes() gives different bytes for them.
func test_hash_ignores_insertion_order() -> void:
	for state: Dictionary in [_sample_state(), _edge_state()]:
		# shuffled: the same state with every Dictionary filled in reverse key order.
		var shuffled: Dictionary = _reordered(state)
		assert_eq(shuffled, state, "reordered copy must be equal")
		assert_ne(var_to_bytes(shuffled), var_to_bytes(state), "plain var_to_bytes should differ, or this test proves nothing")
		assert_eq(Snapshot.to_bytes(shuffled), Snapshot.to_bytes(state), "snapshot bytes")
		assert_eq(Snapshot.state_hash(shuffled), Snapshot.state_hash(state), "hash")


## The hash is 64 lowercase hex characters (SHA-256).
func test_hash_format() -> void:
	# digest: the sample state's hash.
	var digest: String = Snapshot.state_hash(_sample_state())
	assert_eq(digest.length(), 64, "length")
	assert_true(RegEx.create_from_string("^[0-9a-f]{64}$").search(digest) != null, "lowercase hex: " + digest)


## Any single change to the state changes the hash, and no two of these changes give the same hash.
func test_hash_changes_on_any_change() -> void:
	# changes: label -> a function making one small change to a state.
	var changes: Dictionary = {
		"state_version + 1": func(s: Dictionary) -> void: s["state_version"] += 1,
		"run_seed - 1": func(s: Dictionary) -> void: s["run_seed"] -= 1,
		"dude hp - 1": func(s: Dictionary) -> void: s["dudes"][0]["hp"] -= 1,
		"enemy ick + 1": func(s: Dictionary) -> void: s["combat"]["enemies"][1]["ick"] += 1,
		"rng state + 1": func(s: Dictionary) -> void: s["rng"]["combat_ai"] += 1,
		"new rng stream": func(s: Dictionary) -> void: s["rng"]["map"] = 0,
		"card upgraded": func(s: Dictionary) -> void: s["dudes"][0]["cards"]["c1"]["upgraded"] = true,
		"bool flipped": func(s: Dictionary) -> void: s["dudes"][0]["ready"] = true,
		"string changed": func(s: Dictionary) -> void: s["combat"]["phase"] = "over",
		"status added": func(s: Dictionary) -> void: s["dudes"][0]["statuses"]["foggy"] = 1,
		"enemies swapped": func(s: Dictionary) -> void: s["combat"]["enemies"].reverse(),
		"intent cleared": func(s: Dictionary) -> void: s["combat"]["enemies"][0]["intent"] = null,
		"combat ended": func(s: Dictionary) -> void: s["combat"] = null,
		"int became float": func(s: Dictionary) -> void: s["bro_meter"] = 0.0,
		"key renamed": func(s: Dictionary) -> void: s["map"] = {"a": 1},
		"key renamed again": func(s: Dictionary) -> void: s["map"] = {"b": 1},
	}
	# seen: hash -> label of the state that produced it, starting with the unchanged sample.
	var seen: Dictionary = {Snapshot.state_hash(_sample_state()): "unchanged"}
	for label: String in changes.keys():
		# state: a fresh sample with this one change.
		var state: Dictionary = _sample_state()
		changes[label].call(state)
		# digest: the changed state's hash.
		var digest: String = Snapshot.state_hash(state)
		assert_false(seen.has(digest), "%s gives the same hash as %s" % [label, seen.get(digest, "")])
		seen[digest] = label


## Fixed case: the sample state, built from fixed values with a fixed seed, has a recorded hash.
## Catches an engine upgrade or a canonical() change that would break old saves and co-op hashes.
func test_fixed_state_has_recorded_hash() -> void:
	assert_eq(Snapshot.state_hash(_sample_state()), SAMPLE_HASH)


## Empty and too-short bytes are refused before decoding.
func test_refuses_empty_and_short_bytes() -> void:
	_assert_refused(PackedByteArray(), "empty")
	_assert_refused(PackedByteArray([27, 0, 0]), "three bytes")


## Every truncation of a valid snapshot is refused cleanly, with no engine error.
func test_refuses_every_truncation() -> void:
	# whole: a valid snapshot.
	var whole: PackedByteArray = Snapshot.to_bytes(_sample_state())
	for length: int in whole.size():
		_assert_refused(whole.slice(0, length), "first %d bytes" % length)


## Extra bytes after a valid snapshot are refused.
func test_refuses_trailing_bytes() -> void:
	# padded: a valid snapshot followed by four zero bytes.
	var padded: PackedByteArray = Snapshot.to_bytes(_sample_state())
	padded.append_array(PackedByteArray([0, 0, 0, 0]))
	assert_true(_assert_refused(padded, "trailing bytes").contains("unexpected bytes"))


## Random garbage, alone or behind a Dictionary header, is refused or (by chance) yields a
## valid state; it never causes an engine error.
func test_refuses_random_garbage() -> void:
	# rng: fixed-seed generator for the garbage bytes.
	var rng := RandomNumberGenerator.new()
	rng.seed = GARBAGE_SEED
	for attempt: int in GARBAGE_ROUNDS:
		# garbage: random bytes of random length.
		var garbage := PackedByteArray()
		for i: int in rng.randi_range(0, 64):
			garbage.append(rng.randi_range(0, 255))
		_assert_refused_or_valid(garbage, "garbage %d" % attempt)
		# framed: the same garbage behind a Dictionary header and a small count.
		var framed: PackedByteArray = PackedByteArray([TYPE_DICTIONARY, 0, 0, 0, rng.randi_range(0, 3), 0, 0, 0])
		framed.append_array(garbage)
		_assert_refused_or_valid(framed, "framed garbage %d" % attempt)


## Corrupting any one byte of a valid snapshot either is refused or still gives a valid state
## (for example when the byte is inside an int); it never causes an engine error.
func test_refuses_or_survives_each_corrupt_byte() -> void:
	# whole: a valid snapshot.
	var whole: PackedByteArray = Snapshot.to_bytes(_edge_state())
	for i: int in whole.size():
		for flip: int in [0x01, 0x80, 0xFF]:
			# broken: the snapshot with byte i flipped by the bits in flip.
			var broken: PackedByteArray = whole.duplicate()
			broken[i] = broken[i] ^ flip
			_assert_refused_or_valid(broken, "byte %d ^ %02x" % [i, flip])


## A valid encoding of something other than a Dictionary is refused, naming what it was.
func test_refuses_non_dictionary() -> void:
	assert_true(_assert_refused(var_to_bytes([1, 2, 3]), "array").contains("Array"), "error should name Array")
	assert_true(_assert_refused(var_to_bytes(5), "int").contains("int"), "error should name int")
	_assert_refused(var_to_bytes(null), "null")


## Values a state may not hold are refused before decoding: an Object, a float, a StringName,
## a typed Array, a non-String key and invalid UTF-8.
func test_refuses_values_a_state_may_not_hold() -> void:
	# base: a valid state, with one bad value put in its map below.
	var base: Dictionary = _sample_state()
	# typed: a typed Array, which var_to_bytes marks with extra header flags.
	var typed: Array[String] = ["a"]
	# bad: label -> a value that must not appear in a state.
	var bad: Dictionary = {
		"object": RefCounted.new(),
		"float": 1.5,
		"string name": &"tom",
		"typed array": typed,
		"int key": {1: "x"},
		"vector": Vector2i(1, 2),
	}
	for label: String in bad.keys():
		# state: the sample with the bad value inside its map.
		var state: Dictionary = base.duplicate(true)
		state["map"] = {"bad": bad[label]}
		_assert_refused(var_to_bytes(state), label)
	# utf8: a snapshot whose map holds "ab", then with the "a" byte replaced by 0xFF.
	var utf8: PackedByteArray = var_to_bytes({"ab": 1})
	assert_eq(utf8[16], 0x61, "byte 16 should be the 'a' of the key")
	utf8[16] = 0xFF
	assert_true(_assert_refused(utf8, "invalid UTF-8").contains("UTF-8"), "error should mention UTF-8")


## A missing, mistyped or different schema_version is refused with an error naming both versions.
func test_refuses_wrong_schema_version() -> void:
	for version: int in [RunState.SCHEMA_VERSION - 1, RunState.SCHEMA_VERSION + 1]:
		# state: the sample claiming another schema version.
		var state: Dictionary = _sample_state()
		state["schema_version"] = version
		# error: the refusal message.
		var error: String = _assert_refused(Snapshot.to_bytes(state), "schema_version %d" % version)
		assert_true(error.contains("schema_version %d" % version), "names the snapshot's version: " + error)
		assert_true(error.contains("schema_version %d" % RunState.SCHEMA_VERSION), "names this build's version: " + error)
	# missing: the sample with no schema_version at all.
	var missing: Dictionary = _sample_state()
	missing.erase("schema_version")
	assert_true(_assert_refused(Snapshot.to_bytes(missing), "missing").contains("no schema_version"))
	# mistyped: the sample with schema_version as a String.
	var mistyped: Dictionary = _sample_state()
	mistyped["schema_version"] = str(RunState.SCHEMA_VERSION)
	assert_true(_assert_refused(Snapshot.to_bytes(mistyped), "mistyped").contains("not an int"))


## A well-formed snapshot of a state that RunState.check() rejects is refused with check()'s message.
func test_refuses_state_failing_check() -> void:
	# state: the sample with a party_size that does not match its one Dude.
	var state: Dictionary = _sample_state()
	state["party_size"] = 2
	# error: the refusal message.
	var error: String = _assert_refused(Snapshot.to_bytes(state), "party_size mismatch")
	assert_true(error.contains("run_state.check()") and error.contains("party_size"), error)
	# card_bug: the sample with a hand card that has no card instance.
	var card_bug: Dictionary = _sample_state()
	card_bug["dudes"][0]["hand"].append("c99")
	assert_true(_assert_refused(Snapshot.to_bytes(card_bug), "missing card").contains("c99"))
