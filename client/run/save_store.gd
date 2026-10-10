## The run's save file on disk (task 020). Lane: client (Agent B).
##
## GDD "Sessions": the run is saved after every node. The bytes are core/run/save/snapshot.gd's
## to_bytes(state); reading them back goes through its from_bytes(), which refuses a corrupt,
## truncated or wrong-version file with a message. The core never touches files (CLAUDE.md "The
## rules core is pure"): this file is the only place that reads or writes a save, and it lives in
## client/ only. Paths are user:// only; anything else is refused.
##
## Safe replace: save_state() writes the new bytes to "<path>.tmp", closes it, then renames it over
## the old save. A crash while writing leaves the old save whole, and a finished save leaves no
## .tmp file behind. If the platform refuses to rename over an existing file, the old save is
## removed first and the rename tried once more (the only moment a crash could lose the save).
##
## When the run screen saves is decided in client/run/run_screen.gd (see its header).
extends RefCounted

const Snapshot := preload("res://core/run/save/snapshot.gd")

## Where the run is saved when no other path is given. Changed only by the client lane.
const DEFAULT_PATH: String = "user://run.save"
## Added to a save's path for the file written before the rename. Changed only by the client lane.
const TEMP_SUFFIX: String = ".tmp"
## The only path prefix a save may use (Godot's per-user data folder). Fixed by the client lane.
const ALLOWED_PREFIX: String = "user://"
## load_state()'s error when there is no save file at the path. Player-facing; writers may change it.
const NO_SAVE: String = "No saved run found."


## Writes a run state to path, replacing any old save safely (see the file header).
## state: a run state (core/schema/run_state.gd); not changed. path: a user:// file path.
## Returns "" on success, otherwise why the save failed (the old save, if any, is then untouched
## unless the failure came after the old save was removed for the retry).
static func save_state(state: Dictionary, path: String = DEFAULT_PATH) -> String:
	if not path.begins_with(ALLOWED_PREFIX):
		return "saves live under %s only, not %s" % [ALLOWED_PREFIX, path]
	# temp: the file the bytes go to first.
	var temp: String = path + TEMP_SUFFIX
	# file: the temp file, open for writing (created or emptied).
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return "could not write %s (%s)" % [temp, error_string(FileAccess.get_open_error())]
	file.store_buffer(Snapshot.to_bytes(state))
	# written: the write's error code, read before closing.
	var written: Error = file.get_error()
	file.close()
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


## Reads the run saved at path.
## path: a user:// file path.
## Returns {"state": the run state, or {} on error, "error": "" or why it could not be loaded}: NO_SAVE
## when there is no file, otherwise from_bytes()'s own message for a corrupt or wrong-version file.
static func load_state(path: String = DEFAULT_PATH) -> Dictionary:
	if not path.begins_with(ALLOWED_PREFIX):
		return {"state": {}, "error": "saves live under %s only, not %s" % [ALLOWED_PREFIX, path]}
	if not FileAccess.file_exists(path):
		return {"state": {}, "error": NO_SAVE}
	# decoded: from_bytes()'s {"ok", "state", "error"}.
	var decoded: Dictionary = Snapshot.from_bytes(FileAccess.get_file_as_bytes(path))
	if not decoded["ok"]:
		return {"state": {}, "error": decoded["error"]}
	return {"state": decoded["state"], "error": ""}


## Returns true when a save file exists at path (whether or not it loads).
## path: a user:// file path.
static func has_save(path: String = DEFAULT_PATH) -> bool:
	return path.begins_with(ALLOWED_PREFIX) and FileAccess.file_exists(path)


## Removes the save at path and any temp file left beside it. Missing files are not an error.
## path: a user:// file path.
static func delete_save(path: String = DEFAULT_PATH) -> void:
	if not path.begins_with(ALLOWED_PREFIX):
		return
	for file: String in [path, path + TEMP_SUFFIX]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
