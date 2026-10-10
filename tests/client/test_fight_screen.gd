## Tests for the fight screen on the real core and the real data (tasks 018 and 024).
## Lane: tools/client (Agent B). Each test maps to an acceptance check in docs/tasks/018-*.md or
## docs/tasks/024-*.md.
extends "res://tests/framework/test_case.gd"

const FightScreen := preload("res://client/fight/fight_screen.tscn")
const FightModel := preload("res://client/fight/fight_model.gd")
const Targeting := preload("res://client/fight/targeting.gd")
const RequestMaker := preload("res://client/fight/request_maker.gd")
const Messages := preload("res://client/fight/messages.gd")
const EventText := preload("res://client/fight/event_text.gd")
const DevFight := preload("res://client/dev/dev_fight.gd")
const Core := preload("res://core/core.gd")
const Request := preload("res://core/schema/request.gd")
const Event := preload("res://core/schema/event.gd")
const RunState := preload("res://core/schema/run_state.gd")

## File types under client/ that are code or text, not assets needing a source in ASSETS.md.
const NOT_ASSETS: Array[String] = ["gd", "tscn", "md", "uid", "import"]
## Most presses the full-fight test may make before giving up (a safety stop, not a rule).
const MAX_PRESSES: int = 400


## A gateway that applies nothing and returns a fixed list of events, for animation-order tests.
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


## The placeholder fight starts on the real data, in turn 1's player phase, as a valid state.
func test_dev_fight_starts_on_real_data() -> void:
	# started: DevFight.start()'s result.
	var started: Dictionary = DevFight.start()
	assert_eq(started["error"], "", "dev fight starts")
	if started["error"] != "":
		return
	assert_no_errors(RunState.check(started["state"]), "dev fight state")
	assert_eq(started["state"]["combat"]["phase"], "player")
	assert_eq(started["state"]["combat"]["enemies"].size(), DevFight.FOES.size())


## The model shows every value task 018 lists, from the state alone, with names from the data.
func test_model_shows_everything_from_state() -> void:
	# started: the real fight. model: its display model.
	var started: Dictionary = DevFight.start()
	var model: Dictionary = FightModel.build(started["ruleset"], started["state"], started["player_id"])
	# dude: the one Dude. dude_def: its definition.
	var dude: Dictionary = model["dudes"][0]
	var dude_def: Dictionary = started["ruleset"]["dudes"][started["state"]["dudes"][0]["dude_id"]]
	assert_eq(dude["name"], dude_def["name"], "name comes from data")
	assert_eq(dude["hp"], "%d / %d" % [dude_def["max_hp"], dude_def["max_hp"]])
	assert_eq(model["hand"].size(), started["state"]["dudes"][0]["hand"].size(), "hand")
	assert_eq(model["bro_meter"], "0 / %d" % started["ruleset"]["constants"]["BRO_METER_MAX"])
	for i: int in DevFight.FOES.size():
		# enemy: one enemy as shown.
		var enemy: Dictionary = model["enemies"][i]
		assert_eq(enemy["name"], started["ruleset"]["enemies"][DevFight.FOES[i]]["name"])
		assert_true(enemy["arms"].ends_with("arms broken") or enemy["arms"] == "No arms", enemy["arms"])
		assert_true(enemy["ick"].begins_with("0 / "), enemy["ick"])


## Requests pass request.gd check(), carry the player, and seq rises by 1 each time, even across a
## rejected request (the real core leaves last_seq unchanged on a reject).
func test_requests_are_well_formed_and_seq_rises() -> void:
	# maker: starts after a Dude whose last_seq is 4.
	var maker := RequestMaker.new("p2", 4)
	# made: one of each request type, Bro Move with and without a target.
	var made: Array = [maker.play_card("c1", "e3"), maker.set_ready(true), maker.use_brew(0, ""), maker.use_bro_move(), maker.use_bro_move("e3")]
	for i: int in made.size():
		assert_no_errors(Request.check(made[i]), "request %d" % i)
		assert_eq(made[i]["player_id"], "p2")
		assert_eq(made[i]["seq"], 5 + i, "seq of request %d" % i)
	assert_false(made[3].has("target_id"), "no target_id when none is given")
	assert_eq(made[4]["target_id"], "e3")
	# screen: the real fight; aim an enemy card at an enemy that does not exist, then a real one.
	var screen: Control = _screen()
	# uid: the first card in hand that targets an enemy. first: the leftmost enemy.
	var uid: String = _card_with_target(screen, "enemy")
	var first: String = screen._state["combat"]["enemies"][0]["uid"]
	screen.press_card(uid)
	screen.press_enemy("e999")
	assert_eq(screen.message, Messages.reject("bad_target"), "unknown target rejected")
	assert_eq(screen._pending_card, uid, "bad_target asks for a new target")
	screen.press_enemy(first)
	assert_eq(screen._state["dudes"][0]["last_seq"], 1, "seq 0 rejected, seq 1 applied")
	_free(screen)


