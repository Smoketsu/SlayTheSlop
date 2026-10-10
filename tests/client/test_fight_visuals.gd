## Tests for the fight screen's sprites, combatant views and event animation (task 028).
## Lane: tools/client (Agent B). Each test maps to an acceptance check in
## docs/tasks/028-fight-screen-visuals.md. Every animation here runs instantly or is only started,
## never waited on, so no assertion depends on frame timing.
extends "res://tests/framework/test_case.gd"

const FightScreen := preload("res://client/fight/fight_screen.tscn")
const Sprites := preload("res://client/visual/sprites.gd")
const EventPlayer := preload("res://client/visual/event_player.gd")
const Backgrounds := preload("res://client/visual/backgrounds.gd")
const DevFight := preload("res://client/dev/dev_fight.gd")
const Core := preload("res://core/core.gd")
const Event := preload("res://core/schema/event.gd")

## Seconds used where a test starts real tweens (it never waits for them). Any value above 0.
const TIMED_SECONDS: float = 0.25


## A gateway that applies nothing and returns a fixed list of events, as in test_fight_screen.gd.
class CannedGateway extends RefCounted:
	## The events every apply() returns, in order. Set by the test.
	var events: Array = []

	## Returns the state unchanged but with state_version raised, and the canned events.
	## ruleset: unused. state: returned with state_version + 1. request: unused.
	func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
		# next: a writable copy with the version raised.
		var next: Dictionary = state.duplicate(true)
		next["state_version"] += 1
		return {"state": next, "events": events, "reject": ""}


## Every Dude and enemy in data/ gets a real texture after the import step: its own art, or the art
## its FALLBACKS entry borrows. None falls through to the generic box.
func test_every_data_id_has_a_sprite() -> void:
	# ruleset: the real content.
	var ruleset: Dictionary = DevFight.start()["ruleset"]
	# ids: every Dude and enemy id in the data.
	var ids: Array = ruleset["dudes"].keys() + ruleset["enemies"].keys()
	assert_true(ids.size() > 1, "data has Dudes and enemies")
	for id: String in ids:
		# look: how the id is drawn.
		var look: Dictionary = Sprites.look(id)
		assert_true(look["texture"] is Texture2D and look["texture"].get_width() > 0, "%s has a texture" % id)
		assert_eq(look["kind"], Sprites.BORROWED if Sprites.FALLBACKS.has(id) else Sprites.OWN, "%s art kind" % id)
	for id: String in Sprites.FALLBACKS:
		assert_eq(Sprites.look(Sprites.FALLBACKS[id]["art"])["kind"], Sprites.OWN, "%s borrows art that exists" % id)


## foam_slime borrows the Keg Slime art, smaller and tinted; an unknown or malformed id gets the
## generic box instead of crashing.
func test_fallbacks() -> void:
	# foam: how foam_slime is drawn.
	var foam: Dictionary = Sprites.look("foam_slime")
	assert_eq(foam["kind"], Sprites.BORROWED)
	assert_eq(foam["texture"], Sprites.texture_for("keg_slime"), "borrows the Keg Slime art")
	assert_true(foam["scale"] < 1.0, "drawn smaller")
	assert_ne(foam["tint"], Color.WHITE, "tinted")
	for id: String in ["no_such_enemy", "", "../project", "Keg_Slime"]:
		# look: how the bad id is drawn.
		var look: Dictionary = Sprites.look(id)
		assert_eq(look["kind"], Sprites.GENERIC, "'%s' uses the generic box" % id)
		assert_eq(look["texture"], Sprites.generic_texture())
	assert_eq(Sprites.art_path("../project"), "", "no path outside the art folder")
	assert_true(Sprites.generic_texture().get_width() == Sprites.GENERIC_SIZE)


## After the fight starts every Dude and enemy has a view with its sprite, HP and Guard from state;
## a hit on an enemy lowers its HP bar to the state's HP.
func test_views_show_every_combatant_and_update() -> void:
	# screen: the real fight.
	var screen: Control = _screen()
	_assert_views_match(screen)
	# first: the leftmost enemy. before: its HP.
	var first: String = screen._state["combat"]["enemies"][0]["uid"]
	var before: int = screen._state["combat"]["enemies"][0]["hp"]
	screen.press_card(_damage_card(screen))
	screen.press_enemy(first)
	assert_eq(screen._state["state_version"], 1, "the card went through")
	# after: the enemy in the new state.
	var after: Dictionary = _enemy(screen, first)
	assert_true(after.is_empty() or after["hp"] < before, "the card hit the enemy")
	if not after.is_empty():
		assert_eq(screen._views[first].hp_value, after["hp"], "HP bar follows the state")
	_assert_views_match(screen)
	_free(screen)


