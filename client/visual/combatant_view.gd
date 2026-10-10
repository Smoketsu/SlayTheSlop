## One Dude or enemy on the fight screen: sprite, name, HP bar, Guard, statuses and, for an enemy,
## its intent (task 028). Lane: client (Agent B).
##
## A Button, so clicking it targets that Dude or enemy as the old text buttons did. render() draws
## it from one entry of client/fight/fight_model.gd build() (which reads only the state); the
## animation methods (hit, guard_to, heal_to, die, leave, pass_out) change only how it looks until the
## next render(). Nothing here reads or writes game state.
extends Button

const Sprites := preload("res://client/visual/sprites.gd")

## Smallest size of one view, in pixels. Changed only by the client lane.
const VIEW_SIZE := Vector2(170, 330)
## Box the sprite is fitted into, in pixels (keeps its aspect, stands on the bottom edge). Changed
## only by the client lane.
const SPRITE_SIZE := Vector2(150, 140)
## Font size of the view's text, in pixels. Changed only by the client lane.
const FONT_SIZE: int = 13
## Height of the HP bar, in pixels. Changed only by the client lane.
const BAR_HEIGHT: float = 10.0
## HP bar fill of an enemy. Changed only by the client lane.
const ENEMY_BAR_COLOR := Color(0.8, 0.2, 0.2)
## HP bar fill of a Dude. Changed only by the client lane.
const DUDE_BAR_COLOR := Color(0.25, 0.7, 0.3)
## HP bar background. Changed only by the client lane.
const BAR_BACK_COLOR := Color(0.15, 0.15, 0.15)
## Colour of the Guard text and of the flash when Guard is gained. Changed only by the client lane.
const GUARD_COLOR := Color(0.45, 0.7, 1.0)
## Colour of the flash and number when HP is lost. Changed only by the client lane.
const DAMAGE_COLOR := Color(1.0, 0.25, 0.25)
## Colour of the flash and number when HP is healed. Changed only by the client lane.
const HEAL_COLOR := Color(0.4, 1.0, 0.5)
## Tint of a Passed Out Dude. Changed only by the client lane.
const DOWN_COLOR := Color(0.45, 0.45, 0.45)
## How far a Passed Out Dude's sprite leans, in degrees (negative leans left). Changed only by the
## client lane.
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
## Guard the view shows now, 0 or more. render() sets it from the state; hit() and guard_to() move
## it while events play. Display only: never game state.
var guard_value: int = 0

## Intent line above the sprite (enemies only; empty for a Dude).
var _intent_label: Label
## Holds the sprite at a fixed size so it can shake and tilt without the layout moving it.
var _sprite_holder: Control
## The character art.
var _sprite: TextureRect
## Display name, with " (you)" for the local Dude.
var _name_label: Label
## HP as a bar, 0..max HP.
var _hp_bar: ProgressBar
## HP as text, "HP 58 / 70".
var _hp_label: Label
## Guard as text, "Guard 5".
var _guard_label: Label
## Statuses as text, "Exposed 1, Ick 2"; empty when none.
var _status_label: Label
## The rest: Hype, Brews and pile counts for a Dude; arms and Ick for an enemy.
var _detail_label: Label
## Max HP the bar is drawn against, 1 or more. Set by render().
var _hp_max: int = 1
## The sprite's colour when nothing is animating (Sprites.look() tint, greyed when Passed Out).
var _base_tint := Color.WHITE
## The sprite's resting position inside _sprite_holder, in pixels.
var _sprite_home := Vector2.ZERO
## Tweens running on this view, killed when a new animation starts so two never fight.
var _tweens: Array[Tween] = []


## Builds the empty widgets. render() fills them.
func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	focus_mode = Control.FOCUS_NONE
	# column: everything, top to bottom, filling the button.
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	_intent_label = _label(column)
	_sprite_holder = Control.new()
	_sprite_holder.custom_minimum_size = SPRITE_SIZE
	column.add_child(_sprite_holder)
	_sprite = TextureRect.new()
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_holder.add_child(_sprite)
	_name_label = _label(column)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_hp_bar.add_theme_stylebox_override("background", _box(BAR_BACK_COLOR))
	column.add_child(_hp_bar)
	_hp_label = _label(column)
	_guard_label = _label(column)
	_guard_label.add_theme_color_override("font_color", GUARD_COLOR)
	_status_label = _label(column)
	_detail_label = _label(column)
	_ignore_mouse(column)


