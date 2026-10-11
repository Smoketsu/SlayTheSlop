## Tests for the playtest run log, client/run/run_log.gd, and its use by client/run/run_screen.gd
## (task 053). Lane: tools/client (Agent B). Each test maps to an acceptance check in
## docs/tasks/053-playtest-run-log.md: the record is built from states and events only, one sorted
## JSON object per line with ints kept, the same seed and requests give the same line apart from
## logged_at, append only, a write failure only shows a message, no personal data, and the run-over
## screen's Open log folder button.
##
## The full-run tests replay the fixed-seed floor 1 run of tests/client/run_choices_drive.gd (every
## node type, won) through Core.apply(), feeding each answer to a RunLog as the run screen does.
extends "res://tests/framework/test_case.gd"

const RunLog := preload("res://client/run/run_log.gd")
const Drive := preload("res://tests/client/run_choices_drive.gd")
const RunScreen := preload("res://client/run/run_screen.tscn")
const SaveStore := preload("res://client/run/save_store.gd")
const JsonValues := preload("res://core/schema/json_values.gd")
const Core := preload("res://core/core.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")
## The settings store and the How to play seen key (task 049), for _screen().
const UserSettings := preload("res://client/settings/user_settings.gd")
const HowToPlay := preload("res://client/help/how_to_play.gd")

## The log file these tests write, so they never touch a player's real log. Deleted before and after
## each test that writes it.
const LOG_PATH: String = "user://test_run_log.jsonl"
## The save file the run screen tests use. Deleted before and after each test that writes it.
const SAVE_PATH: String = "user://test_run_log.save"
## The client settings file the run screen tests use, so they never touch a player's real settings.
## _screen() marks How to play (task 049) as seen in it, so New Run does not open the overlay.
const SETTINGS_PATH: String = "user://test_run_log_settings.cfg"
## A log path in a folder that does not exist, so opening it for writing fails.
const BAD_LOG_PATH: String = "user://test_run_log_no_such_folder/run_log.jsonl"
## Seed of the run screen tests' runs. Any int works; fixed so failures repeat.
const SEED: int = 7
## A second seed, for the New Run that abandons the SEED run.
const OTHER_SEED: int = 8


## A gateway that applies nothing and returns the state with run_phase set to a fixed value, so the
## run-over view is reached without playing a whole floor (as in test_run_screen.gd).
class PhaseGateway extends RefCounted:
	## The run_phase every apply() returns. Set by the test.
	var phase: String = ""

	## Returns a copy of state with run_phase = phase and state_version + 1, and no events.
	## ruleset: unused. state: copied. request: unused.
	func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
		# next: the changed copy.
		var next: Dictionary = state.duplicate(true)
		next["run_phase"] = phase
		next["state_version"] += 1
		return {"state": next, "events": [], "reject": ""}


