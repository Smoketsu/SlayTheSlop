## Map screen (task 020): floor 1's nodes and links from run_state.map, the party's position, and a
## vote_node request when the player picks a linked node. Interface: client/run/run_screen_api.md.
## Lane: client (Agent B).
##
## Drawn from the state only (CLAUDE.md "The rules core is pure"): one button per map node, placed by
## its row (the entrance at the bottom, the boss at the top) and column (left to right), and a line
## for every link. The party's node (map.nodes[node_index]) is marked "You are here", the nodes on
## run_state.path are dimmed as visited, and the player's vote (run_state.votes) is marked. Only the
## links of the party's node can be picked, and only while run_phase is "map". Everything is built in
## code with Godot's default theme; there is no art file.
extends Control

const RunText := preload("res://client/run/run_text.gd")

## Emitted with {"type": "vote_node", "node_id": <id>} when the player picks a node. The run screen
## adds player_id and seq. request: the request's type and own fields (core/schema/request.gd).
signal request_made(request: Dictionary)

## Size of one node's button on the board, in pixels. Changed only by the client lane.
const NODE_SIZE := Vector2(120, 44)
## Distance between the centres of two neighbouring nodes in a row, in pixels. Changed only by the
## client lane.
const COLUMN_GAP: float = 150.0
## Distance between the centres of two neighbouring rows, in pixels. Changed only by the client lane.
const ROW_GAP: float = 64.0
## Empty space kept around the nodes on the board, in pixels, on every side. Changed only by the
## client lane.
const BOARD_MARGIN: float = 16.0
## Colour and width (pixels) of a link line the party cannot take now. Changed only by the client lane.
const LINK_COLOR := Color(0.55, 0.55, 0.6, 0.6)
## See LINK_COLOR.
const LINK_WIDTH: float = 2.0
## Colour and width (pixels) of a link the party can take now (from the party's node). Changed only
## by the client lane.
const OPEN_LINK_COLOR := Color(1.0, 0.85, 0.3, 1.0)
## See OPEN_LINK_COLOR.
const OPEN_LINK_WIDTH: float = 4.0
## Colour and width (pixels) of a link the party already walked (run_state.path). Changed only by
## the client lane.
const PATH_LINK_COLOR := Color(0.4, 0.8, 1.0, 1.0)
## See PATH_LINK_COLOR.
const PATH_LINK_WIDTH: float = 5.0
## Tint of the party's node button. Changed only by the client lane.
const CURRENT_TINT := Color(1.0, 0.85, 0.3)
## Tint of a node on run_state.path that is not the party's node. Changed only by the client lane.
const VISITED_TINT := Color(0.6, 0.6, 0.65)
## Tint of the node the local player voted for. Changed only by the client lane.
const VOTED_TINT := Color(0.5, 1.0, 0.5)
## Second line of the party's node button. Changed only by the client lane.
const HERE_TEXT: String = "You are here"
## Second line of the node the local player voted for. Changed only by the client lane.
const VOTE_TEXT: String = "Your vote"

## The header line ("Floor 1: The Basement"), as last drawn. Read by tests.
var title_text: String = ""
## The local Dude's line (name, HP, Dolla Bills, as the state holds them), as last drawn. Read by tests.
var dude_text: String = ""
## The instruction or vote line under the header, as last drawn. Read by tests.
var prompt_text: String = ""
## Node id -> its Button on the board, for every node of the map last drawn. Read by tests.
var node_buttons: Dictionary = {}
## Every link line drawn, as [from node id, to node id], in map order. Read by tests.
var drawn_links: Array = []

## The run state last drawn; read only, never changed. {} before the first show_state().
var _state: Dictionary = {}
## The local player's id ("p1".."p4") from the last show_state().
var _player_id: String = ""
## Node ids that can be voted for now: the party node's links while run_phase is "map", else none.
var _pickable: Array = []
## Node id -> the centre of its button on the board, in board pixels, for drawing the links.
var _centres: Dictionary = {}
## The heading label. Built once in _build().
var _title: Label
## The local Dude's label. Built once in _build().
var _dude_label: Label
## The instruction or vote label. Built once in _build().
var _prompt: Label
## The board the node buttons sit on and the links are drawn on. Built once in _build().
var _board: Control


