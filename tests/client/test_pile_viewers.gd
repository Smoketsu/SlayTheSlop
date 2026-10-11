## Tests for the pile and deck viewers (task 043). Lane: tools/client (Agent B).
##
## Each test maps to an acceptance check in docs/tasks/043-pile-and-deck-viewers.md: the pile counts
## follow the state after every request; clicking a pile opens its faces and Escape or a click outside
## closes it; the draw pile is sorted, never in draw order; the run header's Deck button is on the map
## and every offer screen and lists the deck with upgrades; opening a viewer sends nothing and changes
## nothing; each viewer lists exactly the state's cards. Fights run on the real core and data.
extends "res://tests/framework/test_case.gd"

const FightScreen := preload("res://client/fight/fight_screen.tscn")
const RunScreen := preload("res://client/run/run_screen.tscn")
const PileViewer := preload("res://client/visual/pile_viewer.gd")
const RunText := preload("res://client/run/run_text.gd")
const UserSettings := preload("res://client/settings/user_settings.gd")
const SaveStore := preload("res://client/run/save_store.gd")
const HowToPlay := preload("res://client/help/how_to_play.gd")
const DevFight := preload("res://client/dev/dev_fight.gd")
const Drive := preload("res://tests/client/run_choices_drive.gd")
const Core := preload("res://core/core.gd")
const CardDef := preload("res://core/schema/card_def.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const Documentation := preload("res://tests/core/test_documentation.gd")

## The run save the run screen tests use, never the player's real save. Deleted around them.
const SAVE_PATH: String = "user://test_pile_viewers.save"
## The client settings file the run screen tests use, never the player's real settings. Erased
## around them.
const SETTINGS_PATH: String = "user://test_pile_viewers_settings.cfg"
## The client scripts task 043 added or changed, checked by the documentation test.
const SCRIPTS: Array[String] = ["res://client/visual/pile_viewer.gd", "res://client/visual/card_view.gd",
	"res://client/fight/fight_screen.gd", "res://client/fight/messages.gd", "res://client/run/run_screen.gd",
	"res://client/run/run_text.gd", "res://tests/client/test_pile_viewers.gd"]


## A gateway that counts the requests it is asked to apply and passes them to the real core.
class CountingGateway extends RefCounted:
	## How many requests apply() was given. Only grows.
	var count: int = 0

	## Counts the request and returns the real core's answer.
	## ruleset: the content. state: the current state. request: the request.
	func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
		count += 1
		return Core.apply(ruleset, state, request)


## The pile viewer uses the pile names of core/schema/ exactly, and the three pile icons show the
## state's counts at the start and again after a played card and after Ready.
func test_pile_counts_follow_the_state() -> void:
	for pile: String in _fight_script().VIEWABLE_PILES:
		assert_true(DudeState.PILES.has(pile), "%s is a schema pile name" % pile)
	# screen: the real dev fight.
	var screen: Control = _screen(Core.new())
	_assert_counts(screen, "at the start")
	screen.press_card(_card_with_target(screen, "enemy"))
	screen.press_enemy(screen._state["combat"]["enemies"][0]["uid"])
	_assert_counts(screen, "after a card")
	screen.press_ready()
	_assert_counts(screen, "after Ready")
	_free(screen)


## Clicking each pile icon opens a viewer listing exactly that pile's cards (the draw pile sorted, the
## others in pile order), with names and upgrades as the faces show them; Escape closes it, a click
## outside closes it, the Close button closes it. Opening sends nothing and changes nothing: the
## state is frozen read-only (any write is a runtime error) and the gateway sees no request.
func test_each_pile_opens_and_closes_without_a_request() -> void:
	# gateway: counts requests.
	var gateway := CountingGateway.new()
	var screen: Control = _screen(gateway)  # the real dev fight on it
	# Put cards in every pile with real requests first: play a card (discard), then end the turn.
	screen.press_card(_card_with_target(screen, "enemy"))
	screen.press_enemy(screen._state["combat"]["enemies"][0]["uid"])
	# before: the state and the request count before any viewer opens.
	var before: Dictionary = screen._state.duplicate(true)
	var sent: int = gateway.count  # requests so far
	_freeze(screen._state)
	# dude: the local Dude.
	var dude: Dictionary = screen._state["dudes"][0]
	for pile: String in _fight_script().VIEWABLE_PILES:
		_click(screen._draw_badge if pile == "draw_pile" else (screen._discard_badge if pile == "discard_pile" else screen._tapped_badge))
		# viewer: the open viewer.
		var viewer: Control = screen.pile_viewer()
		assert_true(viewer != null, "a click on %s opens its viewer" % pile)
		if viewer == null:
			continue
		# expected: the pile's uids, sorted for the draw pile.
		var expected: Array = dude[pile].duplicate()
		if pile == "draw_pile":
			expected = _sorted_uids(screen._ruleset, dude, expected)
		assert_eq(viewer.card_uids, expected, "%s lists the state's cards" % pile)
		assert_true(viewer.title_text.ends_with("(%d)" % dude[pile].size()), viewer.title_text)
		for i: int in viewer.card_uids.size():
			assert_eq(viewer.card_names[i], RunText.card_copy_name(screen._ruleset, dude, viewer.card_uids[i]))
		# close: Escape, a click outside, then the Close button, one per pile.
		match pile:
			"draw_pile":
				# escape: an Escape key press.
				var escape := InputEventKey.new()
				escape.keycode = KEY_ESCAPE
				escape.pressed = true
				viewer._input(escape)
			"discard_pile":
				# outside: a left click on the dark layer.
				var outside := InputEventMouseButton.new()
				outside.button_index = MOUSE_BUTTON_LEFT
				outside.pressed = true
				outside.position = Vector2(5, 5)
				viewer._gui_input(outside)
			_:
				viewer.close()
		assert_true(screen.pile_viewer() == null, "%s closed" % pile)
	assert_eq(gateway.count, sent, "no viewer sent a request")
	assert_eq(screen._state, before, "no viewer changed the state")
	_free(screen)


## The draw pile viewer is sorted by type then name, never in draw order: on a test copy whose draw
## pile is in reverse sorted order, the viewer still lists it sorted; a wheel turn outside does not
## close it.
func test_draw_pile_is_sorted_not_in_draw_order() -> void:
	# started: the dev fight.
	var started: Dictionary = DevFight.start()
	# state: a test copy with the draw pile reversed from sorted order.
	var state: Dictionary = started["state"].duplicate(true)
	var dude: Dictionary = state["dudes"][0]  # the Dude in it
	dude["draw_pile"].append_array(dude["hand"])
	dude["hand"] = []
	# sorted: the draw pile sorted as the viewer sorts.
	var sorted: Array = _sorted_uids(started["ruleset"], dude, dude["draw_pile"])
	dude["draw_pile"] = sorted.duplicate()
	dude["draw_pile"].reverse()
	assert_ne(dude["draw_pile"], sorted, "the test draw order differs from the sorted order")
	var screen: Control = _screen(Core.new(), {"ruleset": started["ruleset"], "state": state, "player_id": started["player_id"]})  # the fight on it
	screen.open_pile("draw_pile")
	# viewer: the open viewer.
	var viewer: Control = screen.pile_viewer()
	assert_eq(viewer.card_uids, sorted, "sorted, not in draw order")
	# last: the previous listed card's [type place, name]; neither may fall.
	var last: Array = [-1, ""]
	for uid: String in viewer.card_uids:
		# definition: the card's definition. key: its [type place, name].
		var definition: Dictionary = started["ruleset"]["cards"][dude["cards"][uid]["def_id"]]
		var key: Array = [CardDef.TYPES.find(definition["type"]), definition["name"]]  # its sort key
		assert_true(key[0] > last[0] or (key[0] == last[0] and key[1] >= last[1]), "sorted by type, then name: %s after %s" % [key, last])
		last = key
	# wheel: a wheel turn on the dark layer.
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	viewer._gui_input(wheel)
	assert_true(screen.pile_viewer() != null, "the wheel does not close it")
	screen.open_pile("no_such_pile")
	assert_true(screen.pile_viewer() == viewer, "an unknown pile opens nothing")
	_free(screen)


## The run header's Deck button is shown on the map and on every offer kind (card reward, Boss Gear,
## The Tailgate, Baileys, Side Quest) and opens the whole run deck, sorted, a Lifted copy named with
## its upgrade; it is hidden on the menu and during a fight; opening it sends nothing and changes
## nothing.
func test_deck_button_on_every_run_screen() -> void:
	# played: a whole run through the screens.
	var played: Dictionary = Drive.play()
	assert_false(played.is_empty(), "the run starts on the real data")
	if played.is_empty():
		return
	var ruleset: Dictionary = played["rules"]  # the real content
	# screen: a run screen on test files.
	var screen: Control = _run_screen(ruleset)
	assert_false(screen.deck_button.visible, "no Deck button on the menu")
	# states: the map, then the first state of each offer kind.
	var states: Array = [played["map_states"][0]]
	for kind: String in DudeState.OFFER_KINDS:
		# found: the first state with that offer.
		var found: Dictionary = Drive.first_with_offer(played["offer_states"], kind)
		assert_false(found.is_empty(), "the run reaches a %s offer" % kind)
		if not found.is_empty():
			states.append(found)
	for state: Dictionary in states:
		# lifted: a copy with the deck's first card Lifted (display only).
		var lifted: Dictionary = state.duplicate(true)
		var dude: Dictionary = lifted["dudes"][0]  # the Dude in it
		dude["cards"][dude["deck"][0]]["upgraded"] = true
		_freeze(lifted)
		screen._on_run_ready(lifted, false)
		# where: which screen it shows.
		var where: String = screen.current if screen.current != "offer" else "offer " + dude["offers"][0]["kind"]
		assert_true(screen.deck_button.visible, "Deck button on %s" % where)
		# sent: requests before the press.
		var sent: int = screen.sent_requests.size()
		screen.press_deck()
		# viewer: the deck viewer.
		var viewer: Control = screen.deck_viewer()
		assert_true(viewer != null, "Deck opens the viewer on %s" % where)
		if viewer == null:
			continue
		assert_eq(viewer.card_uids, _sorted_uids(ruleset, dude, dude["deck"]), "the whole deck, sorted, on %s" % where)
		assert_true(viewer.card_names[viewer.card_uids.find(dude["deck"][0])].ends_with(RunText.UPGRADED_MARK), "the Lifted copy shows its upgrade")
		assert_true(viewer.title_text.begins_with(RunText.DECK_LABEL), viewer.title_text)
		assert_eq(screen.sent_requests.size(), sent, "opening the deck sent nothing")
		viewer.close()
		assert_true(screen.deck_viewer() == null)
	# start: the run's first state, voted into its first fight through the core.
	var start: Dictionary = played["start"]
	# voted: the vote's result.
	var voted: Dictionary = Core.apply(ruleset, start, {"type": "vote_node", "player_id": start["dudes"][0]["player_id"],
		"seq": start["dudes"][0]["last_seq"] + 1, "node_id": start["map"]["nodes"][start["node_index"]]["links"][0]})
	screen._on_run_ready(voted["state"], false)
	assert_eq(screen.current, "fight")
	assert_false(screen.deck_button.visible, "no Deck button during a fight (the piles are there)")
	screen.press_deck()
	assert_true(screen.deck_viewer() == null, "a hidden button opens nothing")
	screen.get_parent().remove_child(screen)
	screen.free()
	_reset_files()


## entries_for() keeps the given order unless asked to sort, and sorts unknown types last.
func test_entries_order() -> void:
	# ruleset: the real content.
	var ruleset: Dictionary = DevFight.start()["ruleset"]  # the real content
	var ids: Array = ruleset["cards"].keys()  # every card id
	ids.sort()
	# dude: two real copies and one with no definition.
	var dude: Dictionary = {"cards": {"c1": {"def_id": ids[0], "upgraded": false}, "c2": {"def_id": ids[1], "upgraded": false},
		"c3": {"def_id": "no_such_card", "upgraded": false}}}
	# given: the uids in a fixed order.
	var given: Array = ["c3", "c2", "c1"]
	# kept: the entries unsorted.
	var kept: Array[Dictionary] = PileViewer.entries_for(ruleset, dude, given, false)
	assert_eq(kept.map(func(entry: Dictionary) -> String: return entry["card_uid"]), given)
	# sorted: the entries sorted.
	var sorted: Array[Dictionary] = PileViewer.entries_for(ruleset, dude, given, true)
	assert_eq(sorted[-1]["card_uid"], "c3", "a copy with no definition sorts last")


## The scripts task 043 added or changed follow the documentation standard (CLAUDE.md), checked with
## Agent A's lint.
func test_scripts_are_documented() -> void:
	for path: String in SCRIPTS:
		for problem: String in Documentation.lint(FileAccess.get_file_as_string(path)):
			fail("%s:%s" % [path, problem])


## Returns the fight screen's script, for its constants (VIEWABLE_PILES).
func _fight_script() -> Script:
	return load("res://client/fight/fight_screen.gd")


## Checks that the three pile icons show the local Dude's pile sizes.
## screen: a fight screen. label: where in the test this is.
func _assert_counts(screen: Control, label: String) -> void:
	# dude: the local Dude.
	var dude: Dictionary = screen._state["dudes"][0]
	assert_eq(screen._draw_badge.value_text, str(dude["draw_pile"].size()), "draw %s" % label)
	assert_eq(screen._discard_badge.value_text, str(dude["discard_pile"].size()), "discard %s" % label)
	assert_eq(screen._tapped_badge.value_text, str(dude["tapped_pile"].size()), "tapped %s" % label)


## Returns uids sorted as the viewer sorts them: by type (card_def.gd TYPES order), then name, then uid.
## ruleset: the content. dude: their owner. uids: card_uids.
func _sorted_uids(ruleset: Dictionary, dude: Dictionary, uids: Array) -> Array:
	# keyed: [type place, name, uid] per uid.
	var keyed: Array = []
	for uid: String in uids:
		# definition: the copy's definition.
		var definition: Dictionary = ruleset["cards"][dude["cards"][uid]["def_id"]]
		keyed.append([CardDef.TYPES.find(definition["type"]), RunText.card_copy_name(ruleset, dude, uid), uid])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a < b)
	return keyed.map(func(key: Array) -> String: return key[2])


