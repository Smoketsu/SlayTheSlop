## Placeholder fight screen (task 018). Lane: client (Agent B).
##
## Draws the fight from the state only, sends requests through a gateway, and animates the events
## that come back, one at a time, in order; then redraws from the returned state. It never changes
## game state itself (CLAUDE.md "The rules core is pure"): solo uses the same request-and-events
## path co-op will.
##
## Layout (tasks 028, 041 and 057): the Dudes and enemies stand on the room's floor, Dudes on the
## left and enemies on the right (client/visual/floor_layout.gd), each a client/visual/
## combatant_view.gd (intent icon over its head, sprite, HP bar, a row of icon badges) that is
## clicked to target it. The top strip holds the turn label, the message and the last event lines.
## The bottom HAND_SHARE of the screen holds the hand, a fan of card faces (client/visual/
## hand_view.gd holding client/visual/card_view.gd; a card the core would refuse right now is
## dimmed); Hype as an orb left of it with the draw pile under it in the bottom-left corner; and on
## the right the Bro Meter bar, the action buttons, and the discard and Tapped piles in the
## bottom-right corner. Icons come from client/visual/icons.gd. Events play through
## client/visual/event_player.gd. Behind it all, the fight's room (client/visual/backgrounds.gd),
## slightly darkened. Placeholder art (assets/placeholder/). Run it with
##   "$(tools/install_godot.sh)" --path . res://client/fight/fight_screen.tscn
## With no setup() call it starts a fight on the real data (client/dev/dev_fight.gd).
##
## Task 047, the rhythm of a fight: a banner across the middle of the screen when a turn starts
## ("Your turn", also when the screen opens on a player phase), when the enemy phase starts ("Enemy
## turn") and when the fight ends ("Victory" / "Passed Out"), placed among the events by
## client/visual/event_player.gd banners_for() and shown before the screen moves on; and the Ready
## (end turn) button pulses while no card in hand can be played, as the core says (card_playable()).
## How long events and banners take is animation_seconds, which the run screen sets from the
## animation-speed client setting (client/settings/animation_speed.gd).
##
## Task 043: clicking a pile icon (draw, discard, Tapped; their counts update on every redraw) opens
## a client/visual/pile_viewer.gd over the screen with that pile's cards as faces; the draw pile is
## shown sorted (PILES_SORTED), never in draw order. Opening one reads the state and sends nothing.
extends Control

