## Tests for the placeholder fight screen (task 018). Lane: tools/client (Agent B).
## Each test maps to an acceptance check in docs/tasks/018-client-fight-screen.md.
extends "res://tests/framework/test_case.gd"

const FightScreen := preload("res://client/fight/fight_screen.tscn")
const FightModel := preload("res://client/fight/fight_model.gd")
const Targeting := preload("res://client/fight/targeting.gd")
const RequestMaker := preload("res://client/fight/request_maker.gd")
const Messages := preload("res://client/fight/messages.gd")
const DevContent := preload("res://client/dev/dev_content.gd")
const FakeGateway := preload("res://client/dev/fake_gateway.gd")
const Request := preload("res://core/schema/request.gd")
const Event := preload("res://core/schema/event.gd")
const RunState := preload("res://core/schema/run_state.gd")

## File types under client/ that are code or text, not assets needing a source in ASSETS.md.
const NOT_ASSETS: Array[String] = ["gd", "tscn", "md", "uid", "import"]


## A gateway that applies nothing and returns a fixed list of events, for animation-order tests.
class CannedGateway extends RefCounted:
	## The events every apply() returns, in order. Set by the test.
	var events: Array = []

	## Returns the state unchanged (but with state_version raised) and the canned events.
	## ruleset: unused. state: returned with state_version + 1. request: unused.
	func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
		# next: a writable copy with the version raised.
		var next: Dictionary = state.duplicate(true)
		next["state_version"] += 1
		return {"state": next, "events": events, "reject": ""}


## The sample content builds with the real ruleset builder, and the sample state is a valid state.
func test_sample_content_is_valid() -> void:
	# built: the sample ruleset.
	var built: Dictionary = DevContent.ruleset()
	assert_no_errors(built["errors"], "sample content")
	assert_no_errors(RunState.check(DevContent.sample_state()), "sample state")


## The model shows every value the task lists, from the state alone.
func test_model_shows_everything_from_state() -> void:
	# model: the display model of the sample fight.
	var model: Dictionary = FightModel.build(_ruleset(), DevContent.sample_state(), "p1")
	# dude: the one Dude.
	var dude: Dictionary = model["dudes"][0]
	assert_eq(dude["name"], "Test Dude", "name comes from data, not code")
	assert_eq(dude["hp"], "58 / 70")
	assert_eq([dude["guard"], dude["hype"]], [2, 3], "guard, hype")
	assert_eq(dude["statuses"], ["Exposed 1"] as Array[String])
	assert_eq(dude["brews"], "0 / 3")
	assert_eq([dude["draw"], dude["discard"], dude["tapped"]], [1, 0, 0], "pile counts")
	assert_eq(model["hand"].size(), 5, "hand")
	assert_eq(model["hand"][0]["name"], "Jab")
	assert_eq(model["bro_meter"], "10 / 10", "Bro Meter against BRO_METER_MAX")
	assert_true(model["bro_ready"])
	# dummy, blob: the two enemies.
	var dummy: Dictionary = model["enemies"][0]
	var blob: Dictionary = model["enemies"][1]
	assert_eq([dummy["name"], dummy["hp"], dummy["intent"], dummy["targets"]], ["Training Dummy", "20 / 20", "attack", ["Test Dude"] as Array[String]])
	assert_eq(dummy["arms"], "1 of 2 arms broken", "Broken Arm as k of n")
	assert_eq(dummy["ick"], "2 / 5", "Ick against threshold")
	assert_eq([blob["arms"], blob["statuses"], blob["intent"]], ["No arms", ["Noodle Arms 2"] as Array[String], "defend"])


## Requests pass request.gd check(), carry the local player, and seq rises by 1 each time, even
## across a rejected request.
func test_requests_are_well_formed_and_seq_rises() -> void:
	# maker: starts after a Dude whose last_seq is 4.
	var maker := RequestMaker.new("p2", 4)
	# made: one of each request type.
	var made: Array = [maker.play_card("c1", "e3"), maker.set_ready(true), maker.use_brew(0, ""), maker.use_bro_move()]
	for i: int in made.size():
		assert_no_errors(Request.check(made[i]), "request %d" % i)
		assert_eq(made[i]["player_id"], "p2")
		assert_eq(made[i]["seq"], 5 + i, "seq of request %d" % i)
	# screen: the sample fight, to check seq through real presses including a reject.
	var screen: Control = _screen(DevContent.sample_state())
	screen.press_card("c1")
	screen.press_enemy("e999")
	assert_eq(screen.message, Messages.reject("bad_target"), "dead or unknown target rejected")
	screen.press_enemy("e7")
	assert_eq(screen._state["dudes"][0]["last_seq"], 1, "first request seq 0 (rejected), second seq 1 (applied)")
	_free(screen)


