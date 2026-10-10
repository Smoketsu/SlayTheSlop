## Finding Dudes and enemies in a fight, and what happens when one reaches 0 HP (task 007).
## Lane: core (Agent A).
##
## A "body" is a Dude state (core/schema/dude_state.gd) or an enemy state (enemy_state.gd): both
## have hp, guard, swole and statuses, so the ops can treat them alike. Ids follow
## core/schema/README.md "Ids": Dudes by player_id ("p1"), enemies by uid ("e3").
##
## The *_in_place functions change the state they are given. They are only ever called on the
## working copy that Core.apply() or Fight.start_fight() made, never on a caller's state.
## Pure: no file, clock, network or random access.
extends RefCounted

const Event := preload("res://core/schema/event.gd")


## Returns the position of the Dude with this player_id in state.dudes, or -1 when there is none.
## state: a run state. player_id: the id to look for, for example "p1".
static func dude_index(state: Dictionary, player_id: String) -> int:
	for i: int in state["dudes"].size():
		if state["dudes"][i]["player_id"] == player_id:
			return i
	return -1


## Returns the position of the enemy with this uid in combat.enemies, or -1 when there is none
## (or no fight). Dead enemies are removed from the list, so -1 also means "dead".
## state: a run state. uid: the enemy uid to look for, for example "e3".
static func enemy_index(state: Dictionary, uid: String) -> int:
	if state["combat"] == null:
		return -1
	for i: int in state["combat"]["enemies"].size():
		if state["combat"]["enemies"][i]["uid"] == uid:
			return i
	return -1


## Returns the body with this id that can still be hit or act: a Dude that is not Passed Out, or
## an enemy still in the fight. Returns {} when there is none. The returned Dictionary is the one
## inside state, so changing it changes state.
## state: a run state. id: a player_id or an enemy uid.
static func find_alive(state: Dictionary, id: String) -> Dictionary:
	# index: position of a Dude with this id, or -1.
	var index: int = dude_index(state, id)
	if index != -1:
		return {} if state["dudes"][index]["passed_out"] else state["dudes"][index]
	index = enemy_index(state, id)
	if index != -1:
		return state["combat"]["enemies"][index]
	return {}


## Returns the player_ids of the Dudes that are not Passed Out, in seat order.
## state: a run state.
static func awake_dude_ids(state: Dictionary) -> Array:
	# ids: the result.
	var ids: Array = []
	for dude: Dictionary in state["dudes"]:
		if not dude["passed_out"]:
			ids.append(dude["player_id"])
	return ids


## Returns the uids of the enemies still in the fight, left to right. [] outside a fight.
## state: a run state.
static func enemy_uids(state: Dictionary) -> Array:
	# uids: the result.
	var uids: Array = []
	if state["combat"] != null:
		for enemy: Dictionary in state["combat"]["enemies"]:
			uids.append(enemy["uid"])
	return uids


## True when the fight has a winner: every enemy is dead or every Dude is Passed Out.
## Effects stop resolving as soon as this is true.
## state: a run state with a fight.
static func is_decided(state: Dictionary) -> bool:
	return state["combat"]["enemies"].is_empty() or awake_dude_ids(state).is_empty()


## Handles a body that has just reached 0 HP. An enemy dies: enemy_died is emitted and it is
## removed from combat.enemies. A Dude is Passed Out: passed_out becomes true and dude_passed_out
## is emitted, unless the fight holds a pass-out save for them (task 021, Smelling Salts solo:
## combat.pass_out_saves), which is used up instead: their HP becomes the saved HP (at most
## max_hp) and pass_out_prevented is emitted. Does nothing if id names no living body.
## state: the working copy, changed here. id: the player_id or enemy uid at 0 HP.
## events: the event list, appended to.
static func knock_out_in_place(state: Dictionary, id: String, events: Array) -> void:
	# index: position of a Dude with this id, or -1.
	var index: int = dude_index(state, id)
	if index != -1:
		if _use_pass_out_save_in_place(state, index, events):
			return
		if not state["dudes"][index]["passed_out"]:
			state["dudes"][index]["passed_out"] = true
			events.append(Event.make("dude_passed_out", {"player_id": id}))
		return
	index = enemy_index(state, id)
	if index != -1:
		state["combat"]["enemies"].remove_at(index)
		events.append(Event.make("enemy_died", {"enemy_uid": id}))


## Task 021: uses the fight's pass-out save for a Dude who would pass out, if there is one: HP
## becomes the saved HP (at most max_hp), the save is removed, pass_out_prevented is emitted, and
## true is returned. Returns false (and changes nothing) when there is no fight, the Dude is already
## Passed Out, or no save is held.
## state: the working copy. index: the Dude's seat, 0-based. events: the event list, appended to.
static func _use_pass_out_save_in_place(state: Dictionary, index: int, events: Array) -> bool:
	# dude: the Dude at 0 HP, inside state.
	var dude: Dictionary = state["dudes"][index]
	if state["combat"] == null or dude["passed_out"]:
		return false
	# saves: player_id -> HP to stay at, inside the fight.
	var saves: Dictionary = state["combat"].get("pass_out_saves", {})
	if not saves.has(dude["player_id"]):
		return false
	dude["hp"] = mini(saves[dude["player_id"]], dude["max_hp"])
	saves.erase(dude["player_id"])
	events.append(Event.make("pass_out_prevented", {"player_id": dude["player_id"], "hp": dude["hp"]}))
	return true
