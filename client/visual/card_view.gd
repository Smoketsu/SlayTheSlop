## One card in the local player's hand, drawn as a card face (task 041). Lane: client (Agent B).
##
## A Button, so clicking it plays the card exactly as the old text buttons did (the fight screen
## connects pressed to press_card()). render() draws the face from the copy's effective definition
## and nothing else (core/combat/upgrades.gd definition_of(): the upgraded definition for a Lifted
## copy), so no card id is named here: the name, with RunText.UPGRADED_MARK when the copy is Lifted;
## the Hype cost in the top-left corner ("X" for an X cost, "-" for an unplayable card, as
## RunText.card_cost()); the type, by frame colour and a label; the rarity; and the rules text.
##
## Whether the card can be played right now is the caller's answer, taken from the core (the fight
## screen asks Core.validate()); this view never works out Hype or playability itself. A card the
## core would refuse is dimmed but stays clickable, so the core's reject message still tells the
## player why.
##
## Hovering lifts, straightens and enlarges the face so its text can be read. Only the face (a child
## drawn over the button) moves: the clickable area stays where the hand put it, so the hover never
## flickers and never changes which card a click plays. Nothing here reads or writes game state.
extends Button

const Messages := preload("res://client/fight/messages.gd")
const RunText := preload("res://client/run/run_text.gd")
## [added, task 045] Draws the wrapped tooltip (the fight screen sets tooltip_text to the card's
## keyword lines from client/help/tooltip_text.gd card()).
const TooltipView := preload("res://client/visual/tooltip_view.gd")

## Size of one card face at rest, in pixels, before the hand scales it to fit. Changed only by the
## client lane.
const CARD_SIZE := Vector2(120, 166)
## Side of the round cost badge in the top-left corner, in pixels. Changed only by the client lane.
const COST_SIZE: int = 26
## Space between the frame and the face's text, in pixels. Changed only by the client lane.
const PADDING: int = 5
## Width of the coloured frame that shows the card's type, in pixels. Changed only by the client
## lane.
const FRAME_WIDTH: int = 3
## Rounding of the face's corners, in pixels. Changed only by the client lane.
const CORNER: int = 8
## Font size of the card's name, in pixels. Changed only by the client lane.
const NAME_FONT_SIZE: int = 12
## Font size of the cost in its badge, in pixels. Changed only by the client lane.
const COST_FONT_SIZE: int = 15
## Font size of the "Type · Rarity" line, in pixels. Changed only by the client lane.
const KIND_FONT_SIZE: int = 10
## Font size of the rules text, in pixels. Changed only by the client lane.
const TEXT_FONT_SIZE: int = 11
## Most lines the name may wrap to; a longer name is cut off. 1 or more. Changed only by the client
## lane.
const NAME_MAX_LINES: int = 2
## Joins the type and the rarity on the face, for example "Attack · Common". Changed only by the
## client lane.
const KIND_JOIN: String = " · "
## Fill of the face, behind the text. Changed only by the client lane.
const BODY_COLOR := Color(0.1, 0.09, 0.11, 0.95)
## Card type (core/schema/card_def.gd TYPES) -> the colour of its frame and cost badge. Changed only
## by the client lane; a type missing here uses OTHER_TYPE_COLOR.
const TYPE_COLORS := {
	"attack": Color(0.78, 0.25, 0.22),
	"skill": Color(0.25, 0.5, 0.82),
	"power": Color(0.85, 0.65, 0.2),
	"aura": Color(0.3, 0.72, 0.62),
	"junk": Color(0.42, 0.4, 0.36),
}
## Frame colour of a card whose type is not in TYPE_COLORS (or that has no definition). Changed only
## by the client lane.
const OTHER_TYPE_COLOR := Color(0.55, 0.55, 0.55)
## Rarity (core/schema/card_def.gd RARITIES) -> the colour of the "Type · Rarity" line. Changed
## only by the client lane; a rarity missing here uses Color.WHITE.
const RARITY_COLORS := {
	"starter": Color(0.75, 0.75, 0.75),
	"common": Color(0.92, 0.92, 0.92),
	"uncommon": Color(0.45, 0.8, 1.0),
	"rare": Color(1.0, 0.82, 0.3),
	"special": Color(0.7, 0.62, 0.55),
}
## Colour of a Lifted copy's name, so the upgrade reads at a glance next to its "+". Changed only by
## the client lane.
const UPGRADED_NAME_COLOR := Color(0.55, 1.0, 0.55)
## Colour multiplied over a card the core would refuse to play right now (modulate; alpha 0..1).
## Changed only by the client lane.
const DIM_COLOR := Color(0.55, 0.55, 0.55, 0.9)
## How much bigger a hovered face is drawn than a card at full size (CARD_SIZE), 1.0 or more. It is
## the same whatever the hand's own scale. Changed only by the client lane.
const HOVER_SCALE: float = 1.5
## How far a hovered face rises, in pixels on screen. Changed only by the client lane.
const HOVER_LIFT: float = 12.0
## Least distance kept between a hovered face and the window's left and right edges, in pixels.
## Changed only by the client lane.
const HOVER_EDGE: float = 4.0
## Seconds the hover lift takes. Changed only by the client lane.
const HOVER_SECONDS: float = 0.08
## Draw order of a hovered card, above its neighbours (z_index, relative to the hand). Changed only
## by the client lane.
const HOVER_Z: int = 10