const FightModel := preload("res://client/fight/fight_model.gd")
const Targeting := preload("res://client/fight/targeting.gd")
const RequestMaker := preload("res://client/fight/request_maker.gd")
const Messages := preload("res://client/fight/messages.gd")
const DevFight := preload("res://client/dev/dev_fight.gd")
const EventText := preload("res://client/fight/event_text.gd")
const CombatantView := preload("res://client/visual/combatant_view.gd")
const EventPlayer := preload("res://client/visual/event_player.gd")
const Backgrounds := preload("res://client/visual/backgrounds.gd")
const CardView := preload("res://client/visual/card_view.gd")
const HandView := preload("res://client/visual/hand_view.gd")
const FloorLayout := preload("res://client/visual/floor_layout.gd")
const StatBadge := preload("res://client/visual/stat_badge.gd")
const Icons := preload("res://client/visual/icons.gd")
## [added, task 045] Every tooltip's words, and the Button whose tooltip wraps.
const TooltipText := preload("res://client/help/tooltip_text.gd")
const TipButton := preload("res://client/visual/tip_button.gd")
const TipBox := preload("res://client/visual/tip_box.gd")
## [added, task 043] The overlay that shows a pile's cards.
const PileViewer := preload("res://client/visual/pile_viewer.gd")
## The rules gateway: the real rules core (task 007), apply(ruleset, state, request). Co-op will
## swap in a network gateway with the same apply() here.
const Gateway := preload("res://core/core.gd")
## [added, task upgraded-card-display] The core's reader of a card copy's effective definition.
const Upgrades := preload("res://core/combat/upgrades.gd")
## How many of the latest event lines the log in the top strip shows, 1 or more. Changed only by
## the client lane.
const LOG_LINES: int = 4
## Height of each log line, in pixels. [changed, task 057: 26 -> 17, as the log moved to the top
## strip in a smaller font (LOG_FONT_SIZE).] Changed only by the client lane.
const LOG_LINE_PIXELS: int = 17
## [added, task 057] Font size of the event log, in pixels. Changed only by the client lane.
const LOG_FONT_SIZE: int = 12
## Dark layer laid over the room background so white text and the views stay readable; its alpha
## (0..1) is how much the room is darkened. [changed, task 057: 0.5 -> 0.3, as the characters now
## stand in the room with no panels.] Changed only by the client lane.
const SHADE_COLOR := Color(0, 0, 0, 0.3)
## [added, task 057] Share of the screen's height, from the bottom, kept for the hand, the Hype orb,
## the piles and the buttons (0..1). The characters' HP bars and badges always end above it. Changed
## only by the client lane.
const HAND_SHARE: float = 0.3
## [added, task 057] Height of the top strip (turn label, message, event log), in pixels; the
## characters' intent icons never reach into it. Changed only by the client lane.
const TOP_PIXELS: float = 96.0
## [added, task 057] Font size of the turn label, in pixels. Changed only by the client lane.
const HEADER_FONT_SIZE: int = 13
## [added, task 057] Font size of the message (a prompt such as "Pick an enemy.", a reject or the
## latest event), in pixels. Changed only by the client lane.
const MESSAGE_FONT_SIZE: int = 18
## [added, task 057] Side of the Hype orb beside the hand, in pixels. Changed only by the client lane.
const HYPE_PIXELS: int = 60
## [added, task 057] Font size of the Hype number on the orb, in pixels. Changed only by the client
## lane.
const HYPE_FONT_SIZE: int = 24
## [added, task 057] Side of a pile icon in the bottom corners, in pixels. Changed only by the client
## lane.
const PILE_PIXELS: int = 44
## [added, task 057] Font size of a pile's card count, in pixels. Changed only by the client lane.
const PILE_FONT_SIZE: int = 18
## [added, task 057] Width of the column left of the hand (Hype orb, draw pile), in pixels. Changed
## only by the client lane.
const LEFT_COLUMN_PIXELS: float = 90.0
## [added, task 057] Width of the column right of the hand (Bro Meter, buttons, discard and Tapped
## piles), in pixels. Changed only by the client lane.
const RIGHT_COLUMN_PIXELS: float = 150.0
## [added, task 057] Space kept between the bottom strip and the screen's left, right and bottom
## edges, in pixels, so the pile icons in the corners are not cut off. Changed only by the client lane.
const TABLE_MARGIN_PIXELS: float = 8.0
## [added, task 057] Size of the Bro Meter bar, in pixels. Changed only by the client lane.
const BRO_BAR_SIZE := Vector2(110, 16)
## [added, task 057] Fill of the Bro Meter bar while it charges. Changed only by the client lane.
const BRO_FILL_COLOR := Color(0.85, 0.55, 0.25)
## [added, task 057] Fill of the Bro Meter bar once it is full (the Bro Move is ready). Changed only by
## the client lane.
const BRO_READY_COLOR := Color(1.0, 0.85, 0.25)
## [added, task 057] Background of the Bro Meter bar. Changed only by the client lane.
const BRO_BACK_COLOR := Color(0.1, 0.1, 0.1, 0.85)
## Translucent panel behind the event log and the message bar, so their text reads over the room.
## Changed only by the client lane.
const TEXT_PANEL_COLOR := Color(0.06, 0.06, 0.08, 0.6)
## [added, task 047] The band behind a banner, across the whole width. Changed only by the client lane.
const BANNER_BACK_COLOR := Color(0.04, 0.04, 0.06, 0.82)
## [added, task 047] Font size of a banner's big word, in pixels. Changed only by the client lane.
const BANNER_FONT_SIZE: int = 52
## [added, task 047] Font size of the line under it, in pixels. Changed only by the client lane.
const BANNER_LINE_FONT_SIZE: int = 18
## [added, task 047] Where the banner's band is centred, as a share of the screen's height from the
## top (0..1). Changed only by the client lane.
const BANNER_CENTER: float = 0.38
## [added, task 047] Banner kind (event_player.gd BANNERS) -> the colour of its big word. Changed only
## by the client lane; a kind missing here is white.
const BANNER_COLORS := {
	"your_turn": Color(1.0, 0.85, 0.35),
	"enemy_turn": Color(1.0, 0.45, 0.35),
	"victory": Color(0.5, 1.0, 0.5),
	"passed_out": Color(0.75, 0.75, 0.8),
}
## [added, task 047] Share of a banner's time spent fading in, and again fading out (0..0.5). Changed
## only by the client lane.
const BANNER_FADE_SHARE: float = 0.15
## [added, task 043] The piles a click on their icon opens (core/schema/dude_state.gd PILES names, as
## written). Changed only by the client lane.
const VIEWABLE_PILES: Array[String] = ["draw_pile", "discard_pile", "tapped_pile"]
## [added, task 043] The piles the viewer shows sorted by type, then name, instead of in pile order.
## The draw pile must stay here, so the viewer never reveals the shuffle. Changed only by the client
## lane.
const PILES_SORTED: Array[String] = ["draw_pile"]
## [added, task 047] Colour the Ready button pulses to while no card can be played. Changed only by
## the client lane.
const PULSE_COLOR := Color(1.0, 0.8, 0.3)
## [added, task 047] Seconds of one pulse of the Ready button, there and back. Not tied to the
## animation speed: it is a hint, not an event. Changed only by the client lane.
const PULSE_SECONDS: float = 0.9

## [added, task 020] Emitted after every applied request, once its events have animated and the
## screen has redrawn. The run screen (client/run/run_screen.gd) listens to take the new state and
## leave the fight once it is over. Not emitted for a rejected request.
## state: the state the gateway returned for that request; the screen keeps it, so read only.
signal state_applied(state: Dictionary)

## Seconds each event's animation lasts. 0 makes the screen fully synchronous, which tests use.
## Changed by whoever creates the screen, before or after setup().
var animation_seconds: float = 0.3
## True to skip every event's animation and message and only redraw at the end (the event log
## still gets every line). Tests use it to prove the final drawing does not depend on the events.
var skip_animations: bool = false
## One line per event the screen animated, in order, for tests and debugging. Only grows.
var animation_log: Array[String] = []
## The message last shown to the player (a reject, a prompt or the latest event). Read by tests.
var message: String = ""
## Every event line (event_text.gd line()) of this fight, oldest first, whether or not animations
## are skipped. The log shows the last LOG_LINES. Only grows.
var event_lines: Array[String] = []
## The room drawn behind this fight (backgrounds.gd room_for()), picked once in setup() so the room
## does not change when the boss falls. Read by tests.
var room: String = ""
## [added, task 047] One line per banner shown, "<kind>@<n>" where n is how many lines animation_log
## held when it showed (so it came after those events and before the rest), in order; skipped
## animations still log their banners. Read by tests. Only grows.
var banner_log: Array[String] = []
## [added, task 047] The banner's big word while a banner shows, "" otherwise. Read by tests.
var banner_text: String = ""
## [added, task 047] True while the Ready button pulses: the core would accept ending the turn and
## would refuse every card in hand. Set by every redraw. Read by tests.
var ready_pulsing: bool = false

