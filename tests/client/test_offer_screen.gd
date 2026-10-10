## Tests for the offer screen (task 020, client/run/offer_screen.gd) on real states: every offer of a
## fixed-seed run on the real data (tests/client/run_choices_drive.gd), which reaches a card reward,
## Baileys, a Side Quest, The Tailgate and the Boss Gear pick. Lane: tools/client (Agent B).
## Acceptance checks: reward, Tailgate, Baileys, Side Quest and boss reward send exactly task 025's
## requests (choose_reward, -1 only where skippable), each passing request.gd check(); prices, offers
## and Dolla Bills are read from the state; at Baileys every Brew is labelled Shake and no string
## mentions beer or another drink.
extends "res://tests/framework/test_case.gd"

const Drive := preload("res://tests/client/run_choices_drive.gd")
const OfferScreen := preload("res://client/run/offer_screen.gd")
const RunText := preload("res://client/run/run_text.gd")
const Core := preload("res://core/core.gd")
const Request := preload("res://core/schema/request.gd")
const DudeState := preload("res://core/schema/dude_state.gd")

## Words that must never be shown at Baileys (CLAUDE.md "Baileys sells weed, not drinks"), matched as
## whole words, any case, with a plural or -ing ending.
const DRINK_WORDS: String = "\\b(beer|drink|ale|booze|liquor|shot|wine|brew)(s|es|ing)?\\b"


## Returns an offer screen showing the state for the first Dude's player, and the list its requests
## land in. Result: {"screen": the screen (free it), "sent": Array, filled as it emits}.
## rules: the ruleset. state: the run state to show.
func _shown(rules: Dictionary, state: Dictionary) -> Dictionary:
	# screen: a new offer screen.
	var screen: Control = OfferScreen.new()
	# sent: the requests the screen emits.
	var sent: Array = []
	screen.request_made.connect(func(request: Dictionary) -> void: sent.append(request))
	screen.show_state(rules, state, state["dudes"][0]["player_id"])
	return {"screen": screen, "sent": sent}


## Returns the drive's whole run, or {} after recording a failure.
func _played() -> Dictionary:
	# played: the run through the screens.
	var played: Dictionary = Drive.play()
	assert_false(played.is_empty(), "the run starts on the real data")
	return played


## The whole run's offers were answered through the screen, every request was the bot's and was
## accepted, the boss fell, and every offer kind was reached on a real state.
func test_whole_run_reaches_every_offer_kind() -> void:
	# played: the run.
	var played: Dictionary = _played()
	if played.is_empty():
		return
	assert_eq(played["problems"], [], "every choice went through the screens and was accepted")
	assert_eq(played["final"]["run_phase"], "floor_end", "the boss is beaten")
	# kinds: the offer kinds answered.
	var kinds: Dictionary = {}
	for state: Dictionary in played["offer_states"]:
		kinds[state["dudes"][0]["offers"][0]["kind"]] = true
	for kind: String in DudeState.OFFER_KINDS:
		assert_true(kinds.has(kind), "an offer of kind %s on a real state" % kind)


## Every offer of the run is drawn from the state: the title, the Dolla Bills, one button per option in
## order with the option's own name, price and amount, disabled exactly when "available" is false,
## and a Skip / Leave button exactly when the offer is skippable.
func test_every_offer_is_drawn_from_the_state() -> void:
	# played: the run.
	var played: Dictionary = _played()
	if played.is_empty():
		return
	# rules: the real ruleset.
	var rules: Dictionary = played["rules"]
	for state: Dictionary in played["offer_states"]:
		# shown: the screen.
		var shown: Dictionary = _shown(rules, state)
		_check_drawn(rules, state, shown["screen"])
		shown["screen"].free()


