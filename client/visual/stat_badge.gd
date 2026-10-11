## One small icon with a number: a stat, status, intent or pile on the fight screen (task 057).
## Lane: client (Agent B).
##
## The icon comes from client/visual/icons.gd by key; a key with no icon shows its short text in a
## small rounded tag instead, never an error. The number sits right of the icon, or on top of it
## (overlay, for the Hype orb). Hovering shows tooltip_text, "<name>: <value>" in the GDD's terms,
## so nothing the old text lines said is lost; task 045 adds what the thing does on the next line
## (client/help/tooltip_text.gd, passed in as show_value()'s description) and wraps the tooltip
## (client/visual/tooltip_view.gd). Clicks pass through to whatever holds the badge (a
## combatant view stays clickable for targeting). Display only: nothing here reads or writes game
## state.
extends HBoxContainer

const Icons := preload("res://client/visual/icons.gd")
## [added, task 045] The tooltip's words and its wrapping look.
const TooltipText := preload("res://client/help/tooltip_text.gd")
const TooltipView := preload("res://client/visual/tooltip_view.gd")

## Side of the icon of a badge under a character, in pixels. Changed only by the client lane.
const ICON_PIXELS: int = 18
## Font size of a badge's number, in pixels. Changed only by the client lane.
const FONT_SIZE: int = 13
## Width of the dark outline around the number, in pixels, so it reads over the room. Changed only
## by the client lane.
const OUTLINE_PIXELS: int = 4
## Space between the icon and the number, in pixels. Changed only by the client lane.
const GAP_PIXELS: int = 2
## Fill of the text tag drawn instead of a missing icon. Changed only by the client lane.
const FALLBACK_COLOR := Color(0.25, 0.25, 0.3, 0.9)
## Rounding of that tag's corners, in pixels. Changed only by the client lane.
const FALLBACK_CORNER: int = 4

## The icons.gd key this badge shows, such as "guard" or "exposed". Set by show_value().
var key: String = ""
## The number shown, as text ("5", "1 / 2"); "" for an icon alone. Set by show_value().
var value_text: String = ""

## The icon, hidden when the key has none.
var _icon: TextureRect
## The short text shown instead of a missing icon, hidden when the icon exists.
var _fallback: Label
## The number.
var _value: Label


## Builds the empty widgets. show_value() fills them.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", GAP_PIXELS)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fallback = Label.new()
	# tag: the rounded fill behind the fallback text.
	var tag := StyleBoxFlat.new()
	tag.bg_color = FALLBACK_COLOR
	tag.set_corner_radius_all(FALLBACK_CORNER)
	tag.content_margin_left = 3
	tag.content_margin_right = 3
	_fallback.add_theme_stylebox_override("normal", tag)
	_value = Label.new()
	_value.add_theme_constant_override("outline_size", OUTLINE_PIXELS)
	_value.add_theme_color_override("font_outline_color", Color.BLACK)
	for child: Control in [_icon, _fallback, _value]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(child)


## Shows one key with its value.
## badge_key: an icons.gd key (anything else gets the text fallback). value: the number as text, ""
## for none. tooltip_value: what the tooltip says after the name; "" uses value. icon_pixels: side of
## the icon in pixels. font_size: the number's font size in pixels. overlay: true puts the number on
## top of the icon (centred) instead of right of it. description: [added, task 045] what the thing
## does (client/help/tooltip_text.gd describe()), shown on the tooltip's second line; "" for none.
func show_value(badge_key: String, value: String, tooltip_value: String = "", icon_pixels: int = ICON_PIXELS,
		font_size: int = FONT_SIZE, overlay: bool = false, description: String = "") -> void:
	key = badge_key
	value_text = value
	# look: the icon, name and fallback text of the key.
	var look: Dictionary = Icons.look(badge_key)
	_icon.texture = look["texture"]
	_icon.custom_minimum_size = Vector2(icon_pixels, icon_pixels)
	_icon.visible = look["texture"] != null
	_fallback.text = look["short"]
	_fallback.visible = look["texture"] == null
	_fallback.add_theme_font_size_override("font_size", maxi(8, font_size - 2))
	_value.text = value
	_value.add_theme_font_size_override("font_size", font_size)
	_value.visible = value != ""
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if overlay and _icon.visible:
		_value.reparent(_icon, false)
		_value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	elif _value.get_parent() != self:
		_value.reparent(self, false)
	# said: the value as the tooltip says it.
	var said: String = tooltip_value if tooltip_value != "" else value
	tooltip_text = TooltipText.badge(look["name"], said, description)


## Returns true when the key has no icon and its short text is shown instead.
func uses_fallback() -> bool:
	return _fallback.visible


## [added, task 045] Godot asks for the tooltip control when the mouse rests on the badge: the
## tooltip text, wrapped (client/visual/tooltip_view.gd).
## for_text: the badge's tooltip_text.
func _make_custom_tooltip(for_text: String) -> Object:
	return TooltipView.make(for_text)
