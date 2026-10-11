## Lays out the local player's hand of card faces (client/visual/card_view.gd) in a gentle fan
## (task 041). Lane: client (Agent B).
##
## A Container: the fight screen adds one card view per card in hand, left to right, and this places
## them. Cards sit side by side while they fit; when they do not (a full hand of 10 on a narrow
## window), they overlap evenly so the hand never grows wider than its space. Cards shrink to the
## height the screen leaves for the hand (never below MIN_SCALE), so the Dudes and enemies above are
## never pushed or covered at rest. Only positions, sizes, scales and rotations change here; nothing
## reads or writes game state.
extends Container

const CardView := preload("res://client/visual/card_view.gd")

## Space between two cards that fit side by side, in pixels at full size. Changed only by the client
## lane.
const GAP: float = 6.0
## Rotation of the outermost cards of the fan, in degrees (the left one leans left, the right one
## right); cards between lean in proportion. 0 for a straight row. Changed only by the client lane.
const FAN_DEGREES: float = 5.0
## How far the outermost cards sit lower than the middle one, in pixels, so the hand curves like a
## held fan. 0 for a straight row. Changed only by the client lane.
const FAN_DIP: float = 10.0
## Smallest scale the cards are shrunk to when the hand has little height, 0.1..1.0. Below it the
## hand asks its parent for more room instead. Changed only by the client lane.
const MIN_SCALE: float = 0.6


## Places every card view: bottom-aligned, centred, side by side or evenly overlapped, in a fan.
## what: the notification; only NOTIFICATION_SORT_CHILDREN is handled.
func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	# cards: the card views to place, left to right.
	var cards: Array[Control] = []
	for child: Node in get_children():
		if child is Control and (child as Control).visible:
			cards.append(child)
	if cards.is_empty():
		return
	# card_scale: how much the cards are shrunk to fit the hand's height, MIN_SCALE..1.
	var card_scale: float = card_scale_for(size.y)
	# width: one card's width on screen.
	var width: float = CardView.CARD_SIZE.x * card_scale
	# room: how far the outermost cards' corners reach past their upright box once tilted.
	var room: Vector2 = tilt_room(card_scale)
	# step: distance between two neighbouring cards' left edges, inside the room kept at each side.
	var step: float = card_step(cards.size(), size.x - room.x * 2.0, card_scale)
	# start: the left edge of the leftmost card, so the hand is centred.
	var start: float = (size.x - (step * (cards.size() - 1) + width)) / 2.0
	# middle: the index of the middle of the hand (a half for an even count).
	var middle: float = (cards.size() - 1) / 2.0
	for i: int in cards.size():
		# lean: where this card sits in the fan, -1 (leftmost) .. 1 (rightmost); 0 for one card.
		var lean: float = 0.0 if middle == 0.0 else (i - middle) / middle
		# bottom: the card's bottom edge, lower for cards further out, with room for the outermost
		# cards' lower corners once tilted.
		var bottom: float = size.y - room.y - FAN_DIP + FAN_DIP * lean * lean
		# centre: the card's horizontal centre.
		var centre: float = start + width / 2.0 + step * i
		fit_child_in_rect(cards[i], Rect2(Vector2(centre - CardView.CARD_SIZE.x / 2.0, bottom - CardView.CARD_SIZE.y), CardView.CARD_SIZE))
		# fit_child_in_rect() resets scale and rotation, so they are set after it, around the
		# card's bottom centre.
		cards[i].pivot_offset = Vector2(CardView.CARD_SIZE.x / 2.0, CardView.CARD_SIZE.y)
		cards[i].scale = Vector2.ONE * card_scale
		cards[i].rotation = deg_to_rad(FAN_DEGREES * lean)


## The hand needs room for one card at MIN_SCALE plus the fan's dip; it takes any width it is given.
func _get_minimum_size() -> Vector2:
	return Vector2(CardView.CARD_SIZE.x * MIN_SCALE, (CardView.CARD_SIZE.y + FAN_DIP + tilt_room(1.0).y) * MIN_SCALE)


## Returns the scale cards are drawn at in a hand of this height: as big as fits with the fan's dip
## and the tilted corners, at most 1 and at least MIN_SCALE.
## height: the hand's height in pixels.
static func card_scale_for(height: float) -> float:
	return clampf((height - FAN_DIP) / (CardView.CARD_SIZE.y + tilt_room(1.0).y), MIN_SCALE, 1.0)


## Returns how far the outermost cards, tilted by FAN_DEGREES around their bottom centre, reach past
## their upright box: x sideways (the top corner leaning out), y downwards (the outer bottom
## corner), in pixels.
## card_scale: the cards' scale, from card_scale_for().
static func tilt_room(card_scale: float) -> Vector2:
	# turn: sine of the outermost tilt.
	var turn: float = absf(sin(deg_to_rad(FAN_DEGREES)))
	return Vector2(CardView.CARD_SIZE.y * turn, CardView.CARD_SIZE.x / 2.0 * turn) * card_scale


## Returns the distance between neighbouring cards' left edges, in pixels: a card's width plus GAP
## when they all fit, otherwise less (they overlap) so the hand is exactly as wide as width.
## count: cards in hand, 1 or more. width: the hand's width in pixels. card_scale: card_scale_for().
static func card_step(count: int, width: float, card_scale: float) -> float:
	# card: one card's width on screen.
	var card: float = CardView.CARD_SIZE.x * card_scale
	# side_by_side: the step when nothing overlaps.
	var side_by_side: float = card + GAP * card_scale
	if count <= 1:
		return side_by_side
	return minf(side_by_side, (width - card) / (count - 1))
