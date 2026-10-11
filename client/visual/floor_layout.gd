## Stands the Dudes and enemies on the room's floor (task 057). Lane: client (Agent B).
##
## A Container covering the fight screen: the fight screen adds one client/visual/combatant_view.gd
## per Dude, then one per enemy, in state order, and this places them. Dudes stand on the left part
## of the floor and enemies on the right, each side in evenly spaced slots, left to right in the
## order they were added (state order: the order enemies act in). Every sprite's feet are on the
## floor line (client/visual/backgrounds.gd floor_line()); when a side is crowded, every slot and
## sprite shrinks by the same factor so both sides keep the same scale. The name, HP bar and badges
## under the feet always end above hand_top, so the hand is never covered. Only positions and sizes
## change here; nothing reads or writes game state.
extends Container

const CombatantView := preload("res://client/visual/combatant_view.gd")

## Where the Dudes' part of the floor ends, as a fraction of the width from the left (0..1). Changed
## only by the client lane.
const DUDE_SIDE_END: float = 0.42
## Where the enemies' part of the floor starts, as a fraction of the width from the left (0..1),
## after DUDE_SIDE_END so the two sides never touch. Changed only by the client lane.
const ENEMY_SIDE_START: float = 0.47
## Empty space kept at the left and right screen edges, in pixels. Changed only by the client lane.
const EDGE_PIXELS: float = 16.0

## The room's floor line: where feet go, as a fraction of this container's height from the top,
## 0..1 (Backgrounds.floor_line()). Set by the fight screen when it draws; re-sorts when changed.
var floor_line: float = 0.6:
	set(value):
		floor_line = value
		queue_sort()
## Where the hand area begins, as a fraction of this container's height from the top, 0..1. Nothing
## placed here reaches below it. Set by the fight screen; re-sorts when changed.
var hand_top: float = 0.7:
	set(value):
		hand_top = value
		queue_sort()
## Space kept free at the top for the turn label, message and log, in pixels; sprites shrink before
## reaching into it. Set by the fight screen; re-sorts when changed.
var top_pixels: float = 0.0:
	set(value):
		top_pixels = value
		queue_sort()


## Places every combatant view: Dudes left, enemies right, feet on the floor line.
## what: the notification; only NOTIFICATION_SORT_CHILDREN is handled.
func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	# dudes: the Dudes' views, in the order they were added.
	var dudes: Array[Control] = []
	# enemies: the enemies' views, in the order they were added.
	var enemies: Array[Control] = []
	for child: Node in get_children():
		if child is Control and not child.is_queued_for_deletion() and "is_enemy" in child:
			(enemies if child.is_enemy else dudes).append(child)
	# plan: where everything goes (slots()).
	var plan: Dictionary = slots(size, floor_line, hand_top, top_pixels, dudes.size(), enemies.size())
	for i: int in dudes.size():
		fit_child_in_rect(dudes[i], plan["dudes"][i])
		dudes[i].arrange(plan["sprite_height"])
	for i: int in enemies.size():
		fit_child_in_rect(enemies[i], plan["enemies"][i])
		enemies[i].arrange(plan["sprite_height"])


## Returns where the views go, in pixels inside an area of this size: {"feet_y": the feet's height
## from the top, "sprite_height": every sprite box's height, "dudes": one Rect2 per Dude view and
## "enemies": one per enemy view, left to right}. Each rect is a whole view (intent row, sprite and
## the parts under it, combatant_view.gd height_for()), standing on feet_y. Pure.
## area: the container's size. line: the floor line, 0..1 of the height. hand: where the hand starts,
## 0..1 of the height. top: pixels kept free at the top. dude_count, enemy_count: views on each side,
## 0 or more.
static func slots(area: Vector2, line: float, hand: float, top: float, dude_count: int, enemy_count: int) -> Dictionary:
	# feet_y: the floor line in pixels, raised only if the parts under the feet would reach the hand.
	var feet_y: float = minf(area.y * line, area.y * hand - CombatantView.UNDER_HEIGHT)
	# dude_side: the left part of the floor, as [left edge, width] in pixels.
	var dude_side := Vector2(EDGE_PIXELS, area.x * DUDE_SIDE_END - EDGE_PIXELS)
	# enemy_side: the right part of the floor, as [left edge, width] in pixels.
	var enemy_side := Vector2(area.x * ENEMY_SIDE_START, area.x * (1.0 - ENEMY_SIDE_START) - EDGE_PIXELS)
	# width: one slot's width, the same on both sides: as wide as a view gets, or less so the more
	# crowded side fits.
	var width: float = CombatantView.VIEW_WIDTH
	if dude_count > 0:
		width = minf(width, dude_side.y / dude_count)
	if enemy_count > 0:
		width = minf(width, enemy_side.y / enemy_count)
	width = maxf(1.0, width)
	# sprite: the sprite box's height, shrunk with the slot, and never reaching into the top space.
	var sprite: float = CombatantView.SPRITE_HEIGHT * width / CombatantView.VIEW_WIDTH
	sprite = maxf(1.0, minf(sprite, feet_y - top - CombatantView.INTENT_HEIGHT))
	return {
		"feet_y": feet_y,
		"sprite_height": sprite,
		"dudes": _row(dude_side, dude_count, width, sprite, feet_y),
		"enemies": _row(enemy_side, enemy_count, width, sprite, feet_y),
	}


## Returns count view rects of one width, side by side and centred in one side of the floor,
## standing on feet_y.
## side: [left edge, width] of the side in pixels. count: views, 0 or more. width: one slot's width.
## sprite: the sprite box's height. feet_y: the feet's height from the top, in pixels.
static func _row(side: Vector2, count: int, width: float, sprite: float, feet_y: float) -> Array[Rect2]:
	# out: the result.
	var out: Array[Rect2] = []
	# left: the first slot's left edge, so the row is centred in its side.
	var left: float = side.x + (side.y - width * count) / 2.0
	# top: every view's top edge.
	var top: float = feet_y - sprite - CombatantView.INTENT_HEIGHT
	for i: int in count:
		out.append(Rect2(left + width * i, top, width, CombatantView.height_for(sprite)))
	return out