## Targeting follows the card's target; Assist targets yourself in solo and asks in co-op.
func test_targeting() -> void:
	# cards: the real card definitions.
	var cards: Dictionary = DevFight.start()["ruleset"]["cards"]
	for card: Dictionary in cards.values():
		# expected: what the card should ask for in solo.
		var expected: String = Targeting.ENEMY if card["target"] == "enemy" else Targeting.NONE
		assert_eq(Targeting.mode(card, 1), expected, card["id"])
	# ally: an Assist card (none exists in the data yet; built inline).
	var ally: Dictionary = {"id": "x", "target": "ally"}
	assert_eq(Targeting.mode(ally, 1), Targeting.NONE, "Assist in solo asks nothing")
	assert_eq(Targeting.auto_target(ally, "p1", 1), "p1", "Assist in solo targets the player")
	assert_eq(Targeting.mode(ally, 2), Targeting.DUDE, "Assist in co-op asks for a Dude")
	# screen: an enemy card waits for a target and sends nothing until one is picked.
	var screen: Control = _screen()
	screen.press_card(_card_with_target(screen, "enemy"))
	assert_eq(screen._state["state_version"], 0, "nothing sent before a target is picked")
	assert_eq(screen.message, "Pick an enemy.")
	screen.press_enemy(screen._state["combat"]["enemies"][0]["uid"])
	assert_eq(screen._state["state_version"], 1, "sent once the enemy is picked")
	_free(screen)


## The Bro Move asks for an enemy when its card targets one (G33), then sends target_id.
func test_bro_move_asks_for_a_target() -> void:
	# screen: the real fight with the Bro Meter filled by hand (test setup: a fresh state copy).
	var started: Dictionary = DevFight.start()
	started["state"]["bro_meter"] = started["ruleset"]["constants"]["BRO_METER_MAX"]
	var screen: Control = _screen(started)
	screen.press_bro_move()
	assert_eq(screen.message, "Pick an enemy.", "Chest Bump asks for an enemy")
	assert_eq(screen._state["state_version"], 0, "nothing sent yet")
	screen.press_enemy(screen._state["combat"]["enemies"][0]["uid"])
	assert_eq(screen._state["state_version"], 1, "the Bro Move went through")
	assert_eq(screen._state["bro_meter"], 0, "the meter emptied")
	assert_true(screen.animation_log.any(func(l: String) -> bool: return l.begins_with("bro_move_used ")), "bro_move_used animated")
	_free(screen)


## Events animate one at a time in list order, then the screen redraws from the returned state.
func test_events_animate_in_order() -> void:
	# gateway: returns three canned events.
	var gateway := CannedGateway.new()
	gateway.events = [
		Event.make("turn_started", {"turn": 2}),
		Event.make("hype_changed", {"player_id": "p1", "delta": 3, "hype": 3}),
		Event.make("ready_changed", {"player_id": "p1", "ready": false}),
	]
	for event: Dictionary in gateway.events:
		assert_no_errors(Event.check(event), "canned event")
	# screen: the real fight on the canned gateway.
	var screen: Control = _screen(DevFight.start(), gateway)
	screen.press_ready()
	assert_eq(screen.animation_log.size(), 3, "every event animated")
	for i: int in 3:
		assert_true(screen.animation_log[i].begins_with(gateway.events[i]["type"] + " "), "event %d in order: %s" % [i, screen.animation_log[i]])
	assert_eq(screen._state["state_version"], 1, "redrawn from the returned state")
	_free(screen)


