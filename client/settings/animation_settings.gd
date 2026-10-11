## The Animations row of the settings (task 047): one choice of Normal, Fast or Instant. Lane:
## client (Agent B).
##
## Shown on the main menu (client/run/main_menu.gd) under the Sound row, built the same way. Every
## change is saved at once through client/settings/animation_speed.gd in the client settings file
## (settings_path), never in the run state or the run save; the next fight uses it. Built in code,
## no scene file. Test hooks: change_speed(), and the read-only picker.
extends HBoxContainer

const AnimationSpeed := preload("res://client/settings/animation_speed.gd")
const UserSettings := preload("res://client/settings/user_settings.gd")

## The label in front of the choice. Writers may change it.
const SPEED_LABEL: String = "Animations"

## Emitted when the setting could not be saved.
## error: why, from client/settings/user_settings.gd set_setting().
signal save_failed(error: String)

## The user:// settings file the speed is read from and saved to. Set by setup(); tests pass their
## own file.
var settings_path: String = UserSettings.DEFAULT_PATH
## The choice, one item per AnimationSpeed.SPEEDS entry in that order. Built in _init(); read by
## tests.
var picker: OptionButton

## True while setup() moves the choice to the saved speed, so that move is not saved again.
var _loading: bool = false


## Builds the widgets, so setup() can be called before the row is in the tree.
func _init() -> void:
	# label: what the choice is for.
	var label := Label.new()
	label.text = SPEED_LABEL
	picker = OptionButton.new()
	for speed: String in AnimationSpeed.SPEEDS:
		picker.add_item(AnimationSpeed.NAMES[speed])
	picker.item_selected.connect(func(index: int) -> void: change_speed(AnimationSpeed.SPEEDS[index]))
	add_child(label)
	add_child(picker)


## Shows the saved speed from a settings file.
## path: the user:// settings file.
func setup(path: String) -> void:
	settings_path = path
	_loading = true
	picker.select(AnimationSpeed.SPEEDS.find(AnimationSpeed.speed(path)))
	_loading = false


## The choice changed (also the test hook): shows and saves the new speed.
## speed: one of AnimationSpeed.SPEEDS.
func change_speed(speed: String) -> void:
	# index: the speed's item in the picker, or -1 for an unknown speed.
	var index: int = AnimationSpeed.SPEEDS.find(speed)
	if index == -1:
		return
	if picker.selected != index:
		picker.select(index)
	if _loading:
		return
	# error: why the save failed, or "".
	var error: String = AnimationSpeed.set_speed(speed, settings_path)
	if error != "":
		save_failed.emit(error)
