## Base class for every test file. Lane: tools (Agent B).
##
## Test files say `extends "res://tests/framework/test_case.gd"` and define methods named test_*.
## The runner (res://tests/run_tests.gd) makes a fresh instance for each test_* method, calls it,
## then reads `failures`. Assertions record a failure and carry on; they never stop the test.
##
## This interface is what Agent A's tests are written against (task 002). Adding a member is fine;
## renaming or changing one is a shared-contract change.
extends RefCounted

## Failure messages recorded during the current test, in the order they happened. Empty means the
## test passed. Written by the assertions below; read by the runner. Tests should not clear it.
var failures: Array[String] = []


## Records a failure and lets the test continue.
## message: what went wrong, shown in the runner's output.
func fail(message: String) -> void:
	failures.append(message)


## Fails unless condition is true.
## condition: the value under test. message: shown on failure.
func assert_true(condition: bool, message := "expected true") -> void:
	if not condition:
		fail(message)


## Fails unless condition is false.
## condition: the value under test. message: shown on failure.
func assert_false(condition: bool, message := "expected false") -> void:
	if condition:
		fail(message)


## Fails unless actual and expected are strictly and deeply equal (see strict_diff): types must
## match at every level, so 3 and 3.0 differ. Godot's JSON parser returns floats, so this matters.
## actual: the value produced. expected: the value wanted. message: shown before the difference.
func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	# diff: where the two first differ, or "" when equal.
	var diff: String = strict_diff(actual, expected, "$")
	if diff != "":
		fail(diff if message == "" else "%s: %s" % [message, diff])


## Fails if actual and unexpected are strictly and deeply equal. Same strictness as assert_eq.
## actual: the value produced. unexpected: the value it must not equal. message: shown on failure.
func assert_ne(actual: Variant, unexpected: Variant, message := "values are equal") -> void:
	if strict_diff(actual, unexpected, "$") == "":
		fail("%s: %s" % [message, _show(actual)])


## Fails, listing every error, if errors is non-empty. Used with the core/schema check() functions,
## which return a list of problems.
## errors: the problems found; each is shown on its own line. message: shown above the list.
func assert_no_errors(errors: Array, message := "unexpected errors") -> void:
	if not errors.is_empty():
		fail("%s:\n  %s" % [message, "\n  ".join(errors.map(func(e: Variant) -> String: return str(e)))])


## Returns "" when a and b are strictly and deeply equal, otherwise where they first differ, for
## example "$.x[1].y: 2 != 3".
## Rules: the Variant type must match at every level (int 3 is not float 3.0). Arrays compare by
## length then element by element; whether an array is typed is not compared. Dictionaries compare
## by key set (keys strictly typed too) then value by value, in a stable order. Floats compare
## exactly. Objects compare by identity.
## a: the first value. b: the second value. path: where a and b sit, "$" at the top.
static func strict_diff(a: Variant, b: Variant, path: String) -> String:
	if typeof(a) != typeof(b):
		return "%s: %s != %s" % [path, _show(a), _show(b)]
	match typeof(a):
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, \
		TYPE_PACKED_VECTOR4_ARRAY:
			if a.size() != b.size():
				return "%s: length %d != %d" % [path, a.size(), b.size()]
			for i: int in a.size():
				# inner: the difference inside element i, if any.
				var inner: String = strict_diff(a[i], b[i], "%s[%d]" % [path, i])
				if inner != "":
					return inner
			return ""
		TYPE_DICTIONARY:
			# a_keys, b_keys: each side's keys in a stable order, so the reported difference never
			# depends on insertion order.
			var a_keys: Array = _sorted_keys(a)
			var b_keys: Array = _sorted_keys(b)
			for key: Variant in a_keys:
				if _find_key(b_keys, key) == -1:
					return "%s: key %s missing from the second value" % [path, _show(key)]
			for key: Variant in b_keys:
				if _find_key(a_keys, key) == -1:
					return "%s: key %s missing from the first value" % [path, _show(key)]
			for key: Variant in a_keys:
				# step: the path to this value.
				var step: String = "%s.%s" % [path, key] if typeof(key) == TYPE_STRING else "%s[%s]" % [path, _show(key)]
				# inner: the difference under this key, if any.
				var inner: String = strict_diff(a[key], b[key], step)
				if inner != "":
					return inner
			return ""
		TYPE_OBJECT:
			return "" if is_same(a, b) else "%s: %s != %s (different objects)" % [path, _show(a), _show(b)]
		_:
			return "" if a == b else "%s: %s != %s" % [path, _show(a), _show(b)]


## Returns the keys of a dictionary sorted by type, then by printed value, for a stable order.
## d: the dictionary.
static func _sorted_keys(d: Dictionary) -> Array:
	# keys: a copy of the keys, sorted in place.
	var keys: Array = d.keys()
	keys.sort_custom(func(x: Variant, y: Variant) -> bool:
		return typeof(x) < typeof(y) if typeof(x) != typeof(y) else var_to_str(x) < var_to_str(y))
	return keys


## Returns the index in keys of a key equal to key with the same type, or -1.
## keys: the list to search. key: the key wanted.
static func _find_key(keys: Array, key: Variant) -> int:
	for i: int in keys.size():
		if typeof(keys[i]) == typeof(key) and keys[i] == key:
			return i
	return -1


## Returns a value printed with its type, for failure messages, for example "3 (int)".
## value: the value to show.
static func _show(value: Variant) -> String:
	return "%s (%s)" % [var_to_str(value), type_string(typeof(value))]
