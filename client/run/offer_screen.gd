## Offer screen (task 020): the local player's first open choice in dude_state.offers (a card
## reward, the Boss Gear pick, The Tailgate, Baileys or a Side Quest), drawn from the offer's own
## options and prices, sending choose_reward. Interface: client/run/run_screen_api.md.
## Lane: client (Agent B).
##
## Drawn from the state only: the title (the offer's kind, or the Side Quest's name and text from the
## ruleset), the Dude's Dolla Bills as the state holds them, and one button per option in the
## offer's order, labelled by client/run/run_text.gd with the option's price and amount exactly as
## the state gives them. The client works out no price, discount, amount or chance. An option whose
## "available" is false is shown disabled. A Lift or a removal first opens a list of the option's
## card_uids; picking one sends the request with that card_uid. The Skip / Leave button exists only
## when the offer's "skippable" is true and sends choice_index -1.
## Baileys sells weed, not drinks: a Brew there reads "Shake: <Brew name> — <effect>" (G29).
## Task 045: each option also has a hover tooltip from client/help/tooltip_text.gd option_tooltip()
## (a card's keywords, a Gear's data text, a Shake's line).
## Task 063: a Side Quest, The Tailgate and Baileys show their splash picture
## (client/visual/splashes.gd) filling the screen, and everything above sits on a dark panel in the
## lower part of the screen (below Splashes.SAFE_TOP), so the picture's top half stays clear. Other
## offers keep the full-screen layout with no picture.
extends Control

const RunText := preload("res://client/run/run_text.gd")
## [added, task 045] Option tooltips, and the Button whose tooltip wraps.
const TooltipText := preload("res://client/help/tooltip_text.gd")
const TipButton := preload("res://client/visual/tip_button.gd")
## [added, task 063] The splash lookup.
const Splashes := preload("res://client/visual/splashes.gd")

## Emitted with {"type": "choose_reward", "reward_id": <offer id>, "choice_index": <index or -1>}
## and, for a Lift or a removal, "card_uid". The run screen adds player_id and seq.
## request: the request's type and own fields (core/schema/request.gd).
signal request_made(request: Dictionary)

## Shown instead of an offer when the local player has none open outside a node (nothing to choose).
## Changed only by the client lane.
const NOTHING_TEXT: String = "Nothing to choose right now."
## Shown instead of an offer when the local player has none open but the party is still at a node
## (run_phase "node"; in co-op, others are still choosing). Changed only by the client lane.
const WAITING_TEXT: String = "Waiting for the rest of the party to choose."
## The button that closes the card list without choosing. Changed only by the client lane.
const CANCEL_TEXT: String = "Never mind"

## The title as last drawn (offer kind, or the Side Quest's name). Read by tests.
var title_text: String = ""
## The line under the title as last drawn (the Side Quest's text, or the offer kind's prompt).
## Read by tests.
var prompt_text: String = ""
## The Dolla Bills line as last drawn ("<n> Dolla Bills", n read from the state). Read by tests.
var dolla_bills_text: String = ""
## One label per option, in the offer's order, as last drawn. Read by tests.
var option_texts: Array[String] = []
## One Button per option, in the offer's order, as last drawn. Read by tests.
var option_buttons: Array[Button] = []
## The Skip / Leave button, or null when the offer is not skippable (or there is no offer). Read by tests.
var skip_button: Button = null
## Index of the Lift or removal option whose card list is open, or -1 when none is. Read by tests.
var picking_index: int = -1
## One Button per card in the open card list, in the option's card_uids order. Read by tests.
var pick_buttons: Array[Button] = []
## The card names in the open card list, in the same order as pick_buttons. Read by tests.
var pick_texts: Array[String] = []

## [added, task 063] The splash key of the offer as last drawn (Splashes.key_for), or "" when the
## offer shows no splash. Read by tests.
var splash_key: String = ""
## [added, task 063] True when the last drawn offer shows its own splash picture; false when it
## shows the fallback or no splash. Read by tests.
var splash_has_picture: bool = false
## [added, task 063] True when the last drawn offer shows the missing-picture fallback. Read by tests.
var splash_fallback_shown: bool = false

