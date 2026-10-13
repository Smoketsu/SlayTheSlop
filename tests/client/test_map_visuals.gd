## Tests for the map screen's look (task 061, client/run/map_screen.gd and client/visual/map_art.gd)
## on real states from a fixed-seed run (tests/client/run_choices_drive.gd). Lane: tools/client (taken
## over by Agent A from Agent B, 2026-10-13). The map's clicks and requests are tested in
## test_map_screen.gd and are unchanged.
## Acceptance checks: a floor backdrop; every node type has an icon or a text fallback, its name in the
## tooltip; the Boss is bigger with the boss's portrait; a Dude token on the party's node that slides
## when the party moves; visited nodes dimmed; co-op vote markers in seat order; the floor fits 1280x720.
extends "res://tests/framework/test_case.gd"

const Drive := preload("res://tests/client/run_choices_drive.gd")
const MapScreen := preload("res://client/run/map_screen.gd")
const MapArt := preload("res://client/visual/map_art.gd")
const RunText := preload("res://client/run/run_text.gd")

## The window size the map must fit, in pixels.
const WINDOW := Vector2(1280, 720)
## Every map node type (core/schema/run_state.gd map node "type").
const NODE_TYPES: Array[String] = ["start", "brawl", "rival", "side_quest", "tailgate", "baileys", "loot", "boss"]


## Floor 1 has a backdrop, and every node type has an icon; an unknown type or floor has none (the
## screen then shows the name or a plain colour).
func test_every_node_type_has_an_icon() -> void:
	assert_true(MapArt.backdrop_for(1) != null, "floor 1 has a backdrop")
	for node_type: String in NODE_TYPES:
		assert_true(MapArt.icon_for(node_type) != null, "%s has an icon" % node_type)
	assert_true(MapArt.icon_for("no_such_type") == null, "an unknown type has no icon")
	assert_true(MapArt.icon_for("../secret") == null, "a bad name never becomes a path")
	assert_true(MapArt.backdrop_for(99) == null, "a floor with no backdrop has none")


## A node type with no icon is drawn as its name, so nothing is ever blank.
func test_missing_icon_falls_back_to_the_name() -> void:
	# begun: a new run. state: a copy with one node's type changed to one with no icon.
	var begun: Dictionary = Drive.start()
	if begun.is_empty():
		fail("the run starts")
		return
	var state: Dictionary = begun["state"].duplicate(true)  # display-only copy
	state["map"]["nodes"][1]["type"] = "no_such_type"
	# screen: the map screen on it.
	var screen: Control = MapScreen.new()
	screen.show_state(begun["rules"], state, state["dudes"][0]["player_id"])
	# button: the changed node's button.
	var button: Button = screen.node_buttons[state["map"]["nodes"][1]["id"]]
	assert_true(button.icon == null and button.text == RunText.node_label("no_such_type"), "drawn as its name: %s" % button.text)
	screen.free()


## On every voting state of the run, laid out at 1280x720: every node has an icon and its name in the
## tooltip, the Boss is bigger and shows the floor boss's portrait, the token stands on the party's
## node, visited nodes are dimmed, and every node sits inside the window (no scrolling needed).
func test_map_states_look_right_at_1280x720() -> void:
	# played: the run.
	var played: Dictionary = Drive.play()
	if played.is_empty():
		fail("the run starts")
		return
	# boss_id: the floor boss's enemy id on the real data.
	var boss_id: String = MapArt.boss_portrait_id(played["rules"], 1)
	assert_eq(boss_id, "goblin_king_chad", "floor 1's only boss is shown on the Boss node")
	for state: Dictionary in played["map_states"]:
		# frame, screen: the window and the map screen in it, laid out.
		var frame := Control.new()
		frame.size = WINDOW
		(Engine.get_main_loop() as SceneTree).root.add_child(frame)
		var screen: Control = MapScreen.new()  # the map screen, filling frame
		frame.add_child(screen)
		screen.show_state(played["rules"], state, state["dudes"][0]["player_id"])
		for pass_number: int in 2:
			_sort(screen)
		# here: the party's node id.
		var here: String = state["map"]["nodes"][state["node_index"]]["id"]
		assert_eq(screen.token_node_id, here, "the token stands on the party's node")
		assert_true(screen._token.visible, "the token is shown")
		for node: Dictionary in state["map"]["nodes"]:
			# button: the node's button.
			var button: Button = screen.node_buttons[node["id"]]
			assert_true(button.icon != null, "%s has an icon" % node["id"])
			assert_eq(button.text, "", "%s shows no text on the button" % node["id"])
			assert_true(button.tooltip_text.begins_with(RunText.node_label(node["type"])), "%s is named on hover" % node["id"])
			assert_true(Rect2(Vector2.ZERO, WINDOW).encloses(button.get_global_rect()), "%s fits the window: %s" % [node["id"], button.get_global_rect()])
			if node["type"] == "boss":
				assert_eq(button.size, MapScreen.BOSS_SIZE, "the Boss is bigger")
				assert_true(button.tooltip_text.contains(played["rules"]["enemies"][boss_id]["name"]), "the Boss names the boss")
			else:
				assert_eq(button.size, MapScreen.NODE_SIZE)
			if node["id"] != here and state["path"].has(node["id"]):
				assert_eq(button.modulate, MapScreen.VISITED_TINT, "%s dimmed as visited" % node["id"])
		frame.free()


