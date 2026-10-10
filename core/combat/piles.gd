## A Dude's card piles in a fight: the opening shuffle, drawing (with the G8 reshuffle) and the
## end-of-turn discard (task 007). Lane: core (Agent A).
##
## Pile names and order rules are in core/schema/dude_state.gd: index 0 of draw_pile is the top
## card; discard_pile's last entry is the most recently discarded.
##
## G8 (docs/proposals/solo-slice-rule-gaps.md, answered "accept"): when a draw needs a card and the
## draw pile is empty, the discard pile is shuffled with that player's "shuffle" stream and becomes
## the draw pile; if both are empty the draw does nothing. There is no hand size limit.
##
## Every function changes the working copy it is given (see core/combat/bodies.gd) and appends
## events. Pure: randomness only through core/rng/rng.gd; no file, clock or network access.
extends RefCounted

const Rng := preload("res://core/rng/rng.gd")
const Event := preload("res://core/schema/event.gd")

## Task 013: the keyword (core/schema/card_def.gd KEYWORDS) of cards kept in hand at end of turn.
const POCKETED: String = "pocketed"


## Starts a Dude's fight: the whole run deck, shuffled with their "shuffle" stream, becomes the
## draw pile; hand, discard and tapped piles are emptied; guard, hype and cards_played_this_turn go
## to 0 and ready to false. Emits nothing (fight_started covers it).
## state: the working copy; its rng must hold "shuffle:<player_id>". dude_index: the Dude's seat, 0-based.
static func prepare_for_fight_in_place(state: Dictionary, dude_index: int) -> void:
	# dude: the Dude being prepared, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# shuffled: {"state", "value"} from the shuffle stream; value is the new draw pile.
	var shuffled: Dictionary = Rng.shuffle(state, Rng.key_for("shuffle", dude["player_id"]), dude["deck"])
	state["rng"] = shuffled["state"]["rng"]
	dude["draw_pile"] = shuffled["value"]
	dude["hand"] = []
	dude["discard_pile"] = []
	dude["tapped_pile"] = []
	# Task 013: last fight's Powers and thorns do not carry over.
	dude["powers"] = []
	dude["thorns"] = 0
	dude["guard"] = 0
	dude["hype"] = 0
	dude["cards_played_this_turn"] = 0
	dude["ready"] = false


## Draws up to count cards from the top of the Dude's draw pile into their hand, one at a time,
## applying the G8 reshuffle whenever the draw pile is empty. Emits deck_shuffled for each
## reshuffle and card_moved (draw_pile -> hand) for each card. Returns how many cards were drawn.
## state: the working copy. dude_index: the Dude's seat, 0-based. count: cards wanted, 0 or more.
## events: the event list, appended to.
static func draw_in_place(state: Dictionary, dude_index: int, count: int, events: Array) -> int:
	# dude: the drawing Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# drawn: cards drawn so far.
	var drawn: int = 0
	while drawn < count:
		if dude["draw_pile"].is_empty():
			if dude["discard_pile"].is_empty():
				break
			# shuffled: {"state", "value"}; value is the discard pile in its new order.
			var shuffled: Dictionary = Rng.shuffle(state, Rng.key_for("shuffle", dude["player_id"]), dude["discard_pile"])
			state["rng"] = shuffled["state"]["rng"]
			dude["draw_pile"] = shuffled["value"]
			dude["discard_pile"] = []
			events.append(Event.make("deck_shuffled", {"player_id": dude["player_id"]}))
		# uid: the top card, now drawn.
		var uid: String = dude["draw_pile"].pop_front()
		dude["hand"].append(uid)
		events.append(Event.make("card_moved", {"player_id": dude["player_id"], "card_uid": uid,
			"from": "draw_pile", "to": "hand"}))
		drawn += 1
	return drawn


## GDD turn flow step 4: every card left in the Dude's hand goes to the discard pile, in hand
## order, except the cards in keep, which stay in the hand in their order. Emits card_moved
## (hand -> discard_pile) for each card discarded.
## state: the working copy. dude_index: the Dude's seat, 0-based. events: the event list, appended to.
## keep: task 013, card_uids to leave in the hand, normally pocketed_in_hand(); [] discards all.
static func discard_hand_in_place(state: Dictionary, dude_index: int, events: Array, keep: Array = []) -> void:
	# dude: the discarding Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# kept: the cards that stay in hand, in hand order.
	var kept: Array = []
	for uid: String in dude["hand"]:
		if keep.has(uid):
			kept.append(uid)
			continue
		dude["discard_pile"].append(uid)
		events.append(Event.make("card_moved", {"player_id": dude["player_id"], "card_uid": uid,
			"from": "hand", "to": "discard_pile"}))
	dude["hand"] = kept


## Task 013: returns the card_uids in the Dude's hand whose definition has the "pocketed" keyword
## (GDD: "The card is not discarded at end of turn"), in hand order. A card the ruleset lacks is not
## pocketed.
## ruleset: the read-only content. dude: a Dude state.
static func pocketed_in_hand(ruleset: Dictionary, dude: Dictionary) -> Array:
	# uids: the result.
	var uids: Array = []
	for uid: String in dude["hand"]:
		# card: the card's definition, or {}.
		var card: Dictionary = ruleset["cards"].get(dude["cards"][uid]["def_id"], {})
		if card.get("keywords", []).has(POCKETED):
			uids.append(uid)
	return uids
