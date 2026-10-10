## The named random streams (GDD "Random streams" and "Fields added for Ethan"). Lane: core (Agent A).
##
## This file is the only source of randomness in the game. Every stream is an independent
## SplitMix64 generator whose whole state is one 64-bit int, kept in run_state.rng under the key
## format of core/schema/run_state.gd: "map", "encounters", "combat_ai", "side_quest", and per
## player "rewards:<player_id>", "shuffle:<player_id>", "dice:<player_id>". Because the state lives
## in run_state, a snapshot (var_to_bytes / bytes_to_var) resumes every stream exactly.
##
## Everything here is written out in integer math, not Godot's RandomNumberGenerator or
## String.hash(), so results cannot change with an engine upgrade:
##   - Stream seed: SplitMix64's finalizer over (run_seed XOR finalizer(FNV-1a 64 of the key's UTF-8 bytes)).
##   - Step: state += GOLDEN_GAMMA; output = finalizer(state). (Steele, Lea, Flood 2014; Vigna's splitmix64.c.)
##   - Ranges: rejection sampling on the top 63 bits, so no value is more likely than another.
## GDScript ints are signed 64-bit and wrap on overflow; tests/core/rng/test_rng.gd proves this
## and checks the published SplitMix64 test vector, so a change in either is caught.
##
## All functions are static and pure: they never mutate their arguments and return new values.
## Functions that draw take a run state and return
## {"state": new run state, "value": result, "error": ""}.
## The returned state is a shallow copy of the input with a new "rng" Dictionary: every other
## nested value (dudes, combat, map) is the same object as in the input. Neither is changed here,
## but a caller that keeps the old state and then edits the new one in place must duplicate first.
## Who may change values: only the rules core, through these functions.
##
## Bad input (task 029). Rule for all core code: core functions report bad input through an error
## field, never assert or push_error. assert() is removed from release builds, so the check would
## vanish in an exported game; push_error() is invisible to the caller and fails every test. So:
##   - A draw function (next_u64, next_int, weighted_index, shuffle) checks its input before it
##     touches a stream. On bad input it returns {"state": the input state itself, unchanged, no
##     stream advanced; "value": the safe value its comment names; "error": a short text naming
##     the function and the problem}. On success "error" is "". Callers check "error" first, the
##     way apply() callers check "reject" (core/schema/README.md); a caller that ignores it still
##     gets a valid state and a value in the documented range, never a crash.
##   - A function that returns a plain value returns a documented sentinel that no valid result can
##     equal. key_for() returns "" (NO_KEY) for an unknown stream name or a wrong player_id, and
##     every draw function then reports that key as an error, so a bad name cannot create or
##     advance a stream silently. create_streams() skips such keys, so they never get a stream.
##   - Functions that accept every input of their type (derive_stream_state, mix64, fnv1a64,
##     shift_right_logical) need neither; their comments say how each input is handled.
## tests/core/test_purity.gd fails the build if assert( appears in code under core/.
extends RefCounted

## Streams shared by the whole party, keyed by their bare name in run_state.rng (GDD "Random streams").
## map: floor layouts. encounters: which enemies and bosses appear. combat_ai: enemy move and
## target choice. side_quest: gambles and random outcomes. Fixed by the GDD; change only with it.
const SHARED_STREAMS: Array[String] = ["map", "encounters", "combat_ai", "side_quest"]

## Streams each player has their own copy of, keyed "<stream>:<player_id>" in run_state.rng.
## rewards: card, Gear and Brew offers. shuffle: deck shuffles. dice: all die rolls (Ethan's
## Rolls; GDD "Fields added for Ethan"). Fixed by the GDD; change only with it.
const PLAYER_STREAMS: Array[String] = ["rewards", "shuffle", "dice"]

## Separator between a per-player stream name and its player_id in a run_state.rng key ("dice:p1").
## Part of the run_state contract (core/schema/run_state.gd); never change it.
const KEY_SEPARATOR: String = ":"

