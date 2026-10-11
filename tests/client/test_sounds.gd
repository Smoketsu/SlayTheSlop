## Tests for the placeholder sounds and the volume setting (task 055): client/audio/sounds.gd,
## client/audio/volume.gd, client/settings/sound_settings.gd and their hooks in the event player,
## the main menu and the run screen. Lane: tools/client (Agent B). Each test maps to an acceptance
## check in docs/tasks/055-placeholder-sound.md.
##
## Tests run headless, on Godot's dummy audio driver: sounds.gd makes its players but starts none
## (sounds.gd SILENT_DRIVER), and nothing here waits on a sound. Every settings file is a user://
## test file, never the player's real settings, and the Master bus is set back to 0 dB, unmuted,
## after each test that changes it.
extends "res://tests/framework/test_case.gd"

const Sounds := preload("res://client/audio/sounds.gd")
const Volume := preload("res://client/audio/volume.gd")
const SoundSettings := preload("res://client/settings/sound_settings.gd")
const UserSettings := preload("res://client/settings/user_settings.gd")
const EventPlayer := preload("res://client/visual/event_player.gd")
const HowToPlay := preload("res://client/help/how_to_play.gd")
const RunScreen := preload("res://client/run/run_screen.tscn")
const SaveStore := preload("res://client/run/save_store.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")
const Event := preload("res://core/schema/event.gd")

## The client settings file these tests use. Erased before and after each test that writes it.
const SETTINGS_PATH: String = "user://test_sounds_settings.cfg"
## The run save the run screen tests use. Deleted before and after.
const SAVE_PATH: String = "user://test_sounds.save"
## Longest a placeholder sound may last, in seconds (the task asks for short sounds).
const MAX_SECONDS: float = 1.0
## The ten sounds the task lists, by kind. Every one must be in the lookup with a real file.
const LISTED: Array[String] = ["card_played", "hit", "blocked", "guard", "enemy_death", "passed_out",
	"click", "dolla_bills", "victory", "defeat"]


## A gateway that applies nothing: it returns the state with state_version raised and a fixed list
## of events, so the run screen's send() path can be driven without a real node.
class CannedGateway extends RefCounted:
	## The events every apply() returns, in order. Set by the test.
	var events: Array = []

	## Returns the state with state_version + 1, and the canned events.
	## ruleset: unused. state: copied. request: unused.
	func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
		# next: a writable copy with the version raised.
		var next: Dictionary = state.duplicate(true)
		next["state_version"] += 1
		return {"state": next, "events": events, "reject": ""}


## Every listed sound has an entry in the lookup table, its constant names it, and its file exists,
## loads as a sound and lasts under MAX_SECONDS. The table holds nothing else.
func test_lookup_covers_every_listed_sound() -> void:
	assert_eq(Sounds.FILES.size(), LISTED.size(), "one entry per listed sound")
	for kind: String in [Sounds.CARD_PLAYED, Sounds.HIT, Sounds.BLOCKED, Sounds.GUARD, Sounds.ENEMY_DEATH,
			Sounds.PASSED_OUT, Sounds.CLICK, Sounds.DOLLA_BILLS, Sounds.VICTORY, Sounds.DEFEAT]:
		assert_true(LISTED.has(kind), "%s is a listed sound" % kind)
	for kind: String in LISTED:
		assert_true(Sounds.FILES.has(kind), "%s is in the lookup" % kind)
		assert_eq(Sounds.path_for(kind), "%s/%s.wav" % [Sounds.SOUND_DIR, kind])
		# stream: the kind's sound.
		var stream: AudioStream = Sounds.stream_for(kind)
		assert_true(stream != null, "%s has a sound file" % kind)
		if stream != null:
			assert_true(stream.get_length() > 0.0 and stream.get_length() < MAX_SECONDS,
				"%s lasts %.2f s" % [kind, stream.get_length()])


