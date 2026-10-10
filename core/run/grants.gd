## Changing a Dude between fights: cards, Brews, Dolla Bills, HP, upgrades (task 025). Lane: run (Agent A).
##
## The small steps every node uses, each with its event, so rewards, The Tailgate, Baileys and Side
## Quests change a Dude the same way. Gear is gained with core/combat/gear_triggers.gd gain_in_place
## (its stats apply). Functions ending in _in_place change the working copy they are given.
## Pure: no file, clock, network or random access.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const Upgrades := preload("res://core/combat/upgrades.gd")

## Prefix of a card_uid; must equal core/combat/party.gd CARD_UID_PREFIX (core/schema/README.md "Ids").
const CARD_UID_PREFIX: String = "c"

## card_created "to" and card_removed "from" value for the run deck outside a fight (core/schema/event.gd).
const DECK: String = "deck"


## Adds a new copy of a card to a Dude's run deck (a card reward, a Baileys card, a Side Quest's
## Hangover or Regret): a fresh card_uid from next_uid, not upgraded, at the end of the deck. Emits
## card_created with to "deck". Returns the new card_uid, or "" when the ruleset lacks the card.
## ruleset: the read-only content. state: the working copy. dude_index: the Dude's seat, 0-based.
## card_id: the card definition id. events: the event list, appended to.
static func add_card_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, card_id: String, events: Array) -> String:
	if not ruleset["cards"].has(card_id):
		return ""
	# dude: the receiving Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# uid: the new copy's card_uid.
	var uid: String = CARD_UID_PREFIX + str(state["next_uid"])
	state["next_uid"] += 1
	dude["cards"][uid] = {"def_id": card_id, "upgraded": false}
	dude["deck"].append(uid)
	events.append(Event.make("card_created", {"player_id": dude["player_id"], "card_uid": uid, "def_id": card_id, "to": DECK}))
	return uid


## Removes a card copy from a Dude's run deck for good (Baileys): out of the deck, every pile and the
## cards map. Emits card_removed with from "deck".
## state: the working copy. dude_index: the Dude's seat, 0-based. card_uid: a card in the deck.
## events: the event list, appended to.
static func remove_card_in_place(state: Dictionary, dude_index: int, card_uid: String, events: Array) -> void:
	# dude: the Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	dude["deck"].erase(card_uid)
	for pile: String in DudeState.PILES:
		dude[pile].erase(card_uid)
	dude["cards"].erase(card_uid)
	events.append(Event.make("card_removed", {"player_id": dude["player_id"], "card_uid": card_uid, "from": DECK}))


## Upgrades a card copy (Lift, The Unlabeled Brownie): its instance gets upgraded true. Emits
## card_upgraded. The caller has checked that it can be upgraded (upgradable_cards()).
## state: the working copy. dude_index: the Dude's seat, 0-based. card_uid: the copy.
## events: the event list, appended to.
static func upgrade_card_in_place(state: Dictionary, dude_index: int, card_uid: String, events: Array) -> void:
	# dude: the Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	dude["cards"][card_uid]["upgraded"] = true
	events.append(Event.make("card_upgraded", {"player_id": dude["player_id"], "card_uid": card_uid}))


## Returns the card_uids of a Dude's run deck that can be upgraded, in deck order: not upgraded yet,
## and their definition has an upgrade that applies (G15: Lift only for cards with an upgrade).
## ruleset: the read-only content. dude: the Dude's state.
static func upgradable_cards(ruleset: Dictionary, dude: Dictionary) -> Array:
	# uids: the result.
	var uids: Array = []
	for uid: String in dude["deck"]:
		# instance: the copy's {def_id, upgraded}.
		var instance: Dictionary = dude["cards"][uid]
		if not instance["upgraded"] and Upgrades.can_upgrade(ruleset["cards"].get(instance["def_id"], {})):
			uids.append(uid)
	return uids


## Returns the card_uids of a Dude's run deck that Baileys may remove, in deck order: every card
## whose definition does not say "removable": false (Regret, GDD "Junk cards").
## ruleset: the read-only content. dude: the Dude's state.
static func removable_cards(ruleset: Dictionary, dude: Dictionary) -> Array:
	# uids: the result.
	var uids: Array = []
	for uid: String in dude["deck"]:
		if ruleset["cards"].get(dude["cards"][uid]["def_id"], {}).get("removable", true):
			uids.append(uid)
	return uids


## Puts a Brew into the Dude's first free Brew slot (brew_gained), or, when every slot is full, drops
## it (brew_not_kept). Returns true when it was kept.
## state: the working copy. dude_index: the Dude's seat, 0-based. brew_id: the Brew.
## events: the event list, appended to.
static func gain_brew_in_place(state: Dictionary, dude_index: int, brew_id: String, events: Array) -> bool:
	# dude: the Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	if dude["brews"].size() >= dude["brew_slots"]:
		events.append(Event.make("brew_not_kept", {"player_id": dude["player_id"], "brew_id": brew_id}))
		return false
	dude["brews"].append(brew_id)
	events.append(Event.make("brew_gained", {"player_id": dude["player_id"], "brew_id": brew_id, "slot": dude["brews"].size() - 1}))
	return true


## Changes a Dude's Dolla Bills by delta, never below 0. Emits dolla_bills_changed with the actual
## change, only when it is not 0. Returns the actual change.
## state: the working copy. dude_index: the Dude's seat, 0-based. delta: Dolla Bills to add (negative
## to take). events: the event list, appended to.
static func change_dolla_bills_in_place(state: Dictionary, dude_index: int, delta: int, events: Array) -> int:
	# dude: the Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# change: the actual change after the floor at 0.
	var change: int = maxi(0, dude["dolla_bills"] + delta) - dude["dolla_bills"]
	if change != 0:
		dude["dolla_bills"] += change
		events.append(Event.make("dolla_bills_changed", {"player_id": dude["player_id"], "delta": change,
			"dolla_bills": dude["dolla_bills"]}))
	return change


## Heals a Dude by up to amount HP, never above max HP. Emits healed only when HP changes. Returns
## the HP restored. A Passed Out Dude is not healed (waking is core/run/rewards.gd's revive).
## state: the working copy. dude_index: the Dude's seat, 0-based. amount: HP to restore, 0 or more.
## events: the event list, appended to.
static func heal_in_place(state: Dictionary, dude_index: int, amount: int, events: Array) -> int:
	# dude: the Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	if dude["passed_out"]:
		return 0
	# restored: HP actually gained.
	var restored: int = clampi(amount, 0, maxi(0, dude["max_hp"] - dude["hp"]))
	if restored > 0:
		dude["hp"] += restored
		events.append(Event.make("healed", {"target_id": dude["player_id"], "amount": restored, "hp": dude["hp"]}))
	return restored