## The name shown on the face, with RunText.UPGRADED_MARK for a Lifted copy. Set by render(); read
## by tests.
var shown_name: String = ""
## The cost shown in the badge: a number, "X" or "-" (RunText.card_cost()). Set by render().
var shown_cost: String = ""
## The "Type · Rarity" line, for example "Attack · Common"; "" when the card has no definition. Set
## by render().
var shown_kind: String = ""
## The rules text shown, from the effective definition's "text"; "" when it has none. Set by render().
var shown_text: String = ""
## The definition's "type" code ("attack", "junk", ...), or "" when it has none. Set by render().
var card_type: String = ""
## True when the copy is Lifted (shows the upgraded mark). Set by render().
var upgraded: bool = false
## The caller's answer to "would the core play this card now?". false dims the face. Set by
## render(); never worked out here.
var playable: bool = true
## True while the mouse is over the card (the face is lifted and enlarged). Display only.
var hovered: bool = false
## Seconds the hover animation takes; 0 or less makes it instant (tests). Set by whoever creates
## the view, before the mouse reaches it.
var hover_seconds: float = HOVER_SECONDS
## [added, task 043] false keeps the face at rest when hovered (a face in a pile viewer, where a
## lifted face would be cut off by the scroll area); the tooltip still shows. Set by whoever creates
## the view.
var hover_enabled: bool = true

## The visible card, drawn over the button; it is what hovering moves. Ignores the mouse.
var _face: Panel
## The cost badge's panel; its colour follows the type.
var _cost_panel: Panel
## The cost text inside the badge.
var _cost_label: Label
## The card's name.
var _name_label: Label
## The "Type · Rarity" line.
var _kind_label: Label
## The rules text.
var _text_label: Label
## The hover tween, killed when a new hover starts so two never fight; null when none ran.
var _tween: Tween