## On the first offer of each kind, every option sends exactly the choose_reward its click should,
## passing request.gd check() and accepted by Core.apply() (at Baileys an item may be refused as
## unplayable, but only when it costs more than the Dude holds or is a Shake with every Brew slot
## full); an unavailable option sends nothing; Skip / Leave sends -1 only on a skippable offer.
func test_every_option_sends_an_accepted_request() -> void:
	# played: the run.
	var played: Dictionary = _played()
	if played.is_empty():
		return
	# rules: the real ruleset.
	var rules: Dictionary = played["rules"]
	for kind: String in DudeState.OFFER_KINDS:
		# state: the first state with this kind of offer.
		var state: Dictionary = Drive.first_with_offer(played["offer_states"], kind)
		assert_false(state.is_empty(), "a %s offer was reached" % kind)
		if state.is_empty():
			continue
		# dude: the local Dude. offer: the offer.
		var dude: Dictionary = state["dudes"][0]
		var offer: Dictionary = dude["offers"][0]
		for i: int in offer["options"].size():
			# option: the option pressed.
			var option: Dictionary = offer["options"][i]
			# label: names the case.
			var label: String = "%s option %d (%s)" % [kind, i, option["kind"]]
			# shown: a fresh screen.
			var shown: Dictionary = _shown(rules, state)
			# card_uid: the card picked for a Lift or removal, else "".
			var card_uid: String = ""
			if RunText.CARD_PICK_KINDS.has(option["kind"]) and option["available"]:
				card_uid = option["card_uids"][0]
				shown["screen"].press_option(i)
				assert_eq(shown["sent"], [], "%s: opening the card list sends nothing" % label)
				shown["screen"].press_pick(card_uid)
			else:
				shown["screen"].press_option(i)
			if not option["available"]:
				assert_eq(shown["sent"], [], "%s: unavailable, sends nothing" % label)
				shown["screen"].free()
				continue
			# expected: the request the click should send.
			var expected: Dictionary = {"type": "choose_reward", "reward_id": offer["id"], "choice_index": i}
			if card_uid != "":
				expected["card_uid"] = card_uid
			assert_eq(shown["sent"], [expected], label)
			if shown["sent"].size() == 1:
				# reject: the core's answer to it.
				var reject: String = _apply(rules, state, shown["sent"][0], label)
				if kind == "baileys" and reject == "unplayable":
					assert_true(option["price"] > dude["dolla_bills"]
						or (option["kind"] == "shake" and dude["brews"].size() >= dude["brew_slots"]),
						"%s: refused only when unaffordable or no free Brew slot" % label)
				else:
					assert_eq(reject, "", "%s: accepted" % label)
			shown["screen"].free()
		# shown: a fresh screen for Skip / Leave.
		var shown: Dictionary = _shown(rules, state)
		assert_eq(shown["screen"].skip_button != null, offer["skippable"], "%s: skip button only when skippable" % kind)
		shown["screen"].press_skip()
		if offer["skippable"]:
			assert_eq(shown["sent"], [{"type": "choose_reward", "reward_id": offer["id"], "choice_index": -1}], "%s: skip" % kind)
			if shown["sent"].size() == 1:
				assert_eq(_apply(rules, state, shown["sent"][0], kind + " skip"), "", "%s: -1 accepted" % kind)
		else:
			assert_eq(shown["sent"], [], "%s: no skip" % kind)
		shown["screen"].free()


## A Lift opens the option's card list (names from the Dude's cards, in card_uids order) without
## sending; Never mind closes it; a card not in the list sends nothing; picking one sends its card_uid.
func test_lift_picks_a_card_from_the_list() -> void:
	# played: the run.
	var played: Dictionary = _played()
	if played.is_empty():
		return
	# state: the run's first Tailgate.
	var state: Dictionary = Drive.first_with_offer(played["offer_states"], "tailgate")
	if state.is_empty():
		fail("a Tailgate was reached")
		return
	# dude: the local Dude. offer: the Tailgate. lift: the Lift option's index.
	var dude: Dictionary = state["dudes"][0]
	var offer: Dictionary = dude["offers"][0]
	var lift: int = -1
	for i: int in offer["options"].size():
		if offer["options"][i]["kind"] == "lift":
			lift = i
	assert_true(lift >= 0 and offer["options"][lift]["available"], "the Tailgate has a Lift with cards")
	if lift < 0 or not offer["options"][lift]["available"]:
		return
	# uids: the cards that can be Lifted.
	var uids: Array = offer["options"][lift]["card_uids"]
	# shown: the screen. screen: the offer screen.
	var shown: Dictionary = _shown(played["rules"], state)
	var screen: Control = shown["screen"]
	screen.press_option(lift)
	assert_eq(screen.picking_index, lift, "the card list is open")
	# names: the expected card names.
	var names: Array[String] = []
	for uid: String in uids:
		names.append(played["rules"]["cards"][dude["cards"][uid]["def_id"]]["name"] + ("+" if dude["cards"][uid]["upgraded"] else ""))
	assert_eq(screen.pick_texts, names, "the list shows the option's cards")
	assert_eq(screen.pick_buttons.size(), uids.size())
	screen.press_cancel_pick()
	assert_eq(screen.picking_index, -1, "Never mind closes the list")
	screen.press_pick(uids[0])
	screen.press_option(lift, "c99999")
	assert_eq(shown["sent"], [], "nothing sent without an open list or with a card not on it")
	screen.press_option(lift)
	screen.press_pick(uids[uids.size() - 1])
	assert_eq(shown["sent"], [{"type": "choose_reward", "reward_id": offer["id"], "choice_index": lift,
		"card_uid": uids[uids.size() - 1]}])
	if shown["sent"].size() == 1:
		assert_eq(_apply(played["rules"], state, shown["sent"][0], "lift"), "", "the Lift is accepted")
	screen.free()


