## An overlay that shows a list of card copies as card faces (task 043): a fight pile (draw, discard,
## Tapped) or the run deck. Lane: client (Agent B).
##
## A dark layer over the whole screen with a panel in the middle: a title ("Draw pile (12)"), a note,
## and a scrollable grid of client/visual/card_view.gd faces, each drawn from the copy's effective
## definition (core/combat/upgrades.gd definition_of(), so a Lifted copy shows its upgrade and "+"),
## with its keyword tooltip (client/help/tooltip_text.gd card()). Faces here are for reading only:
## they do not lift on hover and clicking them does nothing.
##
## Escape, the Close button or a click outside the panel closes it (closed is emitted and the
## overlay frees itself). It never sends a request and never reads or writes anything but the
## arguments of show_cards(): the caller hands it the uids. entries_for() is the pure list it draws,
## sorted by card type then name when asked (the draw pile always is, so the viewer never reveals
## the shuffle).
extends Control

const CardView := preload("res://client/visual/card_view.gd")
const TooltipText := preload("res://client/help/tooltip_text.gd")
const RunText := preload("res://client/run/run_text.gd")
## The core's reader of a card copy's effective definition, and the card types in their order.
const Upgrades := preload("res://core/combat/upgrades.gd")
const CardDef := preload("res://core/schema/card_def.gd")

## Emitted once when the overlay closes, just before it frees itself.
signal closed

## The dark layer over the screen behind the panel. Changed only by the client lane.
const SHADE_COLOR := Color(0, 0, 0, 0.7)
## The panel's fill. Changed only by the client lane.
const PANEL_COLOR := Color(0.1, 0.09, 0.12, 0.98)
## Space between the panel and the screen's edges, in pixels (left/right, top/bottom). Changed only
## by the client lane.
const PANEL_MARGIN := Vector2(70, 40)
## Cards per row of the grid, 1 or more. Changed only by the client lane.
const COLUMNS: int = 7
## Space between two faces in the grid, in pixels. Changed only by the client lane.
const GRID_GAP: int = 10
## Font size of the title, in pixels. Changed only by the client lane.
const TITLE_FONT_SIZE: int = 24
## Shown instead of the grid when the list is empty. Writers may change it.
const EMPTY_TEXT: String = "Nothing here. Yet."
## The Close button's words. Writers may change them.
const CLOSE_TEXT: String = "Close"

## The title as drawn ("Draw pile (12)"). Read by tests.
var title_text: String = ""
## The card_uids shown, in the grid's order (left to right, top to bottom). Read by tests.
var card_uids: Array[String] = []
## The names shown on the faces, in the same order (with RunText.UPGRADED_MARK for a Lifted copy).
## Read by tests.
var card_names: Array[String] = []

## The panel in the middle; a click outside it closes the overlay.
var _panel: PanelContainer
## The title label.
var _title: Label
## The note under the title ("Sorted by type, then name ...").
var _note: Label
## The grid of faces, inside a ScrollContainer.
var _grid: GridContainer
## True once close() ran, so closed is emitted only once.
var _closing: bool = false


## Builds the empty overlay. show_cards() fills it.
func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# shade: the dark layer.
	var shade := ColorRect.new()
	shade.color = SHADE_COLOR
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = PANEL_MARGIN.x
	_panel.offset_right = -PANEL_MARGIN.x
	_panel.offset_top = PANEL_MARGIN.y
	_panel.offset_bottom = -PANEL_MARGIN.y
	# fill: the panel's style.
	var fill := StyleBoxFlat.new()
	fill.bg_color = PANEL_COLOR
	fill.set_corner_radius_all(8)
	fill.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", fill)
	add_child(_panel)
	# column: title row, note, grid, top to bottom.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	# top: the title and the Close button.
	var top := HBoxContainer.new()
	column.add_child(top)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	# close_button: the Close button.
	var close_button := Button.new()
	close_button.text = CLOSE_TEXT
	close_button.pressed.connect(close)
	top.add_child(close_button)
	_note = Label.new()
	_note.modulate = Color(1, 1, 1, 0.7)
	column.add_child(_note)
	# scroll: lets a long list scroll.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	scroll.add_child(_grid)


