## Placeholder fight screen (task 018). Lane: client (Agent B).
##
## Draws the fight from the state only, sends requests through a gateway, and animates the events
## that come back, one at a time, in order; then redraws from the returned state. It never changes
## game state itself (CLAUDE.md "The rules core is pure"): solo uses the same request-and-events
## path co-op will.
##
## Placeholder look: text on buttons and labels, no art. Run it with
##   "$(tools/install_godot.sh)" --path . res://client/fight/fight_screen.tscn
## With no setup() call it starts a fight on the real data (client/dev/dev_fight.gd).
extends Control

const FightModel := preload("res://client/fight/fight_model.gd")
const Targeting := preload("res://client/fight/targeting.gd")
const RequestMaker := preload("res://client/fight/request_maker.gd")
const Messages := preload("res://client/fight/messages.gd")
const DevFight := preload("res://client/dev/dev_fight.gd")
const EventText := preload("res://client/fight/event_text.gd")
## The rules gateway: the real rules core (task 007), apply(ruleset, state, request). Co-op will
## swap in a network gateway with the same apply() here.
const Gateway := preload("res://core/core.gd")

## Seconds each event's animation lasts. 0 makes the screen fully synchronous, which tests use.
## Changed by whoever creates the screen, before or after setup().
var animation_seconds: float = 0.3
## True to skip every event's animation and only redraw at the end. Tests use it to prove the
## final drawing does not depend on the events.
var skip_animations: bool = false
## One line per event the screen animated, in order, for tests and debugging. Only grows.
var animation_log: Array[String] = []
## The message last shown to the player (a reject, a prompt or the latest event). Read by tests.
var message: String = ""

## The gateway requests go to: anything with apply(ruleset, state, request). Set by setup().
var _gateway: Object
## Read-only content (core/ruleset/ruleset.gd). Set by setup(); never changed here.
var _ruleset: Dictionary = {}
## The current state, as last returned by the gateway. Replaced, never edited.
var _state: Dictionary = {}
## The local player's id.
var _player_id: String = ""
## Builds this player's requests with a rising seq.
var _requests: RequestMaker
## The card_uid waiting for the player to pick a target, or "" when none.
var _pending_card: String = ""
## True while the Bro Move waits for the player to pick an enemy (G33: Chest Bump needs a target).
var _pending_bro: bool = false
## True while events are animating; input is ignored meanwhile.
var _busy: bool = false
## Containers rebuilt on every redraw: header text, Dudes, enemies, hand, buttons, message.
var _header: Label
var _dudes_box: HBoxContainer
var _enemies_box: HBoxContainer
var _hand_box: HBoxContainer
var _actions_box: HBoxContainer
var _message_label: Label


## Gives the screen its gateway, content, starting state and local player. Call before or after
## adding it to the tree.
## gateway: has apply(ruleset, state, request). ruleset: read-only content. state: a run state in a
## fight. player_id: the local player.
func setup(gateway: Object, ruleset: Dictionary, state: Dictionary, player_id: String) -> void:
	_gateway = gateway
	_ruleset = ruleset
	_state = state
	_player_id = player_id
	for dude: Dictionary in state["dudes"]:
		if dude["player_id"] == player_id:
			_requests = RequestMaker.new(player_id, dude["last_seq"])
	if is_inside_tree():
		_redraw()


## Builds the layout, falls back to the sample fight if setup() was not called, and draws.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# root: everything, top to bottom.
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_header = Label.new()
	_enemies_box = HBoxContainer.new()
	_dudes_box = HBoxContainer.new()
	_hand_box = HBoxContainer.new()
	_actions_box = HBoxContainer.new()
	_message_label = Label.new()
	for node: Control in [_header, _enemies_box, _dudes_box, _hand_box, _actions_box, _message_label]:
		root.add_child(node)
	if _ruleset.is_empty():
		# started: a placeholder fight on the real data.
		var started: Dictionary = DevFight.start()
		if started["error"] != "":
			push_error("fight screen could not start a fight: " + started["error"])
			return
		setup(Gateway.new(), started["ruleset"], started["state"], started["player_id"])
	_redraw()