## Prices, amounts and Dolla Bills are shown exactly as the state holds them: on copies of real
## Baileys and Tailgate states with odd numbers put in (display only), the labels show those numbers.
func test_numbers_come_from_the_state() -> void:
	# played: the run.
	var played: Dictionary = _played()
	if played.is_empty():
		return
	# baileys: a copy of the first Baileys state, with made-up prices and Dolla Bills.
	var baileys: Dictionary = Drive.first_with_offer(played["offer_states"], "baileys").duplicate(true)
	# options: its options.
	var options: Array = baileys["dudes"][0]["offers"][0]["options"]
	for i: int in options.size():
		options[i]["price"] = 1001 + i * 7
	baileys["dudes"][0]["dolla_bills"] = 4321
	# shown: the screen.
	var shown: Dictionary = _shown(played["rules"], baileys)
	assert_eq(shown["screen"].dolla_bills_text, "4321 Dolla Bills")
	for i: int in options.size():
		assert_true(shown["screen"].option_texts[i].contains("[%d Dolla Bills]" % (1001 + i * 7)), shown["screen"].option_texts[i])
	shown["screen"].free()
	# tailgate: a copy of the first Tailgate state with a made-up Nap amount.
	var tailgate: Dictionary = Drive.first_with_offer(played["offer_states"], "tailgate").duplicate(true)
	for option: Dictionary in tailgate["dudes"][0]["offers"][0]["options"]:
		if option["kind"] == "nap":
			option["amount"] = 77
	shown = _shown(played["rules"], tailgate)
	assert_true(shown["screen"].option_texts.has("Nap — heal 77 HP"), str(shown["screen"].option_texts))
	shown["screen"].free()


## An option whose "available" is false is disabled, says why, and pressing it sends nothing. Display
## test on a copy of the run's Side Quest with its dumb option made unavailable (as G23 does).
func test_unavailable_option_is_disabled() -> void:
	# played: the run.
	var played: Dictionary = _played()
	if played.is_empty():
		return
	# state: a copy of the Side Quest state.
	var state: Dictionary = Drive.first_with_offer(played["offer_states"], "side_quest").duplicate(true)
	state["dudes"][0]["offers"][0]["options"][1]["available"] = false
	# shown: the screen. screen: the offer screen.
	var shown: Dictionary = _shown(played["rules"], state)
	var screen: Control = shown["screen"]
	assert_true(screen.option_buttons[1].disabled, "unavailable is disabled")
	assert_false(screen.option_buttons[0].disabled, "available is enabled")
	assert_true(screen.option_texts[1].ends_with("(%s)" % RunText.UNAVAILABLE["dumb"]), screen.option_texts[1])
	screen.press_option(1)
	assert_eq(shown["sent"], [], "nothing sent")
	screen.press_option(5)
	screen.press_option(-2)
	assert_eq(shown["sent"], [], "nothing sent for an index out of range")
	screen.free()