## Builds the fixed layout once: a header, the Dude's line, the prompt, and a scrolling board.
func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# column: everything, top to bottom.
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_dude_label = Label.new()
	_dude_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_dude_label)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_prompt)
	# scroll: lets a map taller or wider than the window scroll.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_board = Control.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_board.draw.connect(_draw_links)
	scroll.add_child(_board)


## Redraws the map from a run state snapshot; reads only. May be called again on the same screen
## after every applied request: the old node buttons are removed first.
## ruleset: the read-only content. state: the run state. player_id: the local player.
func show_state(ruleset: Dictionary, state: Dictionary, player_id: String) -> void:
	_state = state
	_player_id = player_id
	for button: Button in node_buttons.values():
		_board.remove_child(button)
		button.queue_free()
	node_buttons = {}
	drawn_links = []
	_centres = {}
	_pickable = []
	# map: the floor map, {} before one exists.
	var map: Dictionary = state.get("map", {})
	# nodes: the map's nodes, ordered by row then column.
	var nodes: Array = map.get("nodes", [])
	# dude: the local Dude, or {} when player_id is not in the run.
	var dude: Dictionary = _dude(state, player_id)
	title_text = RunText.floor_title(state.get("floor", 1))
	dude_text = RunText.dude_line(ruleset, dude) if not dude.is_empty() else ""
	if nodes.is_empty():
		prompt_text = ""
		_show_labels()
		return
	# here: the party's node.
	var here: Dictionary = nodes[clampi(state["node_index"], 0, nodes.size() - 1)]
	if state["run_phase"] == "map":
		_pickable = here["links"].duplicate()
	# vote: the node id the local player voted for, or "".
	var vote: String = state.get("votes", {}).get(player_id, "")
	prompt_text = _prompt_for(state, nodes, vote)
	_layout(nodes)
	for node: Dictionary in nodes:
		_add_button(node, node["id"] == here["id"], state["path"].has(node["id"]), node["id"] == vote)
		for link: String in node["links"]:
			drawn_links.append([node["id"], link])
	_show_labels()
	_board.queue_redraw()


## Votes for a node, exactly as clicking its button does: emits vote_node when the node can be
## picked now, and does nothing otherwise (its button is disabled). Test hook.
## node_id: a map node id, "r<row>c<column>".
func press_node(node_id: String) -> void:
	if not _pickable.has(node_id):
		return
	request_made.emit({"type": "vote_node", "node_id": node_id})


## Returns the ids of the nodes that can be voted for now, in link (column) order. Read by tests.
func pickable_ids() -> Array:
	return _pickable.duplicate()


## Returns the local player's Dude in the state, or {} when the player is not in it.
## state: the run state. player_id: the local player.
static func _dude(state: Dictionary, player_id: String) -> Dictionary:
	for dude: Dictionary in state.get("dudes", []):
		if dude["player_id"] == player_id:
			return dude
	return {}


## Returns the line under the header: who still has to vote, or what the player voted for.
## state: the run state. nodes: the map's nodes. vote: the local player's vote, or "".
static func _prompt_for(state: Dictionary, nodes: Array, vote: String) -> String:
	if state["run_phase"] != "map":
		return ""
	# text: the line being built.
	var text: String = "Pick where the party goes next."
	if vote != "":
		for node: Dictionary in nodes:
			if node["id"] == vote:
				text = "You voted for %s. Waiting for the party." % RunText.node_label(node["type"])
	if state["party_size"] > 1:
		text += " Votes in: %d of %d." % [state["votes"].size(), state["party_size"]]
	return text


