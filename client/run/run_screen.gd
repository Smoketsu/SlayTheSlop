## The run screen (task 020): the whole run around the fights. Lane: client (Agent B).
##
## Holds the content (ruleset), the current run state and the local player, and shows one child at
## a time: the main menu (client/run/main_menu.gd), the map (map_screen.gd), the fight screen
## (client/fight/fight_screen.tscn), the offer screen (offer_screen.gd: card rewards, Boss Gear,
## The Tailgate, Baileys, Side Quests) or the run-over view built here.
##
## Which child is shown comes from the state alone (screen_for()), never from a flow kept in the
## client, so loading a save mid-run opens the right screen and co-op can reuse it unchanged.
##
## One code path (CLAUDE.md "The rules core is pure"): the client never changes game state. The map
## and offer screens emit request_made with a request's type and own fields (run_screen_api.md);
## send() adds player_id and seq and passes it to the gateway. The fight screen gets this screen as
## its gateway, so its requests come through apply() here too. The gateway is the real rules core
## (core/core.gd apply()); co-op will swap in a network gateway with the same apply(). Every request
## sent, applied or rejected, is kept in sent_requests, in order.
##
## Saving (GDD "Sessions": the run is saved after every node): after every applied request whose new
## state is not in a running fight (screen_for() is "map" or "offer"), and once when a new run
## starts, the state is written with client/run/save_store.gd. That covers every finished node (the
## party is back on the map) and every choice inside a node; mid-fight states are not saved, so
## Continue resumes at the last node boundary or choice. When the run is over (screen_for() is "won"
## or "lost") the save is deleted, because a finished run cannot be continued (no Rep or meta
## progression in the solo slice).
##
## Never computes a price, a discount or odds: the sub-screens read them from the state.
## Run it with
##   "$(tools/install_godot.sh)" --path . res://client/run/run_screen.tscn
## With no setup() call it builds the ruleset from data/ (as client/dev/dev_fight.gd does).
## Test hooks: press_new_run(), press_continue(), press_back_to_menu(), send(), child_screen().
extends Control

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")
## The default gateway: the real rules core, apply(ruleset, state, request).
const Core := preload("res://core/core.gd")
const SaveStore := preload("res://client/run/save_store.gd")
const MainMenu := preload("res://client/run/main_menu.gd")
const Messages := preload("res://client/fight/messages.gd")
const FightScreen := preload("res://client/fight/fight_screen.tscn")
## The map and offer screens, by path in client/run/ (interface: run_screen_api.md).
const MapScreen := preload("res://client/run/map_screen.gd")
const OfferScreen := preload("res://client/run/offer_screen.gd")

## Screen names screen_for() returns, and SCREEN_MENU for the menu (no run). Fixed by the client
## lane; tests compare against them.
const SCREEN_MENU: String = "menu"
## The floor map: run_phase "map".
const SCREEN_MAP: String = "map"
## A fight is running: run_phase "node" and combat holds a fight with no result yet.
const SCREEN_FIGHT: String = "fight"
## A node's choice: run_phase "node" outside a running fight (the player's offers, or waiting for
## the other Dudes' choices).
const SCREEN_OFFER: String = "offer"
## Run over, boss beaten: run_phase "floor_end".
const SCREEN_WON: String = "won"
## Run over, every Dude Passed Out: run_phase "lost".
const SCREEN_LOST: String = "lost"

## Run-over texts, by screen name. Player-facing; writers may change them.
const RUN_OVER_TEXT := {
	"won": "Boss down. The Basement is yours, bro.",
	"lost": "Passed out. The run is over.",
}

## Seconds each fight event animates, handed to every fight screen this screen makes. 0 makes the
## fights synchronous, which tests use. Changed by whoever creates the screen.
var animation_seconds: float = 0.3
## The user:// file the run is saved to and Continue reads. Changed by whoever creates the screen
## (tests use their own file), before setup() or _ready().
var save_path: String = SaveStore.DEFAULT_PATH
## The child shown now: one of the SCREEN_ names, or "" before _ready(). Read by tests.
var current: String = ""
## The message last shown in the message bar (a reject, a save problem). Read by tests.
var message: String = ""
## Every request sent to the gateway this run, applied or rejected, in order, with player_id and
## seq. Only grows; emptied when a run starts or loads. Read by tests (the one-code-path replay).
var sent_requests: Array[Dictionary] = []

## Where requests go: anything with apply(ruleset, state, request). Set by setup(); Core by default.
var _gateway: Object
## Read-only content (core/ruleset/ruleset.gd). Set by setup() or built in _ready(); never changed.
var _ruleset: Dictionary = {}
## The current run state, as last returned by the gateway or loaded. Replaced, never edited. {} on
## the menu.
var _state: Dictionary = {}
## The local player's id, "p1".."p4". Solo: the first seat's player. "" on the menu.
var _player_id: String = ""
## The child shown now (menu, map, fight, offer or run-over view), or null.
var _child: Control
## Widgets: the header (Dude, HP, Dolla Bills, floor, seed), the area children fill, the message bar.
var _header: Label
var _content: Control
var _message_label: Label


