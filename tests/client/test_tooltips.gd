## Tests for the tooltips (task 045). Lane: tools/client (Agent B).
##
## Each test maps to an acceptance check in docs/tasks/045-tooltips.md: one table holds every
## tooltip; every status and intent kind the core can put in state has an entry; Gear and Brew
## tooltips are the data's own text; numbers come from data/constants.json through the ruleset; at
## Baileys Brews are Shake in tooltips too; and the tooltips reach the badges, intents, piles, card
## faces, the run header and the offer screen. Fights run on the real core and data.
extends "res://tests/framework/test_case.gd"

const TooltipText := preload("res://client/help/tooltip_text.gd")
const TooltipView := preload("res://client/visual/tooltip_view.gd")
const Icons := preload("res://client/visual/icons.gd")
const RunText := preload("res://client/run/run_text.gd")
const FightScreen := preload("res://client/fight/fight_screen.tscn")
const RunScreen := preload("res://client/run/run_screen.tscn")
const OfferScreen := preload("res://client/run/offer_screen.gd")
const UserSettings := preload("res://client/settings/user_settings.gd")
const HowToPlay := preload("res://client/help/how_to_play.gd")
const DevFight := preload("res://client/dev/dev_fight.gd")
const Drive := preload("res://tests/client/run_choices_drive.gd")
const Core := preload("res://core/core.gd")
const CardDef := preload("res://core/schema/card_def.gd")
const EnemyDef := preload("res://core/schema/enemy_def.gd")
const Documentation := preload("res://tests/core/test_documentation.gd")

## The run save the run screen test uses, so it never touches a player's real save. Erased around
## the test.
const SAVE_PATH: String = "user://test_tooltips.save"
## The client settings file the run screen test uses, never the player's real settings. Erased
## around the test.
const SETTINGS_PATH: String = "user://test_tooltips_settings.cfg"
## Longest a TOOLTIPS sentence may be, in characters ("one or two short lines"; the longest is the
## Bro Meter's, which has to say the solo and the co-op rule).
const MAX_CHARACTERS: int = 220
## Words the GDD glossary replaces (standard deckbuilder term -> themed term); none may appear.
const NON_GLOSSARY_WORDS: Array[String] = ["energy", "block", "gold", "relic", "potion", "elite",
	"exhaust", "rest site", "ascension"]
## Drink words that must never be said at Baileys (CLAUDE.md "Baileys sells weed, not drinks").
const DRINK_WORDS: String = "\\b(beer|drink|ale|booze|liquor|shot|wine|brew)(s|es|ing)?\\b"
## The client scripts task 045 added or changed, checked by the documentation test.
const SCRIPTS: Array[String] = ["res://client/help/tooltip_text.gd", "res://client/visual/tooltip_view.gd",
	"res://client/visual/tip_button.gd", "res://client/visual/tip_box.gd", "res://client/visual/stat_badge.gd",
	"res://client/visual/combatant_view.gd", "res://client/visual/card_view.gd", "res://client/fight/fight_screen.gd",
	"res://client/run/run_screen.gd", "res://client/run/offer_screen.gd", "res://tests/client/test_tooltips.gd"]


## Every status id core/schema/ lists and every intent kind it names (and every kind the data uses)
## has a TOOLTIPS entry under its icons.gd key, as do the stats, piles, markers, the Bro Meter and
## every card keyword; describe() of each is a filled sentence.
func test_every_status_and_intent_has_a_tooltip() -> void:
	# ruleset: the real content.
	var ruleset: Dictionary = DevFight.start()["ruleset"]
	# keys: every key that must have an entry.
	var keys: Array[String] = []
	for status: String in _schema_status_ids():
		keys.append(Icons.look(status)["key"])
	keys.append_array(_schema_intent_kinds(ruleset))
	keys.append_array(["hp", "guard", "swole", "chill", "clout", "hype", "skipped", "target", "seat",
		"bro_meter", "draw_pile", "discard_pile", "tapped_pile", "junk"])
	keys.append_array(CardDef.KEYWORDS)
	for key: String in keys:
		assert_true(TooltipText.TOOLTIPS.has(key), "%s has a tooltip" % key)
		assert_ne(TooltipText.describe(ruleset, key), "", "%s describes something" % key)
		assert_false(TooltipText.describe(ruleset, key).contains("{"), "%s has every placeholder filled" % key)
	for key: String in CardDef.KEYWORDS:
		assert_true(TooltipText.KEYWORD_NAMES.has(key), "keyword %s has its face word" % key)
	assert_eq(TooltipText.describe(ruleset, "no_such_key"), "", "an unknown key has no description")