## The player clicked a card in hand: play it, or ask for a target first.
## card_uid: the card copy.
func press_card(card_uid: String) -> void:
	if _busy:
		return
	# card: the card's definition.
	var card: Dictionary = _ruleset["cards"][_local()["cards"][card_uid]["def_id"]]
	# pick: what the player has to choose.
	var pick: String = Targeting.mode(card, _state["party_size"])
	if pick == Targeting.NONE:
		_pending_card = ""
		_pending_bro = false
		_send(_requests.play_card(card_uid, Targeting.auto_target(card, _player_id, _state["party_size"])))
		return
	_pending_card = card_uid
	_pending_bro = false
	_show_message("Pick an enemy." if pick == Targeting.ENEMY else "Pick a Dude.")


## The player clicked an enemy: the target for a pending card, otherwise nothing.
## enemy_uid: the enemy.
func press_enemy(enemy_uid: String) -> void:
	if _busy:
		return
	if _pending_bro:
		_pending_bro = false
		_send(_requests.use_bro_move(enemy_uid))
		return
	if _pending_card == "":
		return
	# card_uid: the card being aimed.
	var card_uid: String = _pending_card
	_pending_card = ""
	_send(_requests.play_card(card_uid, enemy_uid))


## The player clicked a Dude: the target for a pending ally card, otherwise nothing.
## player_id: the Dude's player.
func press_dude(player_id: String) -> void:
	if _busy or _pending_card == "":
		return
	# card_uid: the card being aimed.
	var card_uid: String = _pending_card
	_pending_card = ""
	_send(_requests.play_card(card_uid, player_id))


## The player pressed Ready (end turn).
func press_ready() -> void:
	if not _busy:
		_pending_card = ""
		_pending_bro = false
		_send(_requests.set_ready(true))


## The player pressed the Bro Move button. When the Dude's Bro Move card targets an enemy (Chest
## Bump, G33), the screen asks for one first and press_enemy() sends it.
func press_bro_move() -> void:
	if _busy:
		return
	_pending_card = ""
	# bro: the Bro Move card's definition, or {} when the Dude has none.
	var bro: Dictionary = _ruleset["cards"].get(_ruleset["dudes"].get(_local()["dude_id"], {}).get("bro_move", ""), {})
	if bro.is_empty():
		_send(_requests.use_bro_move())
		return
	if Targeting.mode(bro, _state["party_size"]) == Targeting.ENEMY:
		_pending_bro = true
		_show_message("Pick an enemy.")
		return
	_send(_requests.use_bro_move(Targeting.auto_target(bro, _player_id, _state["party_size"])))


## The player clicked a Brew. Brews that need a target are not handled yet (no Brew data exists).
## slot: the Brew slot, from 0.
func press_brew(slot: int) -> void:
	if not _busy:
		_pending_card = ""
		_pending_bro = false
		_send(_requests.use_brew(slot, ""))


## Returns every piece of text on the screen, top to bottom, one per line. Tests compare it.
func drawn_text() -> String:
	# lines: collected text.
	var lines: Array[String] = []
	_collect_text(self, lines)
	return "\n".join(lines)


## Sends one request and handles the answer: a reject shows its message (and on bad_target asks for
## a new target, per the GDD's two-players-one-enemy case); otherwise the events animate in order
## and the screen redraws from the new state.
## request: a request built by _requests.
func _send(request: Dictionary) -> void:
	# result: {"state", "events", "reject"} from the gateway.
	var result: Dictionary = _gateway.apply(_ruleset, _state, request)
	if result["reject"] != "":
		_show_message(Messages.reject(result["reject"]))
		if result["reject"] == "bad_target" and request["type"] == "play_card":
			_pending_card = request["card_uid"]
		elif result["reject"] == "bad_target" and request["type"] == "use_bro_move":
			_pending_bro = true
		return
	# names: display names for the event lines, from the state before and after the request.
	var names: Dictionary = EventText.names_for(_ruleset, [_state, result["state"]])
	_busy = true
	for event: Dictionary in result["events"]:
		animation_log.append(_describe(event))
		if skip_animations:
			continue
		_show_message(EventText.line(event, names))
		if animation_seconds > 0.0:
			await get_tree().create_timer(animation_seconds).timeout
	_state = result["state"]
	_busy = false
	_redraw()


