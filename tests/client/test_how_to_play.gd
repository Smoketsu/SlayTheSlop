## Tests for How to play (task 049): client/help/how_to_play.gd and how_to_play_text.gd, opened
## through the main menu and the run screen. Lane: tools/client (Agent B). Each test maps to an
## acceptance check in docs/tasks/049-how-to-play.md: the menu button, paging to the end, Back,
## Skip from any panel, the once-only flag in the client settings (not the run save), numbers read
## from the ruleset, and the writing rules.
extends "res://tests/framework/test_case.gd"

const RunScreen := preload("res://client/run/run_screen.tscn")
const HowToPlay := preload("res://client/help/how_to_play.gd")
const HowToPlayText := preload("res://client/help/how_to_play_text.gd")
const UserSettings := preload("res://client/settings/user_settings.gd")
const SaveStore := preload("res://client/run/save_store.gd")
const RunText := preload("res://client/run/run_text.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")

## The run save these tests use, so they never touch a player's real save. Deleted around tests.
const SAVE_PATH: String = "user://test_how_to_play.save"
## The client settings file these tests use, so they never touch a player's real settings.
## Erased around tests.
const SETTINGS_PATH: String = "user://test_how_to_play_settings.cfg"
## The seed of the new runs here. Any int works; fixed so failures repeat.
const SEED_TEXT: String = "7"
## Fewest and most panels the task allows ("Five to eight short panels").
const MIN_PANELS: int = 5
const MAX_PANELS: int = 8
## Bro Move card text put in the test ruleset, so its number is known (see the numbers test).
const TEST_BRO_TEXT: String = "Deal 88 damage"
## Words the GDD glossary replaces (standard deckbuilder term -> themed term); none may appear.
const NON_GLOSSARY_WORDS: Array[String] = ["energy", "block", "gold", "relic", "potion", "elite",
	"exhaust", "rest site", "ascension"]
## Drink words that must never be said about Baileys (CLAUDE.md "Baileys sells weed, not drinks").
const DRINK_WORDS: Array[String] = ["beer", "drink", "brew", "booze", "shot", "keg"]


## The main menu has a How to play button; pressing it opens the panels over the menu. Next pages
## through every panel in order (Back disabled on the first, the Done words on the last), and Next
## on the last panel closes the overlay with closed(false).
func test_menu_button_opens_panels_and_pages_to_the_end() -> void:
	_reset_files()
	# screen: a run screen on the menu.
	var screen: Control = _screen()
	assert_eq(screen.current, "menu")
	# button: the menu's How to play button.
	var button: Button = _find_button(screen.child_screen(), "How to play")
	assert_true(button != null, "the menu has a How to play button")
	assert_true(screen.how_to_play_screen() == null, "closed before the press")
	button.pressed.emit()
	# overlay: the open How to play overlay.
	var overlay: Control = screen.how_to_play_screen()
	assert_true(overlay != null, "the button opens the panels")
	# closes: what closed() emitted.
	var closes: Array = []
	overlay.closed.connect(func(skipped: bool) -> void: closes.append(skipped))
	# count: how many panels there are.
	var count: int = overlay.panels.size()
	assert_true(count >= MIN_PANELS and count <= MAX_PANELS, "5 to 8 panels, got %d" % count)
	assert_eq(overlay.page, 0)
	assert_true(_find_button(overlay, "Back").disabled, "Back is disabled on the first panel")
	for index: int in count:
		assert_eq(overlay.page, index)
		assert_eq(overlay.shown_text(), overlay.panels[index]["title"] + "\n" + overlay.panels[index]["body"])
		assert_true(screen.drawn_text().contains(overlay.panels[index]["title"]), "the panel is drawn")
		if index < count - 1:
			assert_true(_find_button(overlay, HowToPlay.NEXT_LABEL) != null, "Next before the last panel")
			overlay.press_next()
	assert_true(_find_button(overlay, HowToPlay.DONE_LABEL) != null, "the last panel's button closes")
	assert_false(_find_button(overlay, "Back").disabled, "Back works on the last panel")
	assert_eq(closes, [], "not closed yet")
	overlay.press_next()
	assert_eq(closes, [false], "Next on the last panel closes, not skipped")
	assert_true(screen.how_to_play_screen() == null, "the overlay is gone")
	assert_eq(screen.current, "menu", "the menu is still there")
	_free(screen)
	_reset_files()