## SplitMix64's step: 0x9E3779B97F4A7C15 (2^64 / golden ratio) as a signed 64-bit int.
## Added to the stream state once per draw. Part of the algorithm; never change it.
const GOLDEN_GAMMA: int = -7046029254386353131

## First multiplier of SplitMix64's finalizer: 0xBF58476D1CE4E5B9 as a signed 64-bit int. Never change.
const MIX_MULT_1: int = -4658895280553007687

## Second multiplier of SplitMix64's finalizer: 0x94D049BB133111EB as a signed 64-bit int. Never change.
const MIX_MULT_2: int = -7723592293110705685

## FNV-1a 64-bit offset basis, 0xCBF29CE484222325 as a signed 64-bit int. Used to hash stream
## keys. Changing it changes every stream of every seed and breaks saves; never change it.
const FNV_OFFSET: int = -3750763034362895579

## FNV-1a 64-bit prime, 0x100000001B3 (1099511628211). Used to hash stream keys. Never change.
const FNV_PRIME: int = 1099511628211

## Largest signed 64-bit int, 2^63 - 1. Upper bound of the 63-bit values the range functions use.
const INT64_MAX: int = 9223372036854775807

## What key_for() returns for an unknown stream name or a wrong player_id: the empty string, which
## is never a run_state.rng key. Every draw function rejects it with an error. Never change it.
const NO_KEY: String = ""

## The "error" value of a draw that succeeded. Never change it; callers compare against it.
const NO_ERROR: String = ""

## Safe "value" of weighted_index() on bad input: never a valid index into weights. A caller must
## check "error" first: GDScript reads array[-1] as the last item, so indexing with it is not safe.
## Never change it.
const NO_INDEX: int = -1


## Returns the run_state.rng key for a stream: the bare name for a shared stream, or
## "<stream>:<player_id>" for a per-player stream. Returns NO_KEY ("") when the name is unknown or
## player_id does not fit it (given for a shared stream, missing for a per-player one); every draw
## function reports that key as an error (see the file comment).
## stream: one of SHARED_STREAMS or PLAYER_STREAMS.
## player_id: the owning player ("p1".."p4") for a per-player stream; "" for a shared one.
static func key_for(stream: String, player_id: String = "") -> String:
	if player_id == "":
		if stream in SHARED_STREAMS:
			return stream
		return NO_KEY
	if stream in PLAYER_STREAMS:
		return stream + KEY_SEPARATOR + player_id
	return NO_KEY


## Returns the starting state of one stream, derived from the run's seed and the stream's key
## alone, so adding or removing other streams never changes it. Any 64-bit int.
## run_seed: the run's seed (run_state.run_seed), any 64-bit int.
## key: the run_state.rng key, from key_for(). Any String is hashed, NO_KEY included; callers
## (create_streams) skip NO_KEY so it never becomes a stream.
static func derive_stream_state(run_seed: int, key: String) -> int:
	return mix64(run_seed ^ mix64(fnv1a64(key)))


## Returns a new run_state.rng map holding every stream for a run: the shared streams and, for
## each player, their own rewards, shuffle and dice streams. Values depend only on run_seed and
## each key, never on the order of player_ids.
## run_seed: the run's seed (run_state.run_seed), any 64-bit int.
## player_ids: the run's player ids in seat order, e.g. ["p1"]; 1..4 entries, no duplicates.
## An entry that is not a non-empty String gets no streams (key_for gives NO_KEY), so any draw
## for that player reports an error instead of using a stream nobody seeded.
static func create_streams(run_seed: int, player_ids: Array) -> Dictionary:
	# rng: the map being built, stream key -> starting state.
	var rng: Dictionary = {}
	for stream: String in SHARED_STREAMS:
		rng[stream] = derive_stream_state(run_seed, stream)
	for player_id: Variant in player_ids:
		if not player_id is String:
			continue
		for stream: String in PLAYER_STREAMS:
			# key: this player's key for this stream; NO_KEY when player_id is "".
			var key: String = key_for(stream, player_id)
			if key != NO_KEY:
				rng[key] = derive_stream_state(run_seed, key)
	return rng