## At Baileys every Brew is labelled Shake: on a copy of the run's real Baileys state stocked with all
## 8 Brews (and every Gear Baileys could sell), each Brew option reads "Shake: <Brew name> — <effect>",
## and no string on the screen, the removal's card list included, mentions beer or another drink or
## shows a Brew's id. The unmodified real Baileys is checked the same way.
func test_baileys_sells_shake_not_drinks() -> void:
	# played: the run.
	var played: Dictionary = _played()
	if played.is_empty():
		return
	# rules: the real ruleset.
	var rules: Dictionary = played["rules"]
	# real: the run's first Baileys state.
	var real: Dictionary = Drive.first_with_offer(played["offer_states"], "baileys")
	_check_baileys_words(rules, real, "real Baileys")
	# stocked: a copy with every Brew and every non-boss Gear in stock (display only).
	var stocked: Dictionary = real.duplicate(true)
	# offer: its offer.
	var offer: Dictionary = stocked["dudes"][0]["offers"][0]
	# options: the new stock: the real cards, every Gear Baileys could sell, all 8 Brews, the removal.
	var options: Array = []
	for option: Dictionary in offer["options"]:
		if option["kind"] == "card":
			options.append(option)
	# gear_ids: every Gear id, sorted.
	var gear_ids: Array = rules["gear"].keys()
	gear_ids.sort()
	for gear_id: String in gear_ids:
		if rules["gear"][gear_id]["rarity"] != "boss":
			options.append({"kind": "gear", "available": true, "gear_id": gear_id, "price": 150})
	# brew_ids: every Brew id, sorted.
	var brew_ids: Array = rules["brews"].keys()
	brew_ids.sort()
	assert_eq(brew_ids.size(), 8, "the slice has 8 Brews")
	# first_shake: the index of the first Shake option.
	var first_shake: int = options.size()
	for brew_id: String in brew_ids:
		options.append({"kind": "shake", "available": true, "brew_id": brew_id, "price": 50})
	for option: Dictionary in offer["options"]:
		if option["kind"] == "remove":
			options.append(option)
	offer["options"] = options
	# shown: the screen. screen: the offer screen.
	var shown: Dictionary = _shown(rules, stocked)
	var screen: Control = shown["screen"]
	for i: int in brew_ids.size():
		# brew: the Brew's definition. text: its option's label.
		var brew: Dictionary = rules["brews"][brew_ids[i]]
		var text: String = screen.option_texts[first_shake + i]
		assert_true(text.begins_with("Shake: %s — %s" % [brew["name"], brew["text"]]), text)
	screen.free()
	_check_baileys_words(rules, stocked, "Baileys with every Brew")


## With no open offer the screen says so (waiting while the party is still at a node), shows no option or skip button, and sends nothing.
func test_no_offer_shows_nothing_to_choose() -> void:
	# begun: a new run, on the map with no offer.
	var begun: Dictionary = Drive.start()
	if begun.is_empty():
		fail("the run starts")
		return
	# shown: the screen. screen: the offer screen.
	var shown: Dictionary = _shown(begun["rules"], begun["state"])
	var screen: Control = shown["screen"]
	assert_eq(screen.title_text, OfferScreen.NOTHING_TEXT)
	assert_eq(screen.option_buttons.size(), 0)
	assert_true(screen.skip_button == null, "no skip button")
	screen.press_option(0)
	screen.press_skip()
	assert_eq(shown["sent"], [], "nothing sent")
	screen.free()
	# played: the run.
	var played: Dictionary = _played()
	if played.is_empty():
		return
	# waiting: a copy of a real card-reward state with the offer already answered, as co-op leaves a
	# player whose party is still choosing (display only).
	var waiting: Dictionary = Drive.first_with_offer(played["offer_states"], "card").duplicate(true)
	waiting["dudes"][0]["offers"] = []
	shown = _shown(played["rules"], waiting)
	assert_eq(shown["screen"].title_text, OfferScreen.WAITING_TEXT, "waiting at a node")
	assert_eq(shown["screen"].option_buttons.size(), 0)
	shown["screen"].free()


## The screen is redrawn on the same instance after every request, in the scene tree as the run
## screen uses it: each redraw leaves exactly one button per option (no duplicates), and an open card
## list is closed.
func test_redraw_on_the_same_screen() -> void:
	# played: the run.
	var played: Dictionary = _played()
	if played.is_empty():
		return
	# screen: one screen in the tree, redrawn on every offer state of the run.
	var screen: Control = OfferScreen.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	for state: Dictionary in played["offer_states"]:
		screen.show_state(played["rules"], state, state["dudes"][0]["player_id"])
		screen.show_state(played["rules"], state, state["dudes"][0]["player_id"])
		# options: the offer's options.
		var options: Array = state["dudes"][0]["offers"][0]["options"]
		assert_eq(screen._options_box.get_child_count(), options.size(), "one button per option after a redraw")
		assert_eq(screen._skip_box.get_child_count(), 1 if state["dudes"][0]["offers"][0]["skippable"] else 0)
		for i: int in options.size():
			if RunText.CARD_PICK_KINDS.has(options[i]["kind"]) and options[i]["available"]:
				screen.press_option(i)
		screen.show_state(played["rules"], state, state["dudes"][0]["player_id"])
		assert_eq(screen._pick_box.get_child_count(), 0, "a redraw closes the card list")
		assert_eq(screen.picking_index, -1)
	screen.get_parent().remove_child(screen)
	screen.free()


