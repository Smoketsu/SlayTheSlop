## Snapshots of a run state as bytes, and the state hash (task 027). Lane: run (Agent A).
##
## Used for saves (GDD "Sessions": the host saves after every node) and for co-op resync
## (GDD "How a card gets played in co-op", step 6: clients compare a state hash with the host's
## at the end of each turn, and on a mismatch the host sends a full snapshot).
##
## Format: var_to_bytes() of the canonical form of the state (see canonical()). Never JSON,
## because JSON numbers are doubles and the seed and random stream states are 64-bit ints
## (core/schema/README.md "Serialization"). Objects are never encoded or decoded.
##
## Trust: from_bytes() treats its input as untrusted (a save file, or bytes from the network).
## Before bytes_to_var() sees anything, _scan() walks the whole buffer and accepts only the
## JSON-shaped types a state may hold (null, bool, int, String, untyped Array, untyped
## Dictionary with String keys), with every length inside the buffer and every String valid
## UTF-8. That way corrupt input is refused with a message instead of an engine error, and an
## Object (which bytes_to_var decodes as an EncodedObjectAsID even with objects disallowed) or a
## float can never reach the state.
##
## Pure: produces and consumes bytes only. Writing them to disk or the network is the client's job.
## No file, clock, network, scene tree or random access.
extends RefCounted

const RunState := preload("res://core/schema/run_state.gd")

## Mask for the Variant type in an encoded value's 32-bit header (Godot's marshalls.cpp,
## HEADER_TYPE_MASK). The upper 16 bits are flags. Fixed by the engine; never changed here.
const HEADER_TYPE_MASK: int = 0xFFFF

## Header flag saying an int is stored in 8 bytes instead of 4 (Godot's ENCODE_FLAG_64).
## Godot sets it for ints outside the 32-bit range. Fixed by the engine.
const FLAG_64: int = 1 << 16

## Mask for an Array or Dictionary element count; Godot ignores the top bit when decoding
## (it was the old "shared" flag). Fixed by the engine.
const COUNT_MASK: int = 0x7FFFFFFF

## Deepest nesting of Arrays and Dictionaries accepted, counting the root as depth 0. A state
## nests about 6 levels today; this bounds recursion on crafted input. A technical limit, not
## a tuning constant; raise it in this file if the run lane's map ever nests deeper.
const MAX_DEPTH: int = 64


## Returns the snapshot bytes of a state: var_to_bytes() of canonical(state), without objects.
## Equal states give equal bytes, whatever order their Dictionaries were filled in.
## state: a run state (core/schema/run_state.gd). Not modified. It should pass
## RunState.check(); this function does not check it, but from_bytes() will refuse it if not.
static func to_bytes(state: Dictionary) -> PackedByteArray:
	return var_to_bytes(canonical(state))


## Decodes snapshot bytes back into a run state, refusing anything it cannot trust.
## bytes: snapshot bytes from to_bytes(), possibly corrupt, truncated or from another version.
## Returns {"ok": bool, "state": the run state Dictionary or null, "error": "" or why it was refused}.
## Refused: bytes that are not a well-formed snapshot of JSON-shaped values (see _scan()), a value
## that is not a Dictionary, a missing or different schema_version, and anything
## RunState.check() reports.
static func from_bytes(bytes: PackedByteArray) -> Dictionary:
	# problem: receives the first structural problem _scan() finds, if any.
	var problem: Array[String] = []
	# end: offset just past the root value, or -1 if the bytes are malformed.
	var end: int = _scan(bytes, 0, 0, problem)
	if end < 0:
		return _refuse("not a valid snapshot: " + problem[0])
	if end != bytes.size():
		return _refuse("not a valid snapshot: %d unexpected bytes after the state, from byte %d" % [bytes.size() - end, end])
	# value: the decoded root value; safe to decode because _scan() accepted every byte.
	var value: Variant = bytes_to_var(bytes)
	if typeof(value) != TYPE_DICTIONARY:
		return _refuse("snapshot holds a %s, expected a Dictionary (a run state)" % type_string(typeof(value)))
	if not value.has("schema_version"):
		return _refuse("snapshot has no schema_version; this build reads schema_version %d" % RunState.SCHEMA_VERSION)
	if typeof(value["schema_version"]) != TYPE_INT:
		return _refuse("snapshot schema_version is a %s, not an int; this build reads schema_version %d" % [
			type_string(typeof(value["schema_version"])), RunState.SCHEMA_VERSION])
	if value["schema_version"] != RunState.SCHEMA_VERSION:
		return _refuse("snapshot has schema_version %d but this build reads schema_version %d (saves are not migrated)" % [
			value["schema_version"], RunState.SCHEMA_VERSION])
	# errors: problems RunState.check() finds in the decoded state.
	var errors: Array[String] = RunState.check(value)
	if not errors.is_empty():
		return _refuse("snapshot state fails run_state.check(): " + "; ".join(PackedStringArray(errors)))
	return {"ok": true, "state": value, "error": ""}