## Returns a copy of run_state with "rng" filled from its own run_seed and the player_id of each
## Dude in its dudes list. Any streams already present are replaced. Used once, at run start.
## state: a run state (core/schema/run_state.gd) with run_seed and dudes set. Not changed.
static func with_new_streams(state: Dictionary) -> Dictionary:
	# player_ids: each Dude's player_id, in seat order.
	var player_ids: Array = []
	for dude: Dictionary in state["dudes"]:
		player_ids.append(dude["player_id"])
	# out: the shallow copy returned (see the file comment).
	var out: Dictionary = state.duplicate()
	out["rng"] = create_streams(state["run_seed"], player_ids)
	return out


## Draws one raw 64-bit value (any int, negative included) from a stream.
## Returns {"state": new run state, "value": int, "error": ""}. On a bad key (see _key_error):
## {"state": state unchanged, "value": 0, "error": text}.
## state: a run state whose rng holds key. Not changed.
## key: the run_state.rng key, from key_for().
static func next_u64(state: Dictionary, key: String) -> Dictionary:
	# problem: why key cannot be drawn from, or "" when it can.
	var problem: String = _key_error(state, key)
	if problem != NO_ERROR:
		return _failed(state, 0, "next_u64: " + problem)
	# step: [new stream state, output] for one SplitMix64 step.
	var step: Array[int] = _step(_stream_state(state, key))
	return _drawn(state, key, step[0], step[1])


## Draws a whole number from lo to hi inclusive, each equally likely.
## Returns {"state": new run state, "value": int in lo..hi, "error": ""}. On a bad key, hi < lo, or
## a range too wide (hi - lo >= INT64_MAX): {"state": state unchanged, "value": lo, "error": text}.
## state: a run state whose rng holds key. Not changed.
## key: the run_state.rng key, from key_for().
## lo: smallest possible result. hi: largest possible result; must be >= lo, and hi - lo must
## be below INT64_MAX (any range a game value needs).
static func next_int(state: Dictionary, key: String, lo: int, hi: int) -> Dictionary:
	# problem: why key cannot be drawn from, or "" when it can.
	var problem: String = _key_error(state, key)
	if problem != NO_ERROR:
		return _failed(state, lo, "next_int: " + problem)
	if hi < lo:
		return _failed(state, lo, "next_int: empty range %d..%d (hi is below lo)" % [lo, hi])
	# span: hi - lo; negative when the subtraction wrapped past INT64_MAX.
	var span: int = hi - lo
	if span < 0 or span >= INT64_MAX:
		return _failed(state, lo, "next_int: range %d..%d is too wide (hi - lo must be below 2^63 - 1)" % [lo, hi])
	# draw: [new stream state, offset in 0..hi - lo].
	var draw: Array[int] = _bounded(_stream_state(state, key), span + 1)
	return _drawn(state, key, draw[0], lo + draw[1])