## Same seed and requests, same record: two replays of the fixed-seed run give lines equal apart from
## logged_at. The line is one JSON object, keys sorted at every level, that parses back (with ints
## restored) strictly equal to the record, so no int became a float. And the record holds what the
## run did: won, every fight with turns and HP, the card and Boss Gear choices, the Gear gained.
func test_same_seed_and_requests_give_the_same_record() -> void:
	# played: the drive's run (start state and every applied request).
	var played: Dictionary = Drive.play(Drive.SEED)
	if played.is_empty():
		fail("the fixed-seed run did not start")
		return
	assert_eq(played["problems"], [], "the drive played the whole run")
	# first, second: the two replays' records, logged at different times.
	var first: Dictionary = _replay(played).record(RunLog.WON, "2026-10-11T10:00:00Z")
	var second: Dictionary = _replay(played).record(RunLog.WON, "2026-10-11T23:59:59Z")
	# first_line, second_line: their lines.
	var first_line: String = RunLog.encode(first)
	var second_line: String = RunLog.encode(second)
	assert_ne(first_line, second_line, "logged_at differs")
	assert_eq(first_line.replace("2026-10-11T10:00:00Z", "T"), second_line.replace("2026-10-11T23:59:59Z", "T"),
		"identical apart from logged_at")
	assert_false(first_line.contains("\n"), "one line")
	# parsed: the line read back with ints restored.
	var parsed: Dictionary = JsonValues.parse(first_line)
	assert_eq(parsed["error"], "", "the line is JSON")
	assert_eq(strict_diff(parsed["value"], first, "$"), "", "parses back strictly equal: no int became a float")
	assert_eq(_unsorted_keys(parsed["value"], "$"), "", "keys sorted at every level")
	assert_false(first_line.contains(".0,") or first_line.contains(".0}"), "no whole number written as a float")
	# The run's contents.
	# final: the drive's last state.
	var final: Dictionary = played["final"]
	assert_eq(first["result"], "won")
	assert_eq(first["run_seed"], str(Drive.SEED))
	assert_eq(first["record_version"], RunLog.RECORD_VERSION)
	assert_eq(first["requests_applied"], played["requests"].size(), "every applied request")
	assert_eq(first["requests_rejected"], 0)
	assert_eq(first["resumed"], false)
	assert_eq(first["path"], final["path"])
	assert_eq(first["node_type"], "boss", "the run ended on the boss node")
	assert_eq(first["floor"], final["floor"])
	assert_eq(first["dudes_at_end"]["p1"]["hp"], final["dudes"][0]["hp"])
	assert_true(first["fights"].size() >= 3, "several fights: %d" % first["fights"].size())
	for fight: Dictionary in first["fights"]:
		assert_true(fight["turns"] >= 1, "turns counted: %s" % str(fight))
		assert_eq(fight["result"], "won", "every fight of the won run was won")
		assert_true(fight["hp_after"].has("p1"), "HP after the fight")
		assert_ne(fight["encounter_id"], "", "the encounter is known")
		assert_ne(fight["node_id"], "", "the node is known")
	assert_eq(first["fights"][-1]["node_type"], "boss", "the last fight is the boss")
	# kinds: the reward kinds answered.
	var kinds: Array = []
	for reward: Dictionary in first["rewards"]:
		kinds.append(reward["kind"])
		assert_eq(reward["player_id"], "p1")
		if reward["kind"] == "card":
			assert_eq(reward["taken"].size() + reward["skipped"].size(), 3, "1 of 3 cards: %s" % str(reward))
	for kind: String in ["card", "boss_gear", "tailgate", "baileys", "side_quest"]:
		assert_true(kinds.has(kind), "a %s choice is logged (the drive reaches every offer kind)" % kind)
	# boss_pick: the Boss Gear choice; its taken Gear is the last Gear gained.
	var boss_pick: Dictionary = first["rewards"][kinds.rfind("boss_gear")]
	assert_eq(boss_pick["taken"].size(), 1, "one Boss Gear taken")
	assert_eq(first["gear_gained"]["p1"][-1], boss_pick["taken"][0], "the Boss Gear pick is in gear_gained")
	assert_true(first["brews_gained"].has("p1"), "brews_gained has every Dude")


## A rejected request is counted, and changes nothing else in the record.
func test_rejects_are_counted() -> void:
	# begun: the rules and a new run's state.
	var begun: Dictionary = Drive.start(Drive.SEED)
	var state: Dictionary = begun["state"]
	# run_log: the run's log.
	var run_log := RunLog.new(state)
	# bad: a vote for a node no click could pick.
	var bad: Dictionary = {"type": "vote_node", "player_id": "p1", "seq": 1, "node_id": "r99c99"}
	# result: the core's answer, a reject.
	var result: Dictionary = Core.apply(begun["rules"], state, bad)
	assert_ne(result["reject"], "")
	run_log.observe(state, result)
	# record: the record now.
	var record: Dictionary = run_log.record(RunLog.ABANDONED, "")
	assert_eq(record["requests_rejected"], 1)
	assert_eq(record["requests_applied"], 0)
	assert_eq(record["fights"], [])
	assert_eq(record["node_type"], "start", "still at the entrance")
	assert_eq(record["node_row"], 0)