## Events pick their sound by kind, following event_player.gd effect_for(); events with nothing to
## hear (a Guard loss, a 0 hit, Dolla Bills spent, a status) are silent.
func test_event_kinds() -> void:
	# cases: [event, expected sound kind].
	var cases: Array = [
		[Event.make("card_played", {"player_id": "p1", "card_uid": "c1", "target_id": "e1"}), Sounds.CARD_PLAYED],
		[Event.make("bro_move_used", {"player_id": "p1", "def_id": "x", "target_id": ""}), Sounds.CARD_PLAYED],
		[Event.make("damage_dealt", {"source_id": "p1", "target_id": "e1", "amount": 6, "blocked": 2, "hp_lost": 4}), Sounds.HIT],
		[Event.make("damage_dealt", {"source_id": "e1", "target_id": "p1", "amount": 5, "blocked": 5, "hp_lost": 0}), Sounds.BLOCKED],
		[Event.make("damage_dealt", {"source_id": "e1", "target_id": "p1", "amount": 0, "blocked": 0, "hp_lost": 0}), ""],
		[Event.make("guard_changed", {"target_id": "p1", "delta": 5, "guard": 5}), Sounds.GUARD],
		[Event.make("guard_changed", {"target_id": "p1", "delta": -5, "guard": 0}), ""],
		[Event.make("enemy_died", {"enemy_uid": "e1"}), Sounds.ENEMY_DEATH],
		[Event.make("dude_passed_out", {"player_id": "p1"}), Sounds.PASSED_OUT],
		[Event.make("dolla_bills_changed", {"player_id": "p1", "delta": 12, "dolla_bills": 112}), Sounds.DOLLA_BILLS],
		[Event.make("dolla_bills_changed", {"player_id": "p1", "delta": -50, "dolla_bills": 62}), ""],
		[Event.make("fight_ended", {"result": "won"}), Sounds.VICTORY],
		[Event.make("fight_ended", {"result": "lost"}), Sounds.DEFEAT],
		[Event.make("status_changed", {"target_id": "e1", "status": "exposed", "delta": 1, "stacks": 1}), ""],
		[{"type": "no_such_event"}, ""],
	]
	for case: Array in cases:
		assert_no_errors(Event.check(case[0], "event") if case[0]["type"] != "no_such_event" else [])
		assert_eq(Sounds.kind_for_event(case[0]), case[1], str(case[0]))


## An unknown kind, a missing file and a file that is not a sound are silent: play() returns "",
## nothing is recorded, and no error is reported (the runner fails a test on any Godot error).
func test_missing_sound_is_silent() -> void:
	Sounds.recent.clear()
	assert_eq(Sounds.path_for("no_such_sound"), "")
	assert_eq(Sounds.stream_for("no_such_sound"), null)
	assert_eq(Sounds.play("no_such_sound"), "", "unknown kind plays nothing")
	assert_eq(Sounds.play(""), "", "empty kind plays nothing")
	assert_eq(Sounds.stream_at(Sounds.SOUND_DIR.path_join("missing.wav")), null, "missing file")
	assert_eq(Sounds.stream_at("res://assets/placeholder/characters/tom.png"), null, "not a sound")
	assert_eq(Sounds.stream_at(""), null)
	assert_eq(Sounds.play_event(Event.make("turn_started", {"turn": 2})), "", "an event with no sound")
	assert_eq(Sounds.recent, [] as Array[String], "nothing was played")