## Picks an index into weights, each index with probability weight / total of weights. Used for
## enemy moves, which carry a `weight` for random choice (GDD "Enemy fields").
## Returns {"state": new run state, "value": int index into weights, "error": ""}. Zero-weight
## entries are never picked. On a bad key, empty weights, a weight that is not an int or is
## negative, weights totalling 0, or a total above INT64_MAX:
## {"state": state unchanged, "value": NO_INDEX (-1), "error": text}.
## state: a run state whose rng holds key. Not changed.
## key: the run_state.rng key, from key_for().
## weights: ints >= 0 with a total above 0, in a fixed order (sort first if they come from a Dictionary).
static func weighted_index(state: Dictionary, key: String, weights: Array) -> Dictionary:
	# problem: why key cannot be drawn from, or "" when it can.
	var problem: String = _key_error(state, key)
	if problem != NO_ERROR:
		return _failed(state, NO_INDEX, "weighted_index: " + problem)
	if weights.is_empty():
		return _failed(state, NO_INDEX, "weighted_index: no weights")
	# total: sum of all weights; the draw is a number in 0..total - 1.
	var total: int = 0
	for i: int in weights.size():
		if typeof(weights[i]) != TYPE_INT:
			return _failed(state, NO_INDEX, "weighted_index: weight %d is not an int (%s)" % [i, type_string(typeof(weights[i]))])
		# weight: weights[i] as an int.
		var weight: int = weights[i]
		if weight < 0:
			return _failed(state, NO_INDEX, "weighted_index: weight %d is negative (%d)" % [i, weight])
		if weight > INT64_MAX - total:
			return _failed(state, NO_INDEX, "weighted_index: weights total more than 2^63 - 1")
		total += weight
	if total == 0:
		return _failed(state, NO_INDEX, "weighted_index: weights total 0")
	# draw: [new stream state, ticket in 0..total - 1].
	var draw: Array[int] = _bounded(_stream_state(state, key), total)
	# cumulative: running total of weights up to and including index i.
	var cumulative: int = 0
	# picked: the chosen index; the last one unless a ticket lands earlier.
	var picked: int = weights.size() - 1
	for i: int in weights.size():
		cumulative += weights[i]
		if draw[1] < cumulative:
			picked = i
			break
	return _drawn(state, key, draw[0], picked)


## Shuffles a list with Fisher–Yates (from the last position down, each swapped with a uniformly
## chosen position at or before it), so every order is equally likely.
## Returns {"state": new run state, "value": new Array, "error": ""}; items itself is not changed.
## On a bad key: {"state": state unchanged, "value": a copy of items in its original order,
## "error": text}. The key is checked even for an empty or one-item list.
## state: a run state whose rng holds key. Not changed.
## key: the run_state.rng key, from key_for(); deck shuffles use "shuffle:<player_id>".
## items: the list to shuffle, any values. An empty or one-item list draws nothing.
static func shuffle(state: Dictionary, key: String, items: Array) -> Dictionary:
	# result: the copy being shuffled in place.
	var result: Array = items.duplicate()
	# problem: why key cannot be drawn from, or "" when it can.
	var problem: String = _key_error(state, key)
	if problem != NO_ERROR:
		return _failed(state, result, "shuffle: " + problem)
	# stream: this stream's state, advanced once per swap.
	var stream: int = _stream_state(state, key)
	# i: the position being filled, from the end down to 1.
	var i: int = result.size() - 1
	while i > 0:
		# draw: [new stream state, position j in 0..i to swap with i].
		var draw: Array[int] = _bounded(stream, i + 1)
		stream = draw[0]
		# held: the value at i while it is swapped.
		var held: Variant = result[i]
		result[i] = result[draw[1]]
		result[draw[1]] = held
		i -= 1
	return _drawn(state, key, stream, result)


## SplitMix64's finalizer: scrambles a 64-bit int so nearby inputs give unrelated outputs.
## Returns any 64-bit int. Public so tests can check it against the published algorithm.
## z: any 64-bit int.
static func mix64(z: int) -> int:
	# x: the value as it is scrambled.
	var x: int = z
	x = (x ^ shift_right_logical(x, 30)) * MIX_MULT_1
	x = (x ^ shift_right_logical(x, 27)) * MIX_MULT_2
	return x ^ shift_right_logical(x, 31)


## FNV-1a 64-bit hash of a string's UTF-8 bytes. Returns any 64-bit int. Written out so stream
## seeds do not depend on String.hash(), which Godot may change between versions.
## text: the string to hash; stream keys are ASCII.
static func fnv1a64(text: String) -> int:
	# h: the running hash.
	var h: int = FNV_OFFSET
	for byte: int in text.to_utf8_buffer():
		h = (h ^ byte) * FNV_PRIME
	return h


## Shifts a 64-bit int right, filling with zeros (an unsigned shift). Returns an int >= 0 for
## bits 1..63. GDScript's >> refuses a negative operand ("Only positive operands are supported"), so a
## negative x has its sign bit cleared before the shift and that bit added back at position 63 - bits.
## x: any 64-bit int. bits: how far to shift, 1..63. Outside that, as an unsigned shift would:
## bits <= 0 returns x unchanged and bits >= 64 returns 0.
static func shift_right_logical(x: int, bits: int) -> int:
	if bits <= 0:
		return x
	if bits >= 64:
		return 0
	if x >= 0:
		return x >> bits
	return ((x & INT64_MAX) >> bits) | (1 << (63 - bits))