## The run screen appends one line when a run is won and another when the next run is lost; the
## first line is left as it was (append only). The lines hold no personal data: no user:// or
## machine path, no user or machine name.
func test_run_screen_appends_a_line_per_run() -> void:
	_clean()
	# lines: the log's lines after each run.
	var lines: Array = []
	for phase: String in ["floor_end", "lost"]:
		# gateway: returns the state with run_phase = phase. screen: a run screen on it.
		var gateway := PhaseGateway.new()
		gateway.phase = phase
		var screen: Control = _screen(gateway)
		screen.press_new_run(str(SEED))
		assert_eq(screen.send({"type": "vote_node", "node_id": "r1c0"}), "")
		assert_eq(screen.current, "won" if phase == "floor_end" else "lost")
		assert_eq(screen.message, "", "no write problem shown")
		_free(screen)
		lines.append(_log_lines())
	assert_eq(lines[0].size(), 1, "one line after the first run")
	assert_eq(lines[1].size(), 2, "a second line after the second run")
	assert_eq(lines[1][0], lines[0][0], "the first line is untouched")
	# won, lost: the two records.
	var won: Dictionary = JsonValues.parse(lines[1][0])["value"]
	var lost: Dictionary = JsonValues.parse(lines[1][1])["value"]
	assert_eq(won["result"], "won")
	assert_eq(lost["result"], "lost")
	assert_eq(won["run_seed"], str(SEED))
	assert_eq(won["requests_applied"], 1)
	assert_eq(won["resumed"], false)
	assert_eq(won["game_version"], RunLog.game_version())
	for line: String in lines[1]:
		_assert_no_personal_data(line)
	_clean()


## Abandoned: a New Run over an unfinished saved run (here saved by an earlier session that was
## closed) logs that run as abandoned, from the save, with resumed true; a New Run with no save logs
## nothing.
func test_new_run_over_a_save_logs_it_abandoned() -> void:
	_clean()
	# first: a session that starts a run (saved at once) and is closed.
	var first: Control = _screen()
	first.press_new_run(str(SEED))
	assert_true(SaveStore.has_save(SAVE_PATH), "the run is saved")
	_free(first)
	assert_eq(_log_lines(), [], "nothing logged while the run is unfinished")
	# second: a later session that starts a new run instead of Continue.
	var second: Control = _screen()
	second.press_new_run(str(OTHER_SEED))
	assert_eq(second.current, "map", "the new run starts")
	# lines: the log.
	var lines: Array = _log_lines()
	assert_eq(lines.size(), 1, "the saved run is logged once")
	# record: the abandoned run's record.
	var record: Dictionary = JsonValues.parse(lines[0])["value"]
	assert_eq(record["result"], "abandoned")
	assert_eq(record["run_seed"], str(SEED), "the saved run, not the new one")
	assert_eq(record["resumed"], true, "its history was not seen")
	assert_eq(record["node_type"], "start")
	_assert_no_personal_data(lines[0])
	_free(second)
	_clean()


## A run continued from a save and then ended is logged with resumed true.
func test_continued_run_is_marked_resumed() -> void:
	_clean()
	# gateway: ends the run at the first request. state: a new run, saved as if by an earlier session.
	var gateway := PhaseGateway.new()
	gateway.phase = "lost"
	var begun: Dictionary = Drive.start(SEED)
	assert_eq(SaveStore.save_state(begun["state"], SAVE_PATH), "")
	# screen: a session that continues it.
	var screen: Control = _screen(gateway)
	screen.press_continue()
	assert_eq(screen.current, "map")
	screen.send({"type": "vote_node", "node_id": "r1c0"})
	assert_eq(screen.current, "lost")
	# lines: the log.
	var lines: Array = _log_lines()
	assert_eq(lines.size(), 1)
	assert_eq(JsonValues.parse(lines[0])["value"]["resumed"], true)
	_free(screen)
	_clean()


## A write failure (the log's folder does not exist; a path outside user://) shows a message on the
## run-over view and the game carries on: the view is up and Back to menu works.
func test_write_failure_shows_a_message_and_play_goes_on() -> void:
	for path: String in [BAD_LOG_PATH, "/tmp/test_run_log.jsonl"]:
		_clean()
		# gateway: wins at the first request. screen: a run screen logging to a path that fails.
		var gateway := PhaseGateway.new()
		gateway.phase = "floor_end"
		var screen: Control = _screen(gateway)
		screen.run_log_path = path
		screen.press_new_run(str(SEED))
		screen.send({"type": "vote_node", "node_id": "r1c0"})
		assert_eq(screen.current, "won", "the run-over view is up")
		assert_true(screen.message.begins_with("Couldn't write the run log"), screen.message)
		assert_false(FileAccess.file_exists(path), "nothing written")
		screen.press_back_to_menu()
		assert_eq(screen.current, "menu", "the game goes on")
		_free(screen)
	_clean()