## Gives the screen its content and gateway. Call before adding it to the tree, or not at all to
## use the real data and the real core.
## ruleset: read-only content. gateway: has apply(ruleset, state, request); the real core when null.
func setup(ruleset: Dictionary, gateway: Object = null) -> void:
	_ruleset = ruleset
	_gateway = gateway


## Returns which screen a run state shows, from the state alone: SCREEN_LOST for run_phase "lost",
## SCREEN_WON for "floor_end", SCREEN_MAP for "map"; in "node", SCREEN_FIGHT while combat holds a
## fight with no result, otherwise SCREEN_OFFER (the player's open offers, or, in co-op, waiting
## for the others' choices; the offer screen shows an empty offer list as waiting).
## state: a run state; read only. player_id: the local player (kept for co-op screens that differ
## per player; the routing above is the same for every player).
static func screen_for(state: Dictionary, player_id: String) -> String:
	match state.get("run_phase", ""):
		"lost":
			return SCREEN_LOST
		"floor_end":
			return SCREEN_WON
		"map":
			return SCREEN_MAP
	# combat: the fight in the state, or null.
	var combat: Variant = state.get("combat")
	if combat != null and combat["result"] == "":
		return SCREEN_FIGHT
	return SCREEN_OFFER


## Builds the layout, the ruleset if setup() gave none, and shows the menu.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# backdrop: a plain dark background behind every child.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.08, 0.08, 0.1)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	# root: header, content, message bar, top to bottom.
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_header = Label.new()
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message_label = Label.new()
	for node: Control in [_header, _content, _message_label]:
		root.add_child(node)
	if _gateway == null:
		_gateway = Core.new()
	if _ruleset.is_empty():
		# built: the ruleset build result for data/.
		var built: Dictionary = Ruleset.build(DataFiles.read_all())
		if not built["ok"]:
			_show_message("data/ does not build: " + "; ".join(built["errors"]))
			return
		_ruleset = built["ruleset"]
	show_menu()


## Shows the main menu and forgets the run in memory (the save on disk stays).
func show_menu() -> void:
	_state = {}
	_player_id = ""
	# menu: the new main menu.
	var menu: Control = MainMenu.new()
	_replace_child(menu, SCREEN_MENU)
	menu.setup(_ruleset, save_path)
	menu.run_ready.connect(_on_run_ready)
	_draw_header()


## The player pressed New Run on the menu (test hook; the menu's own button does the same).
## seed_text: the seed field's text; "" picks a seed.
func press_new_run(seed_text: String) -> void:
	if current == SCREEN_MENU:
		_child.press_new_run(seed_text)


## The player pressed Continue on the menu (test hook; the menu's own button does the same).
func press_continue() -> void:
	if current == SCREEN_MENU:
		_child.press_continue()


## The player pressed Back to menu on the run-over view.
func press_back_to_menu() -> void:
	if current == SCREEN_WON or current == SCREEN_LOST:
		show_menu()


## Sends one request from the map or offer screen: adds player_id and the next seq (the local
## Dude's last_seq + 1; the core leaves last_seq unchanged on a reject, so a rejected seq is simply
## used again), applies it through the gateway, and on success takes the new state (save, redraw).
## partial: the request's type and own fields (run_screen_api.md); not changed.
## Returns "" when applied, otherwise the reject code (its message is shown).
func send(partial: Dictionary) -> String:
	if _state.is_empty():
		return "wrong_phase"
	# request: partial plus the common fields.
	var request: Dictionary = partial.duplicate(true)
	request["player_id"] = _player_id
	request["seq"] = _local()["last_seq"] + 1
	# result: {"state", "events", "reject"}.
	var result: Dictionary = apply(_ruleset, _state, request)
	if result["reject"] != "":
		_show_message(Messages.reject(result["reject"]))
		return result["reject"]
	_show_message("")
	_take_state(result["state"])
	return ""


## The gateway every request of this run goes through, the fight screen's included: records the
## request in sent_requests and forwards it to _gateway unchanged. Does not take the new state: the
## caller does (send() at once, the fight screen through state_applied once its events animated).
## ruleset: read-only content. state: the current state. request: a full request.
## Returns the gateway's {"state", "events", "reject"}.
func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	sent_requests.append(request.duplicate(true))
	return _gateway.apply(ruleset, state, request)


## Returns the child shown now (the menu, a sub-screen, the fight screen or the run-over view), or
## null. Tests use it to press the child's own hooks.
func child_screen() -> Control:
	return _child


## Returns the current run state, {} on the menu. Read only; the screen keeps it.
func run_state() -> Dictionary:
	return _state


## Returns every piece of text on the screen, top to bottom, one per line. Tests read it.
func drawn_text() -> String:
	# lines: collected text.
	var lines: Array[String] = []
	_collect_text(self, lines)
	return "\n".join(lines)


