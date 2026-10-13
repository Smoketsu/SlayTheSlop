## Map screen (task 020): floor 1's nodes and links from run_state.map, the party's position, and a
## vote_node request when the player picks a linked node. Interface: client/run/run_screen_api.md.
## Lane: client (Agent B).
##
## Drawn from the state only (CLAUDE.md "The rules core is pure"): one button per map node, placed by
## its row (the entrance at the bottom, the boss at the top) and column (left to right), and a line
## for every link. The party's node (map.nodes[node_index]) is marked "You are here", the nodes on
## run_state.path are dimmed as visited, and the player's vote (run_state.votes) is marked. Only the
## links of the party's node can be picked, and only while run_phase is "map".
##
## Task 061 (taken over by Agent A from Agent B, 2026-10-13, at Smoketsu's request) gave it the same
## care as the fight screen: the floor's backdrop (client/visual/map_art.gd) behind everything, the
## header on a dark strip, each node an icon by type (its name and state in the hover tooltip, the
## Boss bigger with the boss's portrait), links drawn as a dashed trail with the walked path solid and
## the links you can take now pulsing, a Dude token standing on the party's node that slides to the next
## one, reachable nodes lifting on hover, and in co-op one seat-coloured marker per player's vote. The
## board fits 1280x720 for the slice's map size, and otherwise scrolls with the party's node kept in
## view. Clicking is unchanged: only vote_node is ever sent.
extends Control

const RunText := preload("res://client/run/run_text.gd")
## [added, task 061] The map's art, the Dude token's sprite, the vote marker icon and seat colours.
const MapArt := preload("res://client/visual/map_art.gd")
const Sprites := preload("res://client/visual/sprites.gd")
const Icons := preload("res://client/visual/icons.gd")
const CombatantView := preload("res://client/visual/combatant_view.gd")

## Emitted with {"type": "vote_node", "node_id": <id>} when the player picks a node. The run screen
## adds player_id and seq. request: the request's type and own fields (core/schema/request.gd).
signal request_made(request: Dictionary)

