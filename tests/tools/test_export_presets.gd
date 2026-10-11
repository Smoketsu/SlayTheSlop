## Checks export_presets.cfg and tools/build.sh without exporting anything (task 051). Lane: tools
## (Agent B).
##
## Exporting needs about 2 GB of templates and a minute per run, so CI never exports (task 051).
## These checks run in milliseconds and catch the mistakes an export would otherwise only show to
## a playtester: a preset missing or writing outside build/, test code shipped in the game, or a
## file the game loads at runtime left out of it. tools/build.sh --check is the slow, real check.
extends "res://tests/framework/test_case.gd"

## The presets file, at the project root (shared contract).
const PRESETS_PATH := "res://export_presets.cfg"
## The build script, which must pin the same Godot version as INSTALL_SCRIPT.
const BUILD_SCRIPT := "res://tools/build.sh"
## The Godot installer, whose pinned version BUILD_SCRIPT must match.
const INSTALL_SCRIPT := "res://tools/install_godot.sh"
## Every preset tools/build.sh must export: {preset name: Godot export platform}.
const EXPECTED_PRESETS := {
	"Windows Desktop": "Windows Desktop",
	"macOS": "macOS",
	"Linux": "Linux",
}
## Paths that must never ship in a playtest build, one per excluded area. Each is checked against
## every preset's exclude_filter the way Godot's exporter matches it.
const MUST_EXCLUDE: Array[String] = [
	"res://tests/framework/test_case.gd",
	"res://tests/tools/test_export_presets.gd",
	"res://docs/GDD.md",
	"res://.github/workflows/tests.yml",
	"res://tools/test.sh",
	"res://tools/build.sh",
	"res://tools/bot/bot_player.gd",
	"res://assets/placeholder/source/character_sheet.webp",
]
## Folders whose every file the game may need at runtime, so none may be excluded.
const RUNTIME_DIRS: Array[String] = [
	"res://client",
	"res://core",
	"res://data",
	"res://assets/placeholder/characters",
	"res://assets/placeholder/backgrounds",
]
## Folders scanned for res:// paths that scripts and scenes load at runtime (preload, load, consts).
const SOURCE_DIRS: Array[String] = ["res://client", "res://core"]
## File extensions scanned in SOURCE_DIRS for res:// paths.
const SOURCE_EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]


## The file parses (its ";" comments included) and holds exactly the three expected presets, each
## for the right platform, with distinct output folders under build/.
func test_presets_exist_and_write_into_build() -> void:
	# presets: {preset name: {"platform": ..., "export_path": ...}} as read from the file.
	var presets: Dictionary = _read_presets()
	assert_eq(presets.keys().size(), EXPECTED_PRESETS.size(), "preset count in %s" % [presets.keys()])
	# folders: every preset's output folder, to check none share one (build.sh empties each).
	var folders: Array[String] = []
	for name: String in EXPECTED_PRESETS:
		if not presets.has(name):
			fail("no preset named %s" % name)
			continue
		assert_eq(presets[name]["platform"], EXPECTED_PRESETS[name], "%s platform" % name)
		# path: where this preset writes, relative to the repository root.
		var path: String = presets[name]["export_path"]
		# parts: path split on "/", which must be build/<folder>/<file>.
		var parts: PackedStringArray = path.split("/")
		assert_true(parts.size() == 3 and parts[0] == "build" and parts[1] != "" and parts[2] != "",
			"%s exports to build/<folder>/<file>, got %s" % [name, path])
		if parts.size() >= 2:
			assert_false(folders.has(parts[1]), "%s shares the build/%s/ folder" % [name, parts[1]])
			folders.append(parts[1])


## Every preset leaves tests, docs, CI config, tools scripts and the uncut art sheet out of the game.
func test_presets_exclude_non_game_files() -> void:
	# presets: as in test_presets_exist_and_write_into_build.
	var presets: Dictionary = _read_presets()
	for name: String in presets:
		# filters: this preset's exclude globs.
		var filters: PackedStringArray = _filters(presets[name]["exclude_filter"])
		for path: String in MUST_EXCLUDE:
			assert_true(_matches_any(path, filters), "%s does not exclude %s" % [name, path])


