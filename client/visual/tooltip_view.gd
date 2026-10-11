## How a hover tooltip looks (task 045). Lane: client (Agent B).
##
## Godot's own tooltip is one Label that never wraps, so a sentence from client/help/tooltip_text.gd
## would run across the screen. make() builds the control a widget returns from
## _make_custom_tooltip() instead: the same text, wrapped to at most MAX_WIDTH pixels, with the first
## line (the name and value) in TITLE_COLOR. The text itself is always the widget's tooltip_text, so
## tests read tooltip_text and never this view. Display only: reads no game state.
extends RefCounted

## Widest a tooltip's text gets before it wraps, in pixels. Changed only by the client lane.
const MAX_WIDTH: float = 300.0
## Font size of the tooltip text, in pixels. Changed only by the client lane.
const FONT_SIZE: int = 14
## Colour of the first line (the name and value). Changed only by the client lane.
const TITLE_COLOR := Color(1.0, 0.85, 0.4)
## Colour of the lines after it (what the thing does). Changed only by the client lane.
const BODY_COLOR := Color(0.92, 0.92, 0.92)
## Fill behind the text, nearly opaque so the cards and the room never show through it. Changed
## only by the client lane.
const BACK_COLOR := Color(0.07, 0.07, 0.09, 0.97)
## Space between that fill's edge and the text, in pixels. Changed only by the client lane.
const PADDING: int = 6


## Returns the control a tooltip shows: a PanelContainer filled with BACK_COLOR holding a wrapping
## RichTextLabel no wider than MAX_WIDTH, sized to its text. null for empty text (Godot then shows
## no tooltip).
## text: the tooltip text, lines separated by "\n"; the first line is the title.
static func make(text: String) -> Control:
	if text == "":
		return null
	# panel: the opaque fill around the text.
	var panel := PanelContainer.new()
	# back: the fill's style.
	var back := StyleBoxFlat.new()
	back.bg_color = BACK_COLOR
	back.set_corner_radius_all(4)
	back.set_content_margin_all(PADDING)
	panel.add_theme_stylebox_override("panel", back)
	# lines: the text's lines; the first is the title.
	var lines: PackedStringArray = text.split("\n")
	# font: the default font, to measure the widest line.
	var font: Font = ThemeDB.fallback_font
	# width: the widest line's width, capped at MAX_WIDTH.
	var width: float = 0.0
	for line: String in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	# label: the wrapping text.
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(minf(width + 4.0, MAX_WIDTH), 0)
	label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	label.add_theme_color_override("default_color", BODY_COLOR)
	label.push_color(TITLE_COLOR)
	label.add_text(lines[0])
	label.pop()
	for i: int in range(1, lines.size()):
		label.add_text("\n" + lines[i])
	panel.add_child(label)
	return panel
