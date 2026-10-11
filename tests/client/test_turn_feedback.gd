## Tests for the turn and fight-result feedback (task 047). Lane: tools/client (Agent B).
##
## Each test maps to an acceptance check in docs/tasks/047-turn-and-result-feedback.md: banners sit
## between the events where the phase changes; the Ready button pulses only when the core would
## refuse every card in hand; winning and losing show their banner before the screen moves on; the
## animation speed is a client setting that sets the event player's length ("instant" is what tests
## use) and never reaches the state or the save. Fights run on the real core and the real data,
## played instantly (animation_seconds 0), so nothing waits on a frame.
extends "res://tests/framework/test_case.gd"

const FightScreen := preload("res://client/fight/fight_screen.tscn")
const RunScreen := preload("res://client/run/run_screen.tscn")
const EventPlayer := preload("res://client/visual/event_player.gd")
const Messages := preload("res://client/fight/messages.gd")
const AnimationSpeed := preload("res://client/settings/animation_speed.gd")
const AnimationSettings := preload("res://client/settings/animation_settings.gd")
const MainMenu := preload("res://client/run/main_menu.gd")
const UserSettings := preload("res://client/settings/user_settings.gd")
const SaveStore := preload("res://client/run/save_store.gd")
const HowToPlay := preload("res://client/help/how_to_play.gd")
const DevFight := preload("res://client/dev/dev_fight.gd")
const Core := preload("res://core/core.gd")
const Event := preload("res://core/schema/event.gd")
const Documentation := preload("res://tests/core/test_documentation.gd")

## The client settings file these tests use, never the player's real settings. Erased around tests.
const SETTINGS_PATH: String = "user://test_turn_feedback_settings.cfg"
## The run save the run screen test uses, never the player's real save. Deleted around it.
const SAVE_PATH: String = "user://test_turn_feedback.save"
## The normal-speed animation length the speed tests start from, in seconds. Any value above 0.
const BASE_SECONDS: float = 0.3
## The seed of the run screen test's run. Any fixed value.
const SEED: int = 7
## The client scripts task 047 added or changed, checked by the documentation test.
const SCRIPTS: Array[String] = ["res://client/visual/event_player.gd", "res://client/fight/fight_screen.gd",
	"res://client/fight/messages.gd", "res://client/fight/request_maker.gd", "res://client/settings/animation_speed.gd",
	"res://client/settings/animation_settings.gd", "res://client/run/main_menu.gd", "res://client/run/run_screen.gd",
	"res://tests/client/test_turn_feedback.gd"]


## A gateway that applies nothing and returns a fixed list of events, with the state's combat result
## set as the test says, for banner tests.
class CannedGateway extends RefCounted:
	## The events every apply() returns, in order. Set by the test.
	var events: Array = []
	## The combat result the returned state carries ("" keeps the fight going). Set by the test.
	var result: String = ""

	## Returns a copy of the state with state_version raised and combat.result set, and the events.
	## ruleset: unused. state: copied. request: unused.
	func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
		# next: a writable copy with the version raised.
		var next: Dictionary = state.duplicate(true)
		next["state_version"] += 1
		next["combat"]["result"] = result
		return {"state": next, "events": events, "reject": ""}