## Size of one node's button on the board, in pixels. [changed, task 061] A square icon now, not a
## text button. Changed only by the client lane.
const NODE_SIZE := Vector2(58, 58)
## [added, task 061] Size of the Boss node's button, in pixels: bigger than the others. Changed only
## by the client lane.
const BOSS_SIZE := Vector2(96, 96)
## Distance between the centres of two neighbouring nodes in a row, in pixels. Changed only by the
## client lane.
const COLUMN_GAP: float = 150.0
## Distance between the centres of two neighbouring rows, in pixels. Changed only by the client lane.
const ROW_GAP: float = 60.0
## Empty space kept around the nodes on the board, in pixels, on every side. Changed only by the
## client lane.
const BOARD_MARGIN: float = 20.0
## Colour and width (pixels) of a link line the party cannot take now. Changed only by the client lane.
const LINK_COLOR := Color(0.18, 0.12, 0.08, 0.75)
## See LINK_COLOR.
const LINK_WIDTH: float = 3.0
## Colour and width (pixels) of a link the party can take now (from the party's node). Changed only
## by the client lane.
const OPEN_LINK_COLOR := Color(1.0, 0.7, 0.15, 1.0)
## See OPEN_LINK_COLOR.
const OPEN_LINK_WIDTH: float = 5.0
## Colour and width (pixels) of a link the party already walked (run_state.path). Changed only by
## the client lane.
const PATH_LINK_COLOR := Color(0.75, 0.12, 0.1, 1.0)
## See PATH_LINK_COLOR.
const PATH_LINK_WIDTH: float = 5.0
## Tint of the party's node button. Changed only by the client lane.
const CURRENT_TINT := Color(1.0, 0.95, 0.8)
## Tint of a node on run_state.path that is not the party's node: dimmed, as visited. Changed only
## by the client lane.
const VISITED_TINT := Color(0.5, 0.5, 0.5, 0.85)
## Tint of the node the local player voted for. Changed only by the client lane.
const VOTED_TINT := Color(0.7, 1.0, 0.7)
## [added, task 061] Length of one dash of a plain link, in pixels (the trail look). Changed only by
## the client lane.
const DASH_LENGTH: float = 9.0
## [added, task 061] How fast the links you can take now pulse, in pulses per second. Changed only by
## the client lane.
const PULSE_SPEED: float = 1.2
## [added, task 061] Lowest opacity of a pulsing link (0..1); it rises to full and back. Changed only
## by the client lane.
const PULSE_MIN_ALPHA: float = 0.35
## [added, task 061] Size of the Dude token standing on the party's node, in pixels. Changed only by
## the client lane.
const TOKEN_SIZE := Vector2(46, 58)
## [added, task 061] Seconds the token takes to slide to a new node. Changed only by the client lane.
const TOKEN_SLIDE_SECONDS: float = 0.45
## [added, task 061] How much a reachable node grows while hovered (1.0 = not at all). Changed only by
## the client lane.
const HOVER_SCALE: float = 1.18
## [added, task 061] Size of one player's vote marker on a node, in pixels. Changed only by the client
## lane.
const VOTE_MARKER_SIZE := Vector2(18, 18)
## [added, task 061] Tint over the backdrop, darkening it a little so nodes and trails stand out.
## Changed only by the client lane.
const BACKDROP_TINT := Color(0.8, 0.78, 0.75)
## [added, task 061] Colour of the dark strip behind the header text. Changed only by the client lane.
const HEADER_COLOR := Color(0.05, 0.04, 0.03, 0.82)
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
## [added, task 061] The node id the Dude token stands on (the party's node), or "" with no map. Read
## by tests.
var token_node_id: String = ""
## [added, task 061] Node id -> the player ids (in seat order) whose vote marker is on it. Read by tests.
var vote_markers: Dictionary = {}
## [added, task 061] The enemy id whose portrait the Boss node shows, or "" for the crown icon. Read
## by tests.
var boss_portrait: String = ""

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
## [added, task 061] The floor's backdrop, filling the screen. Built once in _init().
var _backdrop: TextureRect
## [added, task 061] Drawn instead of a missing backdrop. Built once in _init().
var _backdrop_fallback: ColorRect
## [added, task 061] Lets the board scroll when it does not fit. Built once in _init().
var _scroll: ScrollContainer
## [added, task 061] Holds the board and, above it, the token and vote markers; sized to the board.
## Built once in _init().
var _canvas: Control
## [added, task 061] Holds the Dude token and the vote markers, over the buttons; ignores the mouse.
## Built once in _init().
var _overlay: Control
## [added, task 061] The Dude token: the local Dude's sprite. Built once in _init().
var _token: TextureRect
## [added, task 061] The ruleset from the last show_state(); read only, for the boss's name.
var _ruleset_cache: Dictionary = {}
## [added, task 061] The running token slide, or null when the token stands still.
var _token_tween: Tween = null
## [added, task 061] Seconds since the screen was built, for the pulse of the open links.
var _clock: float = 0.0


## Builds the fixed layout once: a header, the Dude's line, the prompt, and a scrolling board.
func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop_fallback = ColorRect.new()
	_backdrop_fallback.color = MapArt.FALLBACK_COLOR
	_backdrop_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop_fallback)
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.modulate = BACKDROP_TINT
	add_child(_backdrop)
	# column: everything, top to bottom.
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	# header: the dark strip the three header lines sit on.
	var header := PanelContainer.new()
	# header_style: its look.
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = HEADER_COLOR
	header_style.set_content_margin_all(4)
	header.add_theme_stylebox_override("panel", header_style)
	column.add_child(header)
	# header_lines: the three lines, top to bottom.
	var header_lines := VBoxContainer.new()
	header_lines.add_theme_constant_override("separation", 0)
	header.add_child(header_lines)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lines.add_child(_title)
	_dude_label = Label.new()
	_dude_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lines.add_child(_dude_label)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lines.add_child(_prompt)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_canvas.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_scroll.add_child(_canvas)
	_board = Control.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.draw.connect(_draw_links)
	_canvas.add_child(_board)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_overlay)
	_token = TextureRect.new()
	_token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_token.size = TOKEN_SIZE
	_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_token.visible = false
	_overlay.add_child(_token)


## [added, task 061] Advances the pulse of the links you can take now; redraws only while there are
## such links.
## delta: seconds since the last frame.
func _process(delta: float) -> void:
	_clock += delta
	if not _pickable.is_empty():
		_board.queue_redraw()