## Checks one drawn offer against its state (see test_every_offer_is_drawn_from_the_state).
## rules: the ruleset. state: the state shown. screen: an offer screen showing it.
func _check_drawn(rules: Dictionary, state: Dictionary, screen: Control) -> void:
	# dude: the local Dude. offer: its first offer.
	var dude: Dictionary = state["dudes"][0]
	var offer: Dictionary = dude["offers"][0]
	# label: names the offer in messages.
	var label: String = "%s %s" % [offer["kind"], offer["id"]]
	if offer["kind"] == "side_quest":
		assert_eq(screen.title_text, rules["side_quests"][offer["def_id"]]["name"], label)
		assert_eq(screen.prompt_text, rules["side_quests"][offer["def_id"]]["text"], label)
	else:
		assert_eq(screen.title_text, RunText.OFFER_TITLES[offer["kind"]], label)
	assert_eq(screen.dolla_bills_text, "%d Dolla Bills" % dude["dolla_bills"], label)
	assert_eq(screen.option_texts.size(), offer["options"].size(), label + ": one button per option")
	assert_eq(screen.skip_button != null, offer["skippable"], label + ": skip only when skippable")
	for i: int in mini(offer["options"].size(), screen.option_texts.size()):
		# option: the option. text: its label.
		var option: Dictionary = offer["options"][i]
		var text: String = screen.option_texts[i]
		assert_eq(screen.option_buttons[i].disabled, not option["available"], "%s option %d disabled" % [label, i])
		if option.has("price"):
			assert_true(text.contains("[%d Dolla Bills]" % option["price"]), "%s: %s shows its price" % [label, text])
		match option["kind"]:
			"card":
				assert_true(text.begins_with(rules["cards"][option["card_id"]]["name"] + " ("), "%s: %s" % [label, text])
			"gear":
				assert_true(text.begins_with(rules["gear"][option["gear_id"]]["name"] + " — "), "%s: %s" % [label, text])
			"shake":
				assert_true(text.begins_with("Shake: " + rules["brews"][option["brew_id"]]["name"]), "%s: %s" % [label, text])
			"nap":
				assert_true(text.begins_with("Nap — heal %d HP" % option["amount"]), "%s: %s" % [label, text])
			"lift":
				assert_true(text.begins_with("Lift"), "%s: %s" % [label, text])
			"remove":
				assert_true(text.begins_with("Get rid of a card"), "%s: %s" % [label, text])
			"safe", "dumb":
				assert_true(text.begins_with(rules["side_quests"][offer["def_id"]][option["kind"]]["label"]), "%s: %s" % [label, text])


## Shows a Baileys state, opens the removal's card list, and checks every string on the screen: no
## drink word (DRINK_WORDS) and no Brew id; every Brew option's label starts with "Shake".
## rules: the ruleset. state: a state whose first offer is Baileys. label: names the case.
func _check_baileys_words(rules: Dictionary, state: Dictionary, label: String) -> void:
	# offer: the Baileys offer.
	var offer: Dictionary = state["dudes"][0]["offers"][0]
	assert_eq(offer["kind"], "baileys", label)
	# shown: the screen. screen: the offer screen.
	var shown: Dictionary = _shown(rules, state)
	var screen: Control = shown["screen"]
	# shakes: how many option labels start with "Shake".
	var shakes: int = 0
	for i: int in offer["options"].size():
		if offer["options"][i]["kind"] == "shake":
			assert_true(screen.option_texts[i].begins_with("Shake: "), "%s: %s" % [label, screen.option_texts[i]])
			shakes += 1
		if offer["options"][i]["kind"] == "remove" and offer["options"][i]["available"]:
			screen.press_option(i)
			assert_false(screen.pick_texts.is_empty(), label + ": the removal lists cards")
	assert_true(shakes > 0, label + ": Shake in stock")
	# drinks: matches a drink word.
	var drinks: RegEx = RegEx.create_from_string("(?i)" + DRINK_WORDS)
	for text: String in screen.shown_texts():
		assert_true(drinks.search(text) == null, "%s: \"%s\" names a drink" % [label, text])
		for brew_id: String in rules["brews"]:
			assert_false(text.contains(brew_id), "%s: \"%s\" shows Brew id %s" % [label, text, brew_id])
	assert_eq(shown["sent"], [], label + ": opening the removal list sends nothing")
	screen.free()


## Applies a request completed with the first Dude's player_id and next seq. Returns the reject
## reason, "" when accepted; checks the request's shape first.
## rules: the ruleset. state: the state to apply to (not changed). request: the screen's request.
## label: names the case.
func _apply(rules: Dictionary, state: Dictionary, request: Dictionary, label: String) -> String:
	# dude: the sender.
	var dude: Dictionary = state["dudes"][0]
	# full: the request as the run screen sends it.
	var full: Dictionary = Drive.completed(request, dude["player_id"], dude["last_seq"] + 1)
	assert_no_errors(Request.check(full), label)
	return Core.apply(rules, state, full)["reject"]