## banners_for() on hand-made event lists: "your_turn" at turn_started, "enemy_turn" at the first
## enemy action moved back over that enemy's Guard drop, one per turn, and the result banners at
## fight_ended; every kind has words in messages.gd.
func test_banners_sit_where_the_phase_changes() -> void:
	# events: an end of turn, two enemies acting (the first drops its Guard first), a new turn.
	var events: Array = [
		Event.make("card_moved", {"player_id": "p1", "card_uid": "c1", "from": "hand", "to": "discard_pile"}),
		Event.make("guard_changed", {"target_id": "e1", "delta": -8, "guard": 0}),
		Event.make("enemy_acted", {"enemy_uid": "e1", "move_id": "hit"}),
		Event.make("damage_dealt", {"source_id": "e1", "target_id": "p1", "amount": 5, "blocked": 0, "hp_lost": 5}),
		Event.make("enemy_skipped", {"enemy_uid": "e2", "reason": "grossed_out"}),
		Event.make("turn_started", {"turn": 2}),
		Event.make("intent_set", {"enemy_uid": "e1", "move_id": "hit", "target_ids": ["p1"]}),
	]
	for event: Dictionary in events:
		assert_no_errors(Event.check(event), "hand-made event")
	assert_eq(EventPlayer.banners_for(events), {1: "enemy_turn", 5: "your_turn"})
	# armless: an Armless enemy's skip starts the enemy phase at its armless event.
	var armless: Array = [Event.make("armless", {"enemy_uid": "e1"}), Event.make("enemy_skipped", {"enemy_uid": "e1", "reason": "armless"})]
	assert_eq(EventPlayer.banners_for(armless), {0: "enemy_turn"})
	assert_eq(EventPlayer.banners_for([Event.make("enemy_died", {"enemy_uid": "e1"}), Event.make("fight_ended", {"result": "won"})]), {1: "victory"})
	assert_eq(EventPlayer.banners_for([Event.make("dude_passed_out", {"player_id": "p1"}), Event.make("fight_ended", {"result": "lost"})]), {1: "passed_out"})
	assert_eq(EventPlayer.banners_for([]), {})
	for kind: String in EventPlayer.BANNERS:
		assert_true(Messages.BANNERS.has(kind) and Messages.BANNERS[kind]["title"] != "", "%s has words" % kind)


## play() calls on_banner after the events before it and before the ones after it, and a banner
## lasts its share of seconds (0 when instant).
func test_play_orders_banners_between_events() -> void:
	# order: what play() called, in order.
	var order: Array[String] = []
	# events: the same shape as above, short.
	var events: Array = [
		Event.make("card_moved", {"player_id": "p1", "card_uid": "c1", "from": "hand", "to": "discard_pile"}),
		Event.make("enemy_acted", {"enemy_uid": "e1", "move_id": "hit"}),
		Event.make("turn_started", {"turn": 2}),
	]
	# player: an instant player.
	var player := EventPlayer.new()
	player.seconds = 0.0
	# holder: a node in the tree, for play()'s clock.
	var holder := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(holder)
	player.play(events, {}, func(event: Dictionary) -> void: order.append(event["type"]), holder,
		func(kind: String, seconds: float) -> void: order.append("banner " + kind + " " + str(seconds)))
	assert_eq(order, ["card_moved", "banner enemy_turn 0.0", "enemy_acted", "banner your_turn 0.0", "turn_started"])
	assert_eq(player.banners_played, ["enemy_turn@1", "your_turn@2"])
	holder.free()
	player.seconds = BASE_SECONDS
	assert_eq(player.banner_seconds("your_turn"), BASE_SECONDS * EventPlayer.TURN_BANNER_FACTOR)
	assert_eq(player.banner_seconds("victory"), BASE_SECONDS * EventPlayer.RESULT_BANNER_FACTOR)


