## Tests for the named random streams in core/rng/rng.gd (task 003). Lane: core (Agent A).
##
## Expected values marked "reference" were computed outside Godot with an independent Python
## implementation of the same algorithms (SplitMix64, FNV-1a 64, rejection sampling and
## Fisher–Yates as written in rng.gd), so a change in Godot's integer math, or in rng.gd, is caught.
extends "res://tests/framework/test_case.gd"

const Rng := preload("res://core/rng/rng.gd")
const RunState := preload("res://core/schema/run_state.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const Purity := preload("res://tests/core/test_purity.gd")

## The fixed seed named in the task's acceptance checks.
const FIXED_SEED: int = 12345

## Reference: for seed 12345, each stream key -> [starting state, first four next_u64 values].
const FIXED_SEED_SEQUENCES := {
	"map": [8962072554377740505,
		[8589654046835553445, 8343428399281780528, 2602899048471107498, 5129310415217382818]],
	"encounters": [-7546071163786193006,
		[-3369333236724461514, 7688124361577194962, -8509093182903190030, -8146774571345564620]],
	"combat_ai": [-6697086974433986924,
		[8466426438758400276, -3486402144568393736, -7623412857907925069, 5262620741085851687]],
	"side_quest": [2195633227833964485,
		[-6998058753733150401, -6365903067221743246, -7474338457935115132, 973242213702504260]],
	"rewards:p1": [8687751461451694887,
		[-111146678634756714, 2861674119115809711, -438555923689071962, 3863881952565782312]],
	"shuffle:p1": [2536787316741731711,
		[-3805412984733833823, 1982798112927653567, 2034084450081018936, -5573918776793479980]],
	"dice:p1": [2800795518138003496,
		[4026382341670022443, 4147740148257986826, -4700300242753584794, -2722747722209408285]],
}


## Returns a blank run state for the given seed and players, with every stream created.
## run_seed: the run's seed. player_ids: one Dude is made per id, in seat order.
func _state(run_seed: int, player_ids: Array) -> Dictionary:
	# dudes: one blank Tom per player id.
	var dudes: Array = []
	for player_id: String in player_ids:
		dudes.append(DudeState.blank(player_id, "tom"))
	return Rng.with_new_streams(RunState.blank(run_seed, dudes))


## Draws count raw values from one stream. Returns {"state": final state, "values": Array of ints}.
## state: the run state to draw from. key: the stream's rng key. count: how many draws.
func _draws(state: Dictionary, key: String, count: int) -> Dictionary:
	# current: the state as it advances.
	var current: Dictionary = state
	# values: what was drawn, in order.
	var values: Array = []
	for i: int in count:
		# draw: one {state, value} result.
		var draw: Dictionary = Rng.next_u64(current, key)
		current = draw["state"]
		values.append(draw["value"])
	return {"state": current, "values": values}


## GDScript ints are signed 64-bit and wrap on overflow, which SplitMix64 and FNV-1a rely on;
## and the unsigned shift fills with zeros.
func test_int_math_wraps_as_relied_on() -> void:
	# top: INT64_MAX, held in a var so the sum is computed at run time.
	var top: int = Rng.INT64_MAX
	assert_eq(top + 1, -Rng.INT64_MAX - 1, "addition wraps")
	# Reference: products mod 2^64, as signed ints.
	assert_eq(Rng.GOLDEN_GAMMA * Rng.MIX_MULT_1, -2993748316962524115, "multiplication wraps")
	assert_eq(Rng.GOLDEN_GAMMA * 3, -2691343689449507777, "multiplication wraps")
	assert_eq(Rng.GOLDEN_GAMMA + Rng.GOLDEN_GAMMA, 4354685564936845354, "addition wraps")
	assert_eq(Rng.shift_right_logical(-1, 1), Rng.INT64_MAX)
	assert_eq(Rng.shift_right_logical(-1, 63), 1)
	assert_eq(Rng.shift_right_logical(-8, 1), Rng.INT64_MAX - 3)
	assert_eq(Rng.shift_right_logical(256, 4), 16)


## The generator matches the published SplitMix64 test vector (state 1234567), and FNV-1a 64
## matches its published values, so the algorithms are the standard ones.
func test_algorithms_match_published_vectors() -> void:
	# state: a stand-in run state holding one stream at 1234567.
	var state: Dictionary = {"rng": {"vector": 1234567}}
	# Published: 6457827717110365317, 3203168211198807973, 9817491932198370423,
	# 4593380528125082431, 16408922859458223821 (unsigned), shown here as signed 64-bit ints.
	assert_eq(_draws(state, "vector", 5)["values"], [6457827717110365317, 3203168211198807973,
		-8629252141511181193, 4593380528125082431, -2037821214251327795])
	assert_eq(Rng.fnv1a64(""), Rng.FNV_OFFSET, "FNV-1a of empty input is the offset basis")
	assert_eq(Rng.fnv1a64("a"), -5808556873153909620, "FNV-1a 64 of 'a' is 0xaf63dc4c8601ec8c")
	assert_eq(Rng.fnv1a64("map"), 580780841256168849, "reference")


## Stream derivation is written out: rng.gd uses no engine hash or engine random generator,
## so an engine upgrade cannot change a stream. (The recorded values in the next test prove the rest.)
func test_derivation_uses_no_engine_hash_or_rng() -> void:
	# code: rng.gd with comments and strings removed.
	var code: String = Purity.strip_comments_and_strings(FileAccess.get_file_as_string("res://core/rng/rng.gd"))
	for pattern: String in ["\\.hash\\s*\\(", "\\bhash\\s*\\(", "RandomNumberGenerator", "\\brand"]:
		assert_true(RegEx.create_from_string(pattern).search(code) == null, "rng.gd must not use %s" % pattern)


## Fixed seed 12345 gives the recorded starting state and first draws for every stream.
func test_fixed_seed_gives_recorded_sequences() -> void:
	# state: a solo run on the fixed seed.
	var state: Dictionary = _state(FIXED_SEED, ["p1"])
	# keys: the expected keys, sorted for a stable comparison.
	var keys: Array = FIXED_SEED_SEQUENCES.keys()
	keys.sort()
	# actual_keys: the keys the run actually has.
	var actual_keys: Array = state["rng"].keys()
	actual_keys.sort()
	assert_eq(actual_keys, keys, "solo run streams")
	for key: String in keys:
		assert_eq(state["rng"][key], FIXED_SEED_SEQUENCES[key][0], "%s starting state" % key)
		assert_eq(_draws(state, key, 4)["values"], FIXED_SEED_SEQUENCES[key][1], "%s first draws" % key)


## Fixed seed 12345 gives the recorded d20 rolls, shuffle and weighted picks (reference values).
func test_fixed_seed_gives_recorded_ranges_shuffle_and_picks() -> void:
	# state: a solo run on the fixed seed.
	var state: Dictionary = _state(FIXED_SEED, ["p1"])
	# rolls: ten d20 rolls from p1's dice stream.
	var rolls: Array = []
	# current: the state as the rolls advance it.
	var current: Dictionary = state
	for i: int in 10:
		# roll: one {state, value} result.
		var roll: Dictionary = Rng.next_int(current, "dice:p1", 1, 20)
		current = roll["state"]
		rolls.append(roll["value"])
	assert_eq(rolls, [2, 14, 12, 6, 16, 8, 10, 20, 5, 20], "d20 rolls")
	assert_eq(Rng.shuffle(state, "shuffle:p1", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])["value"],
		[2, 0, 9, 5, 7, 3, 1, 4, 8, 6], "shuffle of 0..9")
	# picks: ten weighted picks from combat_ai with weights [3, 1, 0, 6].
	var picks: Array = []
	current = state
	for i: int in 10:
		# pick: one {state, value} result.
		var pick: Dictionary = Rng.weighted_index(current, "combat_ai", [3, 1, 0, 6])
		current = pick["state"]
		picks.append(pick["value"])
	assert_eq(picks, [3, 0, 1, 1, 3, 3, 3, 0, 3, 0], "weighted picks")