## No sentence in the table types a digit: every number is a {CONSTANT} placeholder naming a constant
## in data/constants.json. Changing a constant in a copy of the ruleset changes the tooltip.
func test_numbers_come_from_the_constants() -> void:
	# ruleset: the real content.
	var ruleset: Dictionary = DevFight.start()["ruleset"]
	# placeholder: the table's placeholder pattern.
	var placeholder := RegEx.create_from_string(TooltipText.PLACEHOLDER)
	# digit: any digit.
	var digit := RegEx.create_from_string("\\d")
	# used: the constant names the table uses.
	var used: Array[String] = []
	for key: String in TooltipText.TOOLTIPS:
		# text: the sentence. bare: the same with placeholders removed.
		var text: String = TooltipText.TOOLTIPS[key]
		var bare: String = placeholder.sub(text, "", true)  # the sentence without its placeholders
		assert_true(digit.search(bare) == null, "%s types no digit: %s" % [key, text])
		for found: RegExMatch in placeholder.search_all(text):
			assert_true(ruleset["constants"].has(found.get_string(1)), "%s names a real constant %s" % [key, found.get_string(1)])
			used.append(found.get_string(1))
	assert_true(used.size() >= 5, "the statuses and Bro Meter read constants: %s" % [used])
	# checks: [key, constant, test value, text the tooltip must then contain].
	var checks: Array = [["exposed", "EXPOSED_MULT", 2.0, "100% more"], ["noodle_arms", "NOODLE_MULT", 0.5, "50% less"],
		["hungover", "HUNGOVER_MULT", 0.9, "10% less"], ["broken_arms", "BROKEN_ARM_MAX_REDUCTION", 0.25, "25% less"],
		["ick", "ICK_THRESHOLD_STEP", 7, "rises by 7"], ["faded", "FADED_MAX_DAMAGE", 4, "at most 4 damage"],
		["bro_meter", "BRO_METER_MAX", 12, "At 12,"], ["bro_meter", "BRO_METER_SOLO_CARDS", 4, "every 4 cards"]]
	for check: Array in checks:
		# changed: a copy of the ruleset with one constant changed.
		var changed: Dictionary = ruleset.duplicate(true)
		changed["constants"][check[1]] = check[2]
		assert_true(TooltipText.describe(changed, check[0]).contains(check[3]), "%s follows %s: %s" % [check[0], check[1], TooltipText.describe(changed, check[0])])
	# real: the real values, as the GDD has them.
	assert_true(TooltipText.describe(ruleset, "exposed").contains("50% more"), TooltipText.describe(ruleset, "exposed"))
	assert_true(TooltipText.describe(ruleset, "noodle_arms").contains("25% less"), TooltipText.describe(ruleset, "noodle_arms"))
	assert_true(TooltipText.describe(ruleset, "broken_arms").contains("40% less"), TooltipText.describe(ruleset, "broken_arms"))
	assert_eq(TooltipText.fill({}, "at {NO_SUCH_CONSTANT}"), "at {NO_SUCH_CONSTANT}", "a missing constant is left as written")