## Works out every node's centre on the board and sizes the board to fit: rows bottom to top from
## the entrance, each row centred, columns left to right.
## nodes: the map's nodes.
func _layout(nodes: Array) -> void:
	# per_row: row -> how many nodes it has.
	var per_row: Dictionary = {}
	# top_row: the highest row number (the boss row).
	var top_row: int = 0
	for node: Dictionary in nodes:
		per_row[node["row"]] = per_row.get(node["row"], 0) + 1
		top_row = maxi(top_row, node["row"])
	# widest: the most nodes in one row.
	var widest: int = 1
	for row: int in per_row:
		widest = maxi(widest, per_row[row])
	# board_size: room for the widest row and every row, plus the margins.
	var board_size := Vector2(COLUMN_GAP * (widest - 1) + NODE_SIZE.x, ROW_GAP * top_row + NODE_SIZE.y) + Vector2.ONE * BOARD_MARGIN * 2
	_board.custom_minimum_size = board_size
	for node: Dictionary in nodes:
		# offset: how far this node sits from its row's middle, in columns.
		var offset: float = node["column"] - (per_row[node["row"]] - 1) / 2.0
		_centres[node["id"]] = Vector2(board_size.x / 2.0 + offset * COLUMN_GAP,
			BOARD_MARGIN + NODE_SIZE.y / 2.0 + (top_row - node["row"]) * ROW_GAP)


## Adds one node's button to the board.
## node: the map node. is_here: it is the party's node. visited: it is on run_state.path.
## voted: the local player voted for it.
func _add_button(node: Dictionary, is_here: bool, visited: bool, voted: bool) -> void:
	# button: the node's button.
	var button := Button.new()
	button.text = RunText.node_label(node["type"])
	if is_here:
		button.text += "\n" + HERE_TEXT
		button.modulate = CURRENT_TINT
	elif voted:
		button.text += "\n" + VOTE_TEXT
		button.modulate = VOTED_TINT
	elif visited:
		button.modulate = VISITED_TINT
	button.disabled = not _pickable.has(node["id"])
	button.size = NODE_SIZE
	button.position = _centres[node["id"]] - NODE_SIZE / 2.0
	button.pressed.connect(press_node.bind(node["id"]))
	node_buttons[node["id"]] = button
	_board.add_child(button)


## Copies the drawn texts into the labels.
func _show_labels() -> void:
	_title.text = title_text
	_dude_label.text = dude_text
	_prompt.text = prompt_text


## Draws every link line on the board, under the buttons: walked links, then open links, brightest
## last so they stay on top. Called by the board's draw signal.
func _draw_links() -> void:
	# walked: "from>to" for each link the party has taken, from the entrance along run_state.path.
	var walked: Dictionary = {}
	if not _state.is_empty() and not _state.get("map", {}).get("nodes", []).is_empty():
		# previous: the node walked from; the entrance first.
		var previous: String = _state["map"]["nodes"][0]["id"]
		for node_id: String in _state["path"]:
			walked[previous + ">" + node_id] = true
			previous = node_id
	# here: the party's node id, whose links are open while voting.
	var here: String = ""
	if not _pickable.is_empty():
		here = _state["map"]["nodes"][_state["node_index"]]["id"]
	# layers: [plain, walked, open] links, drawn in that order.
	var layers: Array = [[], [], []]
	for link: Array in drawn_links:
		if not _centres.has(link[0]) or not _centres.has(link[1]):
			continue
		if walked.has(link[0] + ">" + link[1]):
			layers[1].append(link)
		elif link[0] == here:
			layers[2].append(link)
		else:
			layers[0].append(link)
	# styles: [colour, width] of each layer.
	var styles: Array = [[LINK_COLOR, LINK_WIDTH], [PATH_LINK_COLOR, PATH_LINK_WIDTH], [OPEN_LINK_COLOR, OPEN_LINK_WIDTH]]
	for layer: int in layers.size():
		for link: Array in layers[layer]:
			_board.draw_line(_centres[link[0]], _centres[link[1]], styles[layer][0], styles[layer][1])