## Draws the view from one fight model entry. Call again to redraw; it resets any animation.
## entry: a Dude or enemy entry of FightModel.build(). enemy: true for an enemy entry.
func render(entry: Dictionary, enemy: bool) -> void:
	_stop_tweens()
	is_enemy = enemy
	id = entry["uid"] if enemy else entry["player_id"]
	# look: how to draw this id (Sprites.look()).
	var look: Dictionary = Sprites.look(entry["def_id"])
	_sprite.texture = look["texture"]
	_sprite.size = SPRITE_SIZE * float(look["scale"])
	_sprite_home = Vector2((SPRITE_SIZE.x - _sprite.size.x) / 2.0, SPRITE_SIZE.y - _sprite.size.y)
	_sprite.position = _sprite_home
	_sprite.pivot_offset = _sprite.size / 2.0
	_sprite.rotation = 0.0
	_base_tint = look["tint"]
	_name_label.text = entry["name"] + (" (you)" if entry.get("local", false) else "")
	_hp_max = maxi(1, entry["hp_max"])
	_hp_bar.max_value = _hp_max
	_hp_bar.add_theme_stylebox_override("fill", _box(ENEMY_BAR_COLOR if enemy else DUDE_BAR_COLOR))
	_show_hp(entry["hp_now"])
	_show_guard(entry["guard"])
	_status_label.text = ", ".join(entry["statuses"])
	_status_label.visible = _status_label.text != ""
	modulate = Color.WHITE
	if enemy:
		# aim: who the intent targets, as text.
		var aim: String = (" -> " + ", ".join(entry["targets"])) if not entry["targets"].is_empty() else ""
		_intent_label.text = "Intent: %s%s" % [entry["intent"] if entry["intent"] != "" else "?", aim]
		_detail_label.text = "%s\nIck %s" % [entry["arms"], entry["ick"]]
		disabled = not entry["alive"]
		if not entry["alive"]:
			modulate.a = GONE_ALPHA
	else:
		_intent_label.text = ""
		_detail_label.text = "Hype %d  Brews %s\nDraw %d  Discard %d  Tapped %d" % [entry["hype"], entry["brews"],
			entry["draw"], entry["discard"], entry["tapped"]]
		disabled = entry["passed_out"]
		if entry["passed_out"]:
			_base_tint = _base_tint * DOWN_COLOR
			_sprite.rotation = deg_to_rad(DOWN_TILT_DEGREES)
	_intent_label.visible = enemy
	_sprite.modulate = _base_tint


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


## Guard changed: the Guard number updates, and a gain flashes blue with the amount popping up.
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


## Sets the HP bar and text. hp: HP to show, clamped to 0..max HP.
func _show_hp(hp: int) -> void:
	hp_value = clampi(hp, 0, _hp_max)
	_hp_bar.value = hp_value
	_hp_label.text = "HP %d / %d" % [hp_value, _hp_max]


## Sets the Guard text. guard: Guard to show, 0 or more.
func _show_guard(guard: int) -> void:
	guard_value = maxi(0, guard)
	_guard_label.text = "Guard %d" % guard_value


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
	label.position = Vector2(VIEW_SIZE.x / 2.0 - 20.0, SPRITE_SIZE.y / 2.0)
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


## Adds a small centred wrapping label to a container and returns it.
## parent: the container.
func _label(parent: Container) -> Label:
	# label: the new label.
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	parent.add_child(label)
	return label


## Returns a flat box style of one colour, for the HP bar.
## color: the fill.
func _box(color: Color) -> StyleBoxFlat:
	# box: the style.
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return box


## Lets clicks pass through node and everything under it to this button.
## node: where to start.
func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		if child is Control:
			_ignore_mouse(child)