## The ruleset from the last show_state(); read only.
var _ruleset: Dictionary = {}
## The local Dude from the last show_state() (a part of the state; read only), or {}.
var _dude: Dictionary = {}
## The offer shown: the local Dude's first open offer, or {} when there is none. Read only.
var _offer: Dictionary = {}
## The title label. Built once in _init().
var _title: Label
## The prompt label. Built once in _init().
var _prompt: Label
## The Dolla Bills label. Built once in _init().
var _dolla_bills: Label
## Holds the option buttons. Built once in _init().
var _options_box: VBoxContainer
## Holds the card list of a Lift or a removal. Built once in _init().
var _pick_box: VBoxContainer
## Holds the Skip / Leave button. Built once in _init().
var _skip_box: VBoxContainer
## [added, task 063] The splash picture, filling the screen behind everything. Built once in _init().
var _splash: TextureRect
## [added, task 063] Drawn instead of a missing splash picture. Built once in _init().
var _fallback: ColorRect
## [added, task 063] The panel the title, prompt and choices sit on. Built once in _init(); its top
## anchor is Splashes.SAFE_TOP over a splash, 0 otherwise.
var _panel: PanelContainer


## Builds the fixed layout once: title, prompt, Dolla Bills, options, card list and skip, top to bottom.
func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fallback = ColorRect.new()
	_fallback.color = Splashes.FALLBACK_COLOR
	_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback.visible = false
	add_child(_fallback)
	# fallback_label: the missing-picture words, centred in the clear top part.
	var fallback_label := Label.new()
	fallback_label.text = Splashes.FALLBACK_TEXT
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.anchor_right = 1.0
	fallback_label.anchor_bottom = Splashes.SAFE_TOP
	_fallback.add_child(fallback_label)
	_splash = TextureRect.new()
	_splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.visible = false
	add_child(_splash)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# panel_style: the dark backing for text over a splash (transparent when there is none).
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0)
	panel_style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	# scroll: lets a long Baileys list scroll.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	# column: everything, top to bottom.
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_prompt)
	_dolla_bills = Label.new()
	_dolla_bills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_dolla_bills)
	_options_box = VBoxContainer.new()
	column.add_child(_options_box)
	_pick_box = VBoxContainer.new()
	column.add_child(_pick_box)
	_skip_box = VBoxContainer.new()
	column.add_child(_skip_box)


## Redraws the offer from a run state snapshot; reads only. Closes any open card list. May be called
## again on the same screen after every applied request: the old buttons are removed first. Never
## reads state.combat (null while a fight's card reward is open).
## ruleset: the read-only content. state: the run state. player_id: the local player.
func show_state(ruleset: Dictionary, state: Dictionary, player_id: String) -> void:
	_ruleset = ruleset
	_dude = {}
	_offer = {}
	for dude: Dictionary in state.get("dudes", []):
		if dude["player_id"] == player_id:
			_dude = dude
	if not _dude.is_empty() and not _dude["offers"].is_empty():
		_offer = _dude["offers"][0]
	_show_splash()
	_clear(_options_box)
	_clear(_skip_box)
	option_texts = []
	option_buttons = []
	skip_button = null
	_close_pick()
	dolla_bills_text = "" if _dude.is_empty() else "%d %s" % [_dude["dolla_bills"], RunText.MONEY]
	if _offer.is_empty():
		title_text = WAITING_TEXT if state.get("run_phase", "") == "node" else NOTHING_TEXT
		prompt_text = ""
		_show_labels()
		return
	title_text = RunText.offer_title(ruleset, _offer)
	prompt_text = RunText.offer_prompt(ruleset, _offer)
	for i: int in _offer["options"].size():
		# option: one option of the offer.
		var option: Dictionary = _offer["options"][i]
		# button: its button.
		var button: Button = TipButton.new()
		button.text = RunText.option_label(ruleset, _offer, option)
		button.tooltip_text = TooltipText.option_tooltip(ruleset, option)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = not option["available"]
		button.pressed.connect(press_option.bind(i, ""))
		_options_box.add_child(button)
		option_texts.append(button.text)
		option_buttons.append(button)
	if _offer["skippable"]:
		skip_button = Button.new()
		skip_button.text = RunText.skip_label(_offer)
		skip_button.pressed.connect(press_skip)
		_skip_box.add_child(skip_button)
	_show_labels()


