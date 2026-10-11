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
## Run log (task 053): every gateway answer also goes to the run's client/run/run_log.gd, which
## appends one JSON line to run_log_path when the run is won or lost, or when New Run replaces an
## unfinished saved run (abandoned). A write failure only shows a message. The run-over view's Open
## log folder button (test hook press_open_log_folder()) opens that file's folder.
##
## Never computes a price, a discount or odds: the sub-screens read them from the state.
##
## How to play (task 049): show_how_to_play() puts client/help/how_to_play.gd over everything, from
## the menu's button or, once per machine, when a new run starts. The once-only flag is the client
## setting HowToPlay.SEEN_KEY in settings_path (client/settings/user_settings.gd), set when the
## panels open; it never goes in the run state or the save.
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
## Task 053: the playtest run log, one JSON line per ended run.
const RunLog := preload("res://client/run/run_log.gd")
const MainMenu := preload("res://client/run/main_menu.gd")
const Messages := preload("res://client/fight/messages.gd")
const FightScreen := preload("res://client/fight/fight_screen.tscn")
## The map and offer screens, by path in client/run/ (interface: run_screen_api.md).
const MapScreen := preload("res://client/run/map_screen.gd")
const OfferScreen := preload("res://client/run/offer_screen.gd")
## [added, task 049] The How to play overlay and the client settings store holding its seen flag.
const HowToPlay := preload("res://client/help/how_to_play.gd")
const UserSettings := preload("res://client/settings/user_settings.gd")

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
## Reject code -> message shown instead of Messages.reject() while the offer screen is up, where the
## fight wording reads wrong (an "unplayable" Baileys buy is a missing Dolla Bill or Brew slot, not a
## card). Keys are reject codes from core/schema/request.gd; values are player-facing text. Lane:
## client (Agent B); add a key when a run reject needs its own wording.
const OFFER_REJECTS := {
	"unplayable": "You can't take that right now: not enough Dolla Bills, or no free Brew slot.",
}

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
## [added, task 049] The user:// client settings file the How to play seen flag lives in. Changed by
## whoever creates the screen (tests use their own file), before the first New Run.
var settings_path: String = UserSettings.DEFAULT_PATH
## Task 053: the user:// file each ended run's record is appended to (run_log.gd). Changed by whoever
## creates the screen (tests use their own file), before a run ends.
var run_log_path: String = RunLog.DEFAULT_PATH
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
## [added, task 049] The How to play overlay while it is open, else null.
var _how_to_play: Control
## Task 053: the log of the run in memory (run_log.gd), fed by apply(); null before a run and once the
## run's record is written.
var _run_log: RunLog
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
	menu.how_to_play_requested.connect(show_how_to_play)
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
		_show_message(_reject_text(result["reject"]))
		return result["reject"]
	_show_message("")
	_take_state(result["state"])
	return ""


## The message for a reject code: OFFER_REJECTS while the offer screen is up, else Messages.reject().
## code: a reject code from core/schema/request.gd. Returns player-facing text.
func _reject_text(code: String) -> String:
	if current == SCREEN_OFFER and OFFER_REJECTS.has(code):
		return OFFER_REJECTS[code]
	return Messages.reject(code)


## The gateway every request of this run goes through, the fight screen's included: records the
## request in sent_requests and forwards it to _gateway unchanged. Does not take the new state: the
## caller does (send() at once, the fight screen through state_applied once its events animated).
## ruleset: read-only content. state: the current state. request: a full request.
## Returns the gateway's {"state", "events", "reject"}.
func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	sent_requests.append(request.duplicate(true))
	# result: the gateway's answer, also handed to the run log (task 053).
	var result: Dictionary = _gateway.apply(ruleset, state, request)
	if _run_log != null:
		_run_log.observe(state, result)
	return result


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
		_log_abandoned()
	_run_log = RunLog.new(state, not is_new)
	if is_new:
		_take_state(state)
		if not UserSettings.get_setting(HowToPlay.SEEN_KEY, false, settings_path):
			show_how_to_play()
	else:
		_state = state
		_route()


## [added, task 049] Opens the How to play overlay over everything (no-op while it is open) and
## records in the client settings that it has been seen, so a new run does not open it again.
func show_how_to_play() -> void:
	if how_to_play_screen() != null:
		return
	_how_to_play = HowToPlay.new()
	_how_to_play.setup(_ruleset, _local().get("dude_id", ""))
	add_child(_how_to_play)
	# error: why the seen flag could not be saved, or "".
	var error: String = UserSettings.set_setting(HowToPlay.SEEN_KEY, true, settings_path)
	if error != "":
		_show_message("Couldn't save settings: " + error)


## [added, task 049] Returns the How to play overlay while it is open, else null. Tests use it.
func how_to_play_screen() -> Control:
	if _how_to_play != null and is_instance_valid(_how_to_play) and not _how_to_play.is_queued_for_deletion():
		return _how_to_play
	return null


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
		if _run_log != null:
			_write_run_log(_run_log, RunLog.WON if kind == SCREEN_WON else RunLog.LOST)
			_run_log = null
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
	# open_log: opens the run log's folder (task 053).
	var open_log := Button.new()
	open_log.text = "Open log folder"
	open_log.pressed.connect(press_open_log_folder)
	column.add_child(label)
	column.add_child(back)
	column.add_child(open_log)
	return view


## The player pressed Open log folder on the run-over view (task 053): opens the folder holding
## run_log_path in the system's file browser; does nothing in a headless run (tests).
## Returns true when the folder was handed to the system to open.
func press_open_log_folder() -> bool:
	return RunLog.open_folder(run_log_path)


## Task 053: New Run is replacing a saved run that never ended, so it is logged as abandoned: from the
## log in memory when that holds this run, otherwise from the save alone ("resumed" true). A save that
## does not load is not logged.
func _log_abandoned() -> void:
	if not SaveStore.has_save(save_path):
		return
	# loaded: SaveStore.load_state()'s {"state", "error"}.
	var loaded: Dictionary = SaveStore.load_state(save_path)
	if loaded["error"] != "":
		return
	# run_log: the log the abandoned run's record comes from.
	var run_log: RunLog = _run_log
	if run_log == null or not run_log.is_run(loaded["state"]):
		run_log = RunLog.new(loaded["state"], true)
	_write_run_log(run_log, RunLog.ABANDONED)
	_run_log = null


## Task 053: appends a run's record to run_log_path; a failure is shown and the game carries on.
## run_log: the run's log. result: RunLog.WON, LOST or ABANDONED.
func _write_run_log(run_log: RunLog, result: String) -> void:
	# error: why the line was not written, or "".
	var error: String = run_log.write(result, run_log_path)
	if error != "":
		_show_message("Couldn't write the run log: " + error)


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