## Rebuilds every widget from the state.
func _redraw() -> void:
	if _header == null or _state.is_empty():
		return
	# model: what to show.
	var model: Dictionary = FightModel.build(_ruleset, _state, _player_id)
	_header.text = "Turn %d - %s phase - Bro Meter %s" % [model["turn"], model["phase"], model["bro_meter"]]
	for box: Container in [_enemies_box, _dudes_box, _hand_box, _actions_box]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for enemy: Dictionary in model["enemies"]:
		# aim: who the intent targets, as text.
		var aim: String = (" -> " + ", ".join(enemy["targets"])) if not enemy["targets"].is_empty() else ""
		_add_button(_enemies_box, "\n".join([enemy["name"], "HP " + enemy["hp"], "Guard %d" % enemy["guard"],
			"Intent: %s%s" % [enemy["intent"] if enemy["intent"] != "" else "?", aim], enemy["arms"],
			"Ick " + enemy["ick"], " ".join(enemy["statuses"])]), press_enemy.bind(enemy["uid"]), not enemy["alive"])
	for dude: Dictionary in model["dudes"]:
		_add_button(_dudes_box, "\n".join([dude["name"] + (" (you)" if dude["local"] else ""), "HP " + dude["hp"],
			"Guard %d  Hype %d" % [dude["guard"], dude["hype"]], " ".join(dude["statuses"]), "Brews " + dude["brews"],
			"Draw %d  Discard %d  Tapped %d" % [dude["draw"], dude["discard"], dude["tapped"]]]),
			press_dude.bind(dude["player_id"]), dude["passed_out"])
		if dude["local"]:
			for slot: int in dude["brew_ids"].size():
				_add_button(_actions_box, "Brew: " + dude["brew_ids"][slot], press_brew.bind(slot), false)
	for card: Dictionary in model["hand"]:
		_add_button(_hand_box, "[%s] %s\n%s" % [card["cost"], card["name"], card["text"]], press_card.bind(card["card_uid"]), false)
	_add_button(_actions_box, "Bro Move", press_bro_move, not model["bro_ready"])
	_add_button(_actions_box, "Ready", press_ready, false)
	_message_label.text = message


## Adds one button to a container.
## box: the container. text: the button's label. on_press: called when pressed. disabled: greyed out.
func _add_button(box: Container, text: String, on_press: Callable, disabled: bool) -> void:
	# button: the new button.
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.pressed.connect(on_press)
	box.add_child(button)


## Shows a message to the player.
## text: the message.
func _show_message(text: String) -> void:
	message = text
	if _message_label != null:
		_message_label.text = text


## Returns one line describing an event, for the message bar and animation_log, for example
## "damage_dealt e3 hp_lost=6". Fields are listed in sorted order so the line never depends on how
## the event was built.
## event: one event from the gateway.
func _describe(event: Dictionary) -> String:
	# keys: the event's fields except "type", sorted.
	var keys: Array = event.keys()
	keys.erase("type")
	keys.sort()
	# parts: "field=value" pieces.
	var parts: Array[String] = []
	for key: String in keys:
		parts.append("%s=%s" % [key, event[key]])
	return "%s %s" % [event["type"], " ".join(parts)]


## Returns the local player's Dude in the current state.
func _local() -> Dictionary:
	for dude: Dictionary in _state["dudes"]:
		if dude["player_id"] == _player_id:
			return dude
	return {}


## Adds the text of node and its children to lines, depth first, skipping widgets queued for deletion.
## node: where to start. lines: receives the text.
func _collect_text(node: Node, lines: Array[String]) -> void:
	if node.is_queued_for_deletion():
		return
	if node is Label or node is Button:
		lines.append(node.text)
	for child: Node in node.get_children():
		_collect_text(child, lines)
