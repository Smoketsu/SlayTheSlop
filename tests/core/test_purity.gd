## Static checks that the rules core stays pure and deterministic (CLAUDE.md "Architecture rules").
## Lane: core (Agent A). Scans every .gd file under res://core/, comments and strings removed.
##
## If a rule here blocks something you genuinely need, do not weaken the pattern in your task PR:
## raise it with both people, because every lane relies on these guarantees.
extends "res://tests/framework/test_case.gd"

## Folder scanned. Includes core/run/ and core/schema/, which must be pure as well.
const CORE_ROOT := "res://core"

## Folder whose files may use RandomNumberGenerator: the one place that implements the named
## random streams (task 003). Everywhere else must go through it.
const RNG_DIR := "res://core/rng"

## Banned pattern -> why it is banned. Patterns are PCRE regular expressions matched per line.
const BANNED := {
	"(?<![\\w.])(randi|randf|randi_range|randf_range|randfn|randomize|seed|rand_from_seed)\\s*\\(":
		"global random function; use the named streams in core/rng/",
	"\\bTime\\s*\\.": "reads the clock",
	"\\bOS\\s*\\.": "OS access (clock, environment, files)",
	"\\b(FileAccess|DirAccess|ResourceLoader|ResourceSaver|ProjectSettings)\\b": "file or project access",
	"(?<![\\w.])load\\s*\\(": "runtime load(); use preload() for scripts",
	"\\b(HTTPRequest|HTTPClient|StreamPeer\\w*|PacketPeer\\w*|ENet\\w*|WebSocket\\w*|\\w*Multiplayer\\w*|TCPServer|UDPServer)\\b":
		"network access",
	"\\b(Input|Engine|DisplayServer|RenderingServer)\\s*\\.": "engine, input or rendering access",
	"\\bget_tree\\s*\\(": "scene tree access",
	"\\bextends\\s+(Node\\w*|Control|CanvasItem|Resource|SceneTree|Object)\\b": "core classes must be RefCounted (or plain scripts)",
	"\\bawait\\b": "await depends on frame timing",
	"\\b(Thread|Mutex|Semaphore|WorkerThreadPool)\\b": "threads make order nondeterministic",
	"\\bassert\\s*\\(": "assert() is removed from release builds; report bad input through an error field (task 029, core/rng/rng.gd header)",
}

## The assert() ban from BANNED, kept as its own constant so its self-test names it directly.
## Must equal the matching key of BANNED. Who may change it: Agent A, together with BANNED.
const ASSERT_PATTERN := "\\bassert\\s*\\("

## Pattern allowed only inside RNG_DIR.
const RNG_ONLY := "\\bRandomNumberGenerator\\b"


## No core file uses a banned API.
func test_core_uses_no_banned_apis() -> void:
	# files: every .gd under core/.
	var files: Array[String] = []
	_find_scripts(CORE_ROOT, files)
	# compiled: BANNED patterns compiled once, in the same order as BANNED's keys.
	var compiled: Array[RegEx] = []
	for pattern: String in BANNED.keys():
		compiled.append(RegEx.create_from_string(pattern))
	# rng_only: compiled RNG_ONLY pattern.
	var rng_only: RegEx = RegEx.create_from_string(RNG_ONLY)
	for path: String in files:
		# lines: the file's code with comments and string contents blanked out.
		var lines: PackedStringArray = strip_comments_and_strings(FileAccess.get_file_as_string(path)).split("\n")
		for i: int in lines.size():
			for p: int in compiled.size():
				if compiled[p].search(lines[i]) != null:
					fail("%s:%d: %s -> %s" % [path, i + 1, lines[i].strip_edges(), BANNED.values()[p]])
			if not path.begins_with(RNG_DIR + "/") and rng_only.search(lines[i]) != null:
				fail("%s:%d: RandomNumberGenerator outside %s" % [path, i + 1, RNG_DIR])


## The checker itself catches a banned call and ignores the same text inside a comment or string.
func test_checker_sees_code_not_comments() -> void:
	# sample: one real violation on line 2; the others are in a comment and a string.
	var sample: String = "# randi() in a comment\nvar x: int = randi()\nvar s: String = \"Time.get_ticks_msec()\"\n"
	# lines: sample after stripping.
	var lines: PackedStringArray = strip_comments_and_strings(sample).split("\n")
	# rand: the global-random pattern.
	var rand: RegEx = RegEx.create_from_string(BANNED.keys()[0])
	assert_true(rand.search(lines[0]) == null, "comment must be ignored")
	assert_true(rand.search(lines[1]) != null, "real call must be found")
	assert_true(RegEx.create_from_string("\\bTime\\s*\\.").search(lines[2]) == null, "string must be ignored")


## The assert() ban catches a real assert, including one with a space before the parenthesis,
## ignores the word in a comment or string, and does not catch names that only start with
## "assert" (the test framework's assert_eq, assert_true ...).
func test_checker_bans_assert() -> void:
	assert_true(BANNED.has(ASSERT_PATTERN), "the assert ban is one of the BANNED patterns")
	# sample: real asserts on lines 2 and 3; line 1 is a comment, line 4 a string, line 5 a longer name.
	var sample: String = "\n".join([
		"# assert(x) in a comment",
		"\tassert(hi >= lo, \"bad range\")",
		"\tassert (ok)",
		"var s: String = \"assert(false)\"",
		"\tassert_eq(a, b)",
	])
	# lines: sample after stripping.
	var lines: PackedStringArray = strip_comments_and_strings(sample).split("\n")
	# ban: the compiled assert pattern.
	var ban: RegEx = RegEx.create_from_string(ASSERT_PATTERN)
	assert_true(ban.search(lines[0]) == null, "comment must be ignored")
	assert_true(ban.search(lines[1]) != null, "real assert must be found")
	assert_true(ban.search(lines[2]) != null, "assert with a space must be found")
	assert_true(ban.search(lines[3]) == null, "string must be ignored")
	assert_true(ban.search(lines[4]) == null, "assert_eq is not assert")


## Returns source with every comment removed and every string literal's contents replaced by
## spaces, keeping line breaks, so line numbers still match. Static so other lint tests can use it.
## source: GDScript text.
static func strip_comments_and_strings(source: String) -> String:
	# out: the result, built character by character.
	var out: String = ""
	# quote: the quote character of the string we are inside, or "" when outside a string.
	var quote: String = ""
	# in_comment: true from a # to the end of its line.
	var in_comment: bool = false
	# i: index of the character being read.
	var i: int = 0
	while i < source.length():
		# c: the current character.
		var c: String = source[i]
		if c == "\n":
			in_comment = false
			out += c
		elif in_comment:
			pass
		elif quote != "":
			if c == "\\":
				out += "  "
				i += 1
			elif c == quote:
				quote = ""
				out += c
			else:
				out += " "
		elif c == "#":
			in_comment = true
		elif c == "\"" or c == "'":
			quote = c
			out += c
		else:
			out += c
		i += 1
	return out


## Adds every .gd file under dir, recursively and in sorted order, to out.
## dir: res:// folder to search. out: list receiving full paths.
static func _find_scripts(dir: String, out: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_find_scripts(dir.path_join(sub), out)
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