## Redraws the map from a run state snapshot; reads only. May be called again on the same screen
## after every applied request: the old node buttons are removed first.
## ruleset: the read-only content. state: the run state. player_id: the local player.
func show_state(ruleset: Dictionary, state: Dictionary, player_id: String) -> void:
	_state = state
	_player_id = player_id
	_ruleset_cache = ruleset
	for button: Button in node_buttons.values():
		_board.remove_child(button)
		button.queue_free()
	node_buttons = {}
	drawn_links = []
	_centres = {}
	_pickable = []
	vote_markers = {}
	for marker: Node in _overlay.get_children():
		if marker != _token:
			_overlay.remove_child(marker)
			marker.queue_free()
	# backdrop: the floor's backdrop, or null for the plain colour.
	var backdrop: Texture2D = MapArt.backdrop_for(int(state.get("floor", 1)))
	_backdrop.texture = backdrop
	_backdrop.visible = backdrop != null
	boss_portrait = MapArt.boss_portrait_id(ruleset, int(state.get("floor", 1)))
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
		token_node_id = ""
		_token.visible = false
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
	_place_token(dude, here["id"])
	_add_vote_markers(state)
	_show_labels()
	_board.queue_redraw()
	_keep_in_view.call_deferred(here["id"])


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
	# top_half: room above the top row's centre (the boss row holds the bigger Boss node).
	var top_half: float = BOSS_SIZE.y / 2.0
	# board_size: room for the widest row and every row, plus the margins.
	var board_size := Vector2(COLUMN_GAP * (widest - 1) + maxf(NODE_SIZE.x, BOSS_SIZE.x),
		top_half + ROW_GAP * top_row + NODE_SIZE.y / 2.0 + TOKEN_SIZE.y / 2.0) + Vector2.ONE * BOARD_MARGIN * 2
	_canvas.custom_minimum_size = board_size
	_board.custom_minimum_size = board_size
	for node: Dictionary in nodes:
		# offset: how far this node sits from its row's middle, in columns.
		var offset: float = node["column"] - (per_row[node["row"]] - 1) / 2.0
		_centres[node["id"]] = Vector2(board_size.x / 2.0 + offset * COLUMN_GAP,
			BOARD_MARGIN + top_half + (top_row - node["row"]) * ROW_GAP)


## Adds one node's button to the board.
## node: the map node. is_here: it is the party's node. visited: it is on run_state.path.
## voted: the local player voted for it.
func _add_button(node: Dictionary, is_here: bool, visited: bool, voted: bool) -> void:
	# button: the node's button. size: its size (the Boss is bigger).
	var button := Button.new()
	var size: Vector2 = BOSS_SIZE if node["type"] == "boss" else NODE_SIZE
	# label: the node's name, shown in its tooltip (and as its text only when it has no icon).
	var label: String = RunText.node_label(node["type"])
	# icon: the node's icon; the Boss shows the boss's portrait when the floor has one boss.
	var icon: Texture2D = MapArt.icon_for(node["type"])
	if node["type"] == "boss" and boss_portrait != "":
		icon = Sprites.texture_for(boss_portrait)
		label += ": " + str(_ruleset_name(boss_portrait))
	button.tooltip_text = label
	if icon != null:
		button.icon = icon
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		# A node you cannot pick now keeps its full colours (Godot would grey a disabled icon); visited
		# nodes are dimmed by VISITED_TINT instead.
		button.add_theme_color_override("icon_disabled_color", Color.WHITE)
	else:
		button.text = label
	if is_here:
		button.tooltip_text += "\n" + HERE_TEXT
		button.modulate = CURRENT_TINT
	elif voted:
		button.tooltip_text += "\n" + VOTE_TEXT
		button.modulate = VOTED_TINT
	elif visited:
		button.modulate = VISITED_TINT
	button.disabled = not _pickable.has(node["id"])
	button.size = size
	button.position = _centres[node["id"]] - size / 2.0
	button.pivot_offset = size / 2.0
	button.pressed.connect(press_node.bind(node["id"]))
	if not button.disabled:
		button.mouse_entered.connect(_hover.bind(button, true))
		button.mouse_exited.connect(_hover.bind(button, false))
	node_buttons[node["id"]] = button
	_board.add_child(button)


## [added, task 061] Returns an enemy's name from the ruleset last shown, or its id.
## enemy_id: an enemy id.
func _ruleset_name(enemy_id: String) -> String:
	return _ruleset_cache.get("enemies", {}).get(enemy_id, {}).get("name", enemy_id)


## [added, task 061] Lifts a reachable node while hovered and lowers it after. Only reachable nodes
## have this connected, so others never react.
## button: the node's button. lifted: true on mouse enter, false on exit.
func _hover(button: Button, lifted: bool) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	# tween: the scale change.
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * (HOVER_SCALE if lifted else 1.0), 0.1)