## Sends a left click to a pile icon, as the mouse would.
## badge: the pile's icon.
func _click(badge: Control) -> void:
	# click: a left button press.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	badge.gui_input.emit(click)


## Returns the uid of the first card in the local hand whose definition has this target.
## screen: a fight screen. target: a card_def TARGETS value.
func _card_with_target(screen: Control, target: String) -> String:
	# dude: the local Dude.
	var dude: Dictionary = screen._state["dudes"][0]
	for uid: String in dude["hand"]:
		if screen._ruleset["cards"][dude["cards"][uid]["def_id"]]["target"] == target:
			return uid
	fail("no card targeting %s in hand" % target)
	return ""


## Returns a fight screen in the tree with no animation time.
## gateway: where requests go. started: a DevFight.start()-shaped result; a fresh one when empty.
func _screen(gateway: Object, started: Dictionary = {}) -> Control:
	if started.is_empty():
		started = DevFight.start()
	# screen: the new screen.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.setup(gateway, started["ruleset"], started["state"], started["player_id"])
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


## Returns a run screen in the tree on this test's files, on the menu.
## ruleset: the content.
func _run_screen(ruleset: Dictionary) -> Control:
	_reset_files()
	UserSettings.set_setting(HowToPlay.SEEN_KEY, true, SETTINGS_PATH)
	# screen: the new screen.
	var screen: Control = RunScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.save_path = SAVE_PATH
	screen.settings_path = SETTINGS_PATH
	screen.setup(ruleset)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


## Removes a screen from the tree and frees it now.
## screen: a screen from _screen().
func _free(screen: Control) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()


## Removes this test's save and settings files.
func _reset_files() -> void:
	SaveStore.delete_save(SAVE_PATH)
	UserSettings.erase_settings(SETTINGS_PATH)


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
