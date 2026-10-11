## The How to play overlay (task 049): a few short panels with Back, Skip and Next. Lane: client
## (Agent B).
##
## Shown by the run screen (client/run/run_screen.gd) over whatever it shows: from the main menu's
## How to play button, and once automatically on the first new run on this machine. The "seen" flag
## behind "once" is the client setting SEEN_KEY in client/settings/user_settings.gd, never the run
## state or the run save; the run screen reads and writes it, not this file.
##
## The words come from how_to_play_text.gd, which reads every number from the ruleset. Built in
## code, no scene file. It covers the whole screen with a dimmed backdrop that takes every click,
## so nothing under it can be pressed while it is open. Skip (or the cancel key) closes it from any
## panel; Next on the last panel closes it too. It emits closed and frees itself.
## Test hooks: press_next(), press_back(), press_skip(), and the read-only page and panels.
extends Control

const HowToPlayText := preload("res://client/help/how_to_play_text.gd")

## The client setting (client/settings/user_settings.gd) that is true once How to play has been
## shown on this machine, so the first new run does not show it again. Missing means false.
## Changed only by the client lane; renaming it shows the panels once more to every player.
const SEEN_KEY: String = "how_to_play_seen"
## The Next button's words on the last panel, where it closes the overlay. Writers may change it.
const DONE_LABEL: String = "Let's go"
## The Next button's words on every other panel. Writers may change it.
const NEXT_LABEL: String = "Next"
## How dark the backdrop over the screen below is, 0 (clear) to 1 (black). Changed by the client lane.
const BACKDROP_ALPHA: float = 0.85
## Width of the text column in pixels, so the panels wrap at a readable length. Changed by the
## client lane.
const TEXT_WIDTH: float = 520.0

## Emitted once when the overlay closes, just before it frees itself.
## skipped: true when Skip (or cancel) closed it, false when Next was pressed on the last panel.
signal closed(skipped: bool)

## The panel shown now, 0 to panels.size() - 1. Read by tests; changed only by the press_ hooks.
var page: int = 0
## Every panel, in order, each {"title", "body"} from HowToPlayText.panels(). Set by setup(); read
## by tests, never changed after.
var panels: Array[Dictionary] = []

## True once closed has been emitted, so a second press in the same frame does nothing.
var _closed: bool = false
## Widgets: "2 / 7", the panel's title and text, and the Back and Next buttons.
var _counter_label: Label
var _title_label: Label
var _body_label: Label
var _back_button: Button
var _next_button: Button


## Fills the panels from the content. Call before adding the overlay to the tree.
## ruleset: read-only content; never changed. dude_id: whose Bro Move to name, "" for the first
## Dude in the data (as on the main menu, before any run).
func setup(ruleset: Dictionary, dude_id: String) -> void:
	panels = HowToPlayText.panels(ruleset, dude_id)
	page = 0
	_redraw()


## Builds the widgets.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# backdrop: dims the screen below and takes its clicks.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, BACKDROP_ALPHA)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	# center: keeps the panel in the middle of the screen.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	# column: counter, title, text and buttons, top to bottom.
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	center.add_child(column)
	# heading: names the overlay.
	var heading := Label.new()
	heading.text = "How to play"
	_counter_label = Label.new()
	_title_label = Label.new()
	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	# buttons: Back, Skip and Next, left to right.
	var buttons := HBoxContainer.new()
	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.pressed.connect(press_back)
	# skip_button: closes the overlay from any panel.
	var skip_button := Button.new()
	skip_button.text = "Skip"
	skip_button.pressed.connect(press_skip)
	_next_button = Button.new()
	_next_button.pressed.connect(press_next)
	for node: Control in [_back_button, skip_button, _next_button]:
		buttons.add_child(node)
	for node: Control in [heading, _counter_label, _title_label, _body_label, buttons]:
		column.add_child(node)
	_redraw()
	_next_button.grab_focus.call_deferred()


## The cancel key (Escape by default) does what Skip does.
## event: the input event Godot passes.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		press_skip()


## The player pressed Next: shows the next panel, or closes the overlay on the last one.
func press_next() -> void:
	if page >= panels.size() - 1:
		_close(false)
		return
	page += 1
	_redraw()


## The player pressed Back: shows the previous panel. Does nothing on the first one.
func press_back() -> void:
	if page > 0:
		page -= 1
		_redraw()


## The player pressed Skip: closes the overlay from any panel.
func press_skip() -> void:
	_close(true)


## Returns the shown panel's title and text, one per line. Tests read it.
func shown_text() -> String:
	if _title_label == null:
		return ""
	return _title_label.text + "\n" + _body_label.text


## Redraws the widgets for the current page. Does nothing before _ready().
func _redraw() -> void:
	if _title_label == null or panels.is_empty():
		return
	# panel: the panel shown now.
	var panel: Dictionary = panels[page]
	_counter_label.text = "%d / %d" % [page + 1, panels.size()]
	_title_label.text = panel["title"]
	_body_label.text = panel["body"]
	_back_button.disabled = page == 0
	_next_button.text = DONE_LABEL if page == panels.size() - 1 else NEXT_LABEL


## Emits closed once and frees the overlay at the end of the frame.
## skipped: passed on to closed.
func _close(skipped: bool) -> void:
	if _closed:
		return
	_closed = true
	closed.emit(skipped)
	queue_free()