## Gear and Brew tooltips are the data file's own name and text, and the table holds no Gear or Brew
## id (no copy of their text); at Baileys a Brew's tooltip is the Shake line and never says Brew or a
## drink word.
func test_gear_and_brew_tooltips_use_the_data_text() -> void:
	# ruleset: the real content.
	var ruleset: Dictionary = DevFight.start()["ruleset"]
	# drink: the drink-word pattern.
	var drink := RegEx.create_from_string(DRINK_WORDS)
	for gear_id: String in ruleset["gear"]:
		# gear: the definition.
		var gear: Dictionary = ruleset["gear"][gear_id]
		assert_eq(TooltipText.gear(ruleset, gear_id), gear["name"] + ": " + gear["text"])
		assert_false(TooltipText.TOOLTIPS.has(gear_id), "no copy of %s in the table" % gear_id)
	for brew_id: String in ruleset["brews"]:
		# brew: the definition. shake: its tooltip at Baileys.
		var brew: Dictionary = ruleset["brews"][brew_id]
		var shake: String = TooltipText.brew(ruleset, brew_id, true)  # its tooltip at Baileys
		assert_eq(TooltipText.brew(ruleset, brew_id, false), brew["name"] + ": " + brew["text"])
		assert_eq(shake, RunText.shake_text(ruleset, brew_id))
		assert_true(shake.begins_with(RunText.SHAKE_PREFIX + ": "), shake)
		assert_true(drink.search(shake.to_lower()) == null, "no drink word at Baileys: %s" % shake)
		assert_false(TooltipText.TOOLTIPS.has(brew_id), "no copy of %s in the table" % brew_id)
	assert_eq(TooltipText.gear(ruleset, "no_such_gear"), "no_such_gear")


## The words follow GDD "Rules for writers": no non-glossary term, short sentences, and a keyword
## line names the keyword as the face does.
func test_words_follow_the_glossary() -> void:
	# ruleset: the real content.
	var ruleset: Dictionary = DevFight.start()["ruleset"]
	for key: String in TooltipText.TOOLTIPS:
		# text: the filled sentence, lower case.
		var text: String = TooltipText.describe(ruleset, key)
		assert_true(text.length() <= MAX_CHARACTERS, "%s is short: %d" % [key, text.length()])
		for word: String in NON_GLOSSARY_WORDS:
			assert_false(RegEx.create_from_string("\\b%s\\b" % word).search(text.to_lower()) != null, "%s says %s: %s" % [key, word, text])
	# paperwork: a Tapped Junk card from the data.
	var paperwork: Dictionary = ruleset["cards"]["junk_paperwork"]
	assert_true(paperwork["keywords"].has("tapped"), "the data's Paperwork is Tapped")
	assert_eq(TooltipText.card(ruleset, paperwork), "Tapped: %s\nJunk: %s" % [TooltipText.describe(ruleset, "tapped"), TooltipText.describe(ruleset, "junk")])
	assert_eq(TooltipText.card(ruleset, {}), "", "nothing to explain")


## On the fight screen every badge, intent icon and pile carries "<name>: <value>" then what it does;
## the HP bar and the Bro Meter too; a card face with a keyword explains it; a Brew button shows the
## Brew's data text. Nothing here sends a request.
func test_fight_screen_shows_the_tooltips() -> void:
	# started: the dev fight, with statuses and a Brew set on a test copy.
	var started: Dictionary = DevFight.start()
	var ruleset: Dictionary = started["ruleset"]  # the real content
	var state: Dictionary = started["state"].duplicate(true)  # the test copy
	var dude: Dictionary = state["dudes"][0]  # the local Dude in it
	dude["statuses"] = {"exposed": 2}
	dude["swole"] = 1
	dude["brews"] = ["energy_drink"]
	# paperwork_uid: a Paperwork copy put in the hand (display only).
	var paperwork_uid: String = "c9999"
	dude["cards"][paperwork_uid] = {"def_id": "junk_paperwork", "upgraded": false}
	dude["hand"].append(paperwork_uid)
	var enemy: Dictionary = state["combat"]["enemies"][0]  # the leftmost enemy
	enemy["ick"] = 2
	# screen: the fight screen on it.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.setup(Core.new(), ruleset, state, started["player_id"])
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	# version: the state before anything is hovered.
	var version: int = screen._state["state_version"]
	# badges: every badge on screen.
	var badges: Array[Node] = [screen._hype_badge, screen._draw_badge, screen._discard_badge, screen._tapped_badge]
	for view: Node in screen._views.values():
		badges.append_array(view.badges())
		badges.append_array(view.head_badges())
		assert_true(view._hp_bar.tooltip_text.ends_with(TooltipText.describe(ruleset, "hp")), view._hp_bar.tooltip_text)
	# seen: the badge keys checked.
	var seen: Array[String] = []
	for badge: Node in badges:
		# lines: the tooltip's lines.
		var lines: PackedStringArray = badge.tooltip_text.split("\n")
		assert_eq(lines.size(), 2, "%s: name line and description: %s" % [badge.key, badge.tooltip_text])
		assert_true(lines[0].begins_with(Icons.look(badge.key)["name"]), lines[0])
		assert_eq(lines[1], TooltipText.describe(ruleset, Icons.look(badge.key)["key"]))
		seen.append(badge.key)
		# popup: the wrapped tooltip the badge would show.
		var popup: Object = badge._make_custom_tooltip(badge.tooltip_text)
		assert_true(popup is Control, "%s draws a wrapped tooltip" % badge.key)
		if popup != null:
			popup.free()
	for key: String in ["exposed", "swole", "ick", "hype", "draw_pile", "discard_pile", "tapped_pile"]:
		assert_true(seen.has(key), "%s has a badge on screen: %s" % [key, seen])
	assert_true(screen._bro_box.tooltip_text.ends_with(TooltipText.describe(ruleset, "bro_meter")), screen._bro_box.tooltip_text)
	# card: the Paperwork face in the hand.
	var card: Node = screen._hand_box.get_child(screen._hand_box.get_child_count() - 1)
	assert_true(card.tooltip_text.begins_with("Tapped: "), card.tooltip_text)
	# brew: the Brew button.
	var brew: Button = null
	for button: Node in screen._actions_box.get_children():
		if (button as Button).text.begins_with("Brew: "):
			brew = button
	assert_true(brew != null, "the Brew has a button")
	assert_eq(brew.text, "Brew: " + ruleset["brews"]["energy_drink"]["name"])
	assert_eq(brew.tooltip_text, TooltipText.brew(ruleset, "energy_drink", false))
	assert_eq(screen._state["state_version"], version, "showing tooltips sends nothing")
	screen.get_parent().remove_child(screen)
	screen.free()


