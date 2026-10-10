## Card rules that run without the card being played (task 015, GDD "Junk cards"). Lane: core (Agent A).
##
## Each rule reads an optional field of the card definition (core/schema/card_def.gd), so Junk is
## data, not code keyed to a card id:
##   on_draw                 effects run right after the copy is drawn (Hangover, Bedbugs).
##                           draw_in_place() below is the draw to use whenever the rules draw.
##   on_end_of_turn_in_hand  effects run at End of turn for each copy in hand, before the hand is
##                           discarded (Burn).
##   play_limit_in_hand      while the copy is in hand, its owner may play at most that many cards
##                           this turn; further play_card requests are "unplayable" (Detention).
##   lasts "fight"           the copy is removed from its owner's cards, deck and piles when the
##                           fight ends (Paperwork, Detention, Burn), with card_removed. Task 033:
##                           so is any copy its owner has that is not in the run deck (an add_card
##                           with lasts "fight", such as Beer Helmet's Hangover), since
##                           dude_state.deck is every card the Dude owns for the run.
##   removable               read by the run lane's Baileys (task 025), not here.
##
## Trigger effects run like a card's: the owner is the actor and the only target, damage is not
## attack damage (G3), and they count as "from a card" (Hungover). They resolve in list order and
## stop once the fight is decided; an effect that fails Ops.check() is skipped (a trigger has no
## reject path; content tests catch it). A Passed Out Dude's triggers do not run.
##
## Callers: core/combat/fight.gd (Refresh draw, End of turn, fight end) and core/combat/play.gd
## (the limit), at lines marked "Task 015".
##
## "rules" below is the ruleset, or any Dictionary holding its "cards" and "constants" (an op
## context from core/ops/ops.gd make_context() has both), so an op that draws can pass its context.
##
## Every _in_place function changes the working copy it is given (see core/combat/bodies.gd). Pure:
## randomness only through core/rng/rng.gd (via piles.gd); no file, clock or network access.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const Ops := preload("res://core/ops/ops.gd")
const AddCard := preload("res://core/ops/add_card.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const Piles := preload("res://core/combat/piles.gd")

## card_removed "from" value for a copy that was in no pile (core/schema/event.gd).
const FROM_DECK: String = "deck"


## Draws up to count cards like Piles.draw_in_place (G8 reshuffle included), one at a time, and runs
## each drawn card's on_draw effects right after it reaches the hand. Stops early when the Dude is
## Passed Out (Bedbugs can do that) or the fight is decided. Returns how many cards were drawn.
## rules: the ruleset or an op context (see the file header). state: the working copy.
## dude_index: the drawing Dude's seat, 0-based. count: cards wanted, 0 or more.
## events: the event list, appended to.
static func draw_in_place(rules: Dictionary, state: Dictionary, dude_index: int, count: int, events: Array) -> int:
	# dude: the drawing Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# drawn: cards drawn so far.
	var drawn: int = 0
	while drawn < count:
		if dude["passed_out"] or _decided(state):
			break
		if Piles.draw_in_place(state, dude_index, 1, events) == 0:
			break
		drawn += 1
		# uid: the card just drawn, the last one in hand.
		var uid: String = dude["hand"].back()
		run_effects_in_place(rules, state, dude_index, _definition(rules, dude, uid).get("on_draw", []), events)
	return drawn


## GDD turn flow step 4, before the hand is discarded: runs on_end_of_turn_in_hand for every copy in
## the Dude's hand, in hand order. Does nothing for a Passed Out Dude.
## rules: the ruleset or an op context. state: the working copy, in a fight.
## dude_index: the Dude's seat, 0-based. events: the event list, appended to.
static func end_of_turn_in_hand_in_place(rules: Dictionary, state: Dictionary, dude_index: int, events: Array) -> void:
	# dude: the Dude whose hand is checked, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	for uid: String in dude["hand"].duplicate():
		if dude["passed_out"] or _decided(state):
			return
		if dude["hand"].has(uid):
			run_effects_in_place(rules, state, dude_index, _definition(rules, dude, uid).get("on_end_of_turn_in_hand", []), events)


## Runs a trigger's effects with the Dude as actor and only target (see the file header).
## rules: the ruleset or an op context. state: the working copy. dude_index: the card owner's seat.
## effects: the trigger's effects list (from a card definition). events: the event list, appended to.
static func run_effects_in_place(rules: Dictionary, state: Dictionary, dude_index: int, effects: Array, events: Array) -> void:
	if effects.is_empty():
		return
	# player_id: the card owner, actor and target of the effects.
	var player_id: String = state["dudes"][dude_index]["player_id"]
	# context: the op context; not attack damage (G3), from a card (Hungover).
	var context: Dictionary = Ops.make_context(rules, player_id, [player_id], false, true)
	for effect: Variant in effects:
		if state["dudes"][dude_index]["passed_out"] or _decided(state):
			return
		if Ops.check(effect).is_empty():
			Ops.run(state, effect, context, events)


## True when a copy in the Dude's hand has play_limit_in_hand and the Dude has already played at
## least that many cards this turn, so another play is "unplayable" (Detention). With several such
## copies the smallest limit counts. Reads only.
## rules: the ruleset or an op context. dude: the Dude's state.
static func play_limit_reached(rules: Dictionary, dude: Dictionary) -> bool:
	for uid: String in dude["hand"]:
		# limit: this copy's play limit, or -1 when it has none.
		var limit: Variant = _definition(rules, dude, uid).get("play_limit_in_hand", -1)
		if typeof(limit) == TYPE_INT and limit >= 0 and dude["cards_played_this_turn"] >= limit:
			return true
	return false


## When a fight ends: removes every fight-only copy (_fight_only: its definition lasts "fight", or,
## task 033, it is not in the run deck) from each Dude's cards, deck, piles and powers list, Dudes in
## seat order, copies in pile order (core/schema/dude_state.gd PILES, each pile front to back), then
## the deck, then any other owned copy by card_uid. Emits card_removed per copy, with from = the
## pile it was in, or "deck" when it was in no pile (a Power in play is in no pile). Copies in the
## run deck whose definition lasts the run are untouched. Copies whose definition is missing from
## the ruleset are kept.
## rules: the ruleset or an op context. state: the working copy. events: the event list, appended to.
static func remove_fight_only_in_place(rules: Dictionary, state: Dictionary, events: Array) -> void:
	for dude: Dictionary in state["dudes"]:
		# found: [card_uid, where it was] for each fight-only copy, in removal order.
		var found: Array = []
		# seen: card_uids already in found.
		var seen: Dictionary = {}
		for pile: String in DudeState.PILES:
			for uid: String in dude[pile]:
				if not seen.has(uid) and _fight_only(rules, dude, uid):
					found.append([uid, pile])
					seen[uid] = true
		# owned: every other copy, deck order first, then the cards map's keys sorted.
		var owned: Array = dude["deck"].duplicate()
		# keys: the cards map's keys, sorted so the order never depends on the map.
		var keys: Array = dude["cards"].keys()
		keys.sort()
		owned.append_array(keys)
		for uid: String in owned:
			if not seen.has(uid) and _fight_only(rules, dude, uid):
				found.append([uid, FROM_DECK])
				seen[uid] = true
		for entry: Array in found:
			for pile: String in DudeState.PILES:
				dude[pile].erase(entry[0])
			dude["deck"].erase(entry[0])
			# Task 033: a fight-only Power in play leaves the powers list too, so powers only holds owned cards.
			dude["powers"].erase(entry[0])
			dude["cards"].erase(entry[0])
			events.append(Event.make("card_removed", {"player_id": dude["player_id"], "card_uid": entry[0], "from": entry[1]}))


## Returns the definition of a copy the Dude owns, or {} when the copy or its definition is unknown.
## rules: the ruleset or an op context. dude: the owner's state. uid: a card_uid.
static func _definition(rules: Dictionary, dude: Dictionary, uid: String) -> Dictionary:
	if not dude["cards"].has(uid):
		return {}
	return rules.get("cards", {}).get(dude["cards"][uid]["def_id"], {})


## True when the Dude owns this copy, its definition is known, and the copy lasts one fight only:
## its definition lasts "fight", or (task 033) the copy is not in the run deck.
## rules: the ruleset or an op context. dude: the owner's state. uid: a card_uid.
static func _fight_only(rules: Dictionary, dude: Dictionary, uid: String) -> bool:
	# definition: the copy's definition, or {}.
	var definition: Dictionary = _definition(rules, dude, uid)
	return not definition.is_empty() and (AddCard.is_fight_only(definition) or not dude["deck"].has(uid))


## True when the state is in a fight that is decided (core/combat/bodies.gd is_decided); false
## outside a fight.
## state: a run state.
static func _decided(state: Dictionary) -> bool:
	return state["combat"] != null and Bodies.is_decided(state)