## One SplitMix64 step. Returns [new stream state, output], both any 64-bit int.
## stream: the stream's current state.
static func _step(stream: int) -> Array[int]:
	# next: the advanced state.
	var next: int = stream + GOLDEN_GAMMA
	return [next, mix64(next)]


## Draws a number in 0..count - 1, each equally likely, by rejection sampling on the top 63 bits
## of each output. Returns [new stream state, value].
## stream: the stream's current state. count: how many possible values, 1..INT64_MAX. Callers
## check it first; a count below 1 returns [stream, 0] without drawing, so % 0 cannot happen.
static func _bounded(stream: int, count: int) -> Array[int]:
	if count < 1:
		return [stream, 0]
	# remainder: 2^63 mod count. The last `remainder` 63-bit values are rejected so every result is equally likely.
	var remainder: int = (INT64_MAX % count + 1) % count
	# limit: largest accepted 63-bit value.
	var limit: int = INT64_MAX - remainder
	# current: the stream state as draws are made.
	var current: int = stream
	while true:
		# step: [new state, output] for this attempt.
		var step: Array[int] = _step(current)
		current = step[0]
		# top: the output's top 63 bits, 0..INT64_MAX.
		var top: int = shift_right_logical(step[1], 1)
		if top <= limit:
			return [current, top % count]
	return [current, 0]


## Returns why key cannot be drawn from in state, or NO_ERROR ("") when it can: key is not NO_KEY,
## state has an "rng" Dictionary, and that holds key with an int value.
## state: a run state. Not changed. key: the run_state.rng key, from key_for().
static func _key_error(state: Dictionary, key: String) -> String:
	if key == NO_KEY:
		return "no stream key (key_for got an unknown stream name or a wrong player_id)"
	# rng: the state's stream map, or null when it has none.
	var rng: Variant = state.get("rng")
	if not rng is Dictionary:
		return "state has no rng streams; call with_new_streams at run start"
	if not rng.has(key):
		return "random stream '%s' does not exist" % key
	if typeof(rng[key]) != TYPE_INT:
		return "random stream '%s' is not an int" % key
	return NO_ERROR


## Returns the current state of one stream. Call only after _key_error(state, key) returned "".
## state: a run state. key: the run_state.rng key.
static func _stream_state(state: Dictionary, key: String) -> int:
	return state["rng"][key]


## Returns a draw function's success result: {"state": state with key's stream set to
## stream_state, "value": value, "error": NO_ERROR}.
## state: the input run state. Not changed. key: the stream drawn from.
## stream_state: the stream's new state. value: the drawn result, any type.
static func _drawn(state: Dictionary, key: String, stream_state: int, value: Variant) -> Dictionary:
	return {"state": _with_stream_state(state, key, stream_state), "value": value, "error": NO_ERROR}


## Returns a draw function's bad-input result: {"state": state itself, unchanged, "value": value,
## "error": error}. No stream is advanced.
## state: the input run state, returned as is. value: the function's documented safe value.
## error: a short non-empty text, "<function>: <problem>".
static func _failed(state: Dictionary, value: Variant, error: String) -> Dictionary:
	return {"state": state, "value": value, "error": error}


## Returns a shallow copy of state with a new rng Dictionary in which key holds stream_state.
## state: a run state. Not changed. key: the run_state.rng key. stream_state: the stream's new state.
static func _with_stream_state(state: Dictionary, key: String, stream_state: int) -> Dictionary:
	# out: the shallow copy returned.
	var out: Dictionary = state.duplicate()
	# rng: the new stream map, a copy of the old one with one value changed.
	var rng: Dictionary = state["rng"].duplicate()
	rng[key] = stream_state
	out["rng"] = rng
	return out
