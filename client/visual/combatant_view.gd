## One Dude or enemy on the fight screen (tasks 028 and 057). Lane: client (Agent B).
##
## Top to bottom: the intent icon over its head (enemies; in co-op a Dude shows its seat marker
## there), the sprite standing with its feet on the row's floor line, the name, an HP bar with
## "current / max" inside, and one row of icon badges (client/visual/stat_badge.gd) for Guard, Swole,
## Chill, Clout, every status, broken arms and Ick, each shown only when its value is not 0. No panel
## is drawn behind it: the room shows through, and only hovering lights it faintly.
##
## A Button, so clicking it targets that Dude or enemy as the old text buttons did; badges let clicks
## through and carry tooltips. render() draws it from one entry of client/fight/fight_model.gd build()
## (which reads only the state); arrange() sizes it for its slot on the floor (client/visual/
## floor_layout.gd); the animation methods (hit, guard_to, heal_to, die, pass_out) change only how it
## looks until the next render(). Nothing here reads or writes game state.
extends Button

const Sprites := preload("res://client/visual/sprites.gd")
const StatBadge := preload("res://client/visual/stat_badge.gd")
const Icons := preload("res://client/visual/icons.gd")
const Messages := preload("res://client/fight/messages.gd")

## Widest a view gets, in pixels: a slot on the floor is never wider. Changed only by the client lane.
const VIEW_WIDTH: float = 180.0
## Height of a sprite at full size, in pixels (feet to the top of its art box). Sprites shrink below
## it when the floor is crowded (floor_layout.gd). Changed only by the client lane.
const SPRITE_HEIGHT: float = 170.0
## Height kept above the sprite for the intent icon, in pixels. Changed only by the client lane.
const INTENT_HEIGHT: float = 30.0
## Height of the name line under the sprite, in pixels. Changed only by the client lane.
const NAME_HEIGHT: float = 16.0
## Height of the HP bar, in pixels. Changed only by the client lane.
const BAR_HEIGHT: float = 16.0
## Widest the HP bar gets, in pixels (narrower in a narrow slot). Changed only by the client lane.
const BAR_WIDTH: float = 124.0
## Height of the badge row, in pixels. Changed only by the client lane.
const BADGE_HEIGHT: float = 22.0
## Space between the name, the HP bar and the badge row, in pixels. Changed only by the client lane.
const ROW_GAP: float = 2.0
## Everything under the feet: the name, the HP bar and the badge row with their gaps, in pixels.
## floor_layout.gd keeps it above the hand. Changed only with the constants it adds up.
const UNDER_HEIGHT: float = ROW_GAP * 3.0 + NAME_HEIGHT + BAR_HEIGHT + BADGE_HEIGHT
## Font size of the name, in pixels. Changed only by the client lane.
const NAME_FONT_SIZE: int = 12
## Font size of the number inside the HP bar, in pixels. Changed only by the client lane.
const BAR_FONT_SIZE: int = 11
## Side of the heart drawn at the HP bar's left end, in pixels. Changed only by the client lane.
const HEART_PIXELS: float = 18.0
## Side of the intent icon, in pixels. Changed only by the client lane.
const INTENT_ICON_PIXELS: int = 28
## Font size of the intent's damage number, in pixels. Changed only by the client lane.
const INTENT_FONT_SIZE: int = 17
## Side of a target or seat marker, in pixels. Changed only by the client lane.
const MARKER_PIXELS: int = 16
## Base font size of the view's pop-up text, in pixels; pop-ups are drawn at FONT_SIZE + 9. Changed
## only by the client lane.
const FONT_SIZE: int = 13
## Seat (a Dude's place in state.dudes, 0..3) -> its colour. In co-op a Dude's seat marker and every
## attack marker aimed at that Dude share it, so a player sees who an enemy is aiming at. Changed
## only by the client lane.
const SEAT_COLORS: Array[Color] = [Color(1.0, 0.85, 0.25), Color(0.35, 0.85, 1.0), Color(1.0, 0.45, 0.85), Color(0.55, 1.0, 0.4)]
## Faint light behind the view while the mouse is over it or it is pressed; nothing is drawn behind
## it at rest. Changed only by the client lane.
const HOVER_COLOR := Color(1, 1, 1, 0.08)
## Rounding of that light's corners, in pixels. Changed only by the client lane.
const HOVER_CORNER: int = 10
## HP bar fill of an enemy. Changed only by the client lane.
const ENEMY_BAR_COLOR := Color(0.8, 0.2, 0.2)
## HP bar fill of a Dude. Changed only by the client lane.
const DUDE_BAR_COLOR := Color(0.25, 0.7, 0.3)
## HP bar background. Changed only by the client lane.
const BAR_BACK_COLOR := Color(0.1, 0.1, 0.1, 0.85)
## Colour of the flash when Guard is gained or blocks a hit. Changed only by the client lane.
const GUARD_COLOR := Color(0.45, 0.7, 1.0)
## Colour of the flash and number when HP is lost. Changed only by the client lane.
const DAMAGE_COLOR := Color(1.0, 0.25, 0.25)
## Colour of the flash and number when HP is healed. Changed only by the client lane.
const HEAL_COLOR := Color(0.4, 1.0, 0.5)
## Tint of a Passed Out Dude. Changed only by the client lane.
const DOWN_COLOR := Color(0.45, 0.45, 0.45)
## How far a Passed Out Dude's sprite leans, in degrees (negative leans left), turning about its
## feet so it lies on the floor. Changed only by the client lane.
const DOWN_TILT_DEGREES: float = -75.0
## Opacity of an enemy still listed at 0 HP, 0..1. Changed only by the client lane.
const GONE_ALPHA: float = 0.0
## How far a hit shakes the sprite sideways, in pixels. Changed only by the client lane.
const SHAKE_PIXELS: float = 8.0
## How far a pop-up number rises while it fades, in pixels. Changed only by the client lane.
const POP_RISE: float = 40.0
## Width of the dark outline around a pop-up number, in pixels, so it reads over a flashing
## sprite. Changed only by the client lane.
const POP_OUTLINE: int = 5
## Width of the dark outline around the name and the HP number, in pixels. Changed only by the
## client lane.
const TEXT_OUTLINE: int = 4
## Share of an animation spent flashing to the colour, 0..1; the rest fades back. Changed only by
## the client lane.
const FLASH_IN_SHARE: float = 0.3