## The gateway requests go to: anything with apply(ruleset, state, request). Set by setup().
var _gateway: Object
## Read-only content (core/ruleset/ruleset.gd). Set by setup(); never changed here.
var _ruleset: Dictionary = {}
## The current state, as last returned by the gateway. Replaced, never edited.
var _state: Dictionary = {}
## The local player's id.
var _player_id: String = ""
## Builds this player's requests with a rising seq.
var _requests: RequestMaker
## The card_uid waiting for the player to pick a target, or "" when none.
var _pending_card: String = ""
## [added, task ally-pick] What _pending_card waits for: Targeting.ENEMY (an enemy click sends it) or
## Targeting.DUDE (a click on a Dude who is not Passed Out sends it); "" when no card waits. Set with
## _pending_card by press_card() and by a bad_target reject; read by press_enemy() and press_dude().
var _pending_pick: String = ""
## True while the Bro Move waits for the player to pick an enemy (G33: Chest Bump needs a target).
var _pending_bro: bool = false
## True while events are animating; input is ignored meanwhile.
var _busy: bool = false
## Plays each request's events on the views. Its seconds follow animation_seconds.
var _player := EventPlayer.new()
## player_id or enemy uid -> its combatant_view.gd, as last drawn. Rebuilt by every redraw.
var _views: Dictionary = {}
## Widgets refilled on every redraw: the turn label, the floor the views stand on, hand, buttons,
## message; and the event log, rewritten on every event line. Task 041: the hand is a
## client/visual/hand_view.gd of card_view.gd faces, and the buttons are a column right of it.
## Task 057: the views stand on _arena (floor_layout.gd), which replaced the Dude and enemy boxes.
var _header: Label  # The turn label, "Turn 1 - player phase".
var _arena: Container  # [added, task 057] The floor: a floor_layout.gd holding every combatant view.
var _hand_box: Container  # The hand: a hand_view.gd of card_view.gd faces (task 041).
var _actions_box: VBoxContainer  # Brew, Bro Move and Ready buttons, right of the hand (task 041).
var _message_label: Label  # The message line in the top strip.
var _log_label: Label  # The last LOG_LINES event lines, under the turn label.
## [added, task 057] The local Dude's Hype: an orb with the number on it, left of the hand.
var _hype_badge: HBoxContainer
## [added, task 057] The local Dude's draw pile count, bottom-left corner.
var _draw_badge: HBoxContainer
## [added, task 057] The local Dude's discard pile count, bottom-right corner.
var _discard_badge: HBoxContainer
## [added, task 057] The local Dude's Tapped pile count, bottom-right corner.
var _tapped_badge: HBoxContainer
## [added, task 057] The Bro Meter: an icon and a small bar (0..BRO_METER_MAX) with "4 / 10" inside,
## above the action buttons. Its tooltip names it.
var _bro_box: HBoxContainer
## [added, task 057] The Bro Meter's bar, inside _bro_box.
var _bro_bar: ProgressBar
## [added, task 057] The Bro Meter's "4 / 10", inside its bar.
var _bro_label: Label
## The room picture, filling the screen (cropped to keep its aspect); no texture when the room has
## no file.
var _background: TextureRect
## Plain FALLBACK_COLOR behind the room picture, seen only when the room has no file.
var _backdrop: ColorRect
## [added, task 047] The banner: a band across the screen holding _banner_title and _banner_line,
## hidden while no banner shows. Built in _ready(), on top of everything.
var _banner: PanelContainer
## [added, task 047] The banner's big word.
var _banner_title: Label
## [added, task 047] The smaller line under it.
var _banner_line: Label
## [added, task 047] The banner's fade, killed when the next banner starts; null when none ran.
var _banner_tween: Tween
## [added, task 047] The Ready button as last drawn, for tests; rebuilt by every redraw.
var _ready_button: Button
## [added, task 043] The open pile viewer, or null.
var _pile_viewer: Control
## [added, task 045] icons.gd key -> what it does (client/help/tooltip_text.gd all()), filled from the
## ruleset on every redraw and handed to each combatant view and the turn info badges.
var _tooltips: Dictionary = {}


## Gives the screen its gateway, content, starting state and local player. Call before or after
## adding it to the tree.
## gateway: has apply(ruleset, state, request). ruleset: read-only content. state: a run state in a
## fight. player_id: the local player.
func setup(gateway: Object, ruleset: Dictionary, state: Dictionary, player_id: String) -> void:
	_gateway = gateway
	_ruleset = ruleset
	_state = state
	_player_id = player_id
	for dude: Dictionary in state["dudes"]:
		if dude["player_id"] == player_id:
			_requests = RequestMaker.new(player_id, dude["last_seq"])
	room = Backgrounds.room_for(state)
	if is_inside_tree():
		_redraw()


