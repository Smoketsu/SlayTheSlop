## What happens right after an enemy dies, besides leaving the fight (task 017). Lane: core (Agent A).
##
## core/combat/bodies.gd knock_out_in_place() calls after_death_in_place() for every enemy that
## reaches 0 HP, after it has been removed from the fight and enemy_died has been emitted. Every
## enemy death goes through there, whatever dealt the damage, so these rules hold for cards, Bro
## Moves, thorns and anything added later. An enemy that flees or splits does not die and does not
## come here.
##   - Haul (Dorm Rats, GDD "kill them to get the Dolla Bills back"): every player the enemy stole
##     from gets their own part of enemy.haul back, in player_id order, with dolla_bills_changed
##     then dolla_bills_returned. A Passed Out Dude gets it back too: it is their money.
##   - Brew drop (Mimic Cooler, "always drops a Brew"): when enemy.drops_brews is above 0,
##     combat.brews_dropped rises by it and brew_dropped is emitted. Only reported: the run lane
##     grants the Brews (task 017 acceptance check).
##
## Reads only the state, never the content data (the damage code that kills an enemy does not have
## it), which is why drops_brews is copied onto the enemy when it joins the fight (core/combat/lineup.gd).
## This file preloads nothing from core/combat/, so bodies.gd can preload it without a cycle.
## Pure: no file, clock, network or random access. Changes the working copy it is given.
extends RefCounted

const Event := preload("res://core/schema/event.gd")


## Applies the death rules in the file header for one enemy that has just died.
## state: the working copy, in a fight. enemy: the dead enemy's state, already removed from
## combat.enemies (it is not changed). events: the event list, appended to.
static func after_death_in_place(state: Dictionary, enemy: Dictionary, events: Array) -> void:
	return_haul_in_place(state, enemy, events)
	if enemy.get("drops_brews", 0) > 0:
		state["combat"]["brews_dropped"] += enemy["drops_brews"]
		events.append(Event.make("brew_dropped", {"enemy_uid": enemy["uid"], "count": enemy["drops_brews"]}))


## Gives every player their part of the enemy's haul back, in sorted player_id order. A player_id
## that matches no Dude is skipped.
## state: the working copy. enemy: the dead enemy's state (not changed). events: appended to.
static func return_haul_in_place(state: Dictionary, enemy: Dictionary, events: Array) -> void:
	# player_ids: the players it stole from, sorted so the order never depends on the map.
	var player_ids: Array = enemy.get("haul", {}).keys()
	player_ids.sort()
	for player_id: String in player_ids:
		# amount: Dolla Bills going back to this player.
		var amount: int = enemy["haul"][player_id]
		for dude: Dictionary in state["dudes"]:
			if dude["player_id"] != player_id:
				continue
			dude["dolla_bills"] += amount
			events.append(Event.make("dolla_bills_changed", {"player_id": player_id, "delta": amount,
				"dolla_bills": dude["dolla_bills"]}))
			events.append(Event.make("dolla_bills_returned", {"enemy_uid": enemy["uid"], "player_id": player_id,
				"amount": amount}))