## When the party moves, the token slides from the old node to the new one (a tween runs) and ends
## up on the new node.
func test_token_slides_to_the_next_node() -> void:
	# played: the run; its first two voting states are on different nodes.
	var played: Dictionary = Drive.play()
	if played.is_empty() or played["map_states"].size() < 2:
		fail("the run reaches two votes")
		return
	# screen: one screen in the tree, redrawn as the run screen does.
	var screen: Control = MapScreen.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	# first, second: the two states.
	var first: Dictionary = played["map_states"][0]
	var second: Dictionary = played["map_states"][1]
	screen.show_state(played["rules"], first, first["dudes"][0]["player_id"])
	assert_true(screen._token_tween == null, "the first draw places the token without sliding")
	screen.show_state(played["rules"], second, second["dudes"][0]["player_id"])
	assert_eq(screen.token_node_id, second["map"]["nodes"][second["node_index"]]["id"])
	assert_true(screen._token_tween != null and screen._token_tween.is_valid(), "the token slides")
	screen._token_tween.custom_step(MapScreen.TOKEN_SLIDE_SECONDS + 0.1)
	assert_true(screen._token.position.distance_to(screen._token_spot(screen.token_node_id)) < 0.5, "it ends on the new node")
	screen.get_parent().remove_child(screen)
	screen.free()


## In co-op every player's vote shows as a marker on the node they voted for, in seat order; in solo
## there are none.
func test_vote_markers_in_seat_order() -> void:
	# begun: a new run.
	var begun: Dictionary = Drive.start()
	if begun.is_empty():
		fail("the run starts")
		return
	# state: a display-only copy with a second Dude and both voting for the same node.
	var state: Dictionary = begun["state"].duplicate(true)
	# second: a copy of the first Dude in seat 2.
	var second: Dictionary = state["dudes"][0].duplicate(true)
	second["player_id"] = "p2"
	state["dudes"].append(second)
	state["party_size"] = 2
	# link: the node both vote for.
	var link: String = state["map"]["nodes"][0]["links"][0]
	state["votes"] = {"p2": link, state["dudes"][0]["player_id"]: link}
	# screen: the map screen.
	var screen: Control = MapScreen.new()
	screen.show_state(begun["rules"], state, state["dudes"][0]["player_id"])
	assert_eq(screen.vote_markers, {link: [state["dudes"][0]["player_id"], "p2"]}, "one marker per vote, in seat order")
	state["party_size"] = 1
	state["dudes"].pop_back()
	state["votes"] = {state["dudes"][0]["player_id"]: link}
	screen.show_state(begun["rules"], state, state["dudes"][0]["player_id"])
	assert_eq(screen.vote_markers, {}, "no markers in solo")
	screen.free()


## With two boss candidates on a floor the Boss node keeps its crown icon (the map must not give away
## which boss was rolled).
func test_two_bosses_show_no_portrait() -> void:
	# rules: a tiny ruleset with two floor-1 bosses.
	var rules: Dictionary = {"enemies": {"a": {"tier": "boss"}, "b": {"tier": "boss"}, "c": {"tier": "normal"}},
		"encounters": {"x": {"floor": 1, "node": "boss", "enemies": ["a", "c"]}, "y": {"floor": 1, "node": "boss", "enemies": ["b"]}}}
	assert_eq(MapArt.boss_portrait_id(rules, 1), "")
	rules["encounters"].erase("y")
	assert_eq(MapArt.boss_portrait_id(rules, 1), "a", "one boss: its portrait")
	assert_eq(MapArt.boss_portrait_id(rules, 2), "", "no boss on floor 2")


## Lays out a node and everything under it now (as tests/client/test_fight_layout.gd does).
## node: where to start.
func _sort(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child: Node in node.get_children():
		_sort(child)