## On the real core, pressing Ready shows "Enemy turn" just before the first enemy event and "Your
## turn" just before turn_started, with every earlier event played first; skipping the animations
## logs the same banners. The fight screen opening on a player phase says "Your turn" first. The
## banner text never stays on screen.
func test_ready_shows_the_phase_banners_in_order() -> void:
	# logs: the banner logs with and without animations.
	var logs: Array = []
	for skip: bool in [false, true]:
		# screen: the real dev fight.
		var screen: Control = _screen(DevFight.start())
		screen.skip_animations = skip
		assert_eq(screen.banner_log, ["your_turn@0"], "the fight opens on the player's turn")
		screen.press_ready()
		# enemy_at, turn_at: where the first enemy event and turn_started are in animation_log.
		var enemy_at: int = _enemy_phase_start(screen.animation_log)
		var turn_at: int = _first_index(screen.animation_log, ["turn_started"])  # where the new turn starts
		assert_true(enemy_at >= 0 and turn_at > enemy_at, "the enemies acted, then a turn started: %s" % [screen.animation_log])
		assert_eq(screen.banner_log, ["your_turn@0", "enemy_turn@%d" % enemy_at, "your_turn@%d" % turn_at])
		assert_eq(screen.banner_text, "", "no banner left on screen")
		assert_false(screen.drawn_text().contains(Messages.BANNERS["enemy_turn"]["title"]), "no banner text left")
		logs.append(screen.banner_log)
		_free(screen)
	assert_eq(logs[1], logs[0], "skipped animations log the same banners")


## A won fight shows the victory banner, a lost one the Passed Out banner, at fight_ended and before
## the screen reports the new state (state_applied), so the run screen moves on only after it.
func test_result_banners_before_the_screen_moves_on() -> void:
	for result: String in ["won", "lost"]:
		# gateway: ends the fight with this result.
		var gateway := CannedGateway.new()
		gateway.result = result
		gateway.events = [
			Event.make("enemy_died", {"enemy_uid": "e1"}) if result == "won" else Event.make("dude_passed_out", {"player_id": "p1"}),
			Event.make("fight_ended", {"result": result}),
		]
		# screen: the dev fight on the canned gateway.
		var screen: Control = _screen(DevFight.start(), gateway)
		# at_report: banner_log when state_applied fired.
		var at_report: Array = []
		screen.state_applied.connect(func(_state: Dictionary) -> void: at_report.append(screen.banner_log.duplicate()))
		screen.press_ready()
		# kind: the banner this result shows.
		var kind: String = "victory" if result == "won" else "passed_out"
		assert_eq(screen.banner_log, ["your_turn@0", "%s@1" % kind], result)
		assert_eq(at_report.size(), 1, "the state was reported once")
		assert_true(at_report[0].has("%s@1" % kind), "the banner came before the report")
		_free(screen)


## The Ready button pulses only when the core would accept ending the turn and refuse every card in
## hand: not at the start of a fight, yes with an empty hand, yes with no Hype and only cards that
## cost Hype, not once the turn is already ended.
func test_ready_pulses_only_when_nothing_can_be_played() -> void:
	# started: the dev fight.
	var started: Dictionary = DevFight.start()
	var screen: Control = _screen(started)  # the fight as it starts
	assert_false(screen.ready_pulsing, "cards can be played at the start")
	assert_false(screen.ready_should_pulse())
	_free(screen)
	# empty: a test copy with an empty hand.
	var empty: Dictionary = started["state"].duplicate(true)
	empty["dudes"][0]["hand"] = []
	screen = _screen({"ruleset": started["ruleset"], "state": empty, "player_id": started["player_id"]})
	assert_true(screen.ready_pulsing, "nothing in hand: Ready pulses")
	assert_eq(screen._ready_button.text, "Ready")
	_free(screen)
	# broke: a test copy with no Hype and only cards that cost some.
	var broke: Dictionary = started["state"].duplicate(true)
	var dude: Dictionary = broke["dudes"][0]  # the Dude in it
	dude["hype"] = 0
	# costly: the hand's cards that cost 1 Hype or more.
	var costly: Array = []
	for uid: String in dude["hand"]:
		# cost: the card's cost.
		var cost: Variant = started["ruleset"]["cards"][dude["cards"][uid]["def_id"]]["cost"]
		if typeof(cost) == TYPE_INT and cost > 0:
			costly.append(uid)
	assert_false(costly.is_empty(), "the starting hand has a card that costs Hype")
	# moved: the cards taken out of the hand go on the draw pile so every copy stays in one pile.
	for uid: String in dude["hand"]:
		if not costly.has(uid):
			dude["draw_pile"].append(uid)
	dude["hand"] = costly
	screen = _screen({"ruleset": started["ruleset"], "state": broke, "player_id": started["player_id"]})
	assert_true(screen.ready_pulsing, "no Hype for any card: Ready pulses")
	_free(screen)
	# done: a test copy where the Dude already ended the turn (the core refuses another Ready).
	var done: Dictionary = empty.duplicate(true)
	done["dudes"][0]["ready"] = true
	screen = _screen({"ruleset": started["ruleset"], "state": done, "player_id": started["player_id"]})
	assert_eq(screen.ready_pulsing, Core.validate(started["ruleset"], done, screen._requests.probe_set_ready()) == "", "pulses only if the core takes Ready")
	_free(screen)