## Returns the list a viewer draws for some of a Dude's card copies: one {"card_uid", "definition"
## (the copy's effective definition, {} when it has none), "upgraded" (bool), "name" (as the face
## shows it, with RunText.UPGRADED_MARK for a Lifted copy), "type"} per uid. Sorted by card type (in
## core/schema/card_def.gd TYPES order, unknown types last), then name, then card_uid, when sorted
## is true; otherwise in the order given. Pure: reads its arguments only.
## ruleset: read-only content. dude: the Dude owning the copies (a part of the state; read only).
## uids: card_uids of that Dude, for example its draw_pile. sorted: true to sort as above.
static func entries_for(ruleset: Dictionary, dude: Dictionary, uids: Array, sorted: bool) -> Array[Dictionary]:
	# out: the result.
	var out: Array[Dictionary] = []
	for uid: String in uids:
		# definition: the copy's effective definition, or {}.
		var definition: Dictionary = Upgrades.definition_of(ruleset, dude, uid)
		out.append({
			"card_uid": uid,
			"definition": definition,
			"upgraded": dude["cards"].get(uid, {}).get("upgraded", false),
			"name": RunText.card_copy_name(ruleset, dude, uid),
			"type": definition.get("type", ""),
		})
	if sorted:
		out.sort_custom(_before)
	return out


## Returns true when entry a sorts before entry b: by type order, then name, then card_uid.
## a, b: entries of entries_for().
static func _before(a: Dictionary, b: Dictionary) -> bool:
	# rank_a, rank_b: the types' places in CardDef.TYPES, unknown types last.
	var rank_a: int = _type_rank(a["type"])
	var rank_b: int = _type_rank(b["type"])  # b's type's place
	if rank_a != rank_b:
		return rank_a < rank_b
	if a["name"] != b["name"]:
		return a["name"] < b["name"]
	return a["card_uid"] < b["card_uid"]


## Returns a card type's place in CardDef.TYPES, or TYPES.size() for an unknown type.
## type: a card definition's type.
static func _type_rank(type: String) -> int:
	# rank: the place, -1 when unknown.
	var rank: int = CardDef.TYPES.find(type)
	return rank if rank >= 0 else CardDef.TYPES.size()


## Fills the overlay: the title with the count, the note, and one face per entry.
## ruleset: read-only content, for the keyword tooltips. title: what the list is ("Draw pile").
## note: the line under the title, "" for none. entries: from entries_for(), in the order to show.
func show_cards(ruleset: Dictionary, title: String, note: String, entries: Array[Dictionary]) -> void:
	title_text = "%s (%d)" % [title, entries.size()]
	_title.text = title_text
	_note.text = note
	_note.visible = note != ""
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	card_uids = []
	card_names = []
	if entries.is_empty():
		# empty: says the list is empty.
		var empty := Label.new()
		empty.text = EMPTY_TEXT
		_grid.add_child(empty)
		return
	for entry: Dictionary in entries:
		# face: the card's face, for reading only.
		var face: Button = CardView.new()
		face.hover_enabled = false
		face.render(entry["definition"], entry["upgraded"], true, entry["name"])
		face.tooltip_text = TooltipText.card(ruleset, entry["definition"])
		_grid.add_child(face)
		card_uids.append(entry["card_uid"])
		card_names.append(face.shown_name)


## Closes the overlay: emits closed once and frees it at the end of the frame. Test hook (Escape,
## Close and a click outside call it).
func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()


## Escape closes the overlay, wherever the focus is.
## event: any input event.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


## A click that reaches the overlay itself landed outside the panel (the panel takes its own
## clicks), so it closes the overlay. The mouse wheel does not count as a click.
## event: a GUI input event on the overlay.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		accept_event()
		close()
