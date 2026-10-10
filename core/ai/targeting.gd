## Which Dudes an enemy's move is aimed at (task 011). Lane: core (Agent A).
##
## A move's aim is its optional "target" field (core/schema/enemy_def.gd MOVE_TARGETS). When the
## field is absent, a move with an op that needs a target (core/ops/ops.gd needs_target, for
## example "damage") counts as "dude" and any other move counts as "none".
##   "none":      no targets. Guard, and buffs on itself, land on the enemy (the actor).
##   "all_dudes": every Dude who is not Passed Out, in seat order ("Area attacks hit everyone",
##                GDD "Rules that change in co-op"). No draw.
##   "dude":      a single-target attack (GDD "Difficulty scaling"). It hits 1 Dude, or
##                MULTI_TARGET_COUNT different Dudes once party_size is at least
##                MULTI_TARGET_PARTY_SIZE. Party size counts every player, Passed Out or not,
##                because the GDD's table is by players. Targets are chosen only among Dudes who
##                are not Passed Out, so a Passed Out Dude is never a target. When the count is at
##                least the number of standing Dudes, all of them are targets and no draw is made.
##                Otherwise the targets are picked one at a time from the standing Dudes in seat
##                order: each pick draws Rng.next_int(0, remaining - 1) from combat_ai and removes
##                that Dude, so the targets are always different. They are stored in seat order.
##
## When a target passes out before the enemy acts, the attack is NOT re-aimed. The intent is what
## the players planned around, so it is kept as shown, and the Passed Out target is skipped when
## the enemy acts (core/combat/fight.gd _enemy_act_in_place, as in task 007). If every target has
## passed out, the move's targeted effects land on nobody, and its effects on the enemy itself still
## happen. This choice is reported in task 011's log for both people to confirm.
##
## Pure and deterministic: randomness only through core/rng/rng.gd's combat_ai stream; no file,
## clock or network access.
extends RefCounted

const Rng := preload("res://core/rng/rng.gd")
const Ops := preload("res://core/ops/ops.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const MoveChoice := preload("res://core/ai/move_choice.gd")

## The move "target" value for a single-target attack (enemy_def.gd MOVE_TARGETS).
const SINGLE: String = "dude"

## The move "target" value for an area attack (enemy_def.gd MOVE_TARGETS).
const ALL: String = "all_dudes"

## The move "target" value for a move with no Dude targets (enemy_def.gd MOVE_TARGETS).
const NONE: String = "none"


## Returns how a move is aimed: its "target" field, or, when it has none, SINGLE for a move with an
## op that needs a target and NONE for any other move.
## move: one move of an enemy definition (core/schema/enemy_def.gd MOVE_SPEC), read-only.
static func aim_of(move: Dictionary) -> String:
	if move.has("target"):
		return move["target"]
	return SINGLE if Ops.needs_target(move["effects"]) else NONE


## Returns how many Dudes a single-target attack hits at this party size: MULTI_TARGET_COUNT when
## party_size is at least MULTI_TARGET_PARTY_SIZE, otherwise 1 (a single target). If either constant
## is missing or not an int, the answer is 1. Fight.check_start refuses to start a fight in that case,
## so this only guards hand-made states.
## constants: ruleset.constants. party_size: players in the run, 1..4.
static func single_target_count(constants: Dictionary, party_size: int) -> int:
	if typeof(constants.get("MULTI_TARGET_PARTY_SIZE")) != TYPE_INT or typeof(constants.get("MULTI_TARGET_COUNT")) != TYPE_INT:
		return 1
	if party_size >= constants["MULTI_TARGET_PARTY_SIZE"]:
		return constants["MULTI_TARGET_COUNT"]
	return 1


## Chooses the player_ids a move is aimed at, following the file header. They are in seat order
## and none of them is Passed Out. Draws from combat_ai only when a single-target attack has more
## standing Dudes than targets; then state's "rng" is replaced with the advanced streams. If such
## a draw fails (combat_ai missing, which Fight.check_start refuses), the first standing Dudes in
## seat order are taken, so the result is still deterministic.
## constants: ruleset.constants. state: the working copy; only state.rng changes.
## move: the chosen move of the enemy's definition, read-only.
static func choose_in_place(constants: Dictionary, state: Dictionary, move: Dictionary) -> Array:
	# aim: how the move is aimed.
	var aim: String = aim_of(move)
	# standing: Dudes who are not Passed Out, in seat order.
	var standing: Array = Bodies.awake_dude_ids(state)
	if aim == ALL:
		return standing
	if aim != SINGLE:
		return []
	# count: how many different Dudes it hits, at most every standing Dude.
	var count: int = mini(single_target_count(constants, state["party_size"]), standing.size())
	if count >= standing.size():
		return standing
	# pool: standing Dudes not picked yet, in seat order.
	var pool: Array = standing.duplicate()
	# picked: the Dudes picked so far.
	var picked: Array = []
	while picked.size() < count:
		# drawn: Rng.next_int's result, {"state", "value"} (plus "error" once task 029 merges).
		var drawn: Dictionary = {"error": "random stream %s is missing" % MoveChoice.STREAM}
		if state.get("rng", {}).has(Rng.key_for(MoveChoice.STREAM)):
			drawn = Rng.next_int(state, Rng.key_for(MoveChoice.STREAM), 0, pool.size() - 1)
		if drawn.get("error", "") != "":
			return standing.slice(0, count)
		state["rng"] = drawn["state"]["rng"]
		picked.append(pool[drawn["value"]])
		pool.remove_at(drawn["value"])
	return standing.filter(func(player_id: String) -> bool: return picked.has(player_id))