## Builds the layout, falls back to the sample fight if setup() was not called, and draws.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop = ColorRect.new()
	_backdrop.color = Backgrounds.FALLBACK_COLOR
	_background = TextureRect.new()
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# shade: darkens the room under the text.
	var shade := ColorRect.new()
	shade.color = SHADE_COLOR
	for layer: Control in [_backdrop, _background, shade]:
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	# Task 057: the floor the Dudes and enemies stand on, covering the screen; clicks reach the views.
	_arena = FloorLayout.new()
	_arena.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.hand_top = 1.0 - HAND_SHARE
	_arena.top_pixels = TOP_PIXELS
	add_child(_arena)
	_build_top()
	_build_table()
	_build_banner()
	if _ruleset.is_empty():
		# started: a placeholder fight on the real data.
		var started: Dictionary = DevFight.start()
		if started["error"] != "":
			push_error("fight screen could not start a fight: " + started["error"])
			return
		setup(Gateway.new(), started["ruleset"], started["state"], started["player_id"])
	_redraw()
	# Task 047: a fight opens on its first player phase; say so.
	if not _state.is_empty() and _state["combat"] != null and _state["combat"]["phase"] == "player":
		_player.seconds = animation_seconds
		_on_banner("your_turn", _player.banner_seconds("your_turn"))


## [added, task 047] Builds the banner: a band across the screen, centred at BANNER_CENTER of its
## height, with the big word and a line under it; hidden, and it lets clicks through.
func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = BANNER_CENTER
	_banner.anchor_bottom = BANNER_CENTER
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# band: the band's fill.
	var band := StyleBoxFlat.new()
	band.bg_color = BANNER_BACK_COLOR
	band.content_margin_top = 10
	band.content_margin_bottom = 12
	_banner.add_theme_stylebox_override("panel", band)
	# column: the word over the line.
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(column)
	_banner_title = Label.new()
	_banner_title.add_theme_font_size_override("font_size", BANNER_FONT_SIZE)
	_banner_line = Label.new()
	_banner_line.add_theme_font_size_override("font_size", BANNER_LINE_FONT_SIZE)
	for label: Label in [_banner_title, _banner_line]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
	_banner.visible = false
	add_child(_banner)


## [added, task 057] Builds the top strip: the turn label and, right of it, the message; under them
## the event log. It lets clicks through and ends within TOP_PIXELS.
func _build_top() -> void:
	# top: the strip, top to bottom.
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 2)
	add_child(top)
	# line: the turn label, then the message taking the rest of the width.
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(line)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
	_message_label = Label.new()
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", MESSAGE_FONT_SIZE)
	_message_label.add_theme_constant_override("outline_size", 5)
	_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_child(_header)
	line.add_child(_message_label)
	_log_label = Label.new()
	_log_label.modulate = Color(1, 1, 1, 0.75)
	_log_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_log_label.add_theme_font_size_override("font_size", LOG_FONT_SIZE)
	_log_label.add_theme_constant_override("line_spacing", LOG_LINE_PIXELS - LOG_FONT_SIZE - 3)
	_log_label.visible = false
	top.add_child(_log_label)
	for label: Label in [_header, _log_label]:
		# panel: the label's translucent background.
		var panel := StyleBoxFlat.new()
		panel.bg_color = TEXT_PANEL_COLOR
		panel.content_margin_left = 6
		panel.content_margin_right = 6
		label.add_theme_stylebox_override("normal", panel)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


## [added, task 057] Builds the bottom HAND_SHARE of the screen, left to right: a column with the
## Hype orb and the draw pile (bottom-left corner), the hand, and a column with the Bro Meter, the
## action buttons and the discard and Tapped piles (bottom-right corner).
func _build_table() -> void:
	# table: the bottom strip.
	var table := HBoxContainer.new()
	table.anchor_left = 0.0
	table.anchor_right = 1.0
	table.anchor_top = 1.0 - HAND_SHARE
	table.anchor_bottom = 1.0
	table.offset_left = TABLE_MARGIN_PIXELS
	table.offset_right = -TABLE_MARGIN_PIXELS
	table.offset_bottom = -TABLE_MARGIN_PIXELS
	add_child(table)
	# left: the Hype orb on top, the draw pile at the bottom.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_COLUMN_PIXELS, 0)
	_hype_badge = StatBadge.new()
	_draw_badge = StatBadge.new()
	left.add_child(_hype_badge)
	left.add_child(_spacer())
	left.add_child(_draw_badge)
	_hand_box = HandView.new()
	_hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# right: the Bro Meter and the buttons on top, the discard and Tapped piles at the bottom.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_COLUMN_PIXELS, 0)
	_build_bro_meter()
	right.add_child(_bro_box)
	_actions_box = VBoxContainer.new()
	right.add_child(_actions_box)
	right.add_child(_spacer())
	# piles: the discard and Tapped piles, side by side at the right edge.
	var piles := HBoxContainer.new()
	piles.alignment = BoxContainer.ALIGNMENT_END
	_discard_badge = StatBadge.new()
	_tapped_badge = StatBadge.new()
	piles.add_child(_discard_badge)
	piles.add_child(_tapped_badge)
	right.add_child(piles)
	for node: Control in [left, _hand_box, right]:
		table.add_child(node)
	# Task 043: a click on a pile icon opens its viewer.
	for pair: Array in [[_draw_badge, "draw_pile"], [_discard_badge, "discard_pile"], [_tapped_badge, "tapped_pile"]]:
		# badge: the pile's icon.
		var badge: Control = pair[0]
		badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		badge.gui_input.connect(_on_pile_input.bind(pair[1]))


