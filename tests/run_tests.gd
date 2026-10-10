## Runs every test headless and exits 0 when all pass, 1 otherwise. Lane: tools (Agent B).
##
##   godot --headless --path . --import                                   # once, builds .godot/
##   godot --headless --path . --script res://tests/run_tests.gd          # all tests
##   godot --headless --path . --script res://tests/run_tests.gd -- rng   # paths containing "rng"
##
## Finds every res://tests/**/test_*.gd (except tests/framework/), in sorted path order. Each
## test_* method runs on a fresh instance. A test fails when it records a failure, when its file
## does not parse, or when Godot reports an error while it runs. Godot does not stop a call on a
## script error, so errors are caught with a Logger (Godot 4.5+). Exit code 1 also when no test ran.
extends SceneTree

## Where tests are searched for.
const TESTS_ROOT := "res://tests"
## Folder skipped by the search: it holds the harness itself, not tests.
const FRAMEWORK_DIR := "res://tests/framework/"


## Collects every error Godot reports, from any thread, so the runner can tell which test caused
## it. Warnings are ignored.
class ErrorCollector extends Logger:
	## Guards `messages`: Godot may report errors from threads other than the main one.
	var lock := Mutex.new()
	## Every error reported so far, as "file:line: text", oldest first. Only grows.
	var messages: Array[String] = []

	## Called by Godot for every error and warning. Records errors; ignores warnings.
	## function: the C++ or script function that reported it. file, line: where.
	## code: the error text when rationale is empty. rationale: the human-readable text.
	## editor_notify: unused. error_type: a Logger.ErrorType value.
	## script_backtraces: unused; the location is enough here.
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		# text: the best description Godot gave.
		var text: String = rationale if rationale != "" else code
		lock.lock()
		messages.append("%s:%d: %s" % [file, line, text.strip_edges()])
		lock.unlock()

	## Called by Godot for printed messages. Ignored: only errors matter.
	## message: the text. error: true when it went to stderr.
	func _log_message(message: String, error: bool) -> void:
		pass

	## Returns how many errors have been recorded so far.
	func count() -> int:
		lock.lock()
		# n: the count, read under the lock.
		var n: int = messages.size()
		lock.unlock()
		return n

	## Returns the errors recorded since the count was `since`.
	## since: a value returned earlier by count().
	func since(since: int) -> Array[String]:
		lock.lock()
		# recent: a copy of the newer messages.
		var recent: Array[String] = messages.slice(since)
		lock.unlock()
		return recent


## Entry point when run with --script. Runs the tests and quits with the exit code.
func _initialize() -> void:
	# collector: catches Godot errors while tests run; removed before quitting.
	var collector := ErrorCollector.new()
	OS.add_logger(collector)
	# filters: substrings from the command line after "--"; a test file runs if its path contains
	# any of them. Empty runs everything.
	var filters: PackedStringArray = OS.get_cmdline_user_args()
	# files: the test scripts to run, sorted.
	var files: Array[String] = []
	_find_tests(TESTS_ROOT, files)
	files.sort()
	# passed, failed: test counts for the summary.
	var passed: int = 0
	var failed: int = 0
	for path: String in files:
		if not filters.is_empty() and not Array(filters).any(func(f: String) -> bool: return path.contains(f)):
			continue
		# results: [name, failure messages] for each test in this file.
		var results: Array = _run_file(path, collector)
		for result: Array in results:
			if result[1].is_empty():
				passed += 1
				print("PASS %s" % result[0])
			else:
				failed += 1
				print("FAIL %s" % result[0])
				for message: String in result[1]:
					print("    " + message.replace("\n", "\n    "))
	print("\n%d passed, %d failed" % [passed, failed])
	if passed + failed == 0:
		print("No tests ran. Check the path filter: %s" % " ".join(filters))
	OS.remove_logger(collector)
	quit(0 if failed == 0 and passed > 0 else 1)


## Runs every test_* method in one file. Returns a list of [test name, failure messages].
## A file that does not load gives one failing entry named after the file.
## path: the test script. collector: the error logger, to attribute errors to tests.
func _run_file(path: String, collector: ErrorCollector) -> Array:
	# before: the error count before loading, so load errors can be shown.
	var before: int = collector.count()
	# script: the loaded test script, or null.
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		# reasons: why it could not load.
		var reasons: Array[String] = ["does not load (parse error?)"]
		reasons.append_array(collector.since(before))
		return [[path, reasons]]
	# names: test method names, in declaration order, without duplicates from overrides.
	var names: Array[String] = []
	for method: Dictionary in script.get_script_method_list():
		if String(method["name"]).begins_with("test_") and not names.has(method["name"]):
			names.append(method["name"])
	if names.is_empty():
		return [[path, ["has no test_* methods"] as Array[String]]]
	# results: one entry per test.
	var results: Array = []
	for name: String in names:
		results.append(["%s::%s" % [path, name], _run_test(script, name, collector)])
	return results


## Runs one test method on a fresh instance. Returns its failure messages; empty means it passed.
## script: the test script. method: the test_* method name. collector: the error logger.
func _run_test(script: GDScript, method: String, collector: ErrorCollector) -> Array[String]:
	# before: the error count before the test, so only errors it caused are counted.
	var before: int = collector.count()
	# instance: a fresh test object.
	var instance: Object = script.new()
	# messages: everything wrong with this test.
	var messages: Array[String] = []
	if instance == null or not "failures" in instance:
		messages.append("does not extend res://tests/framework/test_case.gd")
	else:
		instance.call(method)
		messages.append_array(instance.failures)
	for error: String in collector.since(before):
		messages.append("error: " + error)
	return messages


## Adds every test_*.gd under dir to out, recursing into folders, skipping the framework folder.
## dir: a res:// folder. out: the list to fill.
func _find_tests(dir: String, out: Array[String]) -> void:
	if (dir + "/").begins_with(FRAMEWORK_DIR):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_find_tests(dir.path_join(sub), out)
	for file: String in DirAccess.get_files_at(dir):
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(dir.path_join(file))