## The player_id of the Dude, or the uid of the enemy, this view shows. Set by render().
var id: String = ""
## True when this view shows an enemy, false for a Dude. Set by render().
var is_enemy: bool = false
## HP the bar shows now, 0..hp_max. render() sets it from the state; hit() and heal_to() move it
## while events play. Display only: never game state.
var hp_value: int = 0
## Guard the Guard badge shows now, 0 or more. render() sets it from the state; hit() and guard_to()
## move it while events play. Display only: never game state.
var guard_value: int = 0
## Height of the sprite's box in pixels, feet to top; set by arrange(), SPRITE_HEIGHT until then.
var sprite_height: float = SPRITE_HEIGHT

## The fight model entry last drawn ({} before render()). Read only.
var _entry: Dictionary = {}
## Dudes in the fight, 1..4, as last rendered. Markers show only above 1.
var _party_size: int = 1
## The row over the head: the intent badge and target markers (enemy), or the seat marker (Dude).
var _intent_row: HBoxContainer
## Holds the sprite so it can shake and tilt without anything else moving.
var _sprite_holder: Control
## The character art.
var _sprite: TextureRect
## Display name, with " (you)" for the local Dude.
var _name_label: Label
## HP as a bar, 0..max HP, with the number inside it and a heart at its left end.
var _hp_bar: ProgressBar
## HP as text inside the bar, "58 / 70".
var _hp_label: Label
## The badges under the HP bar, left to right.
var _badge_row: HBoxContainer
## Max HP the bar is drawn against, 1 or more. Set by render().
var _hp_max: int = 1
## Size of the sprite relative to a normal one (Sprites.look() "scale", 0.1..1.0).
var _look_scale: float = 1.0
## The sprite's colour when nothing is animating (Sprites.look() tint, greyed when Passed Out).
var _base_tint := Color.WHITE
## The sprite's resting position inside _sprite_holder, in pixels.
var _sprite_home := Vector2.ZERO
## Tweens running on this view, killed when a new animation starts so two never fight.
var _tweens: Array[Tween] = []