## [added, task 061] Stands the Dude token on the party's node: on the first draw it is placed there;
## when the party has moved since the last draw it slides from the old node to the new one.
## dude: the local Dude, or {} (no token then). node_id: the party's node id.
func _place_token(dude: Dictionary, node_id: String) -> void:
	if dude.is_empty() or not _centres.has(node_id):
		_token.visible = false
		token_node_id = ""
		return
	_token.texture = Sprites.texture_for(dude["dude_id"])
	_token.size = TOKEN_SIZE
	# target: where the token stands: on the node, its feet near the node's lower edge.
	var target: Vector2 = _token_spot(node_id)
	if _token_tween != null:
		_token_tween.kill()
		_token_tween = null
	if token_node_id != "" and token_node_id != node_id and _token.visible and is_inside_tree():
		_token_tween = _token.create_tween()
		_token_tween.tween_property(_token, "position", target, TOKEN_SLIDE_SECONDS).set_trans(Tween.TRANS_SINE)
	else:
		_token.position = target
	_token.visible = true
	token_node_id = node_id


## [added, task 061] Returns the token's top-left corner when it stands on a node: centred
## horizontally, a little up and to the left so the node's icon still shows.
## node_id: a node with a centre on the board.
func _token_spot(node_id: String) -> Vector2:
	return _centres[node_id] - Vector2(TOKEN_SIZE.x * 0.95, TOKEN_SIZE.y * 0.75)


## [added, task 061] Puts one marker in the player's seat colour on each node a player voted for
## (run_state.votes), side by side under the node, in seat order. Shown in co-op only: in solo the
## vote is the move itself.
## state: the run state.
func _add_vote_markers(state: Dictionary) -> void:
	if int(state.get("party_size", 1)) <= 1:
		return
	# votes: player id -> the node id they voted for.
	var votes: Dictionary = state.get("votes", {})
	# seat: the seat index of each Dude, in state order.
	var seat: int = 0
	for dude: Dictionary in state.get("dudes", []):
		# node_id: this player's vote, or "".
		var node_id: String = votes.get(dude["player_id"], "")
		if node_id != "" and _centres.has(node_id):
			if not vote_markers.has(node_id):
				vote_markers[node_id] = []
			# marker: the vote marker, tinted by seat.
			var marker := TextureRect.new()
			marker.texture = Icons.look("seat")["texture"]
			marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			marker.size = VOTE_MARKER_SIZE
			marker.modulate = CombatantView.SEAT_COLORS[seat % CombatantView.SEAT_COLORS.size()]
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.position = _centres[node_id] + Vector2(-NODE_SIZE.x / 2.0 + vote_markers[node_id].size() * VOTE_MARKER_SIZE.x, NODE_SIZE.y / 2.0)
			_overlay.add_child(marker)
			vote_markers[node_id].append(dude["player_id"])
		seat += 1


## [added, task 061] Scrolls the board so a node is in view (when the board is bigger than the screen).
## node_id: the node to keep in view.
func _keep_in_view(node_id: String) -> void:
	if node_buttons.has(node_id) and is_instance_valid(node_buttons[node_id]) and node_buttons[node_id].is_inside_tree():
		_scroll.ensure_control_visible(node_buttons[node_id])


## Copies the drawn texts into the labels.
func _show_labels() -> void:
	_title.text = title_text
	_dude_label.text = dude_text
	_prompt.text = prompt_text


## Draws every link line on the board, under the buttons: plain links as a dashed trail, then walked
## links solid, then the open links pulsing, brightest last so they stay on top. Called by the board's
## draw signal.
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
	# pulse: the open links' opacity now, between PULSE_MIN_ALPHA and 1.
	var pulse: float = PULSE_MIN_ALPHA + (1.0 - PULSE_MIN_ALPHA) * (0.5 + 0.5 * sin(_clock * TAU * PULSE_SPEED))
	for link: Array in layers[0]:
		_board.draw_dashed_line(_centres[link[0]], _centres[link[1]], LINK_COLOR, LINK_WIDTH, DASH_LENGTH)
	for link: Array in layers[1]:
		_board.draw_line(_centres[link[0]], _centres[link[1]], PATH_LINK_COLOR, PATH_LINK_WIDTH, true)
	for link: Array in layers[2]:
		_board.draw_line(_centres[link[0]], _centres[link[1]], Color(OPEN_LINK_COLOR, pulse), OPEN_LINK_WIDTH, true)