## The run header lists the Dude's Gear and Brews with their data text as tooltips; on the Baileys
## screen the Brews are under Shake, with Shake tooltips, and no tag or heading says a drink word.
## The offer screen's options carry tooltips too: Shake lines at Baileys, a Gear's data text.
func test_run_header_and_offers_show_item_tooltips() -> void:
	# played: a whole run through the screens.
	var played: Dictionary = Drive.play()
	assert_false(played.is_empty(), "the run starts on the real data")
	if played.is_empty():
		return
	var ruleset: Dictionary = played["rules"]  # the real content
	# baileys: the run's first Baileys state, with Gear and a Brew given to the Dude (display only).
	var baileys: Dictionary = Drive.first_with_offer(played["offer_states"], "baileys").duplicate(true)
	assert_false(baileys.is_empty(), "the run reaches Baileys")
	baileys["dudes"][0]["gear"] = ["backwards_cap"]
	baileys["dudes"][0]["brews"] = ["energy_drink"]
	# map: the same Dude back on the map (not at Baileys).
	var map: Dictionary = baileys.duplicate(true)
	map["run_phase"] = "map"
	map["dudes"][0]["offers"] = []
	_reset_files()
	# screen: a run screen on test files.
	var screen: Control = RunScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.save_path = SAVE_PATH
	screen.settings_path = SETTINGS_PATH
	UserSettings.set_setting(HowToPlay.SEEN_KEY, true, SETTINGS_PATH)
	screen.setup(ruleset)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen._on_run_ready(map, false)
	assert_eq(screen.current, "map")
	assert_false(screen.at_baileys())
	assert_eq(screen.item_tags.size(), 2, "one Gear tag and one Brew tag")
	assert_eq(screen.item_tags[0].text, ruleset["gear"]["backwards_cap"]["name"])
	assert_eq(screen.item_tags[0].tooltip_text, TooltipText.gear(ruleset, "backwards_cap"))
	assert_eq(screen.item_tags[1].tooltip_text, TooltipText.brew(ruleset, "energy_drink", false))
	assert_true(screen.drawn_text().contains(screen.ITEM_HEADINGS["brews"]), "the Brews heading on the map")
	screen._on_run_ready(baileys, false)
	assert_eq(screen.current, "offer")
	assert_true(screen.at_baileys())
	assert_eq(screen.item_tags[1].tooltip_text, RunText.shake_text(ruleset, "energy_drink"), "a Shake at Baileys")
	# drink: the drink-word pattern.
	var drink := RegEx.create_from_string(DRINK_WORDS)
	for tag: Button in screen.item_tags:
		assert_true(drink.search(tag.tooltip_text.to_lower()) == null, "no drink word at Baileys: %s" % tag.tooltip_text)
	assert_true(screen.drawn_text().contains(screen.ITEM_HEADINGS["shake"]), "the Shake heading at Baileys")
	assert_false(drink.search(screen.drawn_text().to_lower()) != null, "no drink word on the Baileys screen: %s" % screen.drawn_text())
	# offer: the offer screen at Baileys.
	var offer: Control = screen.child_screen()
	# options: the Baileys offer's options.
	var options: Array = baileys["dudes"][0]["offers"][0]["options"]
	for i: int in options.size():
		assert_eq(offer.option_buttons[i].tooltip_text, TooltipText.option_tooltip(ruleset, options[i]))
		if options[i]["kind"] == "shake":
			assert_true(offer.option_buttons[i].tooltip_text.begins_with(RunText.SHAKE_PREFIX), offer.option_buttons[i].tooltip_text)
		if options[i]["kind"] == "gear":
			assert_eq(offer.option_buttons[i].tooltip_text, TooltipText.gear(ruleset, options[i]["gear_id"]))
	screen.get_parent().remove_child(screen)
	screen.free()
	_reset_files()