## The menu has a run: a new one (saved at once) or the loaded save.
## state: the run state. is_new: true for New Run.
func _on_run_ready(state: Dictionary, is_new: bool) -> void:
	sent_requests = []
	_player_id = state["dudes"][0]["player_id"]
	_show_message("")
	if is_new:
		_take_state(state)
	else:
		_state = state
		_route()


## The fight screen applied a request and finished animating it.
## state: the new state.
func _on_fight_applied(state: Dictionary) -> void:
	_take_state(state)


## Takes a newly applied state: saves or deletes the save (see the file header), then shows the
## screen the state calls for.
## state: the new state.
func _take_state(state: Dictionary) -> void:
	_state = state
	# kind: the screen the new state shows.
	var kind: String = screen_for(_state, _player_id)
	if kind == SCREEN_WON or kind == SCREEN_LOST:
		SaveStore.delete_save(save_path)
	elif kind != SCREEN_FIGHT:
		# error: why the save failed, or "".
		var error: String = SaveStore.save_state(_state, save_path)
		if error != "":
			_show_message("Couldn't save the run: " + error)
	_route()


## Shows the screen the current state calls for. A running fight screen keeps itself up to date,
## so it is left alone; a map or offer screen already shown is redrawn from the state.
func _route() -> void:
	_draw_header()
	# kind: the screen to show.
	var kind: String = screen_for(_state, _player_id)
	if kind == current and kind == SCREEN_FIGHT:
		return
	if kind == current and (kind == SCREEN_MAP or kind == SCREEN_OFFER):
		_child.show_state(_ruleset, _state, _player_id)
		return
	match kind:
		SCREEN_MAP, SCREEN_OFFER:
			# screen: the map or offer screen.
			var screen: Control = MapScreen.new() if kind == SCREEN_MAP else OfferScreen.new()
			_replace_child(screen, kind)
			screen.request_made.connect(_on_request_made)
			screen.show_state(_ruleset, _state, _player_id)
		SCREEN_FIGHT:
			# fight: a fight screen on this fight, with this screen as its gateway.
			var fight: Control = FightScreen.instantiate()
			fight.animation_seconds = animation_seconds
			fight.setup(self, _ruleset, _state, _player_id)
			fight.state_applied.connect(_on_fight_applied)
			_replace_child(fight, kind)
		_:
			_replace_child(_run_over_view(kind), kind)


## A map or offer screen made a request.
## request: its type and own fields.
func _on_request_made(request: Dictionary) -> void:
	send(request)


## Returns the run-over view: what happened and a Back to menu button.
## kind: SCREEN_WON or SCREEN_LOST.
func _run_over_view(kind: String) -> Control:
	# view: the whole view. column: its contents, centred.
	var view := Control.new()
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	view.add_child(column)
	# label: what happened.
	var label := Label.new()
	label.text = RUN_OVER_TEXT[kind]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# back: returns to the menu.
	var back := Button.new()
	back.text = "Back to menu"
	back.pressed.connect(press_back_to_menu)
	column.add_child(label)
	column.add_child(back)
	return view


## Replaces the shown child. The old one is removed now and freed at the end of the frame (it may
## be the fight screen that is still inside its own signal).
## screen: the new child. kind: its SCREEN_ name.
func _replace_child(screen: Control, kind: String) -> void:
	if _child != null:
		_content.remove_child(_child)
		_child.queue_free()
	_child = screen
	current = kind
	_content.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)


## Redraws the header from the state: the local Dude's name, HP and Dolla Bills, the floor and the
## seed. Empty on the menu.
func _draw_header() -> void:
	if _header == null:
		return
	if _state.is_empty():
		_header.text = ""
		return
	# dude: the local Dude. name_text: its display name from the data.
	var dude: Dictionary = _local()
	var name_text: String = _ruleset["dudes"].get(dude["dude_id"], {}).get("name", dude["dude_id"])
	_header.text = "%s - HP %d / %d - Dolla Bills %d - Floor %d - Seed %d" % [
		name_text, dude["hp"], dude["max_hp"], dude["dolla_bills"], _state["floor"], _state["run_seed"]]


## Shows a message in the message bar.
## text: the message, "" to clear it.
func _show_message(text: String) -> void:
	message = text
	if _message_label != null:
		_message_label.text = text


## Returns the local player's Dude in the current state, or {} when there is none.
func _local() -> Dictionary:
	for dude: Dictionary in _state.get("dudes", []):
		if dude["player_id"] == _player_id:
			return dude
	return {}


## Adds the non-empty text of node and its children to lines, depth first, skipping widgets queued
## for deletion. LineEdit text is included.
## node: where to start. lines: receives the text.
func _collect_text(node: Node, lines: Array[String]) -> void:
	if node.is_queued_for_deletion():
		return
	if (node is Label or node is Button or node is LineEdit) and node.text != "":
		lines.append(node.text)
	for child: Node in node.get_children():
		_collect_text(child, lines)
