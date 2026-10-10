## The Tailgate: Nap or Lift (task 025, GDD "Node types"). Lane: run (Agent A).
##
## Entering a Tailgate opens one "tailgate" offer per Dude, with two options, and no skip (gap G55) ("Nap
## (heal 30% of max HP) or Lift (upgrade one card)"):
##   0 "nap":  heal TAILGATE_NAP_HEAL of max HP, rounded down (amount; capped at max HP). Gap G57.
##   1 "lift": upgrade one card of the run deck that can be upgraded (card_uids, G15); the player
##             names it in choose_reward's card_uid. Unavailable when no card can be upgraded.
## Functions ending in _in_place change the working copy they are given. Pure.
extends RefCounted

const Ratio := preload("res://core/ops/ratio.gd")
const Grants := preload("res://core/run/grants.gd")
const Offers := preload("res://core/run/offers.gd")

## The offer kind (core/schema/dude_state.gd OFFER_KINDS).
const KIND: String = "tailgate"

## Index of the Nap option in the offer.
const NAP: int = 0

## Index of the Lift option in the offer.
const LIFT: int = 1


## Opens the Tailgate offer for every Dude, in seat order.
## ruleset: the read-only content. state: the working copy. events: the event list, appended to.
static func enter_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	for i: int in state["dudes"].size():
		# dude: this Dude, inside state.
		var dude: Dictionary = state["dudes"][i]
		# liftable: the cards a Lift may upgrade.
		var liftable: Array = Grants.upgradable_cards(ruleset, dude)
		Offers.open_in_place(state, i, KIND, "", false, [
			Offers.option("nap", true, {"amount": nap_amount(ruleset, dude)}),
			Offers.option("lift", not liftable.is_empty(), {"card_uids": liftable}),
		], events)


## Returns the HP a Nap restores now: TAILGATE_NAP_HEAL x max HP rounded down, capped at the HP missing.
## ruleset: the read-only content. dude: the Dude.
static func nap_amount(ruleset: Dictionary, dude: Dictionary) -> int:
	# heal: the Nap's size before the cap.
	var heal: int = Ratio.floor_times(dude["max_hp"], Ratio.from_constant(ruleset["constants"]["TAILGATE_NAP_HEAL"]))
	return clampi(heal, 0, maxi(0, dude["max_hp"] - dude["hp"]))


## Applies a checked choice: a Nap heals, a Lift upgrades the named card; then the offer closes.
## ruleset: the read-only content. state: the working copy. dude_index: the Dude's seat, 0-based.
## offer: the Dude's tailgate offer. choice_index: NAP or LIFT. card_uid: the card for a Lift.
## events: the event list, appended to.
static func choose_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, offer: Dictionary,
		choice_index: int, card_uid: String, events: Array) -> void:
	if choice_index == NAP:
		Grants.heal_in_place(state, dude_index, nap_amount(ruleset, state["dudes"][dude_index]), events)
	else:
		Grants.upgrade_card_in_place(state, dude_index, card_uid, events)
	Offers.close_in_place(state, dude_index, offer["id"], choice_index, events)
