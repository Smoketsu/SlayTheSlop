## Loot: free Gear from an unattended cooler, unless the cooler bites (task 025, GDD "Node types", G19).
## Lane: run (Agent A).
##
## Entering a Loot node rolls LOOT_MIMIC_CHANCE once on the "encounters" stream (G19: "Mimic Cooler
## replaces a Loot node 1 time in 4"; which enemies appear is the encounters stream's job):
##   - hit, and the floor has a "loot" encounter (core/schema/encounter_def.gd): that fight starts
##     (core/run/node_flow.gd), and its reward is a Mimic's (core/run/rewards.gd), not Gear.
##   - otherwise: every Dude, in seat order, gains one Gear from their own Loot pool (G24, G28), drawn on
##     their own rewards stream. Nothing to choose, so the party is back on the map at once.
## Co-op drafting "in turn" is not built (gap G59).
##
## Functions ending in _in_place change the working copy they are given. Pure: randomness only
## through core/run/draws.gd.
extends RefCounted

const Rng := preload("res://core/rng/rng.gd")
const Draws := preload("res://core/run/draws.gd")
const Rewards := preload("res://core/run/rewards.gd")

## The stream the Mimic roll uses (GDD "Random streams": encounters).
const MIMIC_STREAM: String = "encounters"


## Rolls whether the Loot node is a Mimic. Returns true when it is (the caller then starts the fight).
## ruleset: the read-only content. state: the working copy; the encounters stream advances.
static func is_mimic_in_place(ruleset: Dictionary, state: Dictionary) -> bool:
	return Draws.chance_in_place(state, MIMIC_STREAM, ruleset["constants"]["LOOT_MIMIC_CHANCE"])


## Gives every Dude their free Gear (see the file header).
## ruleset: the read-only content. state: the working copy. events: the event list, appended to.
static func give_gear_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	for i: int in state["dudes"].size():
		Rewards.random_gear_in_place(ruleset, state, i, Rng.key_for(Rewards.STREAM, state["dudes"][i]["player_id"]), events)
