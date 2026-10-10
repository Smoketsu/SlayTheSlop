## Reads every content file under data/ into memory, for the ruleset builder. Lane: tools (Agent B).
##
## The rules core may not touch files (CLAUDE.md "The rules core is pure"), so whoever builds a
## ruleset reads the files first and passes their text to core/ruleset/ruleset.gd build(). This is
## that reader, shared by tests, tools and the client:
##
##   const DataFiles := preload("res://tools/data_files.gd")
##   var built: Dictionary = Ruleset.build(DataFiles.read_all())
##
## Every file is returned, whatever its extension, so build() can report a stray file instead of it
## being skipped silently. Hidden files (names starting with ".") are skipped: those are editor and
## OS clutter, not content.
extends RefCounted

## The content folder, relative to the root. Keys in read_all()'s result start with this.
const DATA_DIR := "data"


## Returns {repo-relative path: file text} for every file under root's data/ folder, in sorted path
## order, for example {"data/constants.json": "{...}", "data/cards/tom_punch.json": "{...}"}.
## Paths always use "/" and never start with "res://", matching what build() expects.
## Returns {} when there is no data/ folder.
## root: the folder that holds data/. "res://" (the default) is the project; tests pass an absolute
##   path to a temporary folder.
static func read_all(root: String = "res://") -> Dictionary:
	# paths: every file's repo-relative path, collected then sorted.
	var paths: Array[String] = []
	_collect(root, DATA_DIR, paths)
	paths.sort()
	# files: the result, filled in sorted order so iterating it is deterministic.
	var files: Dictionary = {}
	for path: String in paths:
		files[path] = FileAccess.get_file_as_string(root.path_join(path))
	return files


## Adds the repo-relative path of every file under root/relative to out, recursing into folders.
## root: the folder that holds data/. relative: the folder to walk, relative to root. out: the list
##   to fill.
static func _collect(root: String, relative: String, out: Array[String]) -> void:
	# dir: the absolute or res:// folder being walked.
	var dir: String = root.path_join(relative)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_collect(root, relative.path_join(sub), out)
	for file: String in DirAccess.get_files_at(dir):
		if not file.begins_with("."):
			out.append(relative.path_join(file))