## Every stream the GDD names exists, shared ones once and per-player ones for each player,
## and a state with streams still passes the run_state contract check.
func test_streams_exist_for_every_player() -> void:
	# state: a four-player run.
	var state: Dictionary = _state(FIXED_SEED, ["p1", "p2", "p3", "p4"])
	# expected: every key the run should have, sorted.
	var expected: Array = ["map", "encounters", "combat_ai", "side_quest"]
	for player_id: String in ["p1", "p2", "p3", "p4"]:
		for stream: String in ["rewards", "shuffle", "dice"]:
			expected.append("%s:%s" % [stream, player_id])
	expected.sort()
	# actual: the keys present, sorted.
	var actual: Array = state["rng"].keys()
	actual.sort()
	assert_eq(actual, expected)
	assert_no_errors(RunState.check(state), "state with streams")
	assert_eq(Rng.key_for("map"), "map")
	assert_eq(Rng.key_for("dice", "p3"), "dice:p3")


## Per-player streams differ between players, and a stream's start depends only on the seed and
## its key: not on the order of players, nor on how many there are.
func test_per_player_streams_are_separate() -> void:
	# solo: streams for one player.
	var solo: Dictionary = Rng.create_streams(FIXED_SEED, ["p1"])
	# duo: streams for two players on the same seed.
	var duo: Dictionary = Rng.create_streams(FIXED_SEED, ["p1", "p2"])
	# reversed: the same two players listed in the other order.
	var reversed: Dictionary = Rng.create_streams(FIXED_SEED, ["p2", "p1"])
	assert_eq(duo, reversed, "player order does not matter")
	for key: String in solo.keys():
		assert_eq(duo[key], solo[key], "%s is the same with a second player" % key)
	for stream: String in ["rewards", "shuffle", "dice"]:
		assert_ne(duo[stream + ":p1"], duo[stream + ":p2"], "%s differs between players" % stream)
	# Reference value for p2's dice stream.
	assert_eq(duo["dice:p2"], 4449623560839528249)
	# Different seeds give different streams; a negative seed works (reference value).
	assert_ne(Rng.create_streams(FIXED_SEED + 1, ["p1"])["map"], solo["map"], "seed changes streams")
	assert_eq(Rng.derive_stream_state(-1, "map"), 7944227227517549607, "negative seed")


