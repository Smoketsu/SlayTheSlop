## The animation-speed setting (task 047): normal, fast or instant. Lane: client (Agent B).
##
## A client setting (client/settings/user_settings.gd), key SPEED_KEY: about this player's taste,
## never in the run state, a request or the run save (client/run/save_store.gd), and the rules core
## never reads it. The run screen hands every fight screen seconds(base, path): the base length of
## one event's animation times the speed's FACTORS entry. "instant" makes it 0, the same instant
## playback tests use (fight_screen.gd animation_seconds = 0), so the speed never changes what
## happens, only how long it takes to watch. A value that is missing or not one of SPEEDS reads as
## DEFAULT_SPEED. Static functions only.
extends RefCounted

const UserSettings := preload("res://client/settings/user_settings.gd")

## The client setting holding the speed, one of SPEEDS as a String. Missing means DEFAULT_SPEED.
## Changed only by the client lane; renaming it resets every player's speed.
const SPEED_KEY: String = "animation_speed"
## The speeds, in the order the menu lists them. Changed only by the client lane, together with
## FACTORS and NAMES.
const SPEEDS: Array[String] = ["normal", "fast", "instant"]
## Speed -> the factor the base animation length is multiplied by (0 or more; 0 is instant).
## Changed only by the client lane.
const FACTORS := {
	"normal": 1.0,
	"fast": 0.4,
	"instant": 0.0,
}
## Speed -> the word the menu shows. Writers may change the words.
const NAMES := {
	"normal": "Normal",
	"fast": "Fast",
	"instant": "Instant",
}
## The speed before the player has chosen one. Changed only by the client lane.
const DEFAULT_SPEED: String = "normal"


## Returns the saved speed, one of SPEEDS; DEFAULT_SPEED when none is saved or the saved value is
## not one of SPEEDS.
## path: the user:// settings file; UserSettings.DEFAULT_PATH unless a test passes its own.
static func speed(path: String = UserSettings.DEFAULT_PATH) -> String:
	# saved: the stored value, any type.
	var saved: Variant = UserSettings.get_setting(SPEED_KEY, DEFAULT_SPEED, path)
	if typeof(saved) != TYPE_STRING or not SPEEDS.has(saved):
		return DEFAULT_SPEED
	return saved


## Saves a speed. Returns "" on success, otherwise why it was not saved (an unknown speed is
## refused and nothing is written).
## value: one of SPEEDS. path: the user:// settings file.
static func set_speed(value: String, path: String = UserSettings.DEFAULT_PATH) -> String:
	if not SPEEDS.has(value):
		return "unknown animation speed %s" % value
	return UserSettings.set_setting(SPEED_KEY, value, path)


## Returns how long one event's animation lasts at the saved speed, in seconds: base times the
## speed's factor; 0 at "instant" (as tests play).
## base: the length at normal speed, in seconds, 0 or more. path: the user:// settings file.
static func seconds(base: float, path: String = UserSettings.DEFAULT_PATH) -> float:
	return maxf(0.0, base) * float(FACTORS[speed(path)])
