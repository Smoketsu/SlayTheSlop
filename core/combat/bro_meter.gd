## The Bro Meter: gaining points and changing the shared gauge (task 013). Lane: core (Agent A).
##
## GDD "Bro Meter": a shared 0..BRO_METER_MAX gauge (run_state.bro_meter, kept between fights).
##   - Solo (party_size 1): it gains 1 for every BRO_METER_SOLO_CARDS-th card played in a turn
##     (the 3rd, 6th, 9th ... with the default 3), counted by the Dude's cards_played_this_turn,
##     which Refresh resets. Checked right after each card from the hand finishes resolving
##     (core/combat/play.gd), so a card that ends the fight still counts. The Bro Move itself is not
##     a card played from the hand and does not count.
##   - Co-op (party_size 2..4): "gains 1 whenever a player attacks an enemy that a different player
##     debuffed this turn". NOT BUILT: it needs per-enemy "debuffed by" state for the turn (a
##     contract change) and networking is out of scope. In co-op the meter currently never gains.
##   - It never goes above BRO_METER_MAX or below 0. bro_meter_changed is emitted on every change.
## Using the meter is core/combat/bro_move.gd.
##
## Pure: no file, clock, network or random access. Functions ending in _in_place change the
## working copy they are given (see core/combat/bodies.gd).
extends RefCounted

const Event := preload("res://core/schema/event.gd")

## Constant holding the meter's top value (GDD "Tuning constants"); must be an int, 1 or more.
const MAX_CONSTANT: String = "BRO_METER_MAX"

## Constant holding how many cards a solo player plays in a turn per point (G22); an int, 1 or more.
const SOLO_CARDS_CONSTANT: String = "BRO_METER_SOLO_CARDS"

## Party size of solo play, where the solo rule applies. Fixed by the GDD ("In solo play").
const SOLO_PARTY_SIZE: int = 1

## Points gained each time the rule is met (GDD: "gains 1"). A rule from the GDD's text.
const GAIN_PER_STEP: int = 1


## Returns why the Bro Meter constants cannot be used, or "" when they can. Fight.check_start calls it.
## constants: ruleset.constants.
static func check_constants(constants: Dictionary) -> String:
	for name: String in [MAX_CONSTANT, SOLO_CARDS_CONSTANT]:
		if typeof(constants.get(name)) != TYPE_INT or constants[name] < 1:
			return "constant %s is missing or not an int 1 or more" % name
	return ""


## The solo rule, called after a card from the hand has resolved: +GAIN_PER_STEP when the Dude's
## cards_played_this_turn is a multiple of BRO_METER_SOLO_CARDS, in solo play only. Does nothing
## when the constants are unusable (a fight cannot start then).
## ruleset: the read-only content. state: the working copy. dude: the Dude who played the card,
## inside state. events: appended to.
static func after_card_played_in_place(ruleset: Dictionary, state: Dictionary, dude: Dictionary, events: Array) -> void:
	if state["party_size"] != SOLO_PARTY_SIZE or check_constants(ruleset["constants"]) != "":
		return
	if dude["cards_played_this_turn"] % ruleset["constants"][SOLO_CARDS_CONSTANT] == 0:
		change_in_place(ruleset, state, GAIN_PER_STEP, events)


## Changes the meter by delta, kept within 0..BRO_METER_MAX, and emits bro_meter_changed (delta =
## the actual change) when it changes.
## ruleset: the read-only content; reads BRO_METER_MAX, which must be usable (check_constants).
## state: the working copy. delta: the change wanted, any int. events: appended to.
static func change_in_place(ruleset: Dictionary, state: Dictionary, delta: int, events: Array) -> void:
	# after: the new value, within range.
	var after: int = clampi(state["bro_meter"] + delta, 0, ruleset["constants"][MAX_CONSTANT])
	if after == state["bro_meter"]:
		return
	events.append(Event.make("bro_meter_changed", {"delta": after - state["bro_meter"], "bro_meter": after}))
	state["bro_meter"] = after