## The speed setting: normal by default, saved per machine, multiplies the base length (instant is 0,
## what tests use); an unknown value is refused, and a bad stored value reads as normal. The menu's
## Animations row shows and saves it.
func test_animation_speed_setting() -> void:
	UserSettings.erase_settings(SETTINGS_PATH)
	assert_eq(AnimationSpeed.speed(SETTINGS_PATH), "normal")
	assert_eq(AnimationSpeed.seconds(BASE_SECONDS, SETTINGS_PATH), BASE_SECONDS)
	for speed: String in AnimationSpeed.SPEEDS:
		assert_eq(AnimationSpeed.set_speed(speed, SETTINGS_PATH), "")
		assert_eq(AnimationSpeed.speed(SETTINGS_PATH), speed)
		assert_eq(AnimationSpeed.seconds(BASE_SECONDS, SETTINGS_PATH), BASE_SECONDS * AnimationSpeed.FACTORS[speed])
	assert_eq(AnimationSpeed.seconds(BASE_SECONDS, SETTINGS_PATH), 0.0, "instant is 0 seconds, as tests play")
	assert_ne(AnimationSpeed.set_speed("ludicrous", SETTINGS_PATH), "", "an unknown speed is refused")
	assert_eq(AnimationSpeed.speed(SETTINGS_PATH), "instant", "and nothing changed")
	UserSettings.set_setting(AnimationSpeed.SPEED_KEY, 3, SETTINGS_PATH)
	assert_eq(AnimationSpeed.speed(SETTINGS_PATH), "normal", "a bad stored value reads as normal")
	UserSettings.erase_settings(SETTINGS_PATH)
	# menu: a main menu on the test settings.
	var menu: Control = MainMenu.new()
	menu.setup({}, SAVE_PATH, SETTINGS_PATH)
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	assert_true(menu.animation_settings != null, "the menu has the Animations row")
	assert_eq(menu.animation_settings.get_parent(), menu.sound_settings.get_parent(), "next to the Sound row")
	assert_eq(menu.animation_settings.picker.item_count, AnimationSpeed.SPEEDS.size())
	assert_eq(menu.animation_settings.picker.selected, 0, "Normal")
	menu.animation_settings.change_speed("fast")
	assert_eq(AnimationSpeed.speed(SETTINGS_PATH), "fast", "the row saves at once")
	menu.get_parent().remove_child(menu)
	menu.free()
	# row: a new row on the same file shows the saved speed.
	var row: HBoxContainer = AnimationSettings.new()
	row.setup(SETTINGS_PATH)
	assert_eq(row.picker.selected, AnimationSpeed.SPEEDS.find("fast"))
	row.free()
	UserSettings.erase_settings(SETTINGS_PATH)


