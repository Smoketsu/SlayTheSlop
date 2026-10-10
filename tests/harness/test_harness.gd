## Self-tests for the test harness (res://tests/run_tests.gd and res://tests/framework/).
## Lane: tools (Agent B).
##
## The end-to-end tests build a throwaway project in the user data folder holding a copy of the
## harness plus one fixture test file, run it in a child Godot process, and check the exit code.
## That way the deliberately broken fixtures never live in res://tests, where they would break
## the real suite.
extends "res://tests/framework/test_case.gd"

## The harness files copied into every throwaway project, by res:// path.
const HARNESS_FILES: Array[String] = ["res://tests/run_tests.gd", "res://tests/framework/test_case.gd"]

## A fixture whose only test passes.
const PASSING := "extends \"res://tests/framework/test_case.gd\"\nfunc test_ok() -> void:\n\tassert_eq(1, 1)\n"
## A fixture whose test fails one assertion.
const FAILING := "extends \"res://tests/framework/test_case.gd\"\nfunc test_bad() -> void:\n\tassert_eq(1, 2)\n"
## A fixture whose test raises a runtime error (index out of range) and asserts nothing.
const RUNTIME_ERROR := "extends \"res://tests/framework/test_case.gd\"\nfunc test_crash() -> void:\n\tvar a: Array = []\n\tprint(a[3])\n"
## A fixture that does not parse.
const PARSE_ERROR := "extends \"res://tests/framework/test_case.gd\"\nfunc test_broken(:\n"


## strict_diff treats 3 and 3.0 as different, at the top and deep inside.
func test_strict_diff_checks_types() -> void:
	assert_ne(strict_diff(3, 3.0, "$"), "", "int vs float")
	assert_eq(strict_diff({"x": [1, {"y": 2}]}, {"x": [1, {"y": 2.0}]}, "$"), "$.x[1].y: 2 (int) != 2.0 (float)")
	assert_ne(strict_diff("a", &"a", "$"), "", "String vs StringName")


## strict_diff reports equal values as "" and names the first difference otherwise.
func test_strict_diff_paths() -> void:
	assert_eq(strict_diff({"a": [1, 2], "b": {"c": "d"}}, {"b": {"c": "d"}, "a": [1, 2]}, "$"), "", "key order ignored")
	assert_eq(strict_diff([1, 2], [1, 2, 3], "$"), "$: length 2 != 3")
	assert_eq(strict_diff({"a": 1}, {"b": 1}, "$"), "$: key \"a\" (String) missing from the second value")
	assert_eq(strict_diff({1: "x"}, {1.0: "x"}, "$"), "$: key 1 (int) missing from the second value")
	assert_eq(strict_diff(null, null, "$"), "")


## Assertions record failures and let the test carry on.
func test_assertions_record_and_continue() -> void:
	# probe: a separate test object, so its failures do not fail this test.
	var probe: Variant = (get_script() as GDScript).get_base_script().new()
	probe.assert_true(false, "one")
	probe.assert_false(true, "two")
	probe.assert_eq(1, 2, "three")
	probe.assert_ne(1, 1, "four")
	probe.assert_no_errors(["x"], "five")
	probe.assert_true(true)
	probe.assert_eq([1.0], [1.0])
	probe.assert_no_errors([])
	assert_eq(probe.failures.size(), 5, "five failures recorded")
	assert_true(probe.failures[2].begins_with("three: $: 1 (int) != 2 (int)"), "assert_eq message: %s" % probe.failures[2])


## A passing fixture exits 0; a failing assertion, a runtime error and a parse error each exit 1.
func test_exit_codes() -> void:
	assert_eq(_run_fixture({"test_pass.gd": PASSING})[0], 0, "passing file")
	assert_eq(_run_fixture({"test_fail.gd": FAILING})[0], 1, "failing assertion")
	assert_eq(_run_fixture({"test_crash.gd": RUNTIME_ERROR})[0], 1, "runtime error")
	assert_eq(_run_fixture({"test_broken.gd": PARSE_ERROR})[0], 1, "parse error")
	assert_eq(_run_fixture({"test_pass.gd": PASSING, "test_fail.gd": FAILING})[0], 1, "one bad file fails the run")


## No tests at all, or a filter that matches nothing, exits 1; a matching filter runs only matches.
func test_empty_runs_and_filters() -> void:
	assert_eq(_run_fixture({})[0], 1, "no test files")
	assert_eq(_run_fixture({"test_pass.gd": PASSING}, ["nomatch"])[0], 1, "filter matches nothing")
	# result: [exit code, output] for a filter that skips the failing file.
	var result: Array = _run_fixture({"a/test_pass.gd": PASSING, "b/test_fail.gd": FAILING}, ["a/"])
	assert_eq(result[0], 0, "filter skips the failing file")
	assert_true(result[1].contains("1 passed, 0 failed"), "summary shows only the filtered test")


## Builds a throwaway project with the harness and the given fixtures, runs it in a child Godot,
## deletes the project, and returns [exit code, combined output].
## fixtures: path under tests/ -> file text. filters: arguments passed after "--".
func _run_fixture(fixtures: Dictionary, filters: Array[String] = []) -> Array:
	# root: the throwaway project folder, unique per call.
	var root: String = OS.get_user_data_dir().path_join("harness_selftest_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(root.path_join("tests/framework"))
	_write(root.path_join("project.godot"), "config_version=5\n")
	for path: String in HARNESS_FILES:
		_write(root.path_join(path.trim_prefix("res://")), FileAccess.get_file_as_string(path))
	for path: String in fixtures:
		DirAccess.make_dir_recursive_absolute(root.path_join("tests").path_join(path).get_base_dir())
		_write(root.path_join("tests").path_join(path), fixtures[path])
	# args: the child Godot's command line.
	var args: PackedStringArray = ["--headless", "--path", root, "--script", "res://tests/run_tests.gd"]
	if not filters.is_empty():
		args.append("--")
		args.append_array(filters)
	# output: the child's stdout and stderr, filled by OS.execute.
	var output: Array = []
	# code: the child's exit code.
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	_remove(root)
	return [code, "\n".join(output)]


## Writes text to an absolute file path.
## path: where. text: what.
func _write(path: String, text: String) -> void:
	# file: the open file, closed when it goes out of scope.
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)


## Deletes a folder and everything in it.
## path: an absolute folder path inside the user data folder.
func _remove(path: String) -> void:
	for sub: String in DirAccess.get_directories_at(path):
		_remove(path.path_join(sub))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
