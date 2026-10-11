## Main menu (task 020): New Run from a seed, or Continue the saved run. Lane: client (Agent B).
##
## New Run takes the seed the player typed, or, when the field is empty, picks one and shows it, so
## a run can always be replayed or shared. That pick is the only randomness in the client, and it
## only chooses the seed; everything after it comes from the core's seeded streams. The run starts
## through the core's new-run entry point (core/run/new_run.gd start()), with the first Dude in the
## data by id (as client/dev/dev_fight.gd does), so no client code names a Dude.
##
## Continue reads the save through client/run/save_store.gd. A missing, corrupt or wrong-version
## save shows the loader's message and leaves New Run ready; nothing crashes.
##
## The menu never keeps a run itself: it emits run_ready and the run screen (client/run/
## run_screen.gd) takes over. Built in code, no scene file. Test hooks: press_new_run(),
## press_continue(), press_how_to_play().
##
## How to play (task 049): the button only emits how_to_play_requested; the run screen shows the
## panels (client/help/how_to_play.gd) over everything and keeps the "seen" setting.
extends Control

const NewRun := preload("res://core/run/new_run.gd")
const SaveStore := preload("res://client/run/save_store.gd")

## Emitted when a run is ready to play: a new run's first state, or the state loaded from the save.
## state: the run state. is_new: true for New Run, false for Continue.
signal run_ready(state: Dictionary, is_new: bool)
## Emitted when the player presses How to play (task 049). The run screen opens the panels.
signal how_to_play_requested

## The message last shown under the buttons: the seed picked, a bad seed, a load error. Read by tests.
var message: String = ""
## The seed of the last New Run pressed (typed or picked), or 0 before any. Read by tests.
var last_seed: int = 0

## Read-only content (core/ruleset/ruleset.gd). Set by setup(); never changed here.
var _ruleset: Dictionary = {}
## Where Continue reads the save from, a user:// path. Set by setup().
var _save_path: String = SaveStore.DEFAULT_PATH
## Widgets: the seed field, the Continue button (disabled when there is no save) and the message.
var _seed_field: LineEdit
var _continue_button: Button
var _message_label: Label


## Gives the menu its content and save path. Call before or after adding it to the tree.
## ruleset: read-only content. save_path: the user:// save file Continue reads.
func setup(ruleset: Dictionary, save_path: String) -> void:
	_ruleset = ruleset
	_save_path = save_path
	refresh()


## Builds the widgets.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# column: everything, centred top to bottom.
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)
	# title: the game's name.
	var title := Label.new()
	title.text = "Dungeon Dudes"
	# seed_row: the seed label, field and New Run button.
	var seed_row := HBoxContainer.new()
	# seed_label: what the field is for.
	var seed_label := Label.new()
	seed_label.text = "Seed (empty = random):"
	_seed_field = LineEdit.new()
	_seed_field.custom_minimum_size = Vector2(220, 0)
	_seed_field.placeholder_text = "any whole number"
	# new_button: New Run.
	var new_button := Button.new()
	new_button.text = "New Run"
	new_button.pressed.connect(func() -> void: press_new_run(_seed_field.text))
	for node: Control in [seed_label, _seed_field, new_button]:
		seed_row.add_child(node)
	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.pressed.connect(press_continue)
	_message_label = Label.new()
	# help_button: How to play (task 049).
	var help_button := Button.new()
	help_button.text = "How to play"
	help_button.pressed.connect(press_how_to_play)
	for node: Control in [title, seed_row, _continue_button, help_button, _message_label]:
		column.add_child(node)
	refresh()


## Redraws what depends on the disk: Continue is enabled only when a save file exists.
func refresh() -> void:
	if _continue_button != null:
		_continue_button.disabled = not SaveStore.has_save(_save_path)
	if _message_label != null:
		_message_label.text = message


## The player pressed New Run.
## seed_text: the seed field's text. Empty picks a seed; otherwise it must be a whole number (any
## 64-bit int), or the menu says so and starts nothing.
func press_new_run(seed_text: String) -> void:
	# typed: the field without spaces around it.
	var typed: String = seed_text.strip_edges()
	if typed != "" and not typed.is_valid_int():
		_show("The seed has to be a whole number, like 1234.")
		return
	# run_seed: the seed the run starts from.
	var run_seed: int = typed.to_int() if typed != "" else _pick_seed()
	last_seed = run_seed
	if _seed_field != null:
		_seed_field.text = str(run_seed)
	# dude_ids: every Dude in the data, sorted, so the pick is stable.
	var dude_ids: Array = _ruleset.get("dudes", {}).keys()
	dude_ids.sort()
	if dude_ids.is_empty():
		_show("No Dudes in the data, so no run can start.")
		return
	# started: NewRun.start()'s {"state", "events", "error"}.
	var started: Dictionary = NewRun.start(_ruleset, run_seed, [dude_ids[0]])
	if started["error"] != "":
		_show("The run could not start: " + started["error"])
		return
	_show("Seed: %d" % run_seed)
	run_ready.emit(started["state"], true)


## The player pressed Continue: loads the save, or shows why it cannot and leaves New Run ready.
func press_continue() -> void:
	# loaded: SaveStore.load_state()'s {"state", "error"}.
	var loaded: Dictionary = SaveStore.load_state(_save_path)
	if loaded["error"] != "":
		_show("Couldn't load the saved run: %s Start a New Run instead." % _sentence(loaded["error"]))
		return
	_show("")
	run_ready.emit(loaded["state"], false)


## The player pressed How to play (task 049): asks the run screen to open the panels.
func press_how_to_play() -> void:
	how_to_play_requested.emit()


## Returns a seed picked by the client: a whole number from 0 to 4294967295, so it is short enough
## to read out and type back in. Client-side randomness, used for nothing but this pick.
func _pick_seed() -> int:
	# picker: a generator seeded from the clock by randomize().
	var picker := RandomNumberGenerator.new()
	picker.randomize()
	return picker.randi()


## Ends a loader message with a full stop so the menu's next sentence reads well.
## text: a message, possibly without a full stop.
func _sentence(text: String) -> String:
	return text if text.ends_with(".") else text + "."


## Shows a message under the buttons.
## text: the message, "" to clear it.
func _show(text: String) -> void:
	message = text
	refresh()