## Back goes to the previous panel and stops at the first one.
func test_back_goes_back_and_stops_at_the_first_panel() -> void:
	# overlay: a standalone overlay on the real data.
	var overlay: Control = _overlay()
	overlay.press_next()
	overlay.press_next()
	assert_eq(overlay.page, 2)
	overlay.press_back()
	assert_eq(overlay.page, 1)
	assert_eq(overlay.shown_text(), overlay.panels[1]["title"] + "\n" + overlay.panels[1]["body"])
	overlay.press_back()
	overlay.press_back()
	assert_eq(overlay.page, 0, "Back on the first panel stays there")
	_free(overlay)


## Skip closes the overlay from every panel, emitting closed(true) once, and frees it.
func test_skip_works_from_any_panel() -> void:
	# count: how many panels the real data gives.
	var count: int = HowToPlayText.panels(_ruleset(), "").size()
	for index: int in count:
		# overlay: a fresh overlay paged to this panel. closes: what closed() emitted.
		var overlay: Control = _overlay()
		var closes: Array = []
		overlay.closed.connect(func(skipped: bool) -> void: closes.append(skipped))
		for step: int in index:
			overlay.press_next()
		assert_eq(overlay.page, index)
		overlay.press_skip()
		overlay.press_skip()
		assert_eq(closes, [true], "Skip on panel %d closes once, skipped" % index)
		assert_true(overlay.is_queued_for_deletion(), "freed after Skip on panel %d" % index)
		_free(overlay)


## The first New Run on a machine (no settings file) opens the panels once and stores the seen flag
## in the client settings; the flag is not in the run state or the run save. A second New Run, on
## the same screen or a new one, does not open them again; neither does Continue.
func test_first_new_run_shows_once() -> void:
	_reset_files()
	# screen: a run screen on the menu.
	var screen: Control = _screen()
	assert_eq(UserSettings.get_setting(HowToPlay.SEEN_KEY, false, SETTINGS_PATH), false, "not seen yet")
	screen.press_new_run(SEED_TEXT)
	assert_eq(screen.current, "map", "the run started")
	# overlay: the panels opened by the new run.
	var overlay: Control = screen.how_to_play_screen()
	assert_true(overlay != null, "the first new run opens How to play")
	assert_eq(UserSettings.get_setting(HowToPlay.SEEN_KEY, false, SETTINGS_PATH), true, "seen flag stored")
	# dude: the run's Dude definition. bro_name: its Bro Move's name in the data.
	var dude: Dictionary = _ruleset()["dudes"][screen.run_state()["dudes"][0]["dude_id"]]
	var bro_name: String = _ruleset()["cards"][dude["bro_move"]]["name"]
	assert_true(_all_text(overlay.panels).contains(bro_name), "names the run's Bro Move from the data")
	assert_false(var_to_str(screen.run_state()).contains(HowToPlay.SEEN_KEY), "flag not in the run state")
	assert_false(FileAccess.get_file_as_bytes(SAVE_PATH).get_string_from_ascii().contains(HowToPlay.SEEN_KEY),
		"flag not in the run save")
	overlay.press_skip()
	assert_true(screen.how_to_play_screen() == null, "skipped")
	assert_eq(screen.current, "map", "the run is still on the map")
	screen.show_menu()
	screen.press_new_run(SEED_TEXT)
	assert_true(screen.how_to_play_screen() == null, "a second new run does not open it")
	_free(screen)
	# again: a new screen on the same settings file, as after restarting the game.
	var again: Control = _screen()
	again.press_new_run(SEED_TEXT)
	assert_true(again.how_to_play_screen() == null, "not after a restart either")
	_free(again)
	# Continue never opens it, even with no flag stored.
	UserSettings.erase_settings(SETTINGS_PATH)
	# loaded: a screen continuing the saved run.
	var loaded: Control = _screen()
	loaded.press_continue()
	assert_eq(loaded.current, "map", "the saved run loaded")
	assert_true(loaded.how_to_play_screen() == null, "Continue does not open How to play")
	_free(loaded)
	_reset_files()