## [added, task 057] Builds the Bro Meter: its icon and a small bar with "now / max" inside.
func _build_bro_meter() -> void:
	_bro_box = TipBox.new()
	_bro_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_bro_box.mouse_filter = Control.MOUSE_FILTER_PASS
	# icon: the Bro Meter's icon, or its short text when the icon is missing.
	var icon: HBoxContainer = StatBadge.new()
	icon.show_value("bro_meter", "", "", StatBadge.ICON_PIXELS + 4)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bro_bar = ProgressBar.new()
	_bro_bar.show_percentage = false
	_bro_bar.custom_minimum_size = BRO_BAR_SIZE
	_bro_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bro_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# back: the bar's background.
	var back := StyleBoxFlat.new()
	back.bg_color = BRO_BACK_COLOR
	back.set_corner_radius_all(3)
	_bro_bar.add_theme_stylebox_override("background", back)
	_bro_label = Label.new()
	_bro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bro_label.add_theme_font_size_override("font_size", CombatantView.BAR_FONT_SIZE)
	_bro_label.add_theme_constant_override("outline_size", CombatantView.TEXT_OUTLINE)
	_bro_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_bro_bar.add_child(_bro_label)
	_bro_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bro_box.add_child(icon)
	_bro_box.add_child(_bro_bar)


## [added, task 057] Returns an empty control that takes up the spare height of a column.
func _spacer() -> Control:
	# spacer: the new filler.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## The player clicked a card in hand: play it, or ask for a target first. Task ally-pick: an "ally"
## card (Bro Hug) goes straight to the local player's own Dude when only one Dude can be targeted
## (solo), and asks "Pick a Dude." when several can (co-op; Targeting.mode_in_state()).
## card_uid: the card copy.
func press_card(card_uid: String) -> void:
	if _busy:
		return
	# pick: what the player has to choose.
	var pick: String = _pick_for(card_uid)
	if pick == Targeting.NONE:
		_pending_card = ""
		_pending_pick = ""
		_pending_bro = false
		_send(_requests.play_card(card_uid, Targeting.auto_target_in_state(_card_def(card_uid), _player_id)))
		return
	_pending_card = card_uid
	_pending_pick = pick
	_pending_bro = false
	_show_message("Pick an enemy." if pick == Targeting.ENEMY else "Pick a Dude.")


## The player clicked an enemy: the target for a pending card, otherwise nothing. A card waiting for
## a Dude (task ally-pick) ignores enemy clicks and keeps waiting.
## enemy_uid: the enemy.
func press_enemy(enemy_uid: String) -> void:
	if _busy:
		return
	if _pending_bro:
		_pending_bro = false
		_send(_requests.use_bro_move(enemy_uid))
		return
	if _pending_card == "" or _pending_pick != Targeting.ENEMY:
		return
	# card_uid: the card being aimed.
	var card_uid: String = _pending_card
	_pending_card = ""
	_send(_requests.play_card(card_uid, enemy_uid))


## The player clicked a Dude: the target for a pending ally card, otherwise nothing. Task ally-pick:
## only while a card waits for a Dude, and only a Dude who is not Passed Out (Targeting.
## pickable_dudes(); the view of a Passed Out Dude is also disabled); any other click is ignored and
## the card keeps waiting.
## player_id: the Dude's player.
func press_dude(player_id: String) -> void:
	if _busy or _pending_card == "" or _pending_pick != Targeting.DUDE:
		return
	if not Targeting.pickable_dudes(_state).has(player_id):
		return
	# card_uid: the card being aimed.
	var card_uid: String = _pending_card
	_pending_card = ""
	_pending_pick = ""
	_send(_requests.play_card(card_uid, player_id))


## [added, task 043] Opens the viewer of one of the local Dude's fight piles over the screen: its
## cards as faces, sorted when the pile is in PILES_SORTED, otherwise in pile order. Replaces a
## viewer already open. Reads the state only; sends nothing. Test hook (a click on the pile's icon
## calls it). A name not in VIEWABLE_PILES, or no Dude, opens nothing.
## pile: one of VIEWABLE_PILES, a core/schema/dude_state.gd pile name.
func open_pile(pile: String) -> void:
	# dude: the local Dude.
	var dude: Dictionary = _local() if not _state.is_empty() else {}
	if not VIEWABLE_PILES.has(pile) or dude.is_empty():
		return
	if pile_viewer() != null:
		_pile_viewer.close()
	_pile_viewer = PileViewer.new()
	add_child(_pile_viewer)
	_pile_viewer.show_cards(_ruleset, Icons.look(pile)["name"], Messages.PILE_NOTES.get(pile, ""),
		PileViewer.entries_for(_ruleset, dude, dude[pile], PILES_SORTED.has(pile)))


## [added, task 043] Returns the open pile viewer, or null when none is open. Tests use it.
func pile_viewer() -> Control:
	if _pile_viewer != null and is_instance_valid(_pile_viewer) and not _pile_viewer.is_queued_for_deletion():
		return _pile_viewer
	return null


