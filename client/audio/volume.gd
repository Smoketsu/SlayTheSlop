## The master volume and mute (task 055). Lane: client (Agent B).
##
## Both are client settings (client/settings/user_settings.gd), keys VOLUME_KEY and MUTED_KEY: about
## this machine and this player's ears, never in the run state, a request or the run save. They are
## applied to the Master audio bus (AudioServer), which every sound in client/audio/sounds.gd plays
## on. Godot's default bus layout always has Master at index 0, so no bus layout file is needed.
##
## set_volume() and set_muted() save the value and apply it at once; apply_saved() reads both and
## applies them, called when the game starts (client/run/run_screen.gd _ready()). A value that is
## missing or of the wrong type reads as the default. Static functions only.
extends RefCounted

const UserSettings := preload("res://client/settings/user_settings.gd")

## The client setting holding the master volume, a float from 0.0 (silent) to 1.0 (full), linear
## (not decibels). Missing means DEFAULT_VOLUME. Changed only by the client lane; renaming it resets
## every player's volume.
const VOLUME_KEY: String = "master_volume"
## The client setting that is true while all sound is muted. Missing means false. Changed only by the
## client lane; renaming it unmutes every player.
const MUTED_KEY: String = "master_muted"
## Volume before the player has chosen one, 0.0..1.0. Changed only by the client lane.
const DEFAULT_VOLUME: float = 0.8
## Name of the bus the volume and mute apply to. Changed only by the client lane, together with
## client/audio/sounds.gd BUS.
const BUS: StringName = &"Master"
## Bus volume in decibels for a volume of 0 (linear_to_db(0) would be minus infinity). -80 dB is
## inaudible. Changed only by the client lane.
const SILENT_DB: float = -80.0


## Returns the saved volume, clamped to 0.0..1.0; DEFAULT_VOLUME when none is saved or it is not a
## number.
## path: the user:// settings file; UserSettings.DEFAULT_PATH unless a test passes its own.
static func volume(path: String = UserSettings.DEFAULT_PATH) -> float:
	# saved: the stored value, any type.
	var saved: Variant = UserSettings.get_setting(VOLUME_KEY, DEFAULT_VOLUME, path)
	if typeof(saved) != TYPE_FLOAT and typeof(saved) != TYPE_INT:
		return DEFAULT_VOLUME
	return clampf(float(saved), 0.0, 1.0)


## Returns true when sound is saved as muted; false when nothing is saved or it is not a bool.
## path: the user:// settings file.
static func muted(path: String = UserSettings.DEFAULT_PATH) -> bool:
	# saved: the stored value, any type.
	var saved: Variant = UserSettings.get_setting(MUTED_KEY, false, path)
	return saved if typeof(saved) == TYPE_BOOL else false


## Saves a new volume and applies it. Returns "" on success, otherwise why it was not saved (it is
## applied either way, so the slider still works for this session).
## value: the volume, clamped to 0.0..1.0. path: the user:// settings file.
static func set_volume(value: float, path: String = UserSettings.DEFAULT_PATH) -> String:
	# clamped: value inside 0.0..1.0.
	var clamped: float = clampf(value, 0.0, 1.0)
	apply(clamped, muted(path))
	return UserSettings.set_setting(VOLUME_KEY, clamped, path)


## Saves mute on or off and applies it. Returns "" on success, otherwise why it was not saved (it is
## applied either way).
## value: true to mute. path: the user:// settings file.
static func set_muted(value: bool, path: String = UserSettings.DEFAULT_PATH) -> String:
	apply(volume(path), value)
	return UserSettings.set_setting(MUTED_KEY, value, path)


## Reads the saved volume and mute and applies them to the bus.
## path: the user:// settings file.
static func apply_saved(path: String = UserSettings.DEFAULT_PATH) -> void:
	apply(volume(path), muted(path))


## Sets the bus's volume and mute; saves nothing. A missing bus is ignored.
## value: volume 0.0..1.0, linear (0 is silent, SILENT_DB). mute: true to mute.
static func apply(value: float, mute: bool) -> void:
	# bus: the bus's index, -1 when there is none.
	var bus: int = AudioServer.get_bus_index(BUS)
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, maxf(linear_to_db(clampf(value, 0.0, 1.0)), SILENT_DB))
	AudioServer.set_bus_mute(bus, mute)


## Returns the bus's current volume, 0.0..1.0 linear (what apply() last set). Read by tests.
static func applied_volume() -> float:
	# bus: the bus's index, -1 when there is none.
	var bus: int = AudioServer.get_bus_index(BUS)
	return 0.0 if bus < 0 else db_to_linear(AudioServer.get_bus_volume_db(bus))


## Returns true while the bus is muted. Read by tests.
static func applied_muted() -> bool:
	# bus: the bus's index, -1 when there is none.
	var bus: int = AudioServer.get_bus_index(BUS)
	return bus >= 0 and AudioServer.is_bus_mute(bus)
