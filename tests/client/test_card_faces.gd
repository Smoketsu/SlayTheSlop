## Tests for the card faces in the hand (task 041). Lane: tools/client (Agent B).
##
## Each test maps to an acceptance check in docs/tasks/041-card-faces-in-hand.md. Faces are built
## from definitions in the real data (picked by their fields, not by id) and checked against those
## same definitions; dimming is checked against what the real core does when the card is pressed.
## Fights run on the real core and the real data, and the screen's state is frozen read-only before
## the hover test, so any client write to game state fails it.
extends "res://tests/framework/test_case.gd"

const FightScreen := preload("res://client/fight/fight_screen.tscn")
const CardView := preload("res://client/visual/card_view.gd")
const HandView := preload("res://client/visual/hand_view.gd")
const Messages := preload("res://client/fight/messages.gd")
const RunText := preload("res://client/run/run_text.gd")
const DevFight := preload("res://client/dev/dev_fight.gd")
const Core := preload("res://core/core.gd")
const Upgrades := preload("res://core/combat/upgrades.gd")
const Grants := preload("res://core/run/grants.gd")
const CardDef := preload("res://core/schema/card_def.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Documentation := preload("res://tests/core/test_documentation.gd")

## Cards in a full hand, as task 041 "Notes" sizes it (the GDD sets no hand limit yet). Used to
## build the full-hand tests.
const FULL_HAND: int = 10
## The window size the full hand must fit (task 041 "Notes"), in pixels.
const WINDOW := Vector2(1280, 720)
## Hype the dimming tests give the Dude, so cards costing more than this are refused by the core.
const LOW_HYPE: int = 1
## The new client scripts of task 041 whose documentation the doc test checks.
const NEW_SCRIPTS: Array[String] = ["res://client/visual/card_view.gd", "res://client/visual/hand_view.gd"]
## Client scripts task 041 changed, also checked by the doc test (their older code included).
const CHANGED_SCRIPTS: Array[String] = ["res://client/fight/fight_screen.gd", "res://client/fight/messages.gd", "res://client/fight/request_maker.gd"]


## A gateway that counts requests and passes them to the real core, to prove hovering sends none.
class CountingGateway extends RefCounted:
	## Requests received so far, 0 or more. Only grows.
	var count: int = 0

	## Counts the request, then applies it with the real core.
	## ruleset: read-only content. state: the current state. request: the request sent.
	func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
		count += 1
		return Core.apply(ruleset, state, request)


## A common card's face shows its name, cost, type, rarity and rules text, all from its definition.
func test_common_card_face() -> void:
	# card: the first common card in the data, by id.
	var card: Dictionary = _first_card(func(c: Dictionary) -> bool: return c["rarity"] == "common" and typeof(c["cost"]) == TYPE_INT and c["cost"] >= 0)
	if card.is_empty():
		return
	# view: its face.
	var view: Button = _face(card, false, true)
	assert_eq(view.shown_name, card["name"], "name")
	assert_eq(view.shown_cost, str(card["cost"]), "cost is the number")
	assert_eq(view.shown_kind, Messages.card_type_name(card["type"]) + CardView.KIND_JOIN + Messages.rarity_name("common"), "type and rarity")
	assert_eq(view.shown_text, card["text"], "rules text")
	assert_eq(view.drawn_text(), "\n".join([view.shown_cost, card["name"], view.shown_kind, card["text"]]), "drawn text, top to bottom")
	assert_eq(view.modulate, Color.WHITE, "a playable card is not dimmed")
	view.free()


## An upgraded copy's face shows the upgraded name mark and the upgraded definition's cost and text,
## on its own and in the fight screen's hand after the core's Lift.
func test_upgraded_card_face() -> void:
	# card: the first card in the data that can be upgraded and whose upgrade changes its text.
	var card: Dictionary = _first_card(func(c: Dictionary) -> bool: return Upgrades.can_upgrade(c) and Upgrades.upgraded(c)["definition"].get("text", "") != c.get("text", ""))
	if card.is_empty():
		return
	# lifted: its upgraded definition, from the core.
	var lifted: Dictionary = Upgrades.upgraded(card)["definition"]
	# view: the face of a Lifted copy.
	var view: Button = _face(lifted, true, true)
	assert_eq(view.shown_name, lifted["name"] + RunText.UPGRADED_MARK, "name has the upgrade mark")
	assert_eq(view.shown_cost, RunText.card_cost(lifted), "cost of the upgraded definition")
	assert_eq(view.shown_text, lifted["text"], "text of the upgraded definition")
	assert_ne(view.shown_text, card["text"], "not the base text")
	assert_true(view.drawn_text().contains(lifted["name"] + RunText.UPGRADED_MARK), view.drawn_text())
	view.free()
	# started: the real fight with a new copy of the card Lifted by the core and put in hand.
	var started: Dictionary = DevFight.start()
	# uid: the new copy.
	var uid: String = _give(started["state"], card["id"])
	Grants.upgrade_card_in_place(started["state"], 0, uid, [])
	assert_no_errors(RunState.check(started["state"]), "state after Lift")
	# screen: the fight screen on it.
	var screen: Control = _screen(started)
	# face: the copy's face in the hand.
	var face: Button = _face_of(screen, uid)
	assert_eq(face.shown_name, lifted["name"] + RunText.UPGRADED_MARK, "the hand shows the Lifted copy")
	assert_eq(face.shown_text, lifted["text"])
	assert_true(face.upgraded)
	_free(screen)


## A Junk card's face shows its type, rarity and text, and "-" instead of a cost when it is
## unplayable; an X-cost card shows "X". A copy with no usable definition shows its fallback name.
func test_junk_and_special_costs() -> void:
	# junk: the first unplayable Junk card in the data.
	var junk: Dictionary = _first_card(func(c: Dictionary) -> bool: return c["type"] == "junk" and typeof(c["cost"]) == TYPE_INT and c["cost"] < 0)
	if junk.is_empty():
		return
	# view: its face.
	var view: Button = _face(junk, false, false)
	assert_eq(view.shown_cost, "-", "unplayable shows no number")
	assert_eq(view.shown_kind, Messages.card_type_name("junk") + CardView.KIND_JOIN + Messages.rarity_name(junk["rarity"]))
	assert_true(view.shown_kind.begins_with("Junk"), view.shown_kind)
	assert_eq(view.shown_text, junk["text"])
	assert_eq(view.modulate, CardView.DIM_COLOR, "dimmed")
	assert_eq(view.drawn_text(), "\n".join(["-", junk["name"], view.shown_kind, junk["text"]]))
	view.free()
	# x_card: an in-memory X-cost card (no X-cost card is in data/ yet). Not a real content id.
	var x_card: Dictionary = junk.duplicate(true)
	x_card["cost"] = "x"
	x_card["type"] = "attack"
	view = _face(x_card, false, true)
	assert_eq(view.shown_cost, "X", "X cost")
	view.free()
	view = _face({}, true, false, "lost_card+")
	assert_eq(view.drawn_text(), "-\nlost_card+", "no definition: fallback name and no number")
	view.free()


## Every card type and rarity in the schema has a face label.
func test_every_type_and_rarity_has_a_label() -> void:
	for type: String in CardDef.TYPES:
		assert_true(Messages.CARD_TYPES.has(type), "no card face label for type %s" % type)
		assert_true(CardView.TYPE_COLORS.has(type), "no frame colour for type %s" % type)
	for rarity: String in CardDef.RARITIES:
		assert_true(Messages.CARD_RARITIES.has(rarity), "no card face label for rarity %s" % rarity)
		assert_true(CardView.RARITY_COLORS.has(rarity), "no colour for rarity %s" % rarity)


## A card is dimmed exactly when the core refuses it: on a full hand with little Hype, each card
## pressed on a fresh screen (with an enemy picked when it asks for one) is applied by the core if
## and only if its face was not dimmed. Some cards are dimmed and some are not, so both cases run.
func test_dimmed_exactly_when_the_core_refuses() -> void:
	# started: the reference fight, to read the hand from.
	var started: Dictionary = _full_hand_fight()
	# hand: the copies in hand.
	var hand: Array = started["state"]["dudes"][0]["hand"].duplicate()
	# dimmed: how many faces were dimmed.
	var dimmed: int = 0
	for uid: String in hand:
		# screen: a fresh screen on the same fight.
		var screen: Control = _screen(_full_hand_fight())
		# face: this copy's face.
		var face: Button = _face_of(screen, uid)
		if not face.playable:
			dimmed += 1
		assert_eq(face.modulate, Color.WHITE if face.playable else CardView.DIM_COLOR, "%s looks as playable as it is" % uid)
		screen.press_card(uid)
		if screen._pending_card != "":
			screen.press_enemy(screen._state["combat"]["enemies"][0]["uid"])
		assert_eq(screen._state["state_version"] == 1, face.playable, "%s (%s): the core %s it" % [uid, face.shown_name, "applied" if screen._state["state_version"] == 1 else "refused"])
		_free(screen)
	assert_true(dimmed > 0 and dimmed < hand.size(), "some cards dimmed (%d of %d)" % [dimmed, hand.size()])


## Out of the player phase the core refuses every card, so every face is dimmed.
func test_every_card_dimmed_when_not_your_turn() -> void:
	# started: the real fight, set to its enemy phase (test setup on a fresh state).
	var started: Dictionary = DevFight.start()
	started["state"]["combat"]["phase"] = "enemy"
	# screen: the fight screen on it.
	var screen: Control = _screen(started)
	assert_true(screen._hand_box.get_child_count() > 0, "the hand is drawn")
	for face: Node in screen._hand_box.get_children():
		assert_false(face.playable, "%s dimmed" % face.shown_name)
	_free(screen)


## Hovering lifts and enlarges a face and leaving puts it back; it never sends a request or changes
## the state (frozen read-only, so a write would fail the test). A fight then still plays by presses.
func test_hover_never_changes_state() -> void:
	# gateway: counts requests.
	var gateway := CountingGateway.new()
	# screen: the full-hand fight.
	var screen: Control = _screen(_full_hand_fight(), gateway)
	_freeze(screen._state)
	# before: a copy of the state, to compare after hovering.
	var before: Dictionary = screen._state.duplicate(true)
	for face: Node in screen._hand_box.get_children():
		# rest: the face's scale on screen before the hover.
		var rest: float = face.face_scale()
		face.mouse_entered.emit()
		assert_true(face.hovered, "%s hovered" % face.shown_name)
		assert_almost(face.face_scale(), CardView.HOVER_SCALE, "%s grows to HOVER_SCALE" % face.shown_name)
		assert_true(face.z_index > 0, "a hovered card is drawn over its neighbours")
		face.mouse_exited.emit()
		assert_false(face.hovered)
		assert_almost(face.face_scale(), rest, "%s back to rest" % face.shown_name)
		assert_eq(face.z_index, 0)
	assert_eq(gateway.count, 0, "hovering sent nothing")
	assert_eq(strict_diff(screen._state, before, "state"), "", "state unchanged")
	# A press still plays: the first card the core accepts.
	for face: Node in screen._hand_box.get_children():
		if face.playable:
			# uid: that card's copy.
			var uid: String = _uid_of(screen, face)
			screen.press_card(uid)
			if screen._pending_card != "":
				screen.press_enemy(screen._state["combat"]["enemies"][0]["uid"])
			break
	assert_eq(gateway.count, 1, "the press sent one request")
	assert_eq(screen._state["state_version"], 1, "and the core applied it")
	_free(screen)


## A full hand of 10 at 1280x720 stays inside the window, below the Dudes and enemies, without
## covering them; the cards overlap or sit side by side, left to right, never wider than the hand.
func test_full_hand_fits_1280x720() -> void:
	# frame: a 1280x720 stand-in for the window.
	var frame := Control.new()
	frame.size = WINDOW
	(Engine.get_main_loop() as SceneTree).root.add_child(frame)
	# screen: the full-hand fight inside it.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	# started: the fight.
	var started: Dictionary = _full_hand_fight()
	screen.setup(Core.new(), started["ruleset"], started["state"], started["player_id"])
	frame.add_child(screen)
	_layout(screen)
	assert_eq(screen.size, WINDOW, "the screen fills the window")
	# cards: the faces, left to right.
	var cards: Array[Node] = screen._hand_box.get_children()
	assert_eq(cards.size(), FULL_HAND, "a full hand")
	# others: the bottom of the lowest Dude or enemy view.
	var others: float = 0.0
	for view: Node in screen._views.values():
		others = maxf(others, (view as Control).get_global_rect().end.y)
	assert_true(others > 0.0, "the Dudes and enemies are laid out")
	# last_left: the previous card's left edge, to check the order.
	var last_left: float = -INF
	for card: Node in cards:
		# box: the card's corners on screen, after its scale and tilt.
		var box: Rect2 = _screen_box(card)
		assert_true(box.position.x >= 0.0 and box.end.x <= WINDOW.x, "%s inside the window sideways: %s" % [card.shown_name, box])
		assert_true(box.end.y <= WINDOW.y, "%s inside the window's bottom: %s" % [card.shown_name, box])
		assert_true(box.position.y >= others, "%s below the Dudes and enemies (%s, they end at %s)" % [card.shown_name, box, others])
		assert_true(box.position.x > last_left, "left to right")
		last_left = box.position.x
	frame.get_parent().remove_child(frame)
	frame.free()


## The hand's spacing: side by side with a gap when the cards fit, evenly overlapped to the exact
## width when they do not.
func test_hand_spacing() -> void:
	# width: one full-size card's width.
	var width: float = CardView.CARD_SIZE.x
	assert_almost(HandView.card_step(3, 1000.0, 1.0), width + HandView.GAP, "three cards fit side by side")
	# step: the step for a full hand in a narrow hand.
	var step: float = HandView.card_step(FULL_HAND, 800.0, 1.0)
	assert_true(step < width, "a full hand in 800 px overlaps")
	assert_almost(step * (FULL_HAND - 1) + width, 800.0, "and is exactly as wide as the hand")
	assert_almost(HandView.card_scale_for(10000.0), 1.0, "never bigger than full size")
	assert_almost(HandView.card_scale_for(1.0), HandView.MIN_SCALE, "never smaller than MIN_SCALE")


## The card face names no card: no content id from the data appears in its code or the hand's.
func test_card_face_names_no_card() -> void:
	# ids: every card id in the data.
	var ids: Array = DevFight.start()["ruleset"]["cards"].keys()
	for path: String in NEW_SCRIPTS:
		# source: the script's text.
		var source: String = FileAccess.get_file_as_string(path)
		for id: String in ids:
			assert_false(source.contains(id), "%s names the card %s" % [path, id])


## The new scripts follow the documentation standard (CLAUDE.md), checked with Agent A's lint.
func test_new_scripts_are_documented() -> void:
	for path: String in NEW_SCRIPTS + CHANGED_SCRIPTS:
		for problem: String in Documentation.lint(FileAccess.get_file_as_string(path)):
			fail("%s:%s" % [path, problem])


## Returns a card face built from a definition, not in the tree. The caller frees it.
## definition: the effective definition. upgraded: the copy is Lifted. playable: the core's answer.
## fallback_name: the name for an empty definition.
func _face(definition: Dictionary, upgraded: bool, playable: bool, fallback_name: String = "") -> Button:
	# view: the face.
	var view: Button = CardView.new()
	view.hover_seconds = 0.0
	view.render(definition, upgraded, playable, fallback_name)
	return view


## Returns the first card definition in the data, by id, that passes a filter; fails when none does.
## keep: takes a definition, returns true to pick it.
func _first_card(keep: Callable) -> Dictionary:
	# cards: every card definition.
	var cards: Dictionary = DevFight.start()["ruleset"]["cards"]
	# ids: their ids, sorted.
	var ids: Array = cards.keys()
	ids.sort()
	for id: String in ids:
		if keep.call(cards[id]):
			return cards[id]
	fail("no card in data/ fits the test")
	return {}


## Returns the real fight with a full hand: every card of the draw pile moved to the hand up to
## FULL_HAND - 1, plus one copy of the first unplayable Junk card, and LOW_HYPE Hype. Test setup on a
## fresh state; the core's own builders made everything else.
func _full_hand_fight() -> Dictionary:
	# started: the real fight. dude: its Dude.
	var started: Dictionary = DevFight.start()
	var dude: Dictionary = started["state"]["dudes"][0]
	while dude["hand"].size() < FULL_HAND - 1 and not dude["draw_pile"].is_empty():
		dude["hand"].append(dude["draw_pile"].pop_front())
	# junk: the first unplayable Junk card.
	var junk: Dictionary = _first_card(func(c: Dictionary) -> bool: return c["type"] == "junk" and typeof(c["cost"]) == TYPE_INT and c["cost"] < 0)
	_give(started["state"], junk["id"])
	dude["hype"] = LOW_HYPE
	assert_no_errors(RunState.check(started["state"]), "full-hand state")
	return started


## Puts a new, not upgraded copy of a card in the first Dude's deck and hand (test setup on a fresh
## state) and returns its card_uid. state: a fight. def_id: a card id in the ruleset.
func _give(state: Dictionary, def_id: String) -> String:
	# uid: the new copy's card_uid, from the state's uid counter.
	var uid: String = "c%d" % state["next_uid"]
	state["next_uid"] += 1
	state["dudes"][0]["cards"][uid] = {"def_id": def_id, "upgraded": false}
	state["dudes"][0]["hand"].append(uid)
	state["dudes"][0]["deck"].append(uid)
	return uid


## Returns the face of a card copy in a screen's hand, or null (and fails) when it is not there. The
## hand is drawn in the order of the Dude's hand.
## screen: from _screen(). uid: a card copy in hand.
func _face_of(screen: Control, uid: String) -> Button:
	# index: the copy's place in the hand.
	var index: int = screen._state["dudes"][0]["hand"].find(uid)
	if index == -1 or index >= screen._hand_box.get_child_count():
		fail("%s has no face in the hand" % uid)
		return null
	return screen._hand_box.get_child(index)


## Returns the card_uid a face in a screen's hand shows (the hand is drawn in hand order).
## screen: from _screen(). face: one of its hand's faces.
func _uid_of(screen: Control, face: Node) -> String:
	return screen._state["dudes"][0]["hand"][face.get_index()]


## Returns a fight screen in the tree with no animation time.
## started: a DevFight.start()-shaped result. gateway: what requests go to; the real core when null.
func _screen(started: Dictionary, gateway: Object = null) -> Control:
	# screen: the new screen.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.setup(gateway if gateway != null else Core.new(), started["ruleset"], started["state"], started["player_id"])
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


## Removes a screen from the tree and frees it now.
## screen: a screen from _screen().
func _free(screen: Control) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()


## Lays out every container under node now, top down, as the next frame would (tests cannot wait
## for a frame). Two passes, so sizes found in the first settle in the second.
## node: where to start.
func _layout(node: Node) -> void:
	for pass_number: int in 2:
		_sort(node)


## Sends NOTIFICATION_SORT_CHILDREN to node if it is a container, then to everything under it.
## node: where to start.
func _sort(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child: Node in node.get_children():
		_sort(child)


## Returns the smallest upright rectangle holding a control's four corners on screen, after its
## scale and rotation.
## control: a laid-out control.
func _screen_box(control: Control) -> Rect2:
	# transform: the control's transform to the screen.
	var transform: Transform2D = control.get_global_transform()
	# box: grown corner by corner.
	var box := Rect2(transform * Vector2.ZERO, Vector2.ZERO)
	for corner: Vector2 in [Vector2(control.size.x, 0), Vector2(0, control.size.y), control.size]:
		box = box.expand(transform * corner)
	return box


## Fails unless two floats are within a hundredth of each other.
## actual: the value found. expected: the value wanted. message: shown on failure.
func assert_almost(actual: float, expected: float, message: String = "") -> void:
	assert_true(absf(actual - expected) < 0.01, "%s: expected %s, got %s" % [message, expected, actual])


## Makes value read-only at every level (make_read_only() alone is shallow).
## value: a Dictionary or Array from a state.
func _freeze(value: Variant) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key: Variant in value:
			_freeze(value[key])
		value.make_read_only()
	elif typeof(value) == TYPE_ARRAY:
		for item: Variant in value:
			_freeze(item)
		value.make_read_only()
