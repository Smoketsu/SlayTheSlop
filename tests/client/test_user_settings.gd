## Tests for the client settings store, client/settings/user_settings.gd (task 049). Lane:
## tools/client (Agent B). Every test uses its own user:// file and never touches the player's real
## settings (UserSettings.DEFAULT_PATH).
extends "res://tests/framework/test_case.gd"

const UserSettings := preload("res://client/settings/user_settings.gd")

## The settings file these tests use. Erased before and after each test.
const PATH: String = "user://test_user_settings.cfg"


## With no file every key reads as the caller's default; a stored value reads back with its type,
## other keys survive a later write, and no temp file is left behind.
func test_set_then_get_keeps_types_and_other_keys() -> void:
	UserSettings.erase_settings(PATH)
	assert_eq(UserSettings.get_setting("flag", false, PATH), false, "default with no file")
	assert_eq(UserSettings.get_setting("missing", 7, PATH), 7, "default for any type")
	assert_eq(UserSettings.set_setting("flag", true, PATH), "")
	assert_eq(UserSettings.set_setting("speed", 1.5, PATH), "")
	assert_eq(UserSettings.set_setting("name", "loud", PATH), "")
	assert_false(FileAccess.file_exists(PATH + UserSettings.TEMP_SUFFIX), "no temp file left behind")
	assert_eq(UserSettings.get_setting("flag", false, PATH), true)
	assert_eq(typeof(UserSettings.get_setting("flag", false, PATH)), TYPE_BOOL, "a bool stays a bool")
	assert_eq(UserSettings.get_setting("speed", 1.0, PATH), 1.5)
	assert_eq(UserSettings.get_setting("name", "", PATH), "loud")
	assert_eq(UserSettings.set_setting("flag", false, PATH), "", "overwrite one key")
	assert_eq(UserSettings.get_setting("flag", true, PATH), false)
	assert_eq(UserSettings.get_setting("speed", 1.0, PATH), 1.5, "other keys kept")
	assert_eq(UserSettings.get_setting("missing", 7, PATH), 7, "a key never set is still the default")
	UserSettings.erase_settings(PATH)
	assert_false(FileAccess.file_exists(PATH), "erase removes the file")
	assert_eq(UserSettings.get_setting("flag", true, PATH), true, "default again after erase")


## An empty file, and a file with other sections and keys, read as defaults for keys they lack;
## a write keeps what the file already held. (A file that does not parse also reads as defaults, but
## Godot's ConfigFile logs a parse error for it, which the test runner counts as a failure, so that
## case is not tested here.)
func test_empty_and_foreign_files_read_as_defaults() -> void:
	UserSettings.erase_settings(PATH)
	# file: the settings file, written empty.
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.close()
	assert_eq(UserSettings.get_setting("flag", false, PATH), false, "empty file gives the default")
	file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[other]\nflag=true\n\n[%s]\nkept=3\n" % UserSettings.SECTION)
	file.close()
	assert_eq(UserSettings.get_setting("flag", false, PATH), false, "another section's key is not a setting")
	assert_eq(UserSettings.get_setting("kept", 0, PATH), 3)
	assert_eq(UserSettings.set_setting("flag", true, PATH), "")
	assert_eq(UserSettings.get_setting("flag", false, PATH), true, "the write reads back")
	assert_eq(UserSettings.get_setting("kept", 0, PATH), 3, "the file's other key is kept")
	UserSettings.erase_settings(PATH)


## Paths outside user://, an empty key and a null value are refused, and nothing is written.
func test_refuses_bad_paths_keys_and_values() -> void:
	UserSettings.erase_settings(PATH)
	assert_ne(UserSettings.set_setting("flag", true, "res://settings.cfg"), "", "res:// refused")
	assert_false(FileAccess.file_exists("res://settings.cfg"), "nothing written under res://")
	assert_eq(UserSettings.get_setting("flag", false, "res://project.godot"), false, "res:// never read")
	assert_ne(UserSettings.set_setting("", true, PATH), "", "empty key refused")
	assert_ne(UserSettings.set_setting("flag", null, PATH), "", "null refused")
	assert_false(FileAccess.file_exists(PATH), "no file after refused writes")