## No preset excludes a file the game needs at runtime: any file under the runtime folders, the
## main scene, or any res:// path a client or core script or scene refers to (tools/data_files.gd
## is one, which is why "tools/*" cannot be excluded as a whole).
func test_presets_keep_runtime_files() -> void:
	# needed: every res:// path the game may load, sorted for stable failure messages.
	var needed: Array[String] = []
	needed.append(str(ProjectSettings.get_setting("application/run/main_scene")))
	for dir: String in RUNTIME_DIRS:
		_collect_files(dir, [], needed)
	# sources: the scripts and scenes to scan for res:// references.
	var sources: Array[String] = []
	for dir: String in SOURCE_DIRS:
		_collect_files(dir, SOURCE_EXTENSIONS, sources)
	# pattern: a res:// path inside a string literal.
	var pattern := RegEx.create_from_string("res://[A-Za-z0-9_./-]+\\.[A-Za-z0-9]+")
	for source: String in sources:
		for found: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(source)):
			if not needed.has(found.get_string()):
				needed.append(found.get_string())
	needed.sort()
	assert_true(needed.has("res://tools/data_files.gd"), "the scan finds the client's preload of tools/data_files.gd")
	# presets: as in test_presets_exist_and_write_into_build.
	var presets: Dictionary = _read_presets()
	for name: String in presets:
		# filters: this preset's exclude globs.
		var filters: PackedStringArray = _filters(presets[name]["exclude_filter"])
		for path: String in needed:
			assert_false(_matches_any(path, filters), "%s excludes %s, which the game needs" % [name, path])


## tools/build.sh pins the same Godot version as tools/install_godot.sh, so the export templates
## always match the editor that exports with them.
func test_build_script_pins_installed_godot_version() -> void:
	# pin: a GODOT_VERSION="x.y.z" line at the start of a line.
	var pin := RegEx.create_from_string("(?m)^GODOT_VERSION=\"([^\"]+)\"$")
	# built: the match in BUILD_SCRIPT, or null when the line is missing.
	var built: RegExMatch = pin.search(FileAccess.get_file_as_string(BUILD_SCRIPT))
	# installed: the match in INSTALL_SCRIPT, or null when the line is missing.
	var installed: RegExMatch = pin.search(FileAccess.get_file_as_string(INSTALL_SCRIPT))
	assert_true(built != null, "%s has a GODOT_VERSION line" % BUILD_SCRIPT)
	assert_true(installed != null, "%s has a GODOT_VERSION line" % INSTALL_SCRIPT)
	if built != null and installed != null:
		assert_eq(built.get_string(1), installed.get_string(1), "Godot version in build.sh and install_godot.sh")


## Returns {preset name: {"platform", "export_path", "exclude_filter"}} for every [preset.N] section
## of PRESETS_PATH, or {} (with a failure recorded) when the file does not load.
func _read_presets() -> Dictionary:
	# config: the parsed presets file.
	var config := ConfigFile.new()
	# error: the load result; OK when the file exists and parses.
	var error: Error = config.load(PRESETS_PATH)
	if error != OK:
		fail("%s does not load: %s" % [PRESETS_PATH, error_string(error)])
		return {}
	# presets: the result, filled in section order.
	var presets: Dictionary = {}
	# section_name: a top-level preset section, "preset.<N>" (not "preset.<N>.options").
	var section_name := RegEx.create_from_string("^preset\\.[0-9]+$")
	for section: String in config.get_sections():
		if section_name.search(section) == null:
			continue
		presets[str(config.get_value(section, "name", ""))] = {
			"platform": str(config.get_value(section, "platform", "")),
			"export_path": str(config.get_value(section, "export_path", "")),
			"exclude_filter": str(config.get_value(section, "exclude_filter", "")),
		}
	return presets


## Splits a comma-separated filter string into trimmed globs, as Godot's exporter does.
## filter: the preset's exclude_filter text.
static func _filters(filter: String) -> PackedStringArray:
	# globs: the non-empty, trimmed parts.
	var globs := PackedStringArray()
	for part: String in filter.split(","):
		if part.strip_edges() != "":
			globs.append(part.strip_edges())
	return globs


## True when path matches any glob the way Godot's exporter tests a file: case-insensitively, with
## and without the "res://" prefix, and with "*" also matching "/".
## path: a res:// file path. globs: from _filters().
static func _matches_any(path: String, globs: PackedStringArray) -> bool:
	# bare: path without "res://", as the exporter also tries.
	var bare: String = path.trim_prefix("res://")
	for glob: String in globs:
		if path.matchn(glob) or bare.matchn(glob):
			return true
	return false


## Adds every file under dir (recursively, skipping hidden names and .import/.uid side files) to
## out. dir: a res:// folder. extensions: only these extensions, or every file when empty.
## out: the list to fill.
static func _collect_files(dir: String, extensions: Array[String], out: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_collect_files(dir.path_join(sub), extensions, out)
	for file: String in DirAccess.get_files_at(dir):
		if file.begins_with(".") or file.get_extension() in ["import", "uid"]:
			continue
		if extensions.is_empty() or extensions.has(file.get_extension()):
			out.append(dir.path_join(file))
