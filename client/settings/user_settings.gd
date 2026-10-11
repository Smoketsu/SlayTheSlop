## The player's client settings on this machine (task 049). Lane: client (Agent B).
##
## One small store for every client-only setting: the "How to play seen" flag (task 049), and
## later animation speed (task 047) and volume / mute (task 055). Settings are about this machine
## and this player's taste, never about the game: they never go in the run state, in a request or
## in the run save (client/run/save_store.gd), and the rules core never reads them.
##
## The file is a Godot ConfigFile with one section, SECTION. Each setting is one key in it; the
## key's name and its meaning are owned and documented by the client file that uses it (for
## example client/help/how_to_play.gd SEEN_KEY), and listed in that task's docs/changes file.
## Values keep their Godot type (a bool stays a bool).
##
## Reading never fails: a missing file, a file that does not parse, or a key that is not there
## gives the caller's default. Writing reads the file, changes one key and writes it back safely,
## as save_store.gd does: the new text goes to "<path>.tmp", which is then renamed over the old
## file, so a crash while writing leaves the old settings whole. A file that did not parse is
## replaced by one holding only the new key (Godot logs its own parse error for such a file; the
## player sees nothing).
##
## Paths are user:// only, so a test passes its own user:// file and never touches the player's
## real settings. Static functions only: there is no settings object to keep in sync.
extends RefCounted

## Where the settings live when no other path is given. Changed only by the client lane.
const DEFAULT_PATH: String = "user://settings.cfg"
## The ConfigFile section every setting is stored under. Changed only by the client lane (changing
## it makes every saved setting read as its default).
const SECTION: String = "settings"
## Added to the path for the file written before the rename. Changed only by the client lane.
const TEMP_SUFFIX: String = ".tmp"
## The only path prefix a settings file may use (Godot's per-user data folder). Fixed by the client
## lane.
const ALLOWED_PREFIX: String = "user://"


## Returns the value stored for key, or default when there is none (no file, a file that does not
## parse, a path outside user://, or the key missing).
## key: the setting's name, a non-empty String owned by the client file that uses it.
## default: what to return when the setting is not stored; any Variant.
## path: the user:// settings file; DEFAULT_PATH unless a test passes its own.
static func get_setting(key: String, default: Variant = null, path: String = DEFAULT_PATH) -> Variant:
	# config: the file as parsed, or empty when it could not be read.
	var config: ConfigFile = _read(path)
	return config.get_value(SECTION, key, default)


## Stores value for key, keeping every other setting in the file, and writes the file safely (see
## the file header).
## key: the setting's name, a non-empty String. value: any Variant a ConfigFile can hold (bool, int,
## float, String, ...); null is refused because ConfigFile treats it as "erase".
## path: the user:// settings file; DEFAULT_PATH unless a test passes its own.
## Returns "" on success, otherwise why the setting was not saved (the old file is then untouched
## unless the failure came after it was removed for the rename retry).
static func set_setting(key: String, value: Variant, path: String = DEFAULT_PATH) -> String:
	if not path.begins_with(ALLOWED_PREFIX):
		return "settings live under %s only, not %s" % [ALLOWED_PREFIX, path]
	if key == "":
		return "a setting needs a name"
	if value == null:
		return "a setting cannot be null; use erase_settings() to forget them"
	# config: the current settings, with this one changed.
	var config: ConfigFile = _read(path)
	config.set_value(SECTION, key, value)
	# temp: the file the new text goes to first.
	var temp: String = path + TEMP_SUFFIX
	# written: the write's error code.
	var written: Error = config.save(temp)
	if written != OK:
		DirAccess.remove_absolute(temp)
		return "could not write %s (%s)" % [temp, error_string(written)]
	# moved: the rename's error code.
	var moved: Error = DirAccess.rename_absolute(temp, path)
	if moved != OK and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		moved = DirAccess.rename_absolute(temp, path)
	if moved != OK:
		return "could not replace %s (%s)" % [path, error_string(moved)]
	return ""


## Removes the settings file at path and any temp file beside it, so every setting reads as its
## default again. Missing files are not an error. Used by tests; no screen offers it yet.
## path: the user:// settings file.
static func erase_settings(path: String = DEFAULT_PATH) -> void:
	if not path.begins_with(ALLOWED_PREFIX):
		return
	for file: String in [path, path + TEMP_SUFFIX]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)


## Returns the settings file parsed, or an empty ConfigFile when the path is outside user://, the
## file is missing, or it does not parse.
## path: the settings file.
static func _read(path: String) -> ConfigFile:
	# config: the result.
	var config := ConfigFile.new()
	if path.begins_with(ALLOWED_PREFIX) and FileAccess.file_exists(path):
		if config.load(path) != OK:
			config = ConfigFile.new()
	return config
