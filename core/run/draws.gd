## The run lane's random draws, on a working copy (task 025). Lane: run (Agent A).
##
## Thin wrappers over core/rng/rng.gd that write the advanced stream back into the working copy, so
## run code can draw in place. Every draw uses exactly one named stream and the same number of steps
## whatever the outcome (a chance always draws one number, even at 0% or 100%), so how many draws a
## node makes never depends on a result, only on the state before it. Which stream each rule uses:
##   encounters        which encounter a fight node holds, and whether a Loot node is a Mimic (G19).
##   rewards:<player>  every card, Gear and Brew offer, Dolla Bills amounts, the Brawl Brew chance,
##                     and Baileys stock (GDD "Random streams": card, Gear and Brew offers).
##   side_quest        which Side Quest a node holds, and every Side Quest gamble and random outcome.
##
## Probabilities from data/constants.json (0.4, 0.25 ...) are compared in whole millionths
## (core/combat/party_scaling.gd to_millionths), never as floats: a chance p hits when a draw from
## 0..999999 is below p x 1000000.
##
## A stream that is missing (only in a hand-built state; new_run.gd makes them all) leaves the state
## unchanged and gives the documented safe value. Pure: randomness only through core/rng/rng.gd.
extends RefCounted

const Rng := preload("res://core/rng/rng.gd")
const Scaling := preload("res://core/combat/party_scaling.gd")

## Whole percent: a Side Quest chance of percent hits when a draw from 0..PERCENT - 1 is below it.
## Not a tuning number: 100 percent is "every time".
const PERCENT: int = 100


## Draws a whole number from lo to hi inclusive on one stream and writes the stream back.
## Returns the number, or lo when the stream is missing or hi is below lo.
## state: the working copy; its rng changes. key: the stream key (Rng.key_for). lo, hi: the range.
static func int_in_place(state: Dictionary, key: String, lo: int, hi: int) -> int:
	# drawn: next_int's result.
	var drawn: Dictionary = Rng.next_int(state, key, lo, hi)
	if drawn["error"] != Rng.NO_ERROR:
		return lo
	state["rng"] = drawn["state"]["rng"]
	return drawn["value"]


## Rolls a probability from data/constants.json: true with that chance. Always draws one number.
## Returns false when the stream is missing.
## state: the working copy; its rng changes. key: the stream key. probability: an int or float, 0..1.
static func chance_in_place(state: Dictionary, key: String, probability: Variant) -> bool:
	return int_in_place(state, key, 0, Scaling.RATIO_DENOMINATOR - 1) < Scaling.to_millionths(probability)


## Rolls a whole-percent chance (Side Quest data): true with percent in 100. Always draws one number.
## Returns false when the stream is missing.
## state: the working copy; its rng changes. key: the stream key. percent: 0..100.
static func percent_in_place(state: Dictionary, key: String, percent: int) -> bool:
	return int_in_place(state, key, 0, PERCENT - 1) < percent


## Picks one entry of a list, each equally likely. Draws nothing for an empty list.
## Returns the entry, or null for an empty list.
## state: the working copy; its rng changes. key: the stream key. items: the list, in a fixed order.
static func pick_in_place(state: Dictionary, key: String, items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[int_in_place(state, key, 0, items.size() - 1)]


## Picks up to count different entries of a list, one draw each, each remaining entry equally likely,
## in the order drawn. Returns fewer when the list is shorter.
## state: the working copy; its rng changes. key: the stream key. items: the list, in a fixed order
## (sort it first if it comes from a Dictionary). count: how many to pick, 0 or more.
static func pick_distinct_in_place(state: Dictionary, key: String, items: Array, count: int) -> Array:
	# left: the entries not picked yet, in their order.
	var left: Array = items.duplicate()
	# picked: the result.
	var picked: Array = []
	while picked.size() < count and not left.is_empty():
		# index: the drawn position in left.
		var index: int = int_in_place(state, key, 0, left.size() - 1)
		picked.append(left[index])
		left.remove_at(index)
	return picked


## Picks an index by weight (ints, 0 or more, total above 0). Returns -1 when every weight is 0 or
## the stream is missing.
## state: the working copy; its rng changes. key: the stream key. weights: the weights, in a fixed order.
static func weighted_in_place(state: Dictionary, key: String, weights: Array) -> int:
	# drawn: weighted_index's result.
	var drawn: Dictionary = Rng.weighted_index(state, key, weights)
	if drawn["error"] != Rng.NO_ERROR:
		return Rng.NO_INDEX
	state["rng"] = drawn["state"]["rng"]
	return drawn["value"]
