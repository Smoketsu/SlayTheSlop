## Tests for the fight layout and the stat icons (task 057). Lane: tools/client (Agent B).
##
## Each test maps to an acceptance check in docs/tasks/057-fight-layout-and-stat-icons.md. Fights run
## on the real core and the real data, built with the core's own builders; values a test needs (a
## status, some Guard) are set on a fresh test copy of the state before the screen draws it. Layout is
## forced with NOTIFICATION_SORT_CHILDREN, as in test_card_faces.gd, so nothing waits for a frame.
extends "res://tests/framework/test_case.gd"

const FightScreen := preload("res://client/fight/fight_screen.tscn")
const FightModel := preload("res://client/fight/fight_model.gd")
const CombatantView := preload("res://client/visual/combatant_view.gd")
const FloorLayout := preload("res://client/visual/floor_layout.gd")
const Backgrounds := preload("res://client/visual/backgrounds.gd")
const Icons := preload("res://client/visual/icons.gd")
const StatBadge := preload("res://client/visual/stat_badge.gd")
const Messages := preload("res://client/fight/messages.gd")
const DevFight := preload("res://client/dev/dev_fight.gd")
const Core := preload("res://core/core.gd")
const Party := preload("res://core/combat/party.gd")
const Fight := preload("res://core/combat/fight.gd")
const Statuses := preload("res://core/combat/statuses.gd")
const EnemyDef := preload("res://core/schema/enemy_def.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Documentation := preload("res://tests/core/test_documentation.gd")

## The window size the layout must fit (task 057 "Acceptance checks"), in pixels.
const WINDOW := Vector2(1280, 720)
## How far a sprite's feet may be from the floor line, in pixels (layout rounding only).
const FEET_TOLERANCE: float = 1.0
## The run seed of the test fights. Any fixed value.
const SEED: int = 20261011
## The crowded fight's enemies: five floor 1 enemies that bring no helpers, so exactly five stand.
const CROWD: Array[String] = ["goblin_bouncer", "goblin_pledge", "keg_slime", "hall_monitor_golem", "sewer_gator"]
## Dudes in the crowded fight, the most a party has (core/combat/party.gd MAX_PARTY_SIZE).
const CROWD_DUDES: int = 4
## The client scripts task 057 added or changed, checked by the documentation test.
const SCRIPTS: Array[String] = ["res://client/visual/icons.gd", "res://client/visual/stat_badge.gd",
	"res://client/visual/floor_layout.gd", "res://client/visual/combatant_view.gd",
	"res://client/visual/backgrounds.gd", "res://client/fight/fight_model.gd",
	"res://client/fight/fight_screen.gd", "res://client/fight/messages.gd", "res://tests/client/test_fight_layout.gd"]


## Every room with a background has a floor line between 0 and 1; a room without one uses the default.
func test_every_room_has_a_floor_line() -> void:
	for file: String in DirAccess.get_files_at(Backgrounds.BG_DIR):
		if not file.ends_with(Backgrounds.BG_EXTENSION):
			continue
		# room: the room the file draws.
		var room: String = file.get_basename()
		assert_true(Backgrounds.FLOOR_LINES.has(room), "%s has a measured floor line" % room)
		assert_true(Backgrounds.floor_line(room) > 0.0 and Backgrounds.floor_line(room) < 1.0, room)
	assert_eq(Backgrounds.floor_line("no_such_room"), Backgrounds.DEFAULT_FLOOR_LINE)
	assert_eq(Backgrounds.floor_line(""), Backgrounds.DEFAULT_FLOOR_LINE)


## In the Basement at 1280x720 every sprite's feet are on the floor line; Dudes stand left of every
## enemy, enemies left to right in state order; nothing under the feet reaches the hand area.
func test_sprites_stand_on_the_basement_floor() -> void:
	# frame, screen: the window and the dev fight in it (the Basement).
	var frame: Control = _frame()
	var screen: Control = _screen_in(frame, DevFight.start())  # the dev fight's screen, laid out in frame
	assert_eq(screen.room, "basement")
	_assert_on_floor(screen)
	_free(frame)


## Four Dudes and five enemies fit at 1280x720: every view inside the window, none overlapping
## another, feet on the floor line, sprites shrunk, everything above the hand and its cards.
func test_four_dudes_and_five_enemies_fit() -> void:
	# frame, screen: the window and the crowded fight in it.
	var frame: Control = _frame()
	var screen: Control = _screen_in(frame, _crowded_fight())  # the crowded fight's screen, laid out in frame
	assert_eq(screen._views.size(), CROWD_DUDES + CROWD.size(), "every Dude and enemy has a view")
	_assert_on_floor(screen)
	# rects: every view's rectangle on screen.
	var rects: Array[Rect2] = []
	for view: Node in screen._views.values():
		rects.append((view as Control).get_global_rect())
		assert_true(view.sprite_height < CombatantView.SPRITE_HEIGHT, "a crowded floor shrinks the sprites")
	for i: int in rects.size():
		assert_true(Rect2(Vector2.ZERO, WINDOW).encloses(rects[i]), "view inside the window: %s" % rects[i])
		for j: int in range(i + 1, rects.size()):
			assert_false(rects[i].intersects(rects[j]), "views %s and %s do not overlap" % [rects[i], rects[j]])
	# cards_top: the highest card's top edge.
	var cards_top: float = INF
	for card: Node in screen._hand_box.get_children():
		cards_top = minf(cards_top, (card as Control).get_global_rect().position.y)
	for rect: Rect2 in rects:
		assert_true(rect.end.y <= cards_top, "view %s ends above the cards (%s)" % [rect, cards_top])
	_free(frame)


## The pure slot plan: one rect per view, all the same width and height, the more crowded side never
## wider than its part of the floor, and the parts under the feet end above the hand.
func test_slot_plan() -> void:
	for counts: Array in [[1, 1], [1, 3], [2, 5], [4, 5], [4, 1]]:
		# plan: the layout for these counts in the window.
		var plan: Dictionary = FloorLayout.slots(WINDOW, 0.6, 0.7, 96.0, counts[0], counts[1])
		assert_eq(plan["dudes"].size(), counts[0])
		assert_eq(plan["enemies"].size(), counts[1])
		assert_true(plan["feet_y"] + CombatantView.UNDER_HEIGHT <= WINDOW.y * 0.7, "%s: above the hand" % [counts])
		assert_true(plan["feet_y"] - plan["sprite_height"] - CombatantView.INTENT_HEIGHT >= 96.0, "%s: below the top strip" % [counts])
		for rect: Rect2 in plan["dudes"]:
			assert_true(rect.end.x <= WINDOW.x * FloorLayout.DUDE_SIDE_END + 0.01, "%s: Dude on the left" % [counts])
		for rect: Rect2 in plan["enemies"]:
			assert_true(rect.position.x >= WINDOW.x * FloorLayout.ENEMY_SIDE_START - 0.01, "%s: enemy on the right" % [counts])
			assert_true(rect.end.x <= WINDOW.x, "%s: inside the window" % [counts])
	# low: a floor line so low the bars would reach the hand.
	var low: Dictionary = FloorLayout.slots(WINDOW, 0.69, 0.7, 96.0, 1, 1)
	assert_true(low["feet_y"] + CombatantView.UNDER_HEIGHT <= WINDOW.y * 0.7 + 0.01, "a low floor line is raised above the hand")


## At the start of a solo fight no badge shows a 0 and the old text lines are gone; values that are
## not 0 get one badge each, in order, with "k / n" for broken arms and "current / threshold" for Ick.
func test_badges_show_only_values_that_are_not_zero() -> void:
	# started: the dev fight, drawn as it starts.
	var started: Dictionary = DevFight.start()
	var screen: Control = _screen(started)  # the dev fight's screen, as it starts
	for view: Node in screen._views.values():
		for badge: Node in view.badges():
			assert_ne(badge.value_text, "0", "%s shows a 0 badge (%s)" % [view.id, badge.key])
	# lines, text: everything drawn on the floor (the Dudes and enemies) and the turn label.
	var lines: Array[String] = [screen._header.text]
	screen._collect_text(screen._arena, lines)
	var text: String = "\n".join(lines)  # the drawn lines, joined
	for old: String in ["Guard 0", "arms broken", "No arms", "Ick 0", "Draw ", "Discard ", "Tapped ", "Intent", "->", "HP ", "Brews "]:
		assert_false(text.contains(old), "the old text '%s' is gone: %s" % [old, text])
	_free(screen)
	# state: a test copy with one of everything set.
	var state: Dictionary = started["state"].duplicate(true)
	var dude: Dictionary = state["dudes"][0]  # the Dude in the test copy
	dude["guard"] = 6
	dude["swole"] = 2
	dude["chill"] = 1
	dude["statuses"] = {"noodle_arms": 1, "exposed": 2}
	var enemy: Dictionary = state["combat"]["enemies"][0]  # the leftmost enemy in the test copy
	enemy["broken_arms"] = 1
	enemy["ick"] = 3
	enemy["statuses"] = {"faded": 1}
	assert_no_errors(RunState.check(state), "test state")
	screen = _screen({"ruleset": started["ruleset"], "state": state, "player_id": started["player_id"]})
	assert_eq(_badge_pairs(screen._views[dude["player_id"]]), [["guard", "6"], ["swole", "2"], ["chill", "1"], ["exposed", "2"], ["noodle_arms", "1"]])
	assert_eq(_badge_pairs(screen._views[enemy["uid"]]), [["faded", "1"], ["broken_arms", "1 / %d" % enemy["arm_count"]], ["ick", "3 / %d" % enemy["ick_threshold"]]])
	for badge: Node in screen._views[enemy["uid"]].badges():
		assert_false(badge.uses_fallback(), "%s has an icon" % badge.key)
	_free(screen)


## An attack intent shows its damage over the enemy's head as the core works it out (the move's amount
## with no modifiers, more against an Exposed Dude, "AxH" for several hits); defend shows its own icon;
## an enemy the core says will skip shows the skipped icon. No markers in solo.
func test_intent_icons() -> void:
	# started: the dev fight; its enemies' moves from the data.
	var started: Dictionary = DevFight.start()
	var state: Dictionary = started["state"].duplicate(true)  # a test copy of the start
	var ruleset: Dictionary = started["ruleset"]  # the real content
	var pledge: Dictionary = state["combat"]["enemies"][0]  # the leftmost enemy
	_aim(state, pledge, _move_of(ruleset, pledge["def_id"], "attack"))
	# amount: the attack move's base damage in the data.
	var amount: int = _move_of(ruleset, pledge["def_id"], "attack")["effects"][0]["amount"]
	var screen: Control = _screen({"ruleset": ruleset, "state": state, "player_id": started["player_id"]})  # the fight with the pledge aiming
	# head: what the pledge shows over its head.
	var head: Array[Node] = screen._views[pledge["uid"]].head_badges()
	assert_eq(head.size(), 1, "one intent icon, no target marker in solo")
	assert_eq(head[0].key, "attack")
	assert_eq(head[0].value_text, str(amount), "plain damage")
	assert_true(head[0].tooltip_text.contains("Attack") and head[0].tooltip_text.contains(str(amount)), head[0].tooltip_text)
	_free(screen)
	state["dudes"][0]["statuses"] = {"exposed": 1}
	screen = _screen({"ruleset": ruleset, "state": state, "player_id": started["player_id"]})
	assert_true(int(screen._views[pledge["uid"]].head_badges()[0].value_text) > amount, "more against an Exposed Dude")
	_free(screen)
	state["dudes"][0]["statuses"] = {}
	pledge["grossed_out_skips"] = 1
	screen = _screen({"ruleset": ruleset, "state": state, "player_id": started["player_id"]})
	assert_eq(screen._views[pledge["uid"]].head_badges()[0].key, "skipped", "a Grossed Out enemy shows it will skip")
	assert_true(screen._views[pledge["uid"]].head_badges()[0].tooltip_text.contains(Messages.SKIP_REASONS[Statuses.SKIP_GROSSED_OUT]))
	_free(screen)
	# entry: a made-up model entry for a three-hit attack, to check the number's form.
	var entry: Dictionary = {"alive": true, "intent": "attack", "skip": "", "targets": ["A"],
		"intent_damage": {"amount": 5, "hits": 3, "up_to": false}}
	assert_eq(CombatantView.intent_for(entry)["value"], "5x3")
	entry["intent_damage"] = {"amount": 30, "hits": 1, "up_to": true}
	assert_eq(CombatantView.intent_for(entry)["tooltip"], "up to 30 at A")
	entry["intent"] = "defend"
	entry["intent_damage"] = {"amount": -1, "hits": 1, "up_to": false}
	assert_eq(CombatantView.intent_for(entry), {"key": "defend", "value": "", "tooltip": "at A"})


## With more than one Dude an attack intent carries one marker per targeted Dude, coloured like that
## Dude's seat marker; clicking a view in the crowded layout still targets it.
func test_coop_target_markers() -> void:
	# frame, screen: the crowded fight.
	var frame: Control = _frame()
	var started: Dictionary = _crowded_fight()  # the crowded fight
	var screen: Control = _screen_in(frame, started)  # its screen, laid out
	# model: what the screen drew from.
	var model: Dictionary = FightModel.build(started["ruleset"], screen._state, screen._player_id)
	for dude: Dictionary in model["dudes"]:
		# seat: the Dude's seat marker.
		var seat: Array[Node] = screen._views[dude["player_id"]].head_badges()
		assert_eq(seat.size(), 1, "a seat marker over each Dude in co-op")
		assert_eq(seat[0].modulate, CombatantView.SEAT_COLORS[dude["seat"]])
	# markers: attack markers counted over all enemies.
	var markers: int = 0
	for enemy: Dictionary in model["enemies"]:
		# head: the enemy's intent icon and markers.
		var head: Array[Node] = screen._views[enemy["uid"]].head_badges()
		if enemy["intent"] == "" or enemy["skip"] != "":
			continue
		assert_eq(head.size(), 1 + enemy["target_seats"].size(), "%s: one marker per target" % enemy["uid"])
		for i: int in enemy["target_seats"].size():
			assert_eq(head[1 + i].key, "target")
			assert_eq(head[1 + i].modulate, CombatantView.SEAT_COLORS[enemy["target_seats"][i]], "marker coloured like the Dude")
			assert_true(head[1 + i].tooltip_text.contains(enemy["targets"][i]))
			markers += 1
	assert_true(markers > 0, "some enemy aims at a Dude")
	# version: before the click.
	var version: int = screen._state["state_version"]
	screen.press_card(_enemy_card(screen))
	screen._views[model["enemies"][CROWD.size() - 1]["uid"]].pressed.emit()
	assert_eq(screen._state["state_version"], version + 1, "the click on the rightmost enemy picked it")
	_free(frame)


## Hype, the piles and the Bro Meter are off the characters: an orb beside the hand, pile icons in the
## bottom corners and a small bar, each with the state's values and a tooltip naming it; the turn label
## no longer carries the Bro Meter. Task 045 adds what each one does on the tooltip's second line, so
## the first line is checked here (tests/client/test_tooltips.gd checks the rest).
func test_turn_info_off_the_characters() -> void:
	# frame, screen: the dev fight, with the Bro Meter part full on a test copy.
	var started: Dictionary = DevFight.start()
	started["state"]["bro_meter"] = 4
	var frame: Control = _frame()  # the stand-in window
	var screen: Control = _screen_in(frame, started)  # the dev fight in it
	# dude: the local Dude.
	var dude: Dictionary = screen._state["dudes"][0]
	assert_eq(screen._hype_badge.value_text, str(dude["hype"]))
	assert_eq(screen._hype_badge.tooltip_text.get_slice("\n", 0), "Hype: %d / %d" % [dude["hype"], dude["hype_per_turn"]])
	assert_eq(screen._draw_badge.value_text, str(dude["draw_pile"].size()))
	assert_eq(screen._discard_badge.value_text, str(dude["discard_pile"].size()))
	assert_eq(screen._tapped_badge.value_text, str(dude["tapped_pile"].size()))
	assert_eq(screen._draw_badge.tooltip_text.get_slice("\n", 0), "Draw pile: %d" % dude["draw_pile"].size())
	assert_eq(screen._tapped_badge.tooltip_text.get_slice("\n", 0), "Tapped: %d" % dude["tapped_pile"].size())
	assert_eq(screen._bro_bar.value, 4.0)
	assert_eq(screen._bro_box.tooltip_text.get_slice("\n", 0), "Bro Meter: 4 / %d" % started["ruleset"]["constants"]["BRO_METER_MAX"])
	assert_eq(screen._header.text, "Turn 1 - player phase")
	# hand: the hand's rectangle on screen.
	var hand: Rect2 = screen._hand_box.get_global_rect()
	assert_true(screen._hype_badge.get_global_rect().end.x <= hand.position.x, "Hype is beside the hand, on its left")
	assert_true(screen._draw_badge.get_global_rect().position.x < WINDOW.x / 4.0, "draw pile bottom-left")
	assert_true(screen._draw_badge.get_global_rect().end.y > WINDOW.y * 0.9, "draw pile at the bottom")
	for pile: Control in [screen._discard_badge, screen._tapped_badge]:
		assert_true(pile.get_global_rect().position.x > WINDOW.x * 0.75, "%s bottom-right" % pile.key)
		assert_true(pile.get_global_rect().end.y > WINDOW.y * 0.9, "%s at the bottom" % pile.key)
		assert_true(Rect2(Vector2.ZERO, WINDOW).encloses(pile.get_global_rect()), "%s inside the window" % pile.key)
	_free(frame)


## Every badge, intent icon, marker and pile carries its name and value as tooltip text, and the HP
## bar says HP; the names are the icon table's (the GDD's terms).
func test_every_icon_has_a_tooltip() -> void:
	# screen: the crowded fight, which shows the most icons.
	var frame: Control = _frame()
	var screen: Control = _screen_in(frame, _crowded_fight())  # the crowded fight's screen, laid out
	# icons: every badge on screen.
	var icons: Array[Node] = [screen._hype_badge, screen._draw_badge, screen._discard_badge, screen._tapped_badge]
	for view: Node in screen._views.values():
		icons.append_array(view.badges())
		icons.append_array(view.head_badges())
		assert_true(view._hp_bar.tooltip_text.begins_with("HP: "), view._hp_bar.tooltip_text)
	for badge: Node in icons:
		assert_true(badge.tooltip_text.begins_with(Icons.look(badge.key)["name"]), "%s tooltip names it: %s" % [badge.key, badge.tooltip_text])
		if badge.value_text != "":
			assert_true(badge.tooltip_text.contains(badge.value_text.split("x")[0]), "%s tooltip has its value: %s" % [badge.key, badge.tooltip_text])
		assert_ne(badge.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s can be hovered" % badge.key)
	_free(frame)


## Every status id and intent kind in core/schema/ (and every intent kind the data uses) has an icon
## in the one table; every table entry's file exists; a key with no icon falls back to short text
## without an error.
func test_every_status_and_intent_has_an_icon() -> void:
	for status: String in _schema_status_ids():
		assert_true(Icons.has_icon(status), "status %s has an icon" % status)
	for kind: String in _schema_intent_kinds():
		assert_true(Icons.has_icon(kind), "intent kind %s has an icon" % kind)
	for key: String in Icons.ICONS:
		assert_true(ResourceLoader.exists(Icons.icon_path(Icons.ICONS[key]["file"])), "%s's file exists" % key)
		assert_ne(Icons.look(key)["name"], "", "%s has a name" % key)
	for key: String in ["guard", "swole", "chill", "broken_arms", "ick", "attack", "hype", "draw_pile", "discard_pile", "tapped_pile"]:
		assert_true(Icons.has_icon(key), "%s has an icon" % key)
	# missing: how an unknown key is shown.
	var missing: Dictionary = Icons.look("no_such_status")
	assert_true(missing["texture"] == null, "no icon")
	assert_eq(missing["short"], "NOS", "short text instead")
	assert_eq(Icons.icon_path("../project"), "", "no path outside the icon folder")
	# badge: a badge for the unknown key.
	var badge: HBoxContainer = StatBadge.new()
	badge.show_value("no_such_status", "2")
	assert_true(badge.uses_fallback(), "the badge shows its short text")
	assert_eq(badge.tooltip_text, "No Such Status: 2")
	badge.free()
	for reason: String in [Statuses.SKIP_GROSSED_OUT, Statuses.SKIP_FALLEN, Statuses.SKIP_ARMLESS]:
		assert_true(Messages.SKIP_REASONS.has(reason), "skip reason %s has words" % reason)


## Every icon file is recorded in assets/placeholder/README.md as made for this repository.
func test_icons_are_recorded() -> void:
	# readme: the placeholder art record.
	var readme: String = FileAccess.get_file_as_string("res://assets/placeholder/README.md")
	assert_true(readme.contains("## Icons"), "the README has an Icons section")
	for file: String in DirAccess.get_files_at(Icons.ICON_DIR):
		if file.ends_with(Icons.ICON_EXTENSION):
			assert_true(readme.contains("`%s`" % file), "%s is recorded" % file)


## The scripts task 057 added or changed follow the documentation standard (CLAUDE.md), checked with
## Agent A's lint.
func test_scripts_are_documented() -> void:
	for path: String in SCRIPTS:
		for problem: String in Documentation.lint(FileAccess.get_file_as_string(path)):
			fail("%s:%s" % [path, problem])


## Checks that every sprite on a laid-out screen stands with its feet on the room's floor line, Dudes
## left of every enemy, each side left to right in state order.
## screen: a screen laid out in a WINDOW-sized frame.
func _assert_on_floor(screen: Control) -> void:
	# floor_y: the floor line in pixels.
	var floor_y: float = Backgrounds.floor_line(screen.room) * WINDOW.y
	# hand_top: where the hand area begins, in pixels.
	var hand_top: float = (1.0 - screen.HAND_SHARE) * WINDOW.y
	# last_x: the previous view's left edge, to check the order. dudes_end: right edge of the Dudes.
	var last_x: float = -INF
	var dudes_end: float = -INF  # right edge of the rightmost Dude
	for dude: Dictionary in screen._state["dudes"]:
		# view: the Dude's view.
		var view: Button = screen._views[dude["player_id"]]
		assert_true(absf(view.sprite_rect().end.y - floor_y) <= FEET_TOLERANCE, "%s feet %s on the floor %s" % [view.id, view.sprite_rect().end.y, floor_y])
		assert_true(view.get_global_rect().position.x > last_x, "Dudes left to right in state order")
		assert_true(view.get_global_rect().end.y <= hand_top, "%s ends above the hand" % view.id)
		last_x = view.get_global_rect().position.x
		dudes_end = maxf(dudes_end, view.get_global_rect().end.x)
	last_x = -INF
	for enemy: Dictionary in screen._state["combat"]["enemies"]:
		var view: Button = screen._views[enemy["uid"]]  # the enemy's view
		assert_true(absf(view.sprite_rect().end.y - floor_y) <= FEET_TOLERANCE, "%s feet %s on the floor %s" % [view.id, view.sprite_rect().end.y, floor_y])
		assert_true(view.get_global_rect().position.x >= dudes_end, "%s right of every Dude" % view.id)
		assert_true(view.get_global_rect().position.x > last_x, "enemies left to right in state order")
		assert_true(view.get_global_rect().end.y <= hand_top, "%s ends above the hand" % view.id)
		last_x = view.get_global_rect().position.x


## Returns a view's badges as [key, value] pairs, left to right.
## view: a combatant view.
func _badge_pairs(view: Button) -> Array:
	# out: the pairs.
	var out: Array = []
	for badge: Node in view.badges():
		out.append([badge.key, badge.value_text])
	return out


## Returns the status ids core/schema/ lists: the "Status ids" table of core/schema/README.md and
## enemy_def.gd PERIODIC_STATUSES.
func _schema_status_ids() -> Array[String]:
	# ids: the result.
	var ids: Array[String] = []
	# readme: the schema README. section: its "Status ids" section.
	var readme: String = FileAccess.get_file_as_string("res://core/schema/README.md")
	var section: String = readme.get_slice("## Status ids", 1).get_slice("\n## ", 0)  # the README's "Status ids" section
	# row: a table row starting with a backticked id.
	var row := RegEx.create_from_string("(?m)^\\| `(\\w+)` \\|")
	for found: RegExMatch in row.search_all(section):
		ids.append(found.get_string(1))
	for status: String in EnemyDef.PERIODIC_STATUSES:
		if not ids.has(status):
			ids.append(status)
	assert_true(ids.size() >= 7, "the schema lists the statuses: %s" % [ids])
	return ids


## Returns the intent kinds core/schema/ names (enemy_def.gd MOVE_SPEC's "intent" comment) and every
## intent kind a move in data/enemies/ uses.
func _schema_intent_kinds() -> Array[String]:
	# kinds: the result.
	var kinds: Array[String] = []
	# source: enemy_def.gd's text. line: its comment on "intent".
	var source: String = FileAccess.get_file_as_string("res://core/schema/enemy_def.gd")
	var line: String = ""  # the comment line naming the intent kinds
	for text: String in source.split("\n"):
		if text.contains("Intent icon key"):
			line = text
	# word: a quoted word.
	var word := RegEx.create_from_string("\"(\\w+)\"")
	for found: RegExMatch in word.search_all(line):
		kinds.append(found.get_string(1))
	assert_true(kinds.has("attack") and kinds.has("defend"), "the schema names intent kinds: %s" % [kinds])
	for enemy: Dictionary in DevFight.start()["ruleset"]["enemies"].values():
		for move: Dictionary in enemy["moves"]:
			if not kinds.has(move["intent"]):
				kinds.append(move["intent"])
	return kinds


## Returns the first move of an enemy whose intent kind is this one; fails when there is none.
## ruleset: content. def_id: the enemy. kind: an intent kind.
func _move_of(ruleset: Dictionary, def_id: String, kind: String) -> Dictionary:
	for move: Dictionary in ruleset["enemies"][def_id]["moves"]:
		if move["intent"] == kind:
			return move
	fail("%s has no %s move" % [def_id, kind])
	return {}


## Sets an enemy's intent to a move aimed at the first Dude (test setup on a fresh state copy).
## state: the state. enemy: one of its enemies. move: a move of that enemy.
func _aim(state: Dictionary, enemy: Dictionary, move: Dictionary) -> void:
	enemy["intent"] = {"move_id": move["id"], "target_ids": [state["dudes"][0]["player_id"]]}


## Returns a started fight shaped like DevFight.start(): CROWD_DUDES copies of the first Dude in the
## data against the CROWD enemies, built by the core's own builders, with a full hand.
func _crowded_fight() -> Dictionary:
	# ruleset: the real content. dude_ids: the Dude ids, sorted.
	var ruleset: Dictionary = DevFight.start()["ruleset"]
	var dude_ids: Array = ruleset["dudes"].keys()  # every Dude id, sorted
	dude_ids.sort()
	# party: the run state. started: the fight.
	var party: Dictionary = Party.build_run_state(ruleset, SEED, [dude_ids[0], dude_ids[0], dude_ids[0], dude_ids[0]])
	assert_eq(party["error"], "")
	var started: Dictionary = Fight.start_fight(ruleset, party["state"], CROWD)  # the fight against CROWD
	assert_eq(started["error"], "")
	assert_eq(started["state"]["combat"]["enemies"].size(), CROWD.size(), "five enemies stand")
	return {"ruleset": ruleset, "state": started["state"], "player_id": started["state"]["dudes"][0]["player_id"]}


## Returns the uid of a card in the local hand that targets an enemy; fails when there is none.
## screen: a fight screen.
func _enemy_card(screen: Control) -> String:
	# dude: the local Dude.
	var dude: Dictionary = screen._state["dudes"][0]
	for uid: String in dude["hand"]:
		if screen._ruleset["cards"][dude["cards"][uid]["def_id"]]["target"] == "enemy":
			return uid
	fail("no enemy-targeting card in hand")
	return ""


## Returns a WINDOW-sized frame in the tree for a screen to fill.
func _frame() -> Control:
	# frame: the stand-in window.
	var frame := Control.new()
	frame.size = WINDOW
	(Engine.get_main_loop() as SceneTree).root.add_child(frame)
	return frame


## Returns a fight screen, with no animation time, inside a frame and laid out.
## frame: from _frame(). started: a DevFight.start()-shaped result.
func _screen_in(frame: Control, started: Dictionary) -> Control:
	# screen: the new screen.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.setup(Core.new(), started["ruleset"], started["state"], started["player_id"])
	frame.add_child(screen)
	_layout(screen)
	assert_eq(screen.size, WINDOW, "the screen fills the window")
	return screen


## Returns a fight screen in the tree, with no animation time, not laid out.
## started: a DevFight.start()-shaped result.
func _screen(started: Dictionary) -> Control:
	# screen: the new screen.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.setup(Core.new(), started["ruleset"], started["state"], started["player_id"])
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


## Removes a node from the tree and frees it now.
## node: a screen or frame added by this file.
func _free(node: Node) -> void:
	node.get_parent().remove_child(node)
	node.free()


## Lays out every container under node now, top down, as the next frame would (tests cannot wait
## for a frame). Two passes, so sizes found in the first settle in the second.
## node: where to start.
func _layout(node: Node) -> void:
	for pass_number: int in 2:
		_sort(node)


## Sends NOTIFICATION_SORT_CHILDREN to node if it is a container, then to everything under it.
## node: where to start.
func _sort(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child: Node in node.get_children():
		_sort(child)