## Playing headless returns at once with the path, makes one Master-bus player per kind under the
## root's host node, and starts nothing on the dummy driver. Playing the same kind again reuses its
## player.
func test_play_headless_returns_at_once() -> void:
	Sounds.recent.clear()
	assert_eq(AudioServer.get_driver_name(), Sounds.SILENT_DRIVER, "tests run on the dummy driver")
	assert_eq(Sounds.play(Sounds.HIT), Sounds.path_for(Sounds.HIT))
	assert_eq(Sounds.play(Sounds.HIT), Sounds.path_for(Sounds.HIT), "again, at once")
	# host: the node holding the players.
	var host: Node = Sounds.host()
	assert_true(host != null and host.get_parent() == (Engine.get_main_loop() as SceneTree).root, "host under the root")
	# player: the hit sound's player.
	var player: AudioStreamPlayer = host.get_node_or_null(NodePath(Sounds.HIT)) as AudioStreamPlayer
	assert_true(player != null, "one player for the kind")
	if player != null:
		assert_eq(player.bus, Sounds.BUS)
		assert_eq(player.stream, Sounds.stream_for(Sounds.HIT))
		assert_false(player.playing, "nothing starts on the dummy driver")
	assert_eq(host.get_children().filter(func(n: Node) -> bool: return n.name == Sounds.HIT).size(), 1, "reused")
	assert_eq(Sounds.recent, [Sounds.HIT, Sounds.HIT] as Array[String])
	for i: int in Sounds.RECENT_MAX + 5:
		Sounds.play(Sounds.CLICK)
	assert_eq(Sounds.recent.size(), Sounds.RECENT_MAX, "recent stays bounded")


## The event player starts each event's sound as it plays it, in event order, with or without
## views and whatever its seconds; play() with seconds 0 finishes without awaiting anything.
func test_event_player_plays_sounds_without_waiting() -> void:
	# events: a short fight's worth, including silent ones.
	var events: Array = [
		Event.make("card_played", {"player_id": "p1", "card_uid": "c1", "target_id": "e1"}),
		Event.make("damage_dealt", {"source_id": "p1", "target_id": "e1", "amount": 6, "blocked": 0, "hp_lost": 6}),
		Event.make("turn_started", {"turn": 2}),
		Event.make("damage_dealt", {"source_id": "e1", "target_id": "p1", "amount": 3, "blocked": 3, "hp_lost": 0}),
		Event.make("guard_changed", {"target_id": "p1", "delta": 4, "guard": 4}),
		Event.make("enemy_died", {"enemy_uid": "e1"}),
		Event.make("fight_ended", {"result": "won"}),
		Event.make("dolla_bills_changed", {"player_id": "p1", "delta": 15, "dolla_bills": 115}),
	]
	# expected: the sounds those events play, in order.
	var expected: Array[String] = [Sounds.CARD_PLAYED, Sounds.HIT, Sounds.BLOCKED, Sounds.GUARD,
		Sounds.ENEMY_DEATH, Sounds.VICTORY, Sounds.DOLLA_BILLS]
	Sounds.recent.clear()
	# player: an instant event player.
	var player := EventPlayer.new()
	player.seconds = 0.0
	# seen: events handed to on_event, to prove play() ran to the end synchronously.
	var seen: Array = []
	# clock: any node in the tree, as the fight screen passes itself.
	var clock := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(clock)
	player.play(events, {}, func(event: Dictionary) -> void: seen.append(event), clock)
	assert_eq(seen.size(), events.size(), "play() finished without waiting")
	assert_eq(Sounds.recent, expected, "one sound per audible event, in order")
	Sounds.recent.clear()
	player.seconds = 0.5
	for event: Dictionary in events:
		player.play_one(event, {})
	assert_eq(Sounds.recent, expected, "timed play_one() starts the same sounds")
	clock.get_parent().remove_child(clock)
	clock.free()