## [added, task 043] A pile icon got input: a left click opens that pile's viewer.
## event: the input event. pile: the icon's pile, one of VIEWABLE_PILES.
func _on_pile_input(event: InputEvent, pile: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_pile(pile)


## [added, task 047] Returns true when the Ready button should pulse: the core would accept ending
## the turn now (Core.validate() on a probe set_ready that is never sent) and would refuse every
## card in the local hand (card_playable()). No rule is worked out here. Reads only.
func ready_should_pulse() -> bool:
	if _requests == null or _state.is_empty() or _state["combat"] == null:
		return false
	if Gateway.validate(_ruleset, _state, _requests.probe_set_ready()) != "":
		return false
	for uid: String in _local().get("hand", []):
		if card_playable(uid):
			return false
	return true


## The player pressed Ready (end turn).
func press_ready() -> void:
	if not _busy:
		_pending_card = ""
		_pending_bro = false
		_send(_requests.set_ready(true))


## The player pressed the Bro Move button. When the Dude's Bro Move card targets an enemy (Chest
## Bump, G33), the screen asks for one first and press_enemy() sends it.
func press_bro_move() -> void:
	if _busy:
		return
	_pending_card = ""
	# bro: the Bro Move card's definition, or {} when the Dude has none.
	var bro: Dictionary = _ruleset["cards"].get(_ruleset["dudes"].get(_local()["dude_id"], {}).get("bro_move", ""), {})
	if bro.is_empty():
		_send(_requests.use_bro_move())
		return
	if Targeting.mode(bro, _state["party_size"]) == Targeting.ENEMY:
		_pending_bro = true
		_show_message("Pick an enemy.")
		return
	_send(_requests.use_bro_move(Targeting.auto_target(bro, _player_id, _state["party_size"])))


## The player clicked a Brew. Brews that need a target are not handled yet (no Brew data exists).
## slot: the Brew slot, from 0.
func press_brew(slot: int) -> void:
	if not _busy:
		_pending_card = ""
		_pending_bro = false
		_send(_requests.use_brew(slot, ""))


## Returns every piece of text on the screen, top to bottom, one per line. Tests compare it.
func drawn_text() -> String:
	# lines: collected text.
	var lines: Array[String] = []
	_collect_text(self, lines)
	return "\n".join(lines)


## Sends one request and handles the answer: a reject shows its message (and on bad_target asks for
## a new target, per the GDD's two-players-one-enemy case); otherwise the events animate in order
## and the screen redraws from the new state.
## request: a request built by _requests.
func _send(request: Dictionary) -> void:
	# result: {"state", "events", "reject"} from the gateway.
	var result: Dictionary = _gateway.apply(_ruleset, _state, request)
	if result["reject"] != "":
		_show_message(Messages.reject(result["reject"]))
		if result["reject"] == "bad_target" and request["type"] == "play_card":
			# pick: what the refused card should wait for now (task ally-pick: an enemy or a Dude).
			var pick: String = _pick_for(request["card_uid"])
			if pick != Targeting.NONE:
				_pending_card = request["card_uid"]
				_pending_pick = pick
		elif result["reject"] == "bad_target" and request["type"] == "use_bro_move":
			_pending_bro = true
		return
	# names: display names for the event lines, from the state before and after the request.
	var names: Dictionary = EventText.names_for(_ruleset, [_state, result["state"]])
	_busy = true
	if skip_animations:
		# banners: where the banners go (task 047); logged, not shown.
		var banners: Dictionary = EventPlayer.banners_for(result["events"])
		for i: int in result["events"].size():
			if banners.has(i):
				_on_banner(banners[i], 0.0)
			animation_log.append(_describe(result["events"][i]))
			_log_event(EventText.line(result["events"][i], names))
	else:
		_player.seconds = animation_seconds
		await _player.play(result["events"], _views, _on_event.bind(names), self, _on_banner)
	_state = result["state"]
	_busy = false
	_redraw()
	state_applied.emit(_state)


## Rebuilds every widget from the state. Task 020: a won fight's last request can also finish its
## run node, which leaves no fight in the state (combat null); the screen then keeps its last
## drawing until the run screen (client/run/run_screen.gd) replaces it.
func _redraw() -> void:
	if _header == null or _state.is_empty() or _state["combat"] == null:
		return
	# model: what to show.
	var model: Dictionary = FightModel.build(_ruleset, _state, _player_id)
	_tooltips = TooltipText.all(_ruleset)
	_background.texture = Backgrounds.texture_for_room(room)
	_header.text = "Turn %d - %s phase" % [model["turn"], model["phase"]]
	_arena.floor_line = Backgrounds.floor_line(room)
	for box: Container in [_arena, _hand_box, _actions_box]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_views = {}
	# Task 057: Dudes first, then enemies, each in state order; floor_layout.gd stands Dudes on the
	# left and enemies on the right.
	for dude: Dictionary in model["dudes"]:
		_add_view(dude, false, press_dude.bind(dude["player_id"]), model["party_size"])
		if dude["local"]:
			_draw_turn_info(dude)
			for slot: int in dude["brew_ids"].size():
				_add_button(_actions_box, "Brew: " + _brew_name(dude["brew_ids"][slot]), press_brew.bind(slot), false,
					TooltipText.brew(_ruleset, dude["brew_ids"][slot], false))
	for enemy: Dictionary in model["enemies"]:
		_add_view(enemy, true, press_enemy.bind(enemy["uid"]), model["party_size"])
	for card: Dictionary in model["hand"]:
		_add_card(card)
	_add_button(_actions_box, "Bro Move", press_bro_move, not model["bro_ready"])
	_ready_button = _add_button(_actions_box, "Ready", press_ready, false)
	# Task 047: the Ready button pulses while no card can be played.
	ready_pulsing = ready_should_pulse()
	if ready_pulsing:
		_pulse(_ready_button)
	_bro_bar.max_value = maxi(1, model["bro_meter_max"])
	_bro_bar.value = model["bro_meter_now"]
	_bro_label.text = model["bro_meter"]
	_bro_box.tooltip_text = TooltipText.badge(Icons.look("bro_meter")["name"], model["bro_meter"], _tooltips.get("bro_meter", ""))
	# fill: the bar's fill, gold once the Bro Move is ready.
	var fill := StyleBoxFlat.new()
	fill.bg_color = BRO_READY_COLOR if model["bro_ready"] else BRO_FILL_COLOR
	fill.set_corner_radius_all(3)
	_bro_bar.add_theme_stylebox_override("fill", fill)
	_message_label.text = message


## [added, task 057] Shows the local Dude's turn info off the characters: Hype on the orb beside the
## hand ("now", tooltip "now / per turn") and the three pile counts in the bottom corners. Task 045:
## each tooltip also says what it is (_tooltips).
## dude: the local Dude's entry of FightModel.build().
func _draw_turn_info(dude: Dictionary) -> void:
	_hype_badge.show_value("hype", str(dude["hype"]), "%d / %d" % [dude["hype"], dude["hype_per_turn"]], HYPE_PIXELS, HYPE_FONT_SIZE, true,
		_tooltips.get("hype", ""))
	_draw_badge.show_value("draw_pile", str(dude["draw"]), "", PILE_PIXELS, PILE_FONT_SIZE, false, _tooltips.get("draw_pile", ""))
	_discard_badge.show_value("discard_pile", str(dude["discard"]), "", PILE_PIXELS, PILE_FONT_SIZE, false, _tooltips.get("discard_pile", ""))
	_tapped_badge.show_value("tapped_pile", str(dude["tapped"]), "", PILE_PIXELS, PILE_FONT_SIZE, false, _tooltips.get("tapped_pile", ""))


## Adds one combatant view to the floor (_arena, which places it) and remembers it in _views.
## [changed, task 057: the views stand on one floor_layout.gd instead of two boxes.]
## entry: a Dude or enemy entry of the fight model. enemy: true for an enemy.
## on_press: called when it is clicked (enabled only while the Dude is up or the enemy alive).
## party_size: Dudes in the fight (model "party_size"), for the target markers.
func _add_view(entry: Dictionary, enemy: bool, on_press: Callable, party_size: int) -> void:
	# view: the new view.
	var view: Button = CombatantView.new()
	view.tooltips = _tooltips
	view.render(entry, enemy, party_size)
	view.pressed.connect(on_press)
	_arena.add_child(view)
	_views[view.id] = view


## [added, task 041] Returns true when the core would accept playing this card copy now, with some
## target the player could pick: the target sent without asking (Targeting.auto_target_in_state())
## when the card asks for nothing, otherwise any enemy (ENEMY) or any pickable Dude (DUDE). The core
## decides (Core.validate() on a probe request that is never sent); nothing about Hype, phase or
## playability is worked out here. Reads only.
## card_uid: a card copy in the local player's hand.
func card_playable(card_uid: String) -> bool:
	if _requests == null or _state.is_empty():
		return false
	for target_id: String in _probe_targets(card_uid):
		if Gateway.validate(_ruleset, _state, _requests.probe_play_card(card_uid, target_id)) == "":
			return true
	return false


## [added, task 041] Returns the target_ids card_playable() asks the core about for a card copy, in
## the order the player would see them: [the auto target] for a card that asks for nothing, every
## enemy uid in the fight (left to right) for one that asks for an enemy, every pickable Dude for one
## that asks for a Dude. Reads only.
## card_uid: a card copy in the local player's hand.
func _probe_targets(card_uid: String) -> Array[String]:
	# targets: the result.
	var targets: Array[String] = []
	match _pick_for(card_uid):
		Targeting.ENEMY:
			for enemy: Dictionary in _state["combat"]["enemies"]:
				targets.append(enemy["uid"])
		Targeting.DUDE:
			targets = Targeting.pickable_dudes(_state)
		_:
			targets.append(Targeting.auto_target_in_state(_card_def(card_uid), _player_id))
	return targets


## [added, task 041] Adds one card face to the hand: drawn from the copy's effective definition
## (_card_def()), dimmed when card_playable() is false, and playing the card through press_card()
## when clicked, as the old text buttons did.
## card: the card's hand entry from FightModel.build() (card_uid, name, upgraded).
func _add_card(card: Dictionary) -> void:
	# view: the new card face.
	var view: Button = CardView.new()
	view.hover_seconds = CardView.HOVER_SECONDS if animation_seconds > 0.0 else 0.0
	view.render(_card_def(card["card_uid"]), card["upgraded"], card_playable(card["card_uid"]), card["name"])
	view.tooltip_text = TooltipText.card(_ruleset, _card_def(card["card_uid"]))
	view.pressed.connect(press_card.bind(card["card_uid"]))
	_hand_box.add_child(view)


## [added, task 047] Shows a banner (the event player calls it where banners_for() puts one; the
## screen calls it when it opens on a player phase): logs it in banner_log, then shows the band with
## the kind's words (messages.gd BANNERS), fading in and out over seconds, and hides it again. With
## seconds <= 0 it is only logged, so the drawing never keeps a banner.
## kind: a banner kind (event_player.gd BANNERS). seconds: how long it shows.
func _on_banner(kind: String, seconds: float) -> void:
	banner_log.append("%s@%d" % [kind, animation_log.size()])
	if _banner == null:
		return
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	if seconds <= 0.0 or not is_inside_tree():
		_hide_banner()
		return
	# words: the banner's title and line.
	var words: Dictionary = Messages.BANNERS.get(kind, {"title": kind.capitalize(), "line": ""})
	banner_text = words["title"]
	_banner_title.text = words["title"]
	_banner_title.add_theme_color_override("font_color", BANNER_COLORS.get(kind, Color.WHITE))
	_banner_line.text = words["line"]
	_banner_line.visible = words["line"] != ""
	_banner.modulate.a = 0.0
	_banner.visible = true
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, seconds * BANNER_FADE_SHARE)
	_banner_tween.tween_interval(seconds * (1.0 - 2.0 * BANNER_FADE_SHARE))
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, seconds * BANNER_FADE_SHARE)
	_banner_tween.tween_callback(_hide_banner)