## Targeting follows the card's target; Assist targets yourself in solo and asks in co-op.
func test_targeting() -> void:
	# cards: the sample card definitions.
	var cards: Dictionary = DevContent.CARDS
	assert_eq(Targeting.mode(cards["neutral_dev_jab"], 1), Targeting.ENEMY, "enemy asks for an enemy")
	assert_eq(Targeting.mode(cards["neutral_dev_sweep"], 1), Targeting.NONE, "all_enemies asks nothing")
	assert_eq(Targeting.mode(cards["neutral_dev_brace"], 1), Targeting.NONE, "self asks nothing")
	assert_eq(Targeting.mode(cards["neutral_dev_spot_me"], 1), Targeting.NONE, "Assist in solo asks nothing")
	assert_eq(Targeting.auto_target(cards["neutral_dev_spot_me"], "p1", 1), "p1", "Assist in solo targets the player")
	assert_eq(Targeting.mode(cards["neutral_dev_spot_me"], 2), Targeting.DUDE, "Assist in co-op asks for a Dude")
	assert_eq(Targeting.auto_target(cards["neutral_dev_sweep"], "p1", 1), "", "no-target cards send \"\"")
	# screen: pressing an enemy card waits for a target and sends nothing yet.
	var screen: Control = _screen(DevContent.sample_state())
	screen.press_card("c1")
	assert_eq(screen._state["state_version"], 0, "nothing sent before a target is picked")
	assert_eq(screen.message, "Pick an enemy.")
	screen.press_enemy("e7")
	assert_eq(screen._state["state_version"], 1, "sent once the enemy is picked")
	_free(screen)


## Events animate one at a time in list order, then the screen redraws from the returned state.
func test_events_animate_in_order() -> void:
	# gateway: returns three canned events.
	var gateway := CannedGateway.new()
	gateway.events = [
		Event.make("card_played", {"player_id": "p1", "card_uid": "c1", "target_id": "e7"}),
		Event.make("damage_dealt", {"source_id": "p1", "target_id": "e7", "amount": 6, "blocked": 0, "hp_lost": 6}),
		Event.make("card_moved", {"player_id": "p1", "card_uid": "c1", "from": "hand", "to": "discard_pile"}),
	]
	for event: Dictionary in gateway.events:
		assert_no_errors(Event.check(event), "canned event")
	# screen: the sample fight on the canned gateway.
	var screen: Control = _screen(DevContent.sample_state(), gateway)
	screen.press_ready()
	assert_eq(screen.animation_log.size(), 3, "every event animated")
	for i: int in 3:
		assert_true(screen.animation_log[i].begins_with(gateway.events[i]["type"] + " "), "event %d in order: %s" % [i, screen.animation_log[i]])
	assert_eq(screen._state["state_version"], 1, "redrawn from the returned state")
	_free(screen)


## Skipping every animation gives the same final drawing as playing them.
func test_skipping_animations_gives_same_drawing() -> void:
	# drawings: the final text of a played and a skipped run of the same turn.
	var drawings: Array[String] = []
	for skip: bool in [false, true]:
		# screen: a fresh sample fight.
		var screen: Control = _screen(DevContent.sample_state())
		screen.skip_animations = skip
		screen.press_card("c1")
		screen.press_enemy("e7")
		screen.press_card("c3")
		screen.press_ready()
		screen._show_message("")
		drawings.append(screen.drawn_text())
		_free(screen)
	assert_eq(drawings[1], drawings[0], "final drawing")
	assert_true(drawings[0].contains("HP 14 / 20"), "the Jab landed: %s" % drawings[0])


## Every reject code has a message; bad_target asks for a new target and keeps the card pending.
func test_every_reject_has_a_message() -> void:
	for code: String in Request.REJECT_REASONS:
		assert_true(Messages.REJECTS.has(code), "no message for reject code %s" % code)
	assert_eq(Messages.reject("no_hype"), "Not enough Hype.")
	# screen: aim at an enemy that does not exist.
	var screen: Control = _screen(DevContent.sample_state())
	screen.press_card("c1")
	screen.press_enemy("e999")
	assert_eq(screen._pending_card, "c1", "bad_target asks for a new target")
	_free(screen)


## A state read-only at every level goes through a full canned turn with no runtime error (the
## runner fails the test if Godot reports one), and is unchanged afterwards.
func test_screen_never_changes_state() -> void:
	# state: the sample fight, frozen.
	var state: Dictionary = DevContent.sample_state()
	# before: a copy to compare with afterwards.
	var before: Dictionary = state.duplicate(true)
	_freeze(state)
	# screen: plays a whole turn on the frozen state.
	var screen: Control = _screen(state)
	screen.press_card("c1")
	screen.press_enemy("e7")
	screen.press_card("c4")
	screen.press_card("c5")
	screen.press_bro_move()
	screen.press_ready()
	assert_eq(state, before, "the original state is unchanged")
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


## The scene itself loads headless with no setup() call and shows the sample fight.
func test_scene_runs_headless() -> void:
	# screen: the scene, as a player would open it.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	# text: what it drew.
	var text: String = screen.drawn_text()
	assert_true(text.contains("Training Dummy") and text.contains("Test Dude (you)") and text.contains("Ready"), text)
	_free(screen)


## Returns the sample ruleset.
func _ruleset() -> Dictionary:
	return DevContent.ruleset()["ruleset"]


## Returns a fight screen in the tree, set up on state with no animation time.
## state: the starting state. gateway: what requests go to; the fake gateway when null.
func _screen(state: Dictionary, gateway: Object = null) -> Control:
	# screen: the new screen.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.setup(gateway if gateway != null else FakeGateway.new(), _ruleset(), state, "p1")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


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