## Drawing from one stream never changes another: draws interleaved across every stream equal
## the same draws made from each stream in isolation.
func test_streams_are_independent() -> void:
	# start: a two-player run.
	var start: Dictionary = _state(FIXED_SEED, ["p1", "p2"])
	# keys: every stream key, sorted so the interleaving order is fixed.
	var keys: Array = start["rng"].keys()
	keys.sort()
	# isolated: key -> 6 draws made with no other stream touched.
	var isolated: Dictionary = {}
	for key: String in keys:
		isolated[key] = _draws(start, key, 6)["values"]
	# interleaved: key -> draws collected while cycling through all streams in an uneven pattern.
	var interleaved: Dictionary = {}
	for key: String in keys:
		interleaved[key] = []
	# current: the state as the interleaved draws advance it.
	var current: Dictionary = start
	for round_index: int in 6:
		for k: int in keys.size():
			# key: the stream drawn from in this slot, visited in a rotating order.
			var key: String = keys[(k + round_index * 5) % keys.size()]
			# draw: one {state, value} result.
			var draw: Dictionary = Rng.next_u64(current, key)
			current = draw["state"]
			interleaved[key].append(draw["value"])
	for key: String in keys:
		assert_eq(interleaved[key], isolated[key], "%s is unaffected by other streams" % key)
	# p1_draw: one p1 draw from the starting state, and again after many draws on p2's streams.
	var p1_draw: int = Rng.next_u64(start, "dice:p1")["value"]
	# busy: the start state after 50 draws on p2's dice and the shared combat_ai stream.
	var busy: Dictionary = _draws(_draws(start, "dice:p2", 50)["state"], "combat_ai", 50)["state"]
	assert_eq(Rng.next_u64(busy, "dice:p1")["value"], p1_draw, "p1 dice unaffected by p2 and enemies")


## Saving with var_to_bytes / bytes_to_var in the middle of a sequence and continuing gives
## exactly the draws an uninterrupted run gives, for every stream.
func test_snapshot_round_trip_mid_sequence() -> void:
	# start: a two-player run.
	var start: Dictionary = _state(FIXED_SEED, ["p1", "p2"])
	# keys: every stream key, sorted.
	var keys: Array = start["rng"].keys()
	keys.sort()
	for key: String in keys:
		# straight: 10 draws in one go.
		var straight: Array = _draws(start, key, 10)["values"]
		# first: the first 5 draws, and the state after them.
		var first: Dictionary = _draws(start, key, 5)
		# loaded: that state after a binary save and load.
		var loaded: Variant = bytes_to_var(var_to_bytes(first["state"]))
		assert_eq(loaded, first["state"], "%s snapshot is identical" % key)
		# rest: the next 5 draws from the loaded state.
		var rest: Array = _draws(loaded, key, 5)["values"]
		assert_eq(first["values"] + rest, straight, "%s continues identically after load" % key)
	# Same for a shuffle and a roll made after the load.
	# mid: start after three shuffles of p1's deck.
	var mid: Dictionary = start
	for i: int in 3:
		mid = Rng.shuffle(mid, "shuffle:p1", ["c1", "c2", "c3", "c4", "c5"])["state"]
	# reloaded: mid after a save and load.
	var reloaded: Dictionary = bytes_to_var(var_to_bytes(mid))
	assert_eq(Rng.shuffle(reloaded, "shuffle:p1", ["c1", "c2", "c3"])["value"],
		Rng.shuffle(mid, "shuffle:p1", ["c1", "c2", "c3"])["value"], "shuffle after load")
	assert_eq(Rng.next_int(reloaded, "dice:p1", 1, 20)["value"], Rng.next_int(mid, "dice:p1", 1, 20)["value"], "roll after load")