## Every number in the panels is read from the ruleset: with every constant the text uses set to a
## distinct value, and the Bro Move's card text replaced, each value appears and no other number
## does. The real data's numbers show too.
func test_numbers_come_from_the_ruleset() -> void:
	# real: the real data. real_text: its panels as one string.
	var real: Dictionary = _ruleset()
	var real_text: String = _all_text(HowToPlayText.panels(real, ""))
	for name: String in ["BASE_HYPE", "BASE_DRAW", "BRO_METER_MAX", "BASE_BREW_SLOTS"]:
		assert_true(real_text.contains(str(real["constants"][name])), "shows %s" % name)
	# tuned: a writable copy of the real data with changed numbers.
	var tuned: Dictionary = real.duplicate(true)
	# expected: every number the tuned text may show, as text.
	var expected: Array[String] = []
	# next_value: the next distinct value to give a constant.
	var next_value: int = 101
	for name: String in HowToPlayText.USED_CONSTANTS:
		tuned["constants"][name] = next_value
		expected.append(str(next_value))
		next_value += 1
	for name: String in HowToPlayText.PERCENT_CONSTANTS:
		tuned["constants"][name] = 0.57
		expected.append("57")
	# dude_ids: the Dudes, sorted; the first is the one the menu's panels name.
	var dude_ids: Array = tuned["dudes"].keys()
	dude_ids.sort()
	tuned["cards"][tuned["dudes"][dude_ids[0]]["bro_move"]]["text"] = TEST_BRO_TEXT
	expected.append("88")
	# text: the tuned panels as one string. numbers: every run of digits in it.
	var text: String = _all_text(HowToPlayText.panels(tuned, ""))
	var digits := RegEx.create_from_string("\\d+")
	var numbers: Array[String] = []
	for found: RegExMatch in digits.search_all(text):
		numbers.append(found.get_string())
	for number: String in numbers:
		assert_true(number in expected, "number %s is not read from the ruleset" % number)
	for number: String in expected:
		assert_true(number in numbers, "the text shows %s" % number)


## The text follows the glossary and the writing rules: no standard deckbuilder words, Baileys is
## said to sell Shake and never a drink, and every panel is short (a title and one to four lines).
func test_text_follows_the_writing_rules() -> void:
	# panels: the real panels.
	var panels: Array[Dictionary] = HowToPlayText.panels(_ruleset(), "")
	# lower: all the text in lower case.
	var lower: String = _all_text(panels).to_lower()
	for word: String in NON_GLOSSARY_WORDS:
		assert_false(lower.contains(word), "uses the glossary term instead of \"%s\"" % word)
	for term: String in ["Hype", "Guard", "Dolla Bills", "Gear", "Brew", "The Tailgate", "Baileys", "Shake"]:
		assert_true(_all_text(panels).contains(term), "uses %s" % term)
	# baileys_lines: every line that names Baileys.
	var baileys_lines: Array[String] = []
	for panel: Dictionary in panels:
		assert_ne(panel["title"], "")
		assert_true(panel["body"].split("\n").size() <= 4, "%s is short" % panel["title"])
		for line: String in panel["body"].split("\n"):
			if line.begins_with(RunText.NODE_LABELS["baileys"]):
				baileys_lines.append(line)
	assert_eq(baileys_lines.size(), 1, "one line starts with Baileys")
	for line: String in baileys_lines:
		assert_true(line.contains("Shake"), "Baileys sells Shake")
		for word: String in DRINK_WORDS:
			assert_false(line.to_lower().contains(word), "no \"%s\" at Baileys" % word)


## Returns a run screen on the real data and the test's own save and settings files, in the tree.
func _screen() -> Control:
	# screen: the new screen.
	var screen: Control = RunScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.save_path = SAVE_PATH
	screen.settings_path = SETTINGS_PATH
	screen.setup(_ruleset(), null)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


## Returns a standalone How to play overlay on the real data (the menu's panels), in the tree.
func _overlay() -> Control:
	# overlay: the new overlay.
	var overlay: Control = HowToPlay.new()
	overlay.setup(_ruleset(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(overlay)
	return overlay


## Returns the real ruleset built from data/.
func _ruleset() -> Dictionary:
	return Ruleset.build(DataFiles.read_all())["ruleset"]


## Returns every title and body of panels joined into one string.
## panels: panels from HowToPlayText.panels().
func _all_text(panels: Array[Dictionary]) -> String:
	# parts: titles and bodies in order.
	var parts: Array[String] = []
	for panel: Dictionary in panels:
		parts.append(panel["title"])
		parts.append(panel["body"])
	return "\n".join(parts)


## Returns the first Button under node (depth first) whose text is text, or null.
## node: where to look. text: the button's exact words.
func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child: Node in node.get_children():
		# found: a match under child, or null.
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


## Removes a node from the tree (if it is in one) and frees it now.
## node: a screen or overlay from this file.
func _free(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


## Deletes this file's save and settings files.
func _reset_files() -> void:
	SaveStore.delete_save(SAVE_PATH)
	UserSettings.erase_settings(SETTINGS_PATH)