## Skipping every animation gives the same final drawing as playing them, on the real core.
func test_skipping_animations_gives_same_drawing() -> void:
	# drawings: the final text of a played and a skipped run of the same turn.
	var drawings: Array[String] = []
	for skip: bool in [false, true]:
		# screen: a fresh real fight.
		var screen: Control = _screen()
		screen.skip_animations = skip
		screen.press_card(_card_with_target(screen, "enemy"))
		screen.press_enemy(screen._state["combat"]["enemies"][0]["uid"])
		screen.press_ready()
		screen._show_message("")
		drawings.append(screen.drawn_text())
		_free(screen)
	assert_eq(drawings[1], drawings[0], "final drawing")


## Every reject code and every event type has player-facing text.
func test_every_reject_and_event_has_text() -> void:
	for code: String in Request.REJECT_REASONS:
		assert_true(Messages.REJECTS.has(code), "no message for reject code %s" % code)
	for type: String in Event.TYPES:
		assert_true(EventText.TEMPLATES.has(type), "no animation line for event type %s (client/fight/event_text.gd)" % type)
	assert_eq(EventText.line(Event.make("hype_changed", {"player_id": "p1", "delta": -2, "hype": 1}), {"p1": "Dude"}), "Dude: Hype -2 (now 1).")


## A whole fight is played through the screen's own presses on the real core and the real data,
## to a decided result, with the screen's state frozen read-only before every press (so any client
## write to game state is a runtime error, which fails the test).
func test_full_fight_through_the_screen() -> void:
	# screen: the real fight.
	var screen: Control = _screen()
	# presses: presses made so far.
	var presses: int = 0
	while screen._state["combat"]["result"] == "" and presses < MAX_PRESSES:
		_freeze(screen._state)
		# version: state_version before this step, to see whether anything was applied.
		var version: int = screen._state["state_version"]
		# first: the leftmost enemy still in the fight.
		var first: String = screen._state["combat"]["enemies"][0]["uid"]
		screen.press_bro_move()
		if screen._pending_bro:
			screen.press_enemy(first)
		presses += 1
		if screen._state["state_version"] == version:
			for uid: String in screen._state["dudes"][0]["hand"]:
				screen.press_card(uid)
				if screen._pending_card != "":
					screen.press_enemy(first)
				presses += 1
				if screen._state["state_version"] != version:
					break
		if screen._state["state_version"] == version:
			screen.press_ready()
			presses += 1
	assert_ne(screen._state["combat"]["result"], "", "the fight is decided within %d presses" % MAX_PRESSES)
	assert_no_errors(RunState.check(screen._state), "final state")
	assert_true(screen.animation_log.any(func(l: String) -> bool: return l.begins_with("fight_ended ")), "fight_ended animated")
	_free(screen)


## Nothing in client code names a specific Dude; names come from data.
func test_client_code_names_no_dude() -> void:
	# pattern: "tom" as a word or an id prefix, case-insensitive.
	var pattern := RegEx.create_from_string("(?i)\\btom(_|\\b)")
	for path: String in _client_files():
		if not (path.ends_with(".gd") or path.ends_with(".tscn")):
			continue
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			# code: the line without a trailing comment.
			var code: String = line.split("#")[0]
			assert_true(pattern.search(code) == null, "%s names a Dude: %s" % [path, line.strip_edges()])


## Every asset file under client/ is listed in client/ASSETS.md.
func test_assets_are_listed() -> void:
	# listing: the assets file's text.
	var listing: String = FileAccess.get_file_as_string("res://client/ASSETS.md")
	assert_ne(listing, "", "client/ASSETS.md exists")
	for path: String in _client_files():
		if not NOT_ASSETS.has(path.get_extension()):
			assert_true(listing.contains(path.trim_prefix("res://")), "%s is not listed in client/ASSETS.md" % path)


## The scene loads headless with no setup() call and shows a fight on the real data.
func test_scene_runs_headless() -> void:
	# screen: the scene, as a player would open it.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	# text: what it drew.
	var text: String = screen.drawn_text()
	assert_true(text.contains("Goblin Pledge") and text.contains("(you)") and text.contains("Ready"), text)
	_free(screen)


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


## Removes a screen from the tree and frees it now.
## screen: a screen from _screen().
func _free(screen: Control) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()


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


## Returns every file path under res://client/, recursively.
func _client_files() -> Array[String]:
	# out: collected paths.
	var out: Array[String] = []
	# pending: folders still to list.
	var pending: Array[String] = ["res://client"]
	while not pending.is_empty():
		# dir: the folder being listed.
		var dir: String = pending.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for file: String in DirAccess.get_files_at(dir):
			out.append(dir.path_join(file))
	return out
