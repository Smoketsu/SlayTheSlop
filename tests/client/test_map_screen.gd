## Tests for the map screen (task 020, client/run/map_screen.gd) on real states: a fixed-seed run on
## the real data (tests/client/run_choices_drive.gd). Lane: tools/client (Agent B).
## Acceptance check: "Map: shows floor 1's nodes and links from run_state.map and the party's
## position; choosing a node sends vote_node", and each request passes request.gd check().
extends "res://tests/framework/test_case.gd"

const Drive := preload("res://tests/client/run_choices_drive.gd")
const MapScreen := preload("res://client/run/map_screen.gd")
const RunText := preload("res://client/run/run_text.gd")
const Core := preload("res://core/core.gd")
const Request := preload("res://core/schema/request.gd")
const FloorMap := preload("res://core/run/map/floor_map.gd")


## Returns a map screen showing the state for the first Dude's player, and the list its requests
## land in. Result: {"screen": the screen (free it), "sent": Array, filled as it emits}.
## rules: the ruleset. state: the run state to show.
func _shown(rules: Dictionary, state: Dictionary) -> Dictionary:
	# screen: a new map screen.
	var screen: Control = MapScreen.new()
	# sent: the requests the screen emits.
	var sent: Array = []
	screen.request_made.connect(func(request: Dictionary) -> void: sent.append(request))
	screen.show_state(rules, state, state["dudes"][0]["player_id"])
	return {"screen": screen, "sent": sent}


## A new run's map: every node of state.map has a button labelled with its themed type, every link is
## drawn once, the entrance is marked as the party's node, and the header names the floor.
func test_every_node_and_link_is_drawn() -> void:
	# begun: a new run on the real data.
	var begun: Dictionary = Drive.start()
	assert_false(begun.is_empty(), "the run starts")
	if begun.is_empty():
		return
	# state: the new run. map: its floor map.
	var state: Dictionary = begun["state"]
	var map: Dictionary = state["map"]
	# shown: the screen.
	var shown: Dictionary = _shown(begun["rules"], state)
	# screen: the map screen.
	var screen: Control = shown["screen"]
	# ids: every node id, in map order. links: every link, in map order.
	var ids: Array = []
	var links: Array = []
	for node: Dictionary in map["nodes"]:
		ids.append(node["id"])
		for link: String in node["links"]:
			links.append([node["id"], link])
		# button: this node's button.
		var button: Button = screen.node_buttons.get(node["id"])
		assert_true(button != null, "%s has a button" % node["id"])
		if button != null:
			assert_true(button.tooltip_text.begins_with(RunText.node_label(node["type"])), "%s is named %s on hover" % [node["id"], button.tooltip_text])
	# drawn: the button ids, in map order.
	var drawn: Array = screen.node_buttons.keys()
	assert_eq(drawn, ids, "one button per node")
	assert_eq(screen.drawn_links, links, "one line per link")
	assert_true(screen.node_buttons[ids[0]].tooltip_text.ends_with(MapScreen.HERE_TEXT), "the entrance is where the party stands")
	assert_eq(screen.title_text, "Floor 1: The Basement")
	# dude: the Dude, for the line under the header.
	var dude: Dictionary = state["dudes"][0]
	assert_eq(screen.dude_text, "%s: %d / %d HP, %d Dolla Bills" % [begun["rules"]["dudes"][dude["dude_id"]]["name"],
		dude["hp"], dude["max_hp"], dude["dolla_bills"]])
	for type: String in FloorMap.SHARED_TYPES + [FloorMap.NODE_START, FloorMap.NODE_BOSS]:
		assert_true(RunText.NODE_LABELS.has(type), "%s has a themed label" % type)
	screen.free()


## Only the links of the party's node can be picked, and only while run_phase is "map": the rest are
## disabled and pressing them sends nothing. Checked at every vote of the whole run.
func test_only_linked_nodes_can_be_picked() -> void:
	# played: the run through the screens.
	var played: Dictionary = Drive.play()
	assert_false(played.is_empty(), "the run starts")
	if played.is_empty():
		return
	assert_false(played["map_states"].is_empty(), "the run had votes")
	for state: Dictionary in played["map_states"]:
		# here: the party's node.
		var here: Dictionary = state["map"]["nodes"][state["node_index"]]
		# shown: the screen on this state.
		var shown: Dictionary = _shown(played["rules"], state)
		# screen: the map screen.
		var screen: Control = shown["screen"]
		assert_eq(screen.pickable_ids(), here["links"], "pickable at %s" % here["id"])
		for node: Dictionary in state["map"]["nodes"]:
			assert_eq(screen.node_buttons[node["id"]].disabled, not here["links"].has(node["id"]), "%s disabled" % node["id"])
			if not here["links"].has(node["id"]):
				screen.press_node(node["id"])
		assert_eq(shown["sent"], [], "unlinked nodes send nothing at %s" % here["id"])
		screen.press_node("r99c99")
		assert_eq(shown["sent"], [], "an unknown node sends nothing")
		for node_id: String in state["path"]:
			if node_id != here["id"]:
				assert_eq(screen.node_buttons[node_id].modulate, MapScreen.VISITED_TINT, "%s shown as visited" % node_id)
		assert_true(screen.node_buttons[here["id"]].tooltip_text.ends_with(MapScreen.HERE_TEXT), "%s is where the party stands" % here["id"])
		screen.free()
	# at_node: the first state with an offer open (run_phase "node"): nothing can be picked.
	var at_node: Dictionary = played["offer_states"][0]
	assert_eq(at_node["run_phase"], "node")
	# shown: the screen during a node.
	var shown: Dictionary = _shown(played["rules"], at_node)
	assert_eq(shown["screen"].pickable_ids(), [], "nothing to pick outside the map phase")
	for button: Button in shown["screen"].node_buttons.values():
		assert_true(button.disabled, "every node disabled outside the map phase")
	shown["screen"].free()