## [added, task 047] Hides the banner and empties its words, so no banner text stays on screen.
func _hide_banner() -> void:
	banner_text = ""
	if _banner == null:
		return
	_banner.visible = false
	_banner_title.text = ""
	_banner_line.text = ""


## [added, task 047] Makes a button pulse to PULSE_COLOR and back, over and over, until it is freed.
## button: the button (the Ready button).
func _pulse(button: Button) -> void:
	if not button.is_inside_tree():
		button.modulate = PULSE_COLOR
		return
	# tween: the endless pulse, bound to the button so it ends with it.
	var tween: Tween = button.create_tween().set_loops()
	tween.tween_property(button, "modulate", PULSE_COLOR, PULSE_SECONDS / 2.0)
	tween.tween_property(button, "modulate", Color.WHITE, PULSE_SECONDS / 2.0)


## Called by the event player before each event animates: logs it and shows its line.
## event: the event. names: display names, from EventText.names_for().
func _on_event(event: Dictionary, names: Dictionary) -> void:
	animation_log.append(_describe(event))
	# line: the event's player-facing line.
	var line: String = EventText.line(event, names)
	_log_event(line)
	_show_message(line)


## Adds a line to event_lines and shows the last LOG_LINES of them in the log.
## line: one event line.
func _log_event(line: String) -> void:
	event_lines.append(line)
	if _log_label != null:
		_log_label.text = "\n".join(event_lines.slice(-LOG_LINES))
		_log_label.visible = true


