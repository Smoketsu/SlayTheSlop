## Statuses a Dude starts the next fight with (task 025, gap G25). Lane: core (Agent A).
##
## Side Quests can say "start the next fight with ..." (GDD "Example Side Quests": Gas-Station Sushi's
## Hungover for 3 turns, The Unlabeled Brownie's 2 Foggy). G25 (answered "accept"): the status waits
## on the Dude (dude_state.pending_statuses) and is applied when the next fight starts. The run lane
## adds to it (core/run/side_quests.gd); core/combat/fight.gd calls apply_in_place() right after
## fight_started, before Gear's fight_start point and before turn 1's Refresh, so Foggy already
## takes a card from the first hand and every status wears off as usual from turn 1 (G1).
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Statuses := preload("res://core/combat/statuses.gd")

## Name of the dude_state field this file reads and empties (core/schema/dude_state.gd).
const FIELD: String = "pending_statuses"


## For every Dude in seat order who is not Passed Out: adds each pending status, in sorted status
## order, to their statuses (status_changed), then empties the pending map. A status the Dude cannot
## carry (an enemy-only one) is dropped. A Passed Out Dude keeps theirs for a later fight. A Dude state
## without the field (hand-built in old tests) is skipped.
## state: the working copy, in a fight that just started. events: the event list, appended to.
static func apply_in_place(state: Dictionary, events: Array) -> void:
	for dude: Dictionary in state["dudes"]:
		if dude["passed_out"] or dude.get(FIELD, {}).is_empty():
			continue
		# names: the pending status ids, sorted so the events come in a stable order.
		var names: Array = dude[FIELD].keys()
		names.sort()
		for status: String in names:
			if Statuses.STACKED.has(status) and Statuses.can_carry(dude, status):
				Statuses.change_stacks_in_place(dude, dude["player_id"], status, dude[FIELD][status], events)
		dude[FIELD] = {}