## Builds the empty widgets. render() fills them; arrange() places them.
func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2.ZERO
	for style: String in ["normal", "disabled", "focus"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for style: String in ["hover", "pressed"]:
		# light: the faint hover light.
		var light := StyleBoxFlat.new()
		light.bg_color = HOVER_COLOR
		light.set_corner_radius_all(HOVER_CORNER)
		add_theme_stylebox_override(style, light)
	_intent_row = _row()
	_sprite_holder = Control.new()
	add_child(_sprite_holder)
	_sprite = TextureRect.new()
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_sprite_holder.add_child(_sprite)
	_name_label = _label(NAME_FONT_SIZE)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_name_label)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.add_theme_stylebox_override("background", _box(BAR_BACK_COLOR, 3))
	add_child(_hp_bar)
	_hp_label = _label(BAR_FONT_SIZE)
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_bar.add_child(_hp_label)
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# heart: the HP icon at the bar's left end (none when the icon is missing; the number still says it).
	var heart := TextureRect.new()
	heart.texture = Icons.look("hp")["texture"]
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.size = Vector2(HEART_PIXELS, HEART_PIXELS)
	heart.position = Vector2(-HEART_PIXELS / 2.0, (BAR_HEIGHT - HEART_PIXELS) / 2.0)
	_hp_bar.add_child(heart)
	_badge_row = _row()
	_ignore_mouse(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	size = Vector2(VIEW_WIDTH, height_for(SPRITE_HEIGHT))


## Re-places the parts whenever the view's size changes.
## what: the notification; only NOTIFICATION_RESIZED is handled.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _sprite_holder != null:
		_arrange()


## Draws the view from one fight model entry. Call again to redraw; it resets any animation.
## entry: a Dude or enemy entry of FightModel.build(). enemy: true for an enemy entry.
## party_size: Dudes in the fight (model "party_size"), 1..4; target and seat markers show above 1.
func render(entry: Dictionary, enemy: bool, party_size: int = 1) -> void:
	_stop_tweens()
	_entry = entry
	_party_size = party_size
	is_enemy = enemy
	id = entry["uid"] if enemy else entry["player_id"]
	# look: how to draw this id (Sprites.look()).
	var look: Dictionary = Sprites.look(entry["def_id"])
	_sprite.texture = look["texture"]
	_look_scale = float(look["scale"])
	_sprite.rotation = 0.0
	_base_tint = look["tint"]
	_name_label.text = entry["name"] + (" (you)" if entry.get("local", false) else "")
	_name_label.add_theme_color_override("font_color", _seat_color() if not enemy and party_size > 1 else Color.WHITE)
	_hp_max = maxi(1, entry["hp_max"])
	_hp_bar.max_value = _hp_max
	_hp_bar.add_theme_stylebox_override("fill", _box(ENEMY_BAR_COLOR if enemy else DUDE_BAR_COLOR, 3))
	_show_hp(entry["hp_now"])
	guard_value = maxi(0, entry["guard"])
	_draw_badges()
	_draw_intent()
	modulate = Color.WHITE
	if enemy:
		disabled = not entry["alive"]
		if not entry["alive"]:
			modulate.a = GONE_ALPHA
	else:
		disabled = entry["passed_out"]
		if entry["passed_out"]:
			_base_tint = _base_tint * DOWN_COLOR
			_sprite.rotation = deg_to_rad(DOWN_TILT_DEGREES)
	_sprite.modulate = _base_tint
	_arrange()


## Sizes the sprite for its slot on the floor and re-places every part. The view's width is its
## current size.x; call after giving it its slot (floor_layout.gd does both).
## sprite_px: height of the sprite's box in pixels, feet to top, more than 0.
func arrange(sprite_px: float) -> void:
	sprite_height = maxf(1.0, sprite_px)
	_arrange()


## Returns the height a view needs for a sprite of this height: intent row, sprite, and the parts
## under the feet, in pixels.
## sprite_px: height of the sprite's box in pixels.
static func height_for(sprite_px: float) -> float:
	return INTENT_HEIGHT + sprite_px + UNDER_HEIGHT


## Returns how far below the view's top edge the sprite's feet stand, in pixels.
func feet_offset() -> float:
	return INTENT_HEIGHT + sprite_height


## Returns what the badge row shows, left to right: one {"key": icons.gd key, "value": the number as
## text, "tooltip": what the tooltip says after the name} per value that is not 0. Order: Guard,
## Swole, Chill, Clout, (a teammate's Hype), each status by id, broken arms "k / n", Ick
## "current / threshold". Pure: depends on its arguments only.
## entry: a FightModel.build() Dude or enemy entry. enemy: true for an enemy. guard: the Guard to
## show (guard_value, which events move before the redraw).
static func badges_for(entry: Dictionary, enemy: bool, guard: int) -> Array:
	# out: the result.
	var out: Array = []
	# counts: the plain numbers, in badge order.
	var counts: Array = [["guard", guard], ["swole", entry.get("swole", 0)], ["chill", entry.get("chill", 0)],
		["clout", entry.get("clout", 0)]]
	if not enemy and not entry.get("local", true):
		counts.append(["hype", entry.get("hype", 0)])
	counts.append_array(entry.get("status_stacks", []))
	for pair: Array in counts:
		if pair[1] != 0:
			out.append({"key": pair[0], "value": str(pair[1]), "tooltip": str(pair[1])})
	if enemy and entry.get("broken_arms", 0) != 0:
		# arms: "k / n".
		var arms: String = "%d / %d" % [entry["broken_arms"], entry["arm_count"]]
		out.append({"key": "broken_arms", "value": arms, "tooltip": arms + " arms broken"})
	if enemy and entry.get("ick_now", 0) != 0:
		# ick: "current / threshold".
		var ick: String = "%d / %d" % [entry["ick_now"], entry["ick_threshold"]]
		out.append({"key": "ick", "value": ick, "tooltip": ick})
	return out


## Returns what the intent icon over an enemy's head shows: {"key": the icons.gd key (its intent kind,
## "skipped" when the core says it will skip the move, "" for no icon: no intent yet, or gone),
## "value": the damage number for an attack ("7", "5x3"; "" otherwise), "tooltip": what the tooltip
## says after the name ("7 at Tom", "up to 30 at Tom", "Grossed Out")}. Pure.
## entry: a FightModel.build() enemy entry.
static func intent_for(entry: Dictionary) -> Dictionary:
	if not entry.get("alive", false) or entry.get("intent", "") == "":
		return {"key": "", "value": "", "tooltip": ""}
	if entry.get("skip", "") != "":
		return {"key": "skipped", "value": "", "tooltip": Messages.SKIP_REASONS.get(entry["skip"], entry["skip"])}
	# damage: the core's damage of the move (FightModel _intent_damage()).
	var damage: Dictionary = entry.get("intent_damage", {"amount": -1, "hits": 1, "up_to": false})
	# value: the number on screen.
	var value: String = ""
	# said: the same in words, for the tooltip.
	var said: String = ""
	if damage["amount"] >= 0:
		value = str(damage["amount"]) + ("x%d" % damage["hits"] if damage["hits"] > 1 else "")
		said = ("up to " if damage["up_to"] else "") + str(damage["amount"]) + (" x %d" % damage["hits"] if damage["hits"] > 1 else "")
	if not entry.get("targets", []).is_empty():
		said = (said + " at " if said != "" else "at ") + ", ".join(entry["targets"])
	return {"key": entry["intent"], "value": value, "tooltip": said}


## Returns the badges under the HP bar, left to right (stat_badge.gd nodes), for tests.
func badges() -> Array[Node]:
	return _live_children(_badge_row)


## Returns the badges over the head, left to right: the intent first, then any target markers (or a
## Dude's seat marker). Empty when nothing is shown there. For tests.
func head_badges() -> Array[Node]:
	return _live_children(_intent_row)


## Returns the sprite's rectangle on screen, at rest, for tests.
func sprite_rect() -> Rect2:
	return _sprite.get_global_rect()


## A hit landed: HP and Guard drop, the sprite flashes red and shakes, and the HP lost pops up
## (or "Blocked" when Guard took all of it; nothing more when both are 0). Instant (no tween, no
## pop-up) when seconds <= 0.
## hp_lost: HP taken off, 0 or more. blocked: Guard used up, 0 or more. seconds: animation length.
func hit(hp_lost: int, blocked: int, seconds: float) -> void:
	_stop_tweens()
	_show_hp(hp_value - hp_lost)
	_show_guard(guard_value - blocked)
	if seconds <= 0.0:
		return
	if hp_lost > 0:
		_flash(DAMAGE_COLOR, seconds)
		_shake(seconds)
		_pop("-%d" % hp_lost, DAMAGE_COLOR, seconds)
	elif blocked > 0:
		_flash(GUARD_COLOR, seconds)
		_pop("Blocked", GUARD_COLOR, seconds)


## Guard changed: the Guard badge updates, and a gain flashes blue with the amount popping up.
## guard: the new Guard. delta: the change. seconds: animation length; instant when <= 0.
func guard_to(guard: int, delta: int, seconds: float) -> void:
	_stop_tweens()
	_show_guard(guard)
	if seconds > 0.0 and delta > 0:
		_flash(GUARD_COLOR, seconds)
		_pop("+%d Guard" % delta, GUARD_COLOR, seconds)


## Healed: the HP bar fills, the sprite flashes green and the amount pops up.
## hp: the new HP. amount: HP restored. seconds: animation length; instant when <= 0.
func heal_to(hp: int, amount: int, seconds: float) -> void:
	_stop_tweens()
	_show_hp(hp)
	if seconds > 0.0:
		_flash(HEAL_COLOR, seconds)
		_pop("+%d" % amount, HEAL_COLOR, seconds)


## Died, fled or split: the whole view fades out. seconds: animation length; instant when <= 0.
func die(seconds: float) -> void:
	_stop_tweens()
	if seconds <= 0.0:
		modulate.a = GONE_ALPHA
		return
	_track(create_tween()).tween_property(self, "modulate:a", GONE_ALPHA, seconds)


## Passed Out: the sprite greys and tips over. seconds: animation length; instant when <= 0.
func pass_out(seconds: float) -> void:
	_stop_tweens()
	_base_tint = _base_tint * DOWN_COLOR
	if seconds <= 0.0:
		_sprite.modulate = _base_tint
		_sprite.rotation = deg_to_rad(DOWN_TILT_DEGREES)
		return
	# tween: grey and tilt together.
	var tween: Tween = _track(create_tween()).set_parallel(true)
	tween.tween_property(_sprite, "modulate", _base_tint, seconds)
	tween.tween_property(_sprite, "rotation", deg_to_rad(DOWN_TILT_DEGREES), seconds)


## Returns the texture the sprite shows, for tests.
func texture() -> Texture2D:
	return _sprite.texture


## Places every part for the current size and sprite_height: the intent row on top, the sprite
## standing on feet_offset(), then the name, the HP bar and the badge row. Rows too wide for the
## view are shrunk to fit, so there is always exactly one row of badges.
func _arrange() -> void:
	# width: the view's width.
	var width: float = size.x
	_place_row(_intent_row, 0.0, INTENT_HEIGHT, width)
	_sprite_holder.position = Vector2(0.0, INTENT_HEIGHT)
	_sprite_holder.size = Vector2(width, sprite_height)
	_place_sprite(width)
	# y: the top of the next part under the feet.
	var y: float = feet_offset() + ROW_GAP
	_name_label.position = Vector2(0.0, y)
	_name_label.size = Vector2(width, NAME_HEIGHT)
	y += NAME_HEIGHT + ROW_GAP
	# bar_width: the HP bar's width, leaving room for the heart at its left end.
	var bar_width: float = maxf(HEART_PIXELS, minf(BAR_WIDTH, width - HEART_PIXELS))
	_hp_bar.position = Vector2((width - bar_width) / 2.0 + HEART_PIXELS / 4.0, y)
	_hp_bar.size = Vector2(bar_width, BAR_HEIGHT)
	y += BAR_HEIGHT + ROW_GAP
	_place_row(_badge_row, y, BADGE_HEIGHT, width)


## Fits the sprite into its box keeping the art's aspect: as tall as the box times its look scale,
## narrower than the view, centred, with its bottom edge (the feet) on the box's bottom edge.
## width: the view's width in pixels.
func _place_sprite(width: float) -> void:
	# art: the texture's size in pixels, never 0.
	var art := Vector2.ONE
	if _sprite.texture != null:
		art = Vector2(maxi(1, _sprite.texture.get_width()), maxi(1, _sprite.texture.get_height()))
	# fitted: the sprite's size on screen.
	var fitted := Vector2(art.x / art.y, 1.0) * sprite_height * _look_scale
	if fitted.x > width:
		fitted *= width / fitted.x
	_sprite.size = fitted
	_sprite_home = Vector2((width - fitted.x) / 2.0, sprite_height - fitted.y)
	_sprite.position = _sprite_home
	_sprite.pivot_offset = Vector2(fitted.x / 2.0, fitted.y)


## Places a row of badges across the view: centred, and shrunk evenly when it is wider than the view.
## row: the row. top: its top edge in the view, in pixels. height: its height in pixels. width: the
## view's width in pixels.
func _place_row(row: HBoxContainer, top: float, height: float, width: float) -> void:
	# needed: the row's natural width.
	var needed: float = row.get_combined_minimum_size().x
	# shrink: 1, or less when the row would be wider than the view.
	var shrink: float = 1.0 if needed <= width or needed <= 0.0 else width / needed
	row.scale = Vector2(shrink, shrink)
	row.size = Vector2(maxf(width / shrink, needed), height / shrink)
	row.position = Vector2((width - row.size.x * shrink) / 2.0, top)


## Rebuilds the badge row from the last entry, with guard_value for Guard.
func _draw_badges() -> void:
	_clear(_badge_row)
	for badge: Dictionary in badges_for(_entry, is_enemy, guard_value):
		_add_badge(_badge_row, badge["key"], badge["value"], badge["tooltip"], StatBadge.ICON_PIXELS, StatBadge.FONT_SIZE)
	if _sprite_holder != null:
		_place_row(_badge_row, feet_offset() + ROW_GAP * 3.0 + NAME_HEIGHT + BAR_HEIGHT, BADGE_HEIGHT, size.x)


## Rebuilds the row over the head: an enemy's intent icon (with a marker per targeted Dude in co-op),
## or a Dude's seat marker in co-op; nothing otherwise.
func _draw_intent() -> void:
	_clear(_intent_row)
	if not is_enemy:
		if _party_size > 1:
			# seat: this Dude's seat marker.
			var seat: Control = _add_badge(_intent_row, "seat", "", "%d (%s)" % [_entry.get("seat", 0) + 1, _entry["name"]], MARKER_PIXELS, StatBadge.FONT_SIZE)
			seat.modulate = _seat_color()
		return
	# intent: what to show (intent_for()).
	var intent: Dictionary = intent_for(_entry)
	if intent["key"] == "":
		return
	_add_badge(_intent_row, intent["key"], intent["value"], intent["tooltip"], INTENT_ICON_PIXELS, INTENT_FONT_SIZE)
	if _party_size <= 1 or intent["key"] == "skipped":
		return
	# names: the targeted Dudes' names, in the same order as target_seats.
	var names: Array = _entry.get("targets", [])
	for i: int in _entry.get("target_seats", []).size():
		# seat: the targeted Dude's seat.
		var seat: int = _entry["target_seats"][i]
		# marker: the marker naming that Dude.
		var marker: Control = _add_badge(_intent_row, "target", "", names[i] if i < names.size() else "", MARKER_PIXELS, StatBadge.FONT_SIZE)
		marker.modulate = SEAT_COLORS[seat % SEAT_COLORS.size()]


## Adds one badge to a row and returns it.
## row: the row. key: its icons.gd key. value: the number as text, "" for none. tooltip: what its
## tooltip says after the name. icon_pixels: the icon's side in pixels. font_size: the number's size.
func _add_badge(row: HBoxContainer, key: String, value: String, tooltip: String, icon_pixels: int, font_size: int) -> Control:
	# badge: the new badge.
	var badge: HBoxContainer = StatBadge.new()
	badge.show_value(key, value, tooltip, icon_pixels, font_size)
	row.add_child(badge)
	return badge


## Returns this Dude's seat colour (SEAT_COLORS), from the last entry's "seat".
func _seat_color() -> Color:
	return SEAT_COLORS[int(_entry.get("seat", 0)) % SEAT_COLORS.size()]


## Sets the HP bar and its number. hp: HP to show, clamped to 0..max HP.
func _show_hp(hp: int) -> void:
	hp_value = clampi(hp, 0, _hp_max)
	_hp_bar.value = hp_value
	_hp_label.text = "%d / %d" % [hp_value, _hp_max]
	_hp_bar.tooltip_text = "%s: %d / %d" % [Icons.look("hp")["name"], hp_value, _hp_max]


## Sets the Guard badge. guard: Guard to show, 0 or more (0 hides the badge).
func _show_guard(guard: int) -> void:
	guard_value = maxi(0, guard)
	_draw_badges()


## Flashes the sprite to a colour and back to its resting tint.
## color: the flash colour. seconds: the whole flash's length.
func _flash(color: Color, seconds: float) -> void:
	# tween: in, then back out.
	var tween: Tween = _track(create_tween())
	tween.tween_property(_sprite, "modulate", color, seconds * FLASH_IN_SHARE)
	tween.tween_property(_sprite, "modulate", _base_tint, seconds * (1.0 - FLASH_IN_SHARE))


## Shakes the sprite sideways and settles it back home. seconds: the shake's length.
func _shake(seconds: float) -> void:
	# tween: four swings, then home.
	var tween: Tween = _track(create_tween())
	for side: float in [1.0, -1.0, 0.5, -0.5]:
		tween.tween_property(_sprite, "position", _sprite_home + Vector2(SHAKE_PIXELS * side, 0), seconds / 5.0)
	tween.tween_property(_sprite, "position", _sprite_home, seconds / 5.0)


## Shows text over the sprite that rises and fades, then removes itself.
## text: what pops up. color: its colour. seconds: how long it lasts.
func _pop(text: String, color: Color, seconds: float) -> void:
	# label: the pop-up. It is not tracked in _tweens, so a following event never cuts it short.
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", FONT_SIZE + 9)
	label.add_theme_constant_override("outline_size", POP_OUTLINE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(size.x / 2.0 - 20.0, INTENT_HEIGHT + sprite_height / 2.0)
	add_child(label)
	# tween: rise and fade at once, then free the label.
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - POP_RISE, seconds)
	tween.tween_property(label, "modulate:a", 0.0, seconds)
	tween.chain().tween_callback(label.queue_free)


## Remembers a tween so _stop_tweens() can end it. Returns it, for chaining.
## tween: a tween just created on this view.
func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween


## Ends every tracked tween and puts the sprite back at rest.
func _stop_tweens() -> void:
	for tween: Tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_sprite.position = _sprite_home
	_sprite.modulate = _base_tint


## Returns a new row for badges, centred, that lets clicks through to the view.
func _row() -> HBoxContainer:
	# row: the new row.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	return row


## Returns a new centred label with a dark outline (not yet added anywhere).
## font_size: its font size in pixels.
func _label(font_size: int) -> Label:
	# label: the new label.
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label


## Returns a flat box style of one colour, for the HP bar.
## color: the fill. corner: rounding of its corners in pixels, 0 for square.
func _box(color: Color, corner: int = 0) -> StyleBoxFlat:
	# box: the style.
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(corner)
	return box


## Removes and frees every child of a row (badges are rebuilt on each draw).
## row: the row.
func _clear(row: Node) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()


## Returns a node's children that are not queued for deletion, in order.
## node: the parent.
func _live_children(node: Node) -> Array[Node]:
	# out: the result.
	var out: Array[Node] = []
	for child: Node in node.get_children():
		if not child.is_queued_for_deletion():
			out.append(child)
	return out


## Lets clicks pass through node and everything under it to this button.
## node: where to start.
func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		if child is Control:
			_ignore_mouse(child)