## Volume and mute read as their defaults with no file, save to the client settings file, read back
## with their types, apply to the Master bus, and a bad stored value reads as the default.
func test_volume_and_mute_persist_in_settings() -> void:
	UserSettings.erase_settings(SETTINGS_PATH)
	assert_eq(Volume.volume(SETTINGS_PATH), Volume.DEFAULT_VOLUME, "default volume")
	assert_eq(Volume.muted(SETTINGS_PATH), false, "not muted by default")
	assert_eq(Volume.set_volume(0.35, SETTINGS_PATH), "")
	assert_eq(Volume.volume(SETTINGS_PATH), 0.35)
	assert_eq(UserSettings.get_setting(Volume.VOLUME_KEY, null, SETTINGS_PATH), 0.35, "stored under VOLUME_KEY")
	assert_true(absf(Volume.applied_volume() - 0.35) < 0.001, "applied to the bus: %f" % Volume.applied_volume())
	assert_eq(Volume.set_muted(true, SETTINGS_PATH), "")
	assert_eq(Volume.muted(SETTINGS_PATH), true)
	assert_eq(UserSettings.get_setting(Volume.MUTED_KEY, null, SETTINGS_PATH), true, "stored under MUTED_KEY")
	assert_true(Volume.applied_muted(), "bus muted")
	assert_eq(Volume.volume(SETTINGS_PATH), 0.35, "muting keeps the volume")
	Volume.apply(1.0, false)
	Volume.apply_saved(SETTINGS_PATH)
	assert_true(Volume.applied_muted() and absf(Volume.applied_volume() - 0.35) < 0.001, "apply_saved() restores both")
	assert_eq(Volume.set_volume(1.5, SETTINGS_PATH), "")
	assert_eq(Volume.volume(SETTINGS_PATH), 1.0, "clamped high")
	assert_eq(Volume.set_volume(-1.0, SETTINGS_PATH), "")
	assert_eq(Volume.volume(SETTINGS_PATH), 0.0, "clamped low")
	assert_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Volume.BUS)), Volume.SILENT_DB, "0 is SILENT_DB")
	UserSettings.set_setting(Volume.VOLUME_KEY, "loud", SETTINGS_PATH)
	UserSettings.set_setting(Volume.MUTED_KEY, 1, SETTINGS_PATH)
	assert_eq(Volume.volume(SETTINGS_PATH), Volume.DEFAULT_VOLUME, "a non-number reads as the default")
	assert_eq(Volume.muted(SETTINGS_PATH), false, "a non-bool reads as unmuted")
	assert_ne(Volume.set_volume(0.5, "res://settings.cfg"), "", "a path outside user:// is refused")
	UserSettings.erase_settings(SETTINGS_PATH)
	_reset_bus()


## The Sound row shows the saved values, saves every change (slider, test hook or signal), and
## loading the saved values does not write the file.
func test_sound_settings_row() -> void:
	UserSettings.erase_settings(SETTINGS_PATH)
	# row: the Sound row, set up before it enters the tree (it builds its widgets in _init()), as the
	# menu may do.
	var row: HBoxContainer = SoundSettings.new()
	row.setup(SETTINGS_PATH)
	(Engine.get_main_loop() as SceneTree).root.add_child(row)
	assert_eq(row.slider.value, Volume.DEFAULT_VOLUME, "default shown")
	assert_false(row.mute_box.button_pressed)
	assert_false(FileAccess.file_exists(SETTINGS_PATH), "showing the defaults writes nothing")
	row.change_volume(0.4)
	assert_eq(row.slider.value, 0.4)
	row.change_muted(true)
	assert_true(row.mute_box.button_pressed)
	assert_eq(Volume.volume(SETTINGS_PATH), 0.4)
	assert_eq(Volume.muted(SETTINGS_PATH), true)
	row.slider.value = 0.25
	assert_eq(Volume.volume(SETTINGS_PATH), 0.25, "dragging the slider saves")
	row.mute_box.button_pressed = false
	assert_eq(Volume.muted(SETTINGS_PATH), false, "clicking Mute saves")
	row.get_parent().remove_child(row)
	row.free()
	# again: a new row on the same file shows what was saved.
	var again: HBoxContainer = SoundSettings.new()
	Volume.set_muted(true, SETTINGS_PATH)
	again.setup(SETTINGS_PATH)
	assert_eq(again.slider.value, 0.25)
	assert_true(again.mute_box.button_pressed)
	assert_true(Volume.applied_muted(), "setup() applies the saved values")
	again.free()
	UserSettings.erase_settings(SETTINGS_PATH)
	_reset_bus()