## Clicking an enemy's view targets it, like the old enemy button did.
func test_clicking_an_enemy_view_targets_it() -> void:
	# screen: the real fight.
	var screen: Control = _screen()
	screen.press_card(_card_with_target(screen, "enemy"))
	assert_eq(screen._state["state_version"], 0, "waiting for a target")
	screen._views[screen._state["combat"]["enemies"][0]["uid"]].pressed.emit()
	assert_eq(screen._state["state_version"], 1, "the click picked the target")
	_free(screen)


## effect_for() turns each event into the right animation kind; every event type maps to a kind in
## KINDS.
func test_events_map_to_animation_kinds() -> void:
	# cases: event -> expected kind.
	var cases: Array = [
		[Event.make("damage_dealt", {"source_id": "p1", "target_id": "e1", "amount": 6, "blocked": 1, "hp_lost": 5}), "damage"],
		[Event.make("damage_dealt", {"source_id": "p1", "target_id": "e1", "amount": 4, "blocked": 4, "hp_lost": 0}), "blocked"],
		[Event.make("guard_changed", {"target_id": "p1", "delta": 5, "guard": 5}), "guard"],
		[Event.make("healed", {"target_id": "p1", "amount": 3, "hp": 60}), "heal"],
		[Event.make("enemy_died", {"enemy_uid": "e1"}), "death"],
		[Event.make("enemy_fled", {"enemy_uid": "e1"}), "leave"],
		[Event.make("dude_passed_out", {"player_id": "p1"}), "passed_out"],
		[Event.make("card_played", {"player_id": "p1", "card_uid": "c1", "target_id": "e1"}), "log"],
	]
	for case: Array in cases:
		assert_eq(EventPlayer.effect_for(case[0])["kind"], case[1], case[0]["type"])
	assert_eq(EventPlayer.effect_for(cases[2][0])["value"], 5, "Guard's new value")
	for type: String in Event.TYPES:
		assert_true(EventPlayer.KINDS.has(EventPlayer.effect_for(_event(type, "p1", "e1"))["kind"]), type)


## Every event type in Event.TYPES plays through the screen in instant mode without error, in
## event order, aimed once at an enemy and once at the Dude; afterwards every view is redrawn from
## the returned state (the fade of enemy_died and the grey of dude_passed_out are gone).
func test_every_event_type_plays_instantly() -> void:
	# gateway: returns one event of every type, twice.
	var gateway := CannedGateway.new()
	# screen: the real fight on the canned gateway.
	var screen: Control = _screen(DevFight.start(), gateway)
	# player_id, enemy_uid: real ids in the fight, so the events reach views.
	var player_id: String = screen._player_id
	var enemy_uid: String = screen._state["combat"]["enemies"][0]["uid"]
	for target: String in [enemy_uid, player_id]:
		for type: String in Event.TYPES:
			# event: one event of this type.
			var event: Dictionary = _event(type, player_id, target)
			assert_no_errors(Event.check(event), type)
			gateway.events.append(event)
	screen.press_ready()
	assert_eq(screen.animation_log.size(), gateway.events.size(), "every event played")
	assert_eq(screen._player.played.size(), gateway.events.size(), "every event reached the player")
	for i: int in gateway.events.size():
		assert_true(screen.animation_log[i].begins_with(gateway.events[i]["type"] + " "), "event %d in order" % i)
	assert_eq(screen._state["state_version"], 1, "redrawn from the returned state")
	assert_eq(screen._views[enemy_uid].modulate.a, 1.0, "the redraw shows the enemy alive again, as the state says")
	assert_eq(screen.event_lines.size(), gateway.events.size(), "every event logged")
	_free(screen)