## The run screen hands each fight the base length times the setting: normal keeps it, instant makes
## it 0. The setting never reaches the run state or the run save.
func test_run_screen_uses_the_speed_and_keeps_it_out_of_the_state() -> void:
	for speed: String in ["normal", "instant"]:
		UserSettings.erase_settings(SETTINGS_PATH)
		SaveStore.delete_save(SAVE_PATH)
		AnimationSpeed.set_speed(speed, SETTINGS_PATH)
		UserSettings.set_setting(HowToPlay.SEEN_KEY, true, SETTINGS_PATH)
		# screen: a run screen with a normal base length, on the test files.
		var screen: Control = RunScreen.instantiate()
		screen.animation_seconds = BASE_SECONDS
		screen.save_path = SAVE_PATH
		screen.settings_path = SETTINGS_PATH
		(Engine.get_main_loop() as SceneTree).root.add_child(screen)
		screen.press_new_run(str(SEED))
		# state: the new run.
		var state: Dictionary = screen.run_state()
		screen.send({"type": "vote_node", "node_id": state["map"]["nodes"][state["node_index"]]["links"][0]})
		assert_eq(screen.current, "fight", "the vote starts a fight")
		assert_eq(screen.child_screen().animation_seconds, BASE_SECONDS * AnimationSpeed.FACTORS[speed], speed)
		assert_false(var_to_str(screen.run_state()).contains(AnimationSpeed.SPEED_KEY), "not in the state")
		assert_false(FileAccess.get_file_as_string(SAVE_PATH).contains(AnimationSpeed.SPEED_KEY), "not in the save")
		screen.get_parent().remove_child(screen)
		screen.free()
	UserSettings.erase_settings(SETTINGS_PATH)
	SaveStore.delete_save(SAVE_PATH)


## Banners and the pulse never change the state: a fight played to its end through the screen with
## the state frozen read-only before every press (any write is a runtime error) still ends.
func test_feedback_never_changes_the_state() -> void:
	# screen: the real dev fight.
	var screen: Control = _screen(DevFight.start())
	# presses: Ready presses made (a safety stop, not a rule).
	var presses: int = 0
	while screen._state["combat"]["result"] == "" and presses < 60:
		_freeze(screen._state)
		# version: before the press.
		var version: int = screen._state["state_version"]
		screen.press_ready()
		assert_eq(screen._state["state_version"], version + 1, "Ready applied")
		presses += 1
	assert_ne(screen._state["combat"]["result"], "", "the fight ended (the enemies won)")
	assert_true(screen.banner_log.back().begins_with("passed_out@"), "the last banner is Passed Out: %s" % [screen.banner_log])
	_free(screen)


## The scripts task 047 added or changed follow the documentation standard (CLAUDE.md), checked with
## Agent A's lint.
func test_scripts_are_documented() -> void:
	for path: String in SCRIPTS:
		for problem: String in Documentation.lint(FileAccess.get_file_as_string(path)):
			fail("%s:%s" % [path, problem])


## Returns where the enemy phase starts in animation_log lines: the first enemy action line
## (enemy_acted, enemy_skipped or armless), moved back over the guard_changed lines of that same
## enemy right before it (its Guard dropping as its action starts); -1 when no enemy acted.
## lines: animation_log lines ("<type> field=value ...", fields sorted).
func _enemy_phase_start(lines: Array[String]) -> int:
	# first: the first enemy action line.
	var first: int = _first_index(lines, ["enemy_acted ", "enemy_skipped ", "armless "])
	if first == -1:
		return -1
	# uid: the acting enemy, from its "enemy_uid=" field.
	var uid: String = lines[first].get_slice("enemy_uid=", 1).get_slice(" ", 0)
	while first > 0 and lines[first - 1].begins_with("guard_changed ") and lines[first - 1].contains("target_id=%s" % uid):
		first -= 1
	return first


## Returns the index of the first line that begins with any of the prefixes, or -1.
## lines: animation_log lines. prefixes: line starts to look for.
func _first_index(lines: Array[String], prefixes: Array) -> int:
	for i: int in lines.size():
		for prefix: String in prefixes:
			if lines[i].begins_with(prefix):
				return i
	return -1


## Returns a fight screen in the tree with no animation time.
## started: a DevFight.start()-shaped result. gateway: where requests go; the real core when null.
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