## The functions are pure: inputs are not changed, and the same input always gives the same output.
func test_functions_do_not_mutate_inputs() -> void:
	# state: a solo run.
	var state: Dictionary = _state(FIXED_SEED, ["p1"])
	# before: a deep copy of state to compare against afterwards.
	var before: Dictionary = state.duplicate(true)
	# items: a list to shuffle.
	var items: Array = ["c1", "c2", "c3", "c4"]
	# items_before: a copy of items.
	var items_before: Array = items.duplicate()
	# a: a draw from state.
	var a: Dictionary = Rng.next_int(state, "map", 0, 99)
	# b: the same draw made again from the same state.
	var b: Dictionary = Rng.next_int(state, "map", 0, 99)
	Rng.weighted_index(state, "combat_ai", [1, 2])
	Rng.next_u64(state, "encounters")
	Rng.shuffle(state, "shuffle:p1", items)
	Rng.with_new_streams(state)
	assert_eq(state, before, "state unchanged")
	assert_eq(items, items_before, "items unchanged")
	assert_eq(a, b, "same input, same output")
	assert_ne(a["state"]["rng"]["map"], state["rng"]["map"], "the drawn stream advanced")
	assert_eq(a["state"]["rng"]["encounters"], state["rng"]["encounters"], "other streams did not")


## next_int stays inside its range, handles a one-value range and negative bounds, and over many
## draws hits every value about equally often.
func test_next_int_range_and_spread() -> void:
	# current: a solo run's state, advanced by each draw.
	var current: Dictionary = _state(FIXED_SEED, ["p1"])
	# counts: how often each face of a d6 came up; index 0 unused.
	var counts: Array = [0, 0, 0, 0, 0, 0, 0]
	for i: int in 6000:
		# roll: one d6 roll.
		var roll: Dictionary = Rng.next_int(current, "dice:p1", 1, 6)
		current = roll["state"]
		assert_true(roll["value"] >= 1 and roll["value"] <= 6, "d6 out of range: %d" % roll["value"])
		counts[roll["value"]] += 1
	for face: int in range(1, 7):
		# Each face expects 1000; 850..1150 is far outside chance for a fair generator (about 5 sigma).
		assert_true(counts[face] > 850 and counts[face] < 1150, "face %d came up %d times" % [face, counts[face]])
	assert_eq(Rng.next_int(current, "map", 7, 7)["value"], 7, "one-value range")
	for i: int in 50:
		# low: a draw from -3..-1.
		var low: Dictionary = Rng.next_int(current, "map", -3, -1)
		current = low["state"]
		assert_true(low["value"] >= -3 and low["value"] <= -1, "negative range: %d" % low["value"])
	# wide: a draw from the widest allowed range, which must still be non-negative.
	var wide: int = Rng.next_int(current, "map", 0, Rng.INT64_MAX - 1)["value"]
	assert_true(wide >= 0, "wide range: %d" % wide)


## weighted_index never picks a zero weight, and picks a single positive weight every time.
func test_weighted_index_respects_weights() -> void:
	# current: a solo run's state, advanced by each pick.
	var current: Dictionary = _state(FIXED_SEED, ["p1"])
	for i: int in 200:
		# pick: one pick where only index 1 and 3 can win.
		var pick: Dictionary = Rng.weighted_index(current, "combat_ai", [0, 5, 0, 1])
		current = pick["state"]
		assert_true(pick["value"] == 1 or pick["value"] == 3, "picked zero weight index %d" % pick["value"])
		assert_eq(Rng.weighted_index(current, "combat_ai", [0, 0, 9])["value"], 2, "only positive weight")


## shuffle returns a permutation of its input, leaves the stream alone for 0 or 1 items, and
## gives different orders on successive shuffles.
func test_shuffle_is_a_permutation() -> void:
	# current: a solo run's state.
	var current: Dictionary = _state(FIXED_SEED, ["p1"])
	# deck: twenty card uids.
	var deck: Array = []
	for i: int in 20:
		deck.append("c%d" % (i + 1))
	# orders: each shuffle's result, to check they are not all the same.
	var orders: Array = []
	for i: int in 5:
		# result: one shuffle.
		var result: Dictionary = Rng.shuffle(current, "shuffle:p1", deck)
		current = result["state"]
		# sorted_result: the shuffled list sorted, which must equal the sorted deck.
		var sorted_result: Array = result["value"].duplicate()
		sorted_result.sort()
		# sorted_deck: the deck sorted the same way.
		var sorted_deck: Array = deck.duplicate()
		sorted_deck.sort()
		assert_eq(sorted_result, sorted_deck, "shuffle keeps every card exactly once")
		orders.append(result["value"])
	assert_ne(orders[0], orders[1], "successive shuffles differ")
	assert_eq(Rng.shuffle(current, "shuffle:p1", [])["state"], current, "empty list draws nothing")
	assert_eq(Rng.shuffle(current, "shuffle:p1", ["c1"])["value"], ["c1"], "one item")
	assert_eq(Rng.shuffle(current, "shuffle:p1", ["c1"])["state"], current, "one item draws nothing")