## Builds the empty face. render() fills it.
func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	# Scale and tilt (set by the hand) turn around the card's bottom centre, as the face's hover does.
	pivot_offset = Vector2(CARD_SIZE.x / 2.0, CARD_SIZE.y)
	focus_mode = Control.FOCUS_NONE
	for style: String in ["normal", "disabled", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_face = Panel.new()
	_face.size = CARD_SIZE
	_face.pivot_offset = Vector2(CARD_SIZE.x / 2.0, CARD_SIZE.y)
	add_child(_face)
	# column: name, kind and text, top to bottom, inside the frame.
	var column := VBoxContainer.new()
	column.position = Vector2(PADDING, PADDING)
	column.size = CARD_SIZE - Vector2(PADDING, PADDING) * 2.0
	column.add_theme_constant_override("separation", 2)
	_face.add_child(column)
	# top: the cost badge's space, then the name.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 3)
	column.add_child(top)
	_cost_panel = Panel.new()
	_cost_panel.custom_minimum_size = Vector2(COST_SIZE, COST_SIZE)
	_cost_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_cost_panel)
	_cost_label = _label(_cost_panel, COST_FONT_SIZE)
	_cost_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.add_theme_constant_override("outline_size", 3)
	_cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label = _label(top, NAME_FONT_SIZE)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.max_lines_visible = NAME_MAX_LINES
	_name_label.custom_minimum_size = Vector2(0, COST_SIZE)
	_kind_label = _label(column, KIND_FONT_SIZE)
	_text_label = _label(column, TEXT_FONT_SIZE)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.clip_text = true
	_ignore_mouse(_face)
	mouse_entered.connect(hover.bind(true))
	mouse_exited.connect(hover.bind(false))


## Draws the face from a card copy's effective definition. Call again to redraw; it drops the hover.
## definition: the copy's effective definition (core/combat/upgrades.gd definition_of(), upgraded
##   for a Lifted copy); read only. {} for a copy with no usable definition: the face then shows
##   fallback_name, cost "-" and no text, and the core refuses the card anyway.
## is_upgraded: true when the copy is Lifted (dude_state cards[uid].upgraded); adds the upgraded mark.
## can_play: the caller's answer from the core (Core.validate() accepts a play of it now); false dims
##   the face. The card stays clickable either way.
## fallback_name: the name shown when definition is {}, usually the fight model's hand entry name.
func render(definition: Dictionary, is_upgraded: bool, can_play: bool, fallback_name: String = "") -> void:
	upgraded = is_upgraded
	playable = can_play
	card_type = definition.get("type", "")
	if definition.is_empty():
		shown_name = fallback_name
		shown_cost = RunText.card_cost({})
		shown_kind = ""
		shown_text = ""
	else:
		shown_name = definition.get("name", fallback_name) + (RunText.UPGRADED_MARK if is_upgraded else "")
		shown_cost = RunText.card_cost(definition)
		shown_kind = Messages.card_type_name(card_type) + KIND_JOIN + Messages.rarity_name(definition.get("rarity", ""))
		shown_text = definition.get("text", "")
	# frame: the type's colour, on the frame and the cost badge.
	var frame: Color = TYPE_COLORS.get(card_type, OTHER_TYPE_COLOR)
	# body: the face's fill with the type-coloured frame.
	var body := StyleBoxFlat.new()
	body.bg_color = BODY_COLOR
	body.set_corner_radius_all(CORNER)
	body.set_border_width_all(FRAME_WIDTH)
	body.border_color = frame
	_face.add_theme_stylebox_override("panel", body)
	# badge: the round cost badge.
	var badge := StyleBoxFlat.new()
	badge.bg_color = frame.darkened(0.25)
	badge.set_corner_radius_all(COST_SIZE / 2)
	badge.set_border_width_all(1)
	badge.border_color = Color(1, 1, 1, 0.6)
	_cost_panel.add_theme_stylebox_override("panel", badge)
	_cost_label.text = shown_cost
	_name_label.text = shown_name
	if is_upgraded:
		_name_label.add_theme_color_override("font_color", UPGRADED_NAME_COLOR)
	else:
		_name_label.remove_theme_color_override("font_color")
	_kind_label.text = shown_kind
	_kind_label.add_theme_color_override("font_color", RARITY_COLORS.get(definition.get("rarity", ""), Color.WHITE))
	_kind_label.visible = shown_kind != ""
	_text_label.text = shown_text
	modulate = Color.WHITE if can_play else DIM_COLOR
	hovered = false
	_place_face(false, 0.0)