## Adds one button to a container and returns it (task 047). Task 045: a client/visual/
## tip_button.gd, so a tooltip wraps.
## box: the container. text: the button's label. on_press: called when pressed. disabled: greyed out.
## tooltip: [added, task 045] its hover text (client/help/tooltip_text.gd), "" for none.
func _add_button(box: Container, text: String, on_press: Callable, disabled: bool, tooltip: String = "") -> Button:
	# button: the new button.
	var button: Button = TipButton.new()
	button.text = text
	button.tooltip_text = tooltip
	button.disabled = disabled
	button.pressed.connect(on_press)
	box.add_child(button)
	return button


## Shows a message to the player.
## text: the message.
func _show_message(text: String) -> void:
	message = text
	if _message_label != null:
		_message_label.text = text


## Returns one line describing an event, for the message bar and animation_log, for example
## "damage_dealt e3 hp_lost=6". Fields are listed in sorted order so the line never depends on how
## the event was built.
## event: one event from the gateway.
func _describe(event: Dictionary) -> String:
	# keys: the event's fields except "type", sorted.
	var keys: Array = event.keys()
	keys.erase("type")
	keys.sort()
	# parts: "field=value" pieces.
	var parts: Array[String] = []
	for key: String in keys:
		parts.append("%s=%s" % [key, event[key]])
	return "%s %s" % [event["type"], " ".join(parts)]


## [added, task ally-pick] Returns the definition of a card copy in the local player's hand. Task
## upgraded-card-display: the copy's effective definition (core/combat/upgrades.gd definition_of()),
## so a Lifted copy is targeted as its upgraded definition says; {} when it has none (Targeting then
## asks for nothing and the core refuses the card). Reads only.
## card_uid: the card copy.
func _card_def(card_uid: String) -> Dictionary:
	return Upgrades.definition_of(_ruleset, _local(), card_uid)


## [added, task ally-pick] Returns what the player must pick before a card copy is sent, in the
## current state: Targeting.NONE, ENEMY or DUDE (Targeting.mode_in_state()).
## card_uid: the card copy.
func _pick_for(card_uid: String) -> String:
	return Targeting.mode_in_state(_card_def(card_uid), _state)


## [added, task 045] Returns a Brew's display name from the ruleset, or its id when the ruleset lacks
## it. The fight never takes place at Baileys, so it is always a Brew here, never a Shake.
## brew_id: a Brew id (data/brews/).
func _brew_name(brew_id: String) -> String:
	return _ruleset.get("brews", {}).get(brew_id, {}).get("name", brew_id)


## Returns the local player's Dude in the current state.
func _local() -> Dictionary:
	for dude: Dictionary in _state["dudes"]:
		if dude["player_id"] == _player_id:
			return dude
	return {}


## Adds the non-empty text of node and its children to lines, depth first, skipping widgets queued
## for deletion.
## node: where to start. lines: receives the text.
func _collect_text(node: Node, lines: Array[String]) -> void:
	if node.is_queued_for_deletion():
		return
	if (node is Label or node is Button) and node.text != "":
		lines.append(node.text)
	for child: Node in node.get_children():
		_collect_text(child, lines)