## Picks an option, exactly as clicking it does. A disabled option, or an index out of range, does
## nothing. A Lift or a removal with no card_uid opens its card list (no request yet); with one of
## the option's card_uids it sends the request with that card; any other card_uid does nothing.
## Any other option sends the request at once (a card_uid given to it is ignored). Test hook.
## index: the option's index in the offer, 0 or more. card_uid: the card to Lift or remove, or "".
func press_option(index: int, card_uid: String = "") -> void:
	if _offer.is_empty() or index < 0 or index >= _offer["options"].size():
		return
	# option: the option pressed.
	var option: Dictionary = _offer["options"][index]
	if not option["available"]:
		return
	if not RunText.CARD_PICK_KINDS.has(option["kind"]):
		request_made.emit({"type": "choose_reward", "reward_id": _offer["id"], "choice_index": index})
		return
	if card_uid == "":
		_open_pick(index)
		return
	if not option.get("card_uids", []).has(card_uid):
		return
	request_made.emit({"type": "choose_reward", "reward_id": _offer["id"], "choice_index": index, "card_uid": card_uid})


## Picks a card from the open card list, exactly as clicking it does: sends the open option's request
## with that card. Does nothing when no list is open. Test hook.
## card_uid: one of the open option's card_uids.
func press_pick(card_uid: String) -> void:
	if picking_index >= 0:
		press_option(picking_index, card_uid)


## Closes the open card list without choosing, exactly as clicking "Never mind" does. Test hook.
func press_cancel_pick() -> void:
	_close_pick()


## Skips the card reward or leaves Baileys, exactly as clicking Skip / Leave does: sends choice_index
## -1. Does nothing when the offer is not skippable (there is no such button). Test hook.
func press_skip() -> void:
	if _offer.is_empty() or not _offer["skippable"]:
		return
	request_made.emit({"type": "choose_reward", "reward_id": _offer["id"], "choice_index": -1})


## Returns every player-facing string the screen shows now (title, prompt, Dolla Bills, options,
## skip, card list), for tests that check the words. Reads only.
func shown_texts() -> Array[String]:
	# texts: the result.
	var texts: Array[String] = [title_text, prompt_text, dolla_bills_text]
	texts.append_array(option_texts)
	if skip_button != null:
		texts.append(skip_button.text)
	if picking_index >= 0:
		texts.append(RunText.PICK_PROMPTS.get(_offer["options"][picking_index]["kind"], ""))
		texts.append(CANCEL_TEXT)
	texts.append_array(pick_texts)
	return texts


## Opens the card list of a Lift or removal option: one button per card_uid, named from the Dude's
## cards, in the option's order.
## index: the option's index in the offer.
func _open_pick(index: int) -> void:
	_close_pick()
	picking_index = index
	# option: the option whose cards are listed.
	var option: Dictionary = _offer["options"][index]
	# heading: what the list is for.
	var heading := Label.new()
	heading.text = RunText.PICK_PROMPTS.get(option["kind"], "")
	_pick_box.add_child(heading)
	for uid: String in option.get("card_uids", []):
		# button: one card's button.
		var button := Button.new()
		button.text = RunText.card_copy_name(_ruleset, _dude, uid)
		button.pressed.connect(press_pick.bind(uid))
		_pick_box.add_child(button)
		pick_buttons.append(button)
		pick_texts.append(button.text)
	# cancel: closes the list.
	var cancel := Button.new()
	cancel.text = CANCEL_TEXT
	cancel.pressed.connect(press_cancel_pick)
	_pick_box.add_child(cancel)


## Closes the card list, if one is open.
func _close_pick() -> void:
	_clear(_pick_box)
	picking_index = -1
	pick_buttons = []
	pick_texts = []


## [added, task 063] Shows the offer's splash (or the fallback, or none) and places the panel: below
## Splashes.SAFE_TOP on a dark backing over a splash, full screen and clear otherwise.
func _show_splash() -> void:
	splash_key = Splashes.key_for(_offer)
	# shows: whether this offer shows a splash at all.
	var shows: bool = Splashes.shows_splash(_offer)
	# texture: its picture, or null.
	var texture: Texture2D = Splashes.texture_for(splash_key) if shows else null
	splash_has_picture = texture != null
	splash_fallback_shown = shows and texture == null
	_splash.texture = texture
	_splash.visible = splash_has_picture
	_fallback.visible = splash_fallback_shown
	_panel.anchor_top = Splashes.SAFE_TOP if shows else 0.0
	_panel.offset_top = 0.0
	(_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Splashes.SAFE_PANEL_COLOR if shows else Color(0, 0, 0, 0)


## Copies the drawn texts into the labels.
func _show_labels() -> void:
	_title.text = title_text
	_prompt.text = prompt_text
	_dolla_bills.text = dolla_bills_text


## Removes and frees every child of a box. Freed at the end of the frame, so a button may clear its
## own box from its pressed signal (the run screen redraws while the signal runs).
## box: the container to empty.
static func _clear(box: Container) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
