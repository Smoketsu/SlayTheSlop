## Tests for the splash pictures (task 063): client/visual/splashes.gd and the offer screen showing a
## splash behind its choices. Lane: tools/client (taken over by Agent A from Agent B, 2026-10-13).
## Acceptance checks: every Side Quest in data/, The Tailgate and Baileys have a picture; the lookup
## is by Side Quest id and offer kind with a visible fallback; card rewards and the Boss Gear pick show
## none; on a real run, the offer screen shows the right splash and its buttons still sit inside the
## screen at 1280x720, below the clear top part.
extends "res://tests/framework/test_case.gd"

const Splashes := preload("res://client/visual/splashes.gd")
const OfferScreen := preload("res://client/run/offer_screen.gd")
const Drive := preload("res://tests/client/run_choices_drive.gd")
const DataFiles := preload("res://tools/data_files.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")

## Screen size the layout is checked at, in pixels (the project's window size).
const SCREEN_SIZE := Vector2(1280, 720)


## Every Side Quest file in data/side_quests/, The Tailgate and Baileys have a splash file that loads.
func test_every_splash_has_a_picture() -> void:
	# ruleset: the real content.
	var ruleset: Dictionary = Ruleset.build(DataFiles.read_all())["ruleset"]
	assert_true(ruleset["side_quests"].size() >= 5, "the slice's Side Quests are loaded")
	# keys: every key that needs a picture.
	var keys: Array = ruleset["side_quests"].keys()
	keys.append_array(["tailgate", "baileys"])
	for key: String in keys:
		assert_true(Splashes.texture_for(key) != null, "%s has a splash at %s" % [key, Splashes.splash_path(key)])


## The key is the Side Quest's id for a Side Quest and the kind for The Tailgate and Baileys; card
## rewards, the Boss Gear pick and no offer show no splash.
func test_keys_by_kind_and_side_quest() -> void:
	assert_eq(Splashes.key_for({"kind": "side_quest", "def_id": "gas_station_sushi"}), "gas_station_sushi")
	assert_eq(Splashes.key_for({"kind": "tailgate"}), "tailgate")
	assert_eq(Splashes.key_for({"kind": "baileys"}), "baileys")
	assert_eq(Splashes.key_for({"kind": "card"}), "", "a card reward shows no splash")
	assert_eq(Splashes.key_for({"kind": "boss_gear"}), "", "the Boss Gear pick shows no splash")
	assert_eq(Splashes.key_for({}), "", "no offer, no splash")
	assert_false(Splashes.shows_splash({"kind": "card"}))
	assert_true(Splashes.shows_splash({"kind": "side_quest", "def_id": "no_such_quest"}), "an unknown quest still shows the fallback")


## A key that is not a plain snake_case id never becomes a path, and a missing file is null, not a crash.
func test_bad_or_missing_keys() -> void:
	assert_eq(Splashes.splash_path("../secrets"), "")
	assert_eq(Splashes.splash_path("Baileys"), "")
	assert_eq(Splashes.splash_path(""), "")
	assert_true(Splashes.texture_for("no_such_quest") == null)


## A Side Quest with no picture shows the visible fallback, and its buttons still work.
func test_missing_picture_shows_the_fallback() -> void:
	# played: a real run; its first Side Quest state is reused with an unknown quest id.
	var played: Dictionary = Drive.play()
	assert_false(played.is_empty(), "the run starts on the real data")
	if played.is_empty():
		return
	for state: Dictionary in played["offer_states"]:
		if state["dudes"][0]["offers"][0]["kind"] != "side_quest":
			continue
		# changed: the same state with the quest's id swapped for one with no picture.
		var changed: Dictionary = state.duplicate(true)
		changed["dudes"][0]["offers"][0]["def_id"] = "no_such_quest"
		# screen: the offer screen on it.
		var screen: Control = OfferScreen.new()
		screen.show_state(played["rules"], changed, changed["dudes"][0]["player_id"])
		assert_true(screen.splash_fallback_shown, "the fallback is shown")
		assert_false(screen.splash_has_picture)
		assert_true(screen.option_buttons.size() > 0, "the choices are still drawn")
		screen.free()
		return
	assert_true(false, "the run reached a Side Quest")


## On every offer of a real run: the splash shown matches the offer, and at 1280x720 every option
## button sits inside the screen, below the splash's clear top part when there is a splash.
func test_offer_screen_shows_the_splash_at_1280x720() -> void:
	# played: the run.
	var played: Dictionary = Drive.play()
	assert_false(played.is_empty(), "the run starts on the real data")
	if played.is_empty():
		return
	# seen: splash keys shown with a picture.
	var seen: Dictionary = {}
	for state: Dictionary in played["offer_states"]:
		# offer: the offer shown.
		var offer: Dictionary = state["dudes"][0]["offers"][0]
		# frame: a stand-in window of SCREEN_SIZE. screen: the offer screen in it, laid out.
		var frame := Control.new()
		frame.size = SCREEN_SIZE
		(Engine.get_main_loop() as SceneTree).root.add_child(frame)
		var screen: Control = OfferScreen.new()  # the offer screen, filling frame
		frame.add_child(screen)
		screen.show_state(played["rules"], state, state["dudes"][0]["player_id"])
		for pass_number: int in 2:
			_sort(screen)
		assert_eq(screen.splash_key, Splashes.key_for(offer), "the splash key follows the offer")
		assert_eq(screen.splash_has_picture, Splashes.shows_splash(offer), "%s: a picture exactly when the kind shows one" % offer["kind"])
		if screen.splash_has_picture:
			seen[screen.splash_key] = true
		# top: where the choices may start, in pixels.
		var top: float = SCREEN_SIZE.y * Splashes.SAFE_TOP if Splashes.shows_splash(offer) else 0.0
		for button: Button in screen.option_buttons:
			# rect: the button on screen.
			var rect: Rect2 = button.get_global_rect()
			if not button.is_visible_in_tree() or rect.end.y > SCREEN_SIZE.y:
				continue  # below the fold of a long Baileys list: it scrolls
			assert_true(rect.position.y >= top - 1.0, "%s: a button sits below the clear top part (%s)" % [offer["kind"], rect])
			assert_true(rect.position.x >= 0.0 and rect.end.x <= SCREEN_SIZE.x + 1.0, "%s: a button fits the width" % offer["kind"])
		frame.free()
	assert_true(seen.has("tailgate") and seen.has("baileys"), "the run showed The Tailgate and Baileys splashes: %s" % [seen.keys()])


## Lays out a node and everything under it now, without waiting for a frame: sends
## NOTIFICATION_SORT_CHILDREN to every container (as tests/client/test_fight_layout.gd does).
## node: where to start.
func _sort(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child: Node in node.get_children():
		_sort(child)
