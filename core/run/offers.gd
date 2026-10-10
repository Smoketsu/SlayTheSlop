## Open choices on a map node: making, finding and closing offers (task 025). Lane: run (Agent A).
##
## Shapes: core/schema/dude_state.gd OFFER_SPEC and OPTION_SPEC. Every choice a player makes on a
## node is an offer in their dude_state.offers, answered by choose_reward (reward_id = the offer's
## id). Offer ids are "o" + run_state.next_uid, so they are unique in the run and a stale reward_id
## from an earlier node can never match a new offer. Functions ending in _in_place change the working
## copy they are given. Pure: no file, clock, network or random access.
extends RefCounted

const Event := preload("res://core/schema/event.gd")

## Prefix of an offer id (core/schema/README.md "Ids"). Part of the id format; never changes.
const OFFER_PREFIX: String = "o"

## choice_index that skips a card reward or leaves Baileys (GDD "choose_reward": -1 to skip).
const SKIP: int = -1


## Opens a new offer for a Dude: appends it to their offers (offer_opened) and returns it (the
## Dictionary inside state).
## state: the working copy; next_uid rises by 1. dude_index: the Dude's seat, 0-based.
## kind: one of dude_state.gd OFFER_KINDS. def_id: the Side Quest id for "side_quest", else "".
## skippable: whether -1 may answer it. options: its options (option() builds one).
## events: the event list, appended to.
static func open_in_place(state: Dictionary, dude_index: int, kind: String, def_id: String, skippable: bool,
		options: Array, events: Array) -> Dictionary:
	# dude: the Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# offer: the new offer.
	var offer: Dictionary = {"id": OFFER_PREFIX + str(state["next_uid"]), "kind": kind, "def_id": def_id,
		"skippable": skippable, "options": options}
	state["next_uid"] += 1
	dude["offers"].append(offer)
	events.append(Event.make("offer_opened", {"player_id": dude["player_id"], "reward_id": offer["id"], "kind": kind}))
	return offer


## Returns one option Dictionary: {"kind": kind, "available": available} plus the extra fields.
## kind: one of dude_state.gd OPTION_KINDS. available: whether it can be picked now.
## extra: optional fields from dude_state.gd OPTION_OPTIONAL (card_id, price ...).
static func option(kind: String, available: bool, extra: Dictionary = {}) -> Dictionary:
	# result: the option.
	var result: Dictionary = {"kind": kind, "available": available}
	result.merge(extra)
	return result


## Returns the position of a Dude's open offer with this id, or -1 when they have none.
## dude: the Dude's state. reward_id: an offer id.
static func find(dude: Dictionary, reward_id: String) -> int:
	for i: int in dude["offers"].size():
		if dude["offers"][i]["id"] == reward_id:
			return i
	return -1


## Closes a Dude's offer: removes it from their offers (offer_closed).
## state: the working copy. dude_index: the Dude's seat, 0-based. reward_id: the offer's id.
## choice_index: the choice that closed it, -1 for skip or leave. events: the event list, appended to.
static func close_in_place(state: Dictionary, dude_index: int, reward_id: String, choice_index: int, events: Array) -> void:
	# dude: the Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# index: the offer's position.
	var index: int = find(dude, reward_id)
	if index == -1:
		return
	dude["offers"].remove_at(index)
	events.append(Event.make("offer_closed", {"player_id": dude["player_id"], "reward_id": reward_id, "choice_index": choice_index}))


## True when any Dude still has an open offer, so the party stays on the node.
## state: a run state.
static func anyone_choosing(state: Dictionary) -> bool:
	for dude: Dictionary in state["dudes"]:
		if not dude["offers"].is_empty():
			return true
	return false