## With a real animation length, play_one() starts tweens and returns how long they run, without the
## test waiting: animated events take TIMED_SECONDS, log-only events, Guard losses and events aimed
## at an id with no view take 0. Starting an animation moves only the view, never the state.
func test_timed_animations_report_their_length() -> void:
	# screen: the real fight.
	var screen: Control = _screen()
	# frozen: a copy of the state to compare with afterwards.
	var frozen: Dictionary = screen._state.duplicate(true)
	# player: a timed player on the screen's views.
	var player := EventPlayer.new()
	player.seconds = TIMED_SECONDS
	# enemy_uid: the leftmost enemy. view: its view. hp: its HP before.
	var enemy_uid: String = screen._state["combat"]["enemies"][0]["uid"]
	var view: Button = screen._views[enemy_uid]
	var hp: int = view.hp_value
	assert_eq(player.play_one(Event.make("damage_dealt", {"source_id": screen._player_id, "target_id": enemy_uid, "amount": 3, "blocked": 0, "hp_lost": 3}), screen._views), TIMED_SECONDS)
	assert_eq(view.hp_value, hp - 3, "the bar drops at once")
	assert_eq(player.play_one(Event.make("guard_changed", {"target_id": screen._player_id, "delta": 4, "guard": 4}), screen._views), TIMED_SECONDS)
	assert_eq(player.play_one(Event.make("guard_changed", {"target_id": screen._player_id, "delta": -4, "guard": 0}), screen._views), 0.0)
	assert_eq(player.play_one(Event.make("dude_passed_out", {"player_id": screen._player_id}), screen._views), TIMED_SECONDS)
	assert_eq(player.play_one(Event.make("enemy_died", {"enemy_uid": enemy_uid}), screen._views), TIMED_SECONDS)
	assert_eq(player.play_one(Event.make("enemy_died", {"enemy_uid": "e999"}), screen._views), 0.0, "no view, no wait")
	assert_eq(player.play_one(Event.make("turn_started", {"turn": 2}), screen._views), 0.0, "log only")
	assert_eq(screen._state, frozen, "animating never changed the state")
	_free(screen)


## The dev fight (two goblins on floor 1) is drawn in the Basement, and the screen shows that room.
func test_default_fight_uses_the_basement() -> void:
	# started: the dev fight.
	var started: Dictionary = DevFight.start()
	assert_eq(Backgrounds.room_for(started["state"]), Backgrounds.DEFAULT_ROOM)
	assert_eq(Backgrounds.DEFAULT_ROOM, "basement")
	assert_true(Backgrounds.texture_for_room("basement") is Texture2D, "the Basement has a file")
	# screen: the dev fight on screen.
	var screen: Control = _screen(started)
	assert_eq(screen.room, "basement")
	assert_eq(screen._background.texture, Backgrounds.texture_for_room("basement"), "the room is drawn")
	_free(screen)


## A fight with an enemy that has its own room (a boss) is drawn in that room, wherever it stands.
func test_boss_fight_uses_the_boss_room() -> void:
	# state: the dev fight with its right-hand enemy swapped for the boss (a test copy only).
	var state: Dictionary = DevFight.start()["state"].duplicate(true)
	state["combat"]["enemies"][1]["def_id"] = "goblin_king_chad"
	assert_eq(Backgrounds.room_for(state), "goblin_king_chad")
	assert_true(Backgrounds.texture_for_room("goblin_king_chad") is Texture2D, "the boss room has a file")


## A room or floor with no file falls back without an error: no texture (the screen shows the
## plain colour), an unknown floor uses the default room, and no fight at all is fine.
func test_missing_rooms_fall_back() -> void:
	for name: String in ["no_such_room", "", "../project", "Basement"]:
		assert_true(Backgrounds.texture_for_room(name) == null, "'%s' has no texture" % name)
	assert_eq(Backgrounds.room_path("../project"), "", "no path outside the backgrounds folder")
	assert_eq(Backgrounds.room_for({"floor": 99, "combat": null}), Backgrounds.DEFAULT_ROOM, "unknown floor")
	assert_eq(Backgrounds.room_for({}), Backgrounds.FLOOR_ROOMS[1], "no floor, no fight")
	# screen: the dev fight, then pointed at a room with no file and redrawn.
	var screen: Control = _screen()
	screen.room = "no_such_room"
	screen._redraw()
	assert_true(screen._background.texture == null, "no picture")
	assert_eq(screen._backdrop.color, Backgrounds.FALLBACK_COLOR, "the plain colour shows instead")
	_free(screen)