## Returns the state hash used for the co-op desync check: SHA-256 of to_bytes(state), as 64
## lowercase hex characters. Equal states give the same hash whatever their Dictionary insertion
## order; any change to a value, a key, a type (3 versus 3.0) or a list's order changes it.
## state: a run state. Not modified.
static func state_hash(state: Dictionary) -> String:
	# context: SHA-256 hasher fed the canonical snapshot bytes.
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(to_bytes(state))
	return context.finish().hex_encode()


## Returns a deep copy of value in canonical form: every Dictionary rebuilt with its keys inserted
## in sorted order, every Array rebuilt as a plain untyped Array, other values unchanged.
## var_to_bytes() keeps insertion order, so this is what makes equal states give equal bytes.
## value: any state value. Dictionary keys must all be Strings (the state rule), so they sort
## by Unicode code point, the same on every machine.
static func canonical(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			# keys: value's keys in sorted order.
			var keys: Array = value.keys()
			keys.sort()
			# out: the rebuilt Dictionary.
			var out: Dictionary = {}
			for key: Variant in keys:
				out[key] = canonical(value[key])
			return out
		TYPE_ARRAY:
			# out: the rebuilt, untyped Array, same order.
			var out: Array = []
			for item: Variant in value:
				out.append(canonical(item))
			return out
		_:
			return value


## Returns a refusal result for from_bytes().
## error: why the bytes were refused, shown to whoever handles the failed load.
static func _refuse(error: String) -> Dictionary:
	return {"ok": false, "state": null, "error": error}


## Checks that one encoded value starting at byte at is well formed and JSON-shaped, recursively,
## without decoding it. Returns the offset just past the value, or -1 after appending one message
## to problem. Mirrors Godot 4's var_to_bytes layout: a 32-bit little-endian header (type in the
## low 16 bits, flags above), then the payload, padded to a multiple of 4 bytes.
## bytes: the whole snapshot. at: offset of the value's header, 0 or more.
## depth: nesting level of this value, 0 for the root, at most MAX_DEPTH.
## problem: receives the message when the value is refused.
static func _scan(bytes: PackedByteArray, at: int, depth: int, problem: Array[String]) -> int:
	if depth > MAX_DEPTH:
		problem.append("byte %d: nested deeper than %d levels" % [at, MAX_DEPTH])
		return -1
	if at + 4 > bytes.size():
		problem.append("truncated at byte %d (snapshot is %d bytes)" % [at, bytes.size()])
		return -1
	# header: the value's 32-bit header word.
	var header: int = bytes.decode_u32(at)
	# type: the Variant.Type in the header.
	var type: int = header & HEADER_TYPE_MASK
	# flags: the header bits above the type; only FLAG_64 on an int is allowed.
	var flags: int = header & ~HEADER_TYPE_MASK
	# body: offset of the payload, just past the header.
	var body: int = at + 4
	if type >= TYPE_MAX or (flags != 0 and not (type == TYPE_INT and flags == FLAG_64)):
		problem.append("byte %d: header %08x is not a value a state may hold" % [at, header])
		return -1
	match type:
		TYPE_NIL:
			return body
		TYPE_BOOL:
			if not _fits(bytes, body, 4, problem):
				return -1
			if bytes.decode_u32(body) > 1:
				problem.append("byte %d: bool is %d, expected 0 or 1" % [body, bytes.decode_u32(body)])
				return -1
			return body + 4
		TYPE_INT:
			# size: payload size in bytes, 8 with FLAG_64, otherwise 4.
			var size: int = 8 if flags == FLAG_64 else 4
			if not _fits(bytes, body, size, problem):
				return -1
			return body + size
		TYPE_STRING:
			return _scan_string(bytes, at, problem)
		TYPE_ARRAY, TYPE_DICTIONARY:
			if not _fits(bytes, body, 4, problem):
				return -1
			# count: number of elements (Array) or key/value pairs (Dictionary).
			var count: int = bytes.decode_u32(body) & COUNT_MASK
			# next: offset of the next element to scan.
			var next: int = body + 4
			# smallest: bytes each element needs at least (one header, two for a key/value pair).
			var smallest: int = 4 if type == TYPE_ARRAY else 8
			if count > (bytes.size() - next) / smallest:
				problem.append("byte %d: %d entries cannot fit in the %d bytes left" % [body, count, bytes.size() - next])
				return -1
			for i: int in count:
				if type == TYPE_DICTIONARY:
					if next + 4 <= bytes.size() and (bytes.decode_u32(next) & HEADER_TYPE_MASK) != TYPE_STRING:
						problem.append("byte %d: Dictionary key is not a String" % next)
						return -1
					next = _scan(bytes, next, depth + 1, problem)
					if next < 0:
						return -1
				next = _scan(bytes, next, depth + 1, problem)
				if next < 0:
					return -1
			return next
		_:
			problem.append("byte %d: a %s is not allowed in a state" % [at, type_string(type)])
			return -1


## Checks one encoded String whose header is at byte at: a 32-bit length, that many bytes of
## UTF-8 with no NUL, then zero to three padding bytes up to a multiple of 4. Returns the offset
## just past the padding, or -1 after appending a message to problem.
## bytes: the whole snapshot. at: offset of the String's header.
## problem: receives the message when the String is refused.
static func _scan_string(bytes: PackedByteArray, at: int, problem: Array[String]) -> int:
	if not _fits(bytes, at + 4, 4, problem):
		return -1
	# length: the String's size in bytes of UTF-8, without padding.
	var length: int = bytes.decode_u32(at + 4)
	# text: offset of the first UTF-8 byte.
	var text: int = at + 8
	# padded: length rounded up to a multiple of 4, as var_to_bytes writes it.
	var padded: int = length + (4 - length % 4) % 4
	if not _fits(bytes, text, padded, problem):
		return -1
	if not _is_utf8(bytes, text, length):
		problem.append("byte %d: String is not valid UTF-8 (or contains a NUL)" % text)
		return -1
	return text + padded


## True when size bytes starting at byte from lie inside bytes; otherwise appends a message to problem.
## bytes: the whole snapshot. from: first offset needed. size: number of bytes needed, 0 or more.
## problem: receives the message when they do not fit.
static func _fits(bytes: PackedByteArray, from: int, size: int, problem: Array[String]) -> bool:
	if from + size <= bytes.size():
		return true
	problem.append("truncated at byte %d: %d bytes needed, %d left" % [from, size, maxi(bytes.size() - from, 0)])
	return false


## True when the length bytes starting at byte from are well-formed UTF-8 (RFC 3629: no overlong
## forms, no surrogates, nothing above U+10FFFF) and contain no NUL. Stricter than or equal to
## Godot's decoder, so bytes accepted here never make bytes_to_var() report a Unicode error.
## bytes: the whole snapshot. from: offset of the first byte. length: number of bytes, 0 or more,
## already known to lie inside bytes.
static func _is_utf8(bytes: PackedByteArray, from: int, length: int) -> bool:
	# i: offset of the byte being read.
	var i: int = from
	# end: offset just past the last byte.
	var end: int = from + length
	while i < end:
		# lead: the first byte of a character.
		var lead: int = bytes[i]
		if lead == 0:
			return false
		if lead < 0x80:
			i += 1
			continue
		# extra: continuation bytes this character needs, 1..3.
		var extra: int
		# code: the code point being assembled.
		var code: int
		# lowest: smallest code point allowed for this length, to refuse overlong forms.
		var lowest: int
		if lead & 0xE0 == 0xC0:
			extra = 1
			code = lead & 0x1F
			lowest = 0x80
		elif lead & 0xF0 == 0xE0:
			extra = 2
			code = lead & 0x0F
			lowest = 0x800
		elif lead & 0xF8 == 0xF0:
			extra = 3
			code = lead & 0x07
			lowest = 0x10000
		else:
			return false
		if i + extra >= end:
			return false
		for k: int in range(1, extra + 1):
			# next_byte: one continuation byte, which must look like 10xxxxxx.
			var next_byte: int = bytes[i + k]
			if next_byte & 0xC0 != 0x80:
				return false
			code = (code << 6) | (next_byte & 0x3F)
		if code < lowest or code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF):
			return false
		i += extra + 1
	return true