## Pressing each linked node emits exactly {"type": "vote_node", "node_id": id}; with player_id and seq
## added it passes request.gd check() and Core.apply() accepts it. The whole run's votes, made through
## the screen, were the bot's and were all accepted.
func test_press_node_sends_an_accepted_vote() -> void:
	# begun: a new run.
	var begun: Dictionary = Drive.start()
	if begun.is_empty():
		fail("the run starts")
		return
	# state: the new run.
	var state: Dictionary = begun["state"]
	# player_id: the local player. seq: the next seq.
	var player_id: String = state["dudes"][0]["player_id"]
	var seq: int = state["dudes"][0]["last_seq"] + 1
	for link: String in state["map"]["nodes"][0]["links"]:
		# shown: a fresh screen on the new run.
		var shown: Dictionary = _shown(begun["rules"], state)
		shown["screen"].press_node(link)
		assert_eq(shown["sent"], [{"type": "vote_node", "node_id": link}], "press %s" % link)
		if shown["sent"].size() == 1:
			# request: completed as the run screen does.
			var request: Dictionary = Drive.completed(shown["sent"][0], player_id, seq)
			assert_no_errors(Request.check(request), "vote for %s" % link)
			# applied: the core's answer.
			var applied: Dictionary = Core.apply(begun["rules"], state, request)
			assert_eq(applied["reject"], "", "the core accepts the vote for %s" % link)
			if applied["reject"] == "":
				assert_eq(applied["state"]["path"], [link], "the party moved to %s" % link)
		shown["screen"].free()
	# played: the whole run.
	var played: Dictionary = Drive.play()
	assert_eq(played["problems"], [], "every vote and choice went through the screens and was accepted")
	assert_eq(played["final"]["path"], played["plan"], "the party walked the planned path")


## The player's own vote is shown (co-op: the party moves only once everyone has voted). Display test
## on a copy of a real state with a vote put in place, as a two-player vote would leave it.
func test_vote_is_shown() -> void:
	# begun: a new run.
	var begun: Dictionary = Drive.start()
	if begun.is_empty():
		fail("the run starts")
		return
	# state: a copy with a vote and a second seat counted (display only).
	var state: Dictionary = begun["state"].duplicate(true)
	# link: the voted node.
	var link: String = state["map"]["nodes"][0]["links"][0]
	state["votes"] = {state["dudes"][0]["player_id"]: link}
	state["party_size"] = 2
	# shown: the screen.
	var shown: Dictionary = _shown(begun["rules"], state)
	# screen: the map screen.
	var screen: Control = shown["screen"]
	# node_type: the voted node's type.
	var node_type: String = state["map"]["nodes"][1]["type"]
	assert_true(screen.node_buttons[link].tooltip_text.ends_with(MapScreen.VOTE_TEXT), "the vote is marked")
	assert_true(screen.prompt_text.begins_with("You voted for %s." % RunText.node_label(node_type)), screen.prompt_text)
	assert_true(screen.prompt_text.ends_with("Votes in: 1 of 2."), screen.prompt_text)
	screen.free()


## The map is redrawn on the same instance after every request, in the scene tree as the run screen
## uses it: each redraw leaves exactly one button per node on the board (no duplicates).
func test_redraw_on_the_same_screen() -> void:
	# played: the run.
	var played: Dictionary = Drive.play()
	if played.is_empty():
		fail("the run starts")
		return
	# screen: one screen in the tree, redrawn on every voting state of the run and the final state.
	var screen: Control = MapScreen.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	for state: Dictionary in played["map_states"] + [played["final"]]:
		screen.show_state(played["rules"], state, state["dudes"][0]["player_id"])
		screen.show_state(played["rules"], state, state["dudes"][0]["player_id"])
		assert_eq(screen._board.get_child_count(), state["map"]["nodes"].size(), "one button per node after a redraw")
	assert_eq(screen.pickable_ids(), [], "nothing to pick once the floor is over")
	screen.get_parent().remove_child(screen)
	screen.free()
