## The Sound row of the settings (task 055): a master volume slider and a Mute box. Lane: client
## (Agent B).
##
## Shown on the main menu (client/run/main_menu.gd). Every change is applied to the Master bus and
## saved at once through client/audio/volume.gd in the client settings file (settings_path), never
## in the run state or the run save. Built in code, no scene file.
## Test hooks: change_volume(), change_muted(), and the read-only slider and mute_box.
extends HBoxContainer

const Volume := preload("res://client/audio/volume.gd")
const UserSettings := preload("res://client/settings/user_settings.gd")

## The label in front of the slider. Writers may change it.
const VOLUME_LABEL: String = "Volume"
## The Mute box's words. Writers may change it.
const MUTE_LABEL: String = "Mute"
## How far one slider step moves the volume, 0.0..1.0. Changed by the client lane.
const STEP: float = 0.05
## Width of the slider in pixels. Changed by the client lane.
const SLIDER_WIDTH: float = 180.0

## Emitted when a setting could not be saved (it is still applied for this session).
## error: why, from client/settings/user_settings.gd set_setting().
signal save_failed(error: String)

## The user:// settings file the values are read from and saved to. Set by setup(); tests pass
## their own file.
var settings_path: String = UserSettings.DEFAULT_PATH
## The volume slider, 0.0..1.0 in STEP steps. Built in _init(); read by tests.
var slider: HSlider
## The Mute check box. Built in _init(); read by tests.
var mute_box: CheckBox

## The "80%" text after the slider.
var _percent_label: Label
## True while setup() moves the widgets to the saved values, so that move is not saved again.
var _loading: bool = false


## Builds the widgets, so setup() can be called before the row is in the tree.
func _init() -> void:
	# label: what the slider is for.
	var label := Label.new()
	label.text = VOLUME_LABEL
	slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = STEP
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(change_volume)
	_percent_label = Label.new()
	mute_box = CheckBox.new()
	mute_box.text = MUTE_LABEL
	mute_box.toggled.connect(change_muted)
	for node: Control in [label, slider, _percent_label, mute_box]:
		add_child(node)


## Shows the saved volume and mute from a settings file and applies them to the bus.
## path: the user:// settings file.
func setup(path: String) -> void:
	settings_path = path
	_loading = true
	slider.value = Volume.volume(path)
	mute_box.button_pressed = Volume.muted(path)
	_loading = false
	_show_percent()
	Volume.apply_saved(path)


## The slider moved (also the test hook): applies and saves the new volume.
## value: the volume, 0.0..1.0.
func change_volume(value: float) -> void:
	if slider.value != value:
		slider.set_value_no_signal(value)
	_show_percent()
	if _loading:
		return
	_report(Volume.set_volume(value, settings_path))


## The Mute box was toggled (also the test hook): applies and saves mute.
## on: true to mute.
func change_muted(on: bool) -> void:
	if mute_box.button_pressed != on:
		mute_box.set_pressed_no_signal(on)
	if _loading:
		return
	_report(Volume.set_muted(on, settings_path))


## Writes the slider's value as a percentage after it.
func _show_percent() -> void:
	_percent_label.text = "%d%%" % roundi(slider.value * 100.0)


## Emits save_failed when a save went wrong.
## error: "" on success, else why it failed.
func _report(error: String) -> void:
	if error != "":
		save_failed.emit(error)