## The main menu shows the Sound row on the run screen's settings file; volume set there never goes
## into the run state or the run save. Buttons under the run screen click when pressed.
func test_menu_row_clicks_and_no_volume_in_run_state() -> void:
	UserSettings.erase_settings(SETTINGS_PATH)
	SaveStore.delete_save(SAVE_PATH)
	# screen: a run screen on test files.
	var screen: Control = _screen(null)
	# menu: the main menu.
	var menu: Control = screen.child_screen()
	assert_true(menu.sound_settings != null, "the menu has a Sound row")
	assert_eq(menu.sound_settings.settings_path, SETTINGS_PATH, "on the run screen's settings file")
	menu.sound_settings.change_volume(0.55)
	assert_eq(Volume.volume(SETTINGS_PATH), 0.55)
	Sounds.recent.clear()
	# buttons: every button on the menu.
	var buttons: Array[Node] = menu.find_children("*", "BaseButton", true, false)
	assert_true(buttons.size() >= 3, "the menu has buttons")
	# continue_button: the Continue button (no save, so pressing it only shows a message).
	var continue_button: Button = menu._continue_button
	continue_button.pressed.emit()
	assert_eq(Sounds.recent, [Sounds.CLICK] as Array[String], "a button under the run screen clicks")
	screen.press_new_run("7")
	assert_eq(screen.current, "map")
	# text: the run state and the save, as text.
	var text: String = JSON.stringify(screen.run_state()) + FileAccess.get_file_as_string(SAVE_PATH)
	assert_false(text.contains(Volume.VOLUME_KEY) or text.contains(Volume.MUTED_KEY), "no sound setting in the run")
	_free(screen)
	SaveStore.delete_save(SAVE_PATH)
	UserSettings.erase_settings(SETTINGS_PATH)
	_reset_bus()


## A map or offer request that gains Dolla Bills plays their sound through the run screen's send().
func test_run_request_plays_dolla_bills() -> void:
	UserSettings.erase_settings(SETTINGS_PATH)
	SaveStore.delete_save(SAVE_PATH)
	# gateway: answers every request with a Dolla Bills gain.
	var gateway := CannedGateway.new()
	gateway.events = [Event.make("dolla_bills_changed", {"player_id": "p1", "delta": 20, "dolla_bills": 120})]
	# screen: a run screen on the canned gateway.
	var screen: Control = _screen(gateway)
	screen.press_new_run("7")
	Sounds.recent.clear()
	assert_eq(screen.send({"type": "vote_node", "node_id": "anything"}), "")
	assert_eq(Sounds.recent, [Sounds.DOLLA_BILLS] as Array[String])
	_free(screen)
	SaveStore.delete_save(SAVE_PATH)
	UserSettings.erase_settings(SETTINGS_PATH)
	_reset_bus()


## Returns a run screen in the tree with no animation time, saving to SAVE_PATH, with How to play
## already seen in SETTINGS_PATH.
## gateway: where requests go; the real core when null.
func _screen(gateway: Object) -> Control:
	# screen: the new screen.
	var screen: Control = RunScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.save_path = SAVE_PATH
	screen.settings_path = SETTINGS_PATH
	UserSettings.set_setting(HowToPlay.SEEN_KEY, true, SETTINGS_PATH)
	screen.setup(Ruleset.build(DataFiles.read_all())["ruleset"], gateway)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


## Removes a screen from the tree and frees it now.
## screen: a screen made by _screen().
func _free(screen: Control) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()


## Puts the Master bus back to 0 dB, unmuted, as Godot starts it.
func _reset_bus() -> void:
	Volume.apply(1.0, false)