## Lifts, straightens and enlarges the face (true) or puts it back at rest (false). Called by the
## mouse entering and leaving the card; tests may call it. Changes only how the view looks. Task 043:
## always at rest while hover_enabled is false.
## on: true to lift the face, false to put it back.
func hover(on: bool) -> void:
	if not hover_enabled:
		on = false
	hovered = on
	_place_face(on, hover_seconds)


## Returns the face's text, one line per label, top to bottom: cost, name, "Type · Rarity" (when
## there is a definition) and rules text (when it has any). Tests compare it.
func drawn_text() -> String:
	# lines: the non-empty texts.
	var lines: Array[String] = []
	for label: Label in [_cost_label, _name_label, _kind_label, _text_label]:
		if label.text != "":
			lines.append(label.text)
	return "\n".join(lines)


## [added, task 045] Godot asks for the tooltip control when the mouse rests on the card: its
## keyword lines, wrapped (client/visual/tooltip_view.gd); none when tooltip_text is "".
## for_text: the card's tooltip_text.
func _make_custom_tooltip(for_text: String) -> Object:
	return TooltipView.make(for_text)


## Returns the face's scale on screen relative to CARD_SIZE (the hand's scale times the hover's), for
## tests.
func face_scale() -> float:
	return scale.x * _face.scale.x


## Moves the face to its hovered or resting place.
## on: true for the hovered place. seconds: how long the move takes; instant when <= 0.
func _place_face(on: bool, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# own: this card's scale in the hand, so the hovered size is HOVER_SCALE on screen whatever it is.
	var own: float = maxf(scale.x, 0.01)
	# goal_scale: the face's target scale, relative to this button.
	var goal_scale: Vector2 = Vector2.ONE * (HOVER_SCALE / own) if on else Vector2.ONE
	# goal_turn: the face's target rotation, undoing the hand's tilt so a hovered face stands upright.
	var goal_turn: float = -rotation if on else 0.0
	# goal_shift: where the face moves on screen, in pixels: up by HOVER_LIFT, and sideways when the
	# enlarged face would leave the window.
	var goal_shift: Vector2 = Vector2(_edge_shift(), -HOVER_LIFT) if on else Vector2.ZERO
	# goal_position: goal_shift in this button's own (scaled, tilted) coordinates.
	var goal_position: Vector2 = goal_shift.rotated(-rotation) / own
	z_index = HOVER_Z if on else 0
	if seconds <= 0.0 or not is_inside_tree():
		_face.scale = goal_scale
		_face.position = goal_position
		_face.rotation = goal_turn
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_face, "scale", goal_scale, seconds)
	_tween.tween_property(_face, "position", goal_position, seconds)
	_tween.tween_property(_face, "rotation", goal_turn, seconds)


## Returns how far, in screen pixels, the hovered face must move sideways so all of it stays at
## least HOVER_EDGE inside the window: positive moves it right, 0 when it already fits or the view is
## not in a window.
func _edge_shift() -> float:
	if not is_inside_tree():
		return 0.0
	# centre: the card's bottom centre on screen, the point the face grows from.
	var centre: float = (get_global_transform() * Vector2(CARD_SIZE.x / 2.0, CARD_SIZE.y)).x
	# half: half the hovered face's width on screen.
	var half: float = CARD_SIZE.x * HOVER_SCALE / 2.0
	# window: the width the face must stay inside.
	var window: float = get_viewport_rect().size.x
	if centre - half < HOVER_EDGE:
		return HOVER_EDGE - (centre - half)
	if centre + half > window - HOVER_EDGE:
		return window - HOVER_EDGE - (centre + half)
	return 0.0


## Adds a centred wrapping label to a node and returns it.
## parent: where it goes. font_size: its font size in pixels.
func _label(parent: Control, font_size: int) -> Label:
	# label: the new label.
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


## Lets clicks pass through node and everything under it to this button.
## node: where to start.
func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		if child is Control:
			_ignore_mouse(child)
