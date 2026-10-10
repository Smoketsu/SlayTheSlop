## The "gain_stat" effect operation, and the stat-change helpers Gear uses (task 021). Lane: core
## (Agent A). Catalogue: core/ops/README.md.
##
## Fields: stat (String, one of core/schema/gear_def.gd STATS for a Dude; only "swole" for an
## enemy), amount (int, not 0; negative lowers the stat) and duration (String, optional: "fight").
## Recipients: the effect's targets. A target that does not have the stat (an enemy and "chill") is
## left alone.
##   - Without duration the change is permanent for the run (it stays after the fight).
##   - duration "fight": the change lasts for this fight only. It is added to the stat now and
##     recorded in combat.fight_stat_changes; when the fight ends, undo_fight_changes_in_place()
##     takes it back. Protein Shake: "Gain 3 Swole for this fight". Outside a fight it does nothing.
##     Enemies only exist in their fight, so an enemy's change is not recorded.
## Floors (a stat never goes below these): max_hp 1, hype_per_turn 0, draw_per_turn 0, brew_slots 0.
## swole, chill and clout may go negative (Protein Bucket: -1 Chill). When max_hp drops below hp,
## hp drops with it (no separate event; stat_changed carries the new max_hp).
## Gallon Jug's "+8 Max HP" raises max_hp only, not hp (task 021 log: the GDD does not say).
##
## Events: stat_changed (delta = the actual change, value = the new value), only when it changes.
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const GearDef := preload("res://core/schema/gear_def.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## False: an enemy move with this op does not aim at Dudes.
const NEEDS_TARGET: bool = false

## Fields a gain_stat effect may have, besides "op", and their types. duration is optional.
const FIELDS := {
	# Which stat: one of GearDef.STATS (Dudes); enemies only have "swole".
	"stat": TYPE_STRING,
	# Change to the stat, any int but 0.
	"amount": TYPE_INT,
	# Optional. "fight": the change is undone when the fight ends. Absent: permanent for the run.
	"duration": TYPE_STRING,
}

## Allowed values of duration.
const DURATIONS: Array[String] = ["fight"]

## Stats an enemy has (core/schema/enemy_state.gd). Every other stat is Dude-only.
const ENEMY_STATS: Array[String] = ["swole"]

## Lowest value a stat may reach, for stats that have one. A rule of the stat's meaning (a Dude
## needs at least 1 max HP; a count cannot be negative), not a tuning constant.
const FLOORS := {"max_hp": 1, "hype_per_turn": 0, "draw_per_turn": 0, "brew_slots": 0}


## Returns the problems with a gain_stat effect's fields; empty means it can run.
## effect: one entry of an effects list. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op gain_stat" % [path, field])
	if typeof(effect.get("stat")) != TYPE_STRING or not GearDef.STATS.has(effect["stat"]):
		errors.append("%s.stat: must be one of %s" % [path, ", ".join(PackedStringArray(GearDef.STATS))])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] == 0:
		errors.append("%s.amount: must be an int other than 0" % path)
	if effect.has("duration") and not DURATIONS.has(effect["duration"]):
		errors.append("%s.duration: must be one of %s" % [path, ", ".join(PackedStringArray(DURATIONS))])
	return errors


## Runs a gain_stat effect on every target still standing that has the stat (see the file header).
## state: the working copy. effect: a gain_stat effect that passed check().
## context: {"targets": Array of ids it lands on; other keys unused}. events: appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# for_fight: true when the change must be undone at the end of the fight.
	var for_fight: bool = effect.get("duration", "") == "fight"
	if for_fight and state["combat"] == null:
		return
	for target_id: String in context["targets"]:
		# body: the target, inside state, or {} if it is gone.
		var body: Dictionary = Bodies.find_alive(state, target_id)
		if body.is_empty() or not has_stat(body, effect["stat"]):
			continue
		# changed: the change actually made, after the floor.
		var changed: int = change_in_place(body, target_id, effect["stat"], effect["amount"], events)
		if for_fight and changed != 0 and Bodies.dude_index(state, target_id) != -1:
			record_fight_change_in_place(state, target_id, effect["stat"], changed)


## True when the body has this stat: a Dude has every GearDef.STATS stat, an enemy only ENEMY_STATS.
## body: a Dude or enemy state. stat: a stat name.
static func has_stat(body: Dictionary, stat: String) -> bool:
	if body.has("arm_count"):
		return ENEMY_STATS.has(stat)
	return GearDef.STATS.has(stat) and body.has(stat)


## Adds delta to one stat of a body, applying FLOORS, and emits stat_changed when it changes.
## Returns the change actually made (0 when nothing changed). Lowering max_hp below hp lowers hp too.
## body: the Dude or enemy, inside state. id: its player_id or uid, for the event.
## stat: a stat the body has (see has_stat). delta: the change wanted. events: appended to.
static func change_in_place(body: Dictionary, id: String, stat: String, delta: int, events: Array) -> int:
	# before: the stat before the change.
	var before: int = body[stat]
	# after: the stat after it, never below its floor.
	var after: int = before + delta
	if FLOORS.has(stat):
		after = maxi(FLOORS[stat], after)
	if after == before:
		return 0
	body[stat] = after
	if stat == "max_hp" and body["hp"] > after:
		body["hp"] = after
	events.append(Event.make("stat_changed", {"target_id": id, "stat": stat, "delta": after - before, "value": after}))
	return after - before


## Adds a fight-only change to combat.fight_stat_changes, removing entries that net to 0.
## state: the working copy, in a fight. player_id: the Dude. stat: the stat. delta: the change made.
static func record_fight_change_in_place(state: Dictionary, player_id: String, stat: String, delta: int) -> void:
	# changes: player_id -> {stat -> change}, inside state.
	var changes: Dictionary = state["combat"]["fight_stat_changes"]
	if not changes.has(player_id):
		changes[player_id] = {}
	changes[player_id][stat] = changes[player_id].get(stat, 0) + delta
	if changes[player_id][stat] == 0:
		changes[player_id].erase(stat)
	if changes[player_id].is_empty():
		changes.erase(player_id)


## Takes back every fight-only stat change (combat.fight_stat_changes), in sorted player and stat
## order, emitting stat_changed for each, then empties the map. Passed Out Dudes are included.
## Called once when a fight ends (core/combat/gear_triggers.gd fight_end_in_place).
## state: the working copy, with a fight. events: the event list, appended to.
static func undo_fight_changes_in_place(state: Dictionary, events: Array) -> void:
	# changes: player_id -> {stat -> change}, inside state.
	var changes: Dictionary = state["combat"]["fight_stat_changes"]
	# players: the player_ids with changes, sorted.
	var players: Array = changes.keys()
	players.sort()
	for player_id: String in players:
		# index: the Dude's seat, or -1 if the player is gone.
		var index: int = Bodies.dude_index(state, player_id)
		if index == -1:
			continue
		# stats: the changed stats, sorted.
		var stats: Array = changes[player_id].keys()
		stats.sort()
		for stat: String in stats:
			change_in_place(state["dudes"][index], player_id, stat, -changes[player_id][stat], events)
	changes.clear()