## Returns an event of a type with every field filled: player_id fields get player_id; target_id,
## source_id and enemy_uid get target; other strings "x", ints 3, bools true, lists [].
## type: an Event.TYPES key. player_id: a Dude. target: the id hits and changes land on.
func _event(type: String, player_id: String, target: String) -> Dictionary:
	# fields: the filled fields.
	var fields: Dictionary = {}
	for key: String in Event.TYPES[type]:
		# spec: the field's type.
		var spec: Variant = Event.TYPES[type][key]
		if typeof(spec) == TYPE_DICTIONARY:
			fields[key] = []
		elif spec == TYPE_INT:
			fields[key] = 3
		elif spec == TYPE_BOOL:
			fields[key] = true
		elif key == "player_id":
			fields[key] = player_id
		elif key in ["target_id", "source_id", "enemy_uid"]:
			fields[key] = target
		else:
			fields[key] = "x"
	return Event.make(type, fields)


## Checks that the screen has exactly one view per Dude and enemy in its state, each showing that
## combatant's sprite, HP and Guard.
## screen: a screen from _screen().
func _assert_views_match(screen: Control) -> void:
	# expected: id -> [def_id, hp, guard] for every combatant in the state.
	var expected: Dictionary = {}
	for dude: Dictionary in screen._state["dudes"]:
		expected[dude["player_id"]] = [dude["dude_id"], dude["hp"], dude["guard"]]
	for enemy: Dictionary in screen._state["combat"]["enemies"]:
		expected[enemy["uid"]] = [enemy["def_id"], enemy["hp"], enemy["guard"]]
	assert_eq(screen._views.size(), expected.size(), "one view per combatant")
	for id: String in expected:
		assert_true(screen._views.has(id), "%s has a view" % id)
		if not screen._views.has(id):
			continue
		# view: its view.
		var view: Button = screen._views[id]
		assert_eq(view.texture(), Sprites.texture_for(expected[id][0]), "%s sprite" % id)
		assert_eq(view.hp_value, expected[id][1], "%s HP" % id)
		assert_eq(view.guard_value, expected[id][2], "%s Guard" % id)


## Returns the enemy with this uid in the screen's state, or {} when it is gone.
## screen: a screen from _screen(). uid: the enemy.
func _enemy(screen: Control, uid: String) -> Dictionary:
	for enemy: Dictionary in screen._state["combat"]["enemies"]:
		if enemy["uid"] == uid:
			return enemy
	return {}


## Returns a fight screen in the tree with no animation time, on a started fight.
## started: a DevFight.start() result; a fresh one when empty. gateway: what requests go to; the
##   real core when null.
func _screen(started: Dictionary = {}, gateway: Object = null) -> Control:
	if started.is_empty():
		started = DevFight.start()
	# screen: the new screen.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.setup(gateway if gateway != null else Core.new(), started["ruleset"], started["state"], started["player_id"])
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


## Returns the uid of the first card in the local hand whose definition has this target, or "".
## screen: a screen from _screen(). target: a card_def TARGETS value.
func _card_with_target(screen: Control, target: String) -> String:
	# dude: the local Dude.
	var dude: Dictionary = screen._state["dudes"][0]
	for uid: String in dude["hand"]:
		if screen._ruleset["cards"][dude["cards"][uid]["def_id"]]["target"] == target:
			return uid
	fail("no card targeting %s in hand" % target)
	return ""


## Returns the uid of the first card in the local hand that targets an enemy and deals damage
## (has a "damage" effect), or "".
## screen: a screen from _screen().
func _damage_card(screen: Control) -> String:
	# dude: the local Dude.
	var dude: Dictionary = screen._state["dudes"][0]
	for uid: String in dude["hand"]:
		# card: the card's definition.
		var card: Dictionary = screen._ruleset["cards"][dude["cards"][uid]["def_id"]]
		if card["target"] == "enemy" and card["effects"].any(func(effect: Dictionary) -> bool: return effect["op"] == "damage"):
			return uid
	fail("no damage card in hand")
	return ""


## Removes a screen from the tree and frees it now.
## screen: a screen from _screen().
func _free(screen: Control) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()