## append_line() keeps what the file holds and adds the line at the end.
func test_append_line_never_rewrites() -> void:
	_clean()
	assert_eq(RunLog.append_line("{\"a\":1}", LOG_PATH), "")
	assert_eq(RunLog.append_line("{\"b\":2}", LOG_PATH), "")
	assert_eq(FileAccess.get_file_as_string(LOG_PATH), "{\"a\":1}\n{\"b\":2}\n")
	_clean()


## The run-over view has an Open log folder button; pressing it opens nothing in a headless run.
func test_open_log_folder_button() -> void:
	_clean()
	# gateway: wins at the first request. screen: the run screen.
	var gateway := PhaseGateway.new()
	gateway.phase = "floor_end"
	var screen: Control = _screen(gateway)
	screen.press_new_run(str(SEED))
	screen.send({"type": "vote_node", "node_id": "r1c0"})
	assert_true(screen.drawn_text().contains("Open log folder"), screen.drawn_text())
	if DisplayServer.get_name() == "headless":
		assert_false(screen.press_open_log_folder(), "a no-op in headless runs")
	_free(screen)
	_clean()


## Returns a RunLog fed the drive's run: its requests replayed from its start through Core.apply(),
## each answer passed to observe() as the run screen's apply() does.
## played: Drive.play()'s result.
func _replay(played: Dictionary) -> RunLog:
	# state: the run as it goes. run_log: the log being fed.
	var state: Dictionary = played["start"]
	var run_log := RunLog.new(state)
	for request: Dictionary in played["requests"]:
		# result: the core's answer.
		var result: Dictionary = Core.apply(played["rules"], state, request)
		run_log.observe(state, result)
		state = result["state"]
	return run_log


## Returns "" when every Dictionary inside value has its keys in sorted order (the parser keeps the
## text's order), otherwise where one does not.
## value: a parsed JSON value. path: where value sits, "$" at the top.
func _unsorted_keys(value: Variant, path: String) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		# keys: the keys in text order. sorted: the same, sorted.
		var keys: Array = value.keys()
		var sorted: Array = keys.duplicate()
		sorted.sort()
		if keys != sorted:
			return "%s: %s" % [path, str(keys)]
		for key: String in keys:
			# inner: a problem below this key, if any.
			var inner: String = _unsorted_keys(value[key], path + "." + key)
			if inner != "":
				return inner
	elif typeof(value) == TYPE_ARRAY:
		for i: int in value.size():
			# inner: a problem in element i, if any.
			var inner: String = _unsorted_keys(value[i], "%s[%d]" % [path, i])
			if inner != "":
				return inner
	return ""


## Fails if a log line holds a path or a user or machine name.
## line: one line of the log.
func _assert_no_personal_data(line: String) -> void:
	assert_false(line.contains("user://"), "no user:// path: " + line)
	assert_false(line.contains(ProjectSettings.globalize_path("user://")), "no real path: " + line)
	for who: String in [OS.get_environment("USER"), OS.get_environment("USERNAME"), OS.get_environment("HOSTNAME")]:
		if who.length() >= 3:
			assert_false(line.contains("\"%s\"" % who), "no user or machine name: " + line)


## Returns the log file's lines (without the final empty one), [] when it does not exist.
func _log_lines() -> Array:
	if not FileAccess.file_exists(LOG_PATH):
		return []
	# lines: the file split at line breaks.
	var lines: Array = Array(FileAccess.get_file_as_string(LOG_PATH).split("\n"))
	if not lines.is_empty() and lines[-1] == "":
		lines.pop_back()
	return lines


## Returns a run screen in the tree with no animation time, saving to SAVE_PATH and logging to
## LOG_PATH.
## gateway: where requests go; the real core when null.
func _screen(gateway: Object = null) -> Control:
	# screen: the new screen.
	var screen: Control = RunScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.save_path = SAVE_PATH
	screen.run_log_path = LOG_PATH
	screen.settings_path = SETTINGS_PATH
	UserSettings.set_setting(HowToPlay.SEEN_KEY, true, SETTINGS_PATH)
	screen.setup(Ruleset.build(DataFiles.read_all())["ruleset"], gateway)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


## Removes a screen from the tree and frees it now.
## screen: a screen from _screen().
func _free(screen: Control) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()


## Deletes the test log and save files.
func _clean() -> void:
	SaveStore.delete_save(SAVE_PATH)
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)