## The wrapped tooltip view: nothing for empty text, the whole text otherwise, never wider than
## MAX_WIDTH.
func test_tooltip_view_wraps() -> void:
	assert_true(TooltipView.make("") == null, "no tooltip for empty text")
	# view: a long tooltip.
	var view: Control = TooltipView.make("Name: 1\n" + "word ".repeat(80))
	var label: RichTextLabel = view.get_child(0)  # the text inside the fill
	assert_true(label.custom_minimum_size.x <= TooltipView.MAX_WIDTH, "wraps at MAX_WIDTH")
	assert_true(label.get_parsed_text().begins_with("Name: 1\nword"), label.get_parsed_text())
	view.free()


## The scripts task 045 added or changed follow the documentation standard (CLAUDE.md), checked with
## Agent A's lint.
func test_scripts_are_documented() -> void:
	for path: String in SCRIPTS:
		for problem: String in Documentation.lint(FileAccess.get_file_as_string(path)):
			fail("%s:%s" % [path, problem])


## Returns the status ids core/schema/ lists: the "Status ids" table of core/schema/README.md and
## enemy_def.gd PERIODIC_STATUSES.
func _schema_status_ids() -> Array[String]:
	# ids: the result.
	var ids: Array[String] = []
	# section: the README's "Status ids" section.
	var section: String = FileAccess.get_file_as_string("res://core/schema/README.md").get_slice("## Status ids", 1).get_slice("\n## ", 0)
	for found: RegExMatch in RegEx.create_from_string("(?m)^\\| `(\\w+)` \\|").search_all(section):
		ids.append(found.get_string(1))
	for status: String in EnemyDef.PERIODIC_STATUSES:
		if not ids.has(status):
			ids.append(status)
	assert_true(ids.size() >= 7, "the schema lists the statuses: %s" % [ids])
	return ids


## Returns the intent kinds core/schema/enemy_def.gd names (its MOVE_SPEC "intent" comment) and every
## intent kind a move in the data uses.
## ruleset: the real content.
func _schema_intent_kinds(ruleset: Dictionary) -> Array[String]:
	# kinds: the result.
	var kinds: Array[String] = []
	for line: String in FileAccess.get_file_as_string("res://core/schema/enemy_def.gd").split("\n"):
		if line.contains("Intent icon key"):
			for found: RegExMatch in RegEx.create_from_string("\"(\\w+)\"").search_all(line):
				kinds.append(found.get_string(1))
	assert_true(kinds.has("attack") and kinds.has("defend"), "the schema names intent kinds: %s" % [kinds])
	for enemy: Dictionary in ruleset["enemies"].values():
		for move: Dictionary in enemy["moves"]:
			if not kinds.has(move["intent"]):
				kinds.append(move["intent"])
	return kinds


## Removes this test's save and settings files.
func _reset_files() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	UserSettings.erase_settings(SETTINGS_PATH)
