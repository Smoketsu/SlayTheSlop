## Enforces the owner's documentation standard (CLAUDE.md "Documentation standard") on Agent A's
## lanes: res://core/ (including core/run/ and core/schema/), res://tests/core/ and res://tests/run/.
## Lane: core (Agent A). Agent B may copy it for their lanes; it is not applied to their files here.
##
## Rules checked, per .gd file:
##   1. Every var, const, enum and signal has a comment, either on the line(s) directly above or
##      at the end of its own line. A const that only preloads a script is exempt: the script
##      it names is its documentation.
##   2. Every named func has a ## doc comment directly above it (decorators may sit in between).
##   3. Every parameter of that func is mentioned by name in the doc comment.
##   4. Every inner class has a comment directly above it.
extends "res://tests/framework/test_case.gd"

## Folders whose scripts must follow the standard.
const ROOTS: Array[String] = ["res://core", "res://tests/core", "res://tests/run"]

const Purity := preload("res://tests/core/test_purity.gd")


## Every script in the checked folders follows the rules above.
func test_scripts_are_documented() -> void:
	# files: every .gd under the checked folders.
	var files: Array[String] = []
	for root: String in ROOTS:
		Purity._find_scripts(root, files)
	for path: String in files:
		for problem: String in lint(FileAccess.get_file_as_string(path)):
			fail("%s:%s" % [path, problem])


## The lint flags an undocumented var, a func with no doc, and a parameter missing from the doc,
## and accepts the documented forms.
func test_lint_catches_each_rule() -> void:
	# good: every rule satisfied.
	var good: String = "\n".join([
		"## How many.", "var count: int = 0",
		"var other: int = 1  # Trailing comment.",
		"const Helper := preload(\"res://x.gd\")",
		"## Adds amount to count.", "## amount: how much.", "func add(amount: int) -> void:",
		"\t# total: the sum.", "\tvar total: int = count + amount",
	])
	assert_eq(lint(good), [] as Array[String], "documented code")
	assert_eq(lint("var bare: int = 0").size(), 1, "undocumented var")
	assert_eq(lint("func f() -> void:\n\tpass").size(), 1, "undocumented func")
	assert_eq(lint("## Does it.\nfunc g(target: String) -> void:\n\tpass").size(), 1, "undocumented parameter")


## Returns the documentation problems in one script, each as "line: message".
## source: the script's text.
static func lint(source: String) -> Array[String]:
	# problems: what was found, returned at the end.
	var problems: Array[String] = []
	# lines: the raw source lines, used to read comments.
	var lines: PackedStringArray = source.split("\n")
	# code: the same lines with comments and strings blanked, used to find declarations.
	var code: PackedStringArray = Purity.strip_comments_and_strings(source).split("\n")
	# decl: matches a var / const / enum / signal declaration and captures its name.
	var decl: RegEx = RegEx.create_from_string("^\\s*(?:static\\s+)?(?:@\\w+\\s+)*(var|const|enum|signal)\\s+(\\w+)")
	# preload_const: matches a const whose value is only a preload(...).
	var preload_const: RegEx = RegEx.create_from_string("^\\s*const\\s+\\w+\\s*:?=\\s*preload\\(")
	# func_decl: matches a named func and captures its name.
	var func_decl: RegEx = RegEx.create_from_string("^\\s*(?:static\\s+)?func\\s+(\\w+)\\s*\\(")
	# class_decl: matches an inner class.
	var class_decl: RegEx = RegEx.create_from_string("^\\s*class\\s+\\w+")
	for i: int in lines.size():
		# found: a declaration match on this line, or null.
		var found: RegExMatch = decl.search(code[i])
		if found != null:
			if preload_const.search(code[i]) == null and not _has_comment(lines, i):
				problems.append("%d: %s %s has no comment" % [i + 1, found.get_string(1), found.get_string(2)])
			continue
		if class_decl.search(code[i]) != null and not _has_comment(lines, i):
			problems.append("%d: inner class has no comment" % (i + 1))
			continue
		# func_found: a func match on this line, or null.
		var func_found: RegExMatch = func_decl.search(code[i])
		if func_found == null:
			continue
		# doc: the ## comment block above the func, joined.
		var doc: String = _doc_above(lines, i)
		if doc == "":
			problems.append("%d: func %s has no ## doc comment" % [i + 1, func_found.get_string(1)])
			continue
		for param: String in _params(code, i):
			if RegEx.create_from_string("\\b%s\\b" % param).search(doc) == null:
				problems.append("%d: func %s: parameter %s is not described" % [i + 1, func_found.get_string(1), param])
	return problems


## True when line i ends with a comment or the nearest non-blank line above it is a comment.
## lines: raw source lines. i: index of the declaration line.
static func _has_comment(lines: PackedStringArray, i: int) -> bool:
	if Purity.strip_comments_and_strings(lines[i]).length() < lines[i].length() and lines[i].contains("#"):
		return true
	# j: index walking upward from the line above.
	var j: int = i - 1
	while j >= 0 and lines[j].strip_edges() == "":
		j -= 1
	return j >= 0 and lines[j].strip_edges().begins_with("#")


## Returns the ## comment lines directly above line i, joined by newlines, skipping decorator lines.
## lines: raw source lines. i: index of the func line.
static func _doc_above(lines: PackedStringArray, i: int) -> String:
	# block: comment lines collected bottom-up.
	var block: PackedStringArray = []
	# j: index walking upward.
	var j: int = i - 1
	while j >= 0 and lines[j].strip_edges().begins_with("@"):
		j -= 1
	while j >= 0 and lines[j].strip_edges().begins_with("##"):
		block.insert(0, lines[j])
		j -= 1
	return "\n".join(block)


## Returns the parameter names of the func whose signature starts on line i, reading across lines
## until the closing parenthesis.
## code: comment-free source lines. i: index of the func line.
static func _params(code: PackedStringArray, i: int) -> Array[String]:
	# text: the signature from the opening parenthesis on, possibly spanning lines.
	var text: String = code[i].substr(code[i].find("(") + 1)
	# j: index of the next line to append while the parentheses are unbalanced.
	var j: int = i + 1
	while text.count("(") >= text.count(")") and j < code.size():
		text += " " + code[j]
		j += 1
	# depth: parenthesis/bracket nesting while scanning; 0 is the parameter list itself.
	var depth: int = 0
	# current: the parameter being read.
	var current: String = ""
	# pieces: all parameters, raw.
	var pieces: Array[String] = []
	for c: String in text:
		if c in ["(", "[", "{"]:
			depth += 1
		elif c in [")", "]", "}"]:
			if depth == 0:
				break
			depth -= 1
		elif c == "," and depth == 0:
			pieces.append(current)
			current = ""
			continue
		current += c
	pieces.append(current)
	# names: the identifier at the start of each non-empty piece.
	var names: Array[String] = []
	for piece: String in pieces:
		# name: piece up to its type annotation or default value.
		var name: String = piece.split(":")[0].split("=")[0].strip_edges()
		if name != "":
			names.append(name)
	return names
