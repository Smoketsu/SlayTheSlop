## Enemy intents and the start of an enemy's action (task 011). Lane: core (Agent A).
##
## core/combat/fight.gd calls this file at three points of the GDD "Turn flow":
##   - Step 1, Intents (and so after every enemy phase, step 5, "then choose new intents"):
##     set_intent_in_place() for each enemy, left to right. The move comes from move_choice.gd and
##     the targets from targeting.gd, in that order, so combat_ai is drawn from in a fixed order:
##     enemy by enemy, move first, then targets. The move id is appended to the enemy's
##     move_history, and intent_set is emitted.
##   - Step 5, Enemy phase: begin_action_in_place() for each enemy, just before it acts.
##     G30 (answered "accept") says an enemy's Guard drops to 0 at the start of its own action,
##     before it acts. The reset happens even if the enemy then skips its action (Grossed Out or
##     Armless, task 009), because it happens at the START of the action.
##   - start_fight: check_start() refuses a fight the AI could not run.
## The intent is not changed between step 1 and the enemy's action. targeting.gd says what happens to
## a target that passes out in between.
##
## Pure and deterministic: randomness only through core/rng/rng.gd's combat_ai stream; no file,
## clock or network access. Functions ending in _in_place change the working copy they are given
## (see core/combat/bodies.gd).
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Rng := preload("res://core/rng/rng.gd")
const MoveChoice := preload("res://core/ai/move_choice.gd")
const Targeting := preload("res://core/ai/targeting.gd")

## Constants the AI reads, all ints (data/constants.json). check_start() requires each of them.
const NEEDED_CONSTANTS: Array[String] = ["MULTI_TARGET_PARTY_SIZE", "MULTI_TARGET_COUNT"]


## Returns why the AI could not run a fight in this state, or "" when it can. A needed constant is
## missing or not an int, MULTI_TARGET_COUNT is below 1, or the combat_ai stream is missing.
## ruleset: the read-only content. state: the run state the fight would start in.
static func check_start(ruleset: Dictionary, state: Dictionary) -> String:
	for name: String in NEEDED_CONSTANTS:
		if typeof(ruleset["constants"].get(name)) != TYPE_INT:
			return "constant %s is missing or not an int" % name
	if ruleset["constants"]["MULTI_TARGET_COUNT"] < 1:
		return "constant MULTI_TARGET_COUNT must be 1 or more"
	if not state.get("rng", {}).has(Rng.key_for(MoveChoice.STREAM)):
		return "random stream %s is missing (build the run with Rng.with_new_streams)" % MoveChoice.STREAM
	return ""


## Turn flow step 1 for one enemy: chooses its next move and targets, sets enemy.intent, appends
## the move id to enemy.move_history and emits intent_set. If the enemy has no move it can choose
## (see move_choice.gd), intent becomes null, nothing is appended and nothing is emitted.
## ruleset: the read-only content. state: the working copy; its rng may advance.
## enemy: the enemy's state, inside state; changed here. events: the event list, appended to.
static func set_intent_in_place(ruleset: Dictionary, state: Dictionary, enemy: Dictionary, events: Array) -> void:
	# definition: the enemy's fixed values.
	var definition: Dictionary = ruleset["enemies"][enemy["def_id"]]
	# move_id: the chosen move, or "".
	var move_id: String = MoveChoice.choose_in_place(state, definition, enemy)
	# move: the chosen move's definition, or {}.
	var move: Dictionary = find_move(definition, move_id)
	if move.is_empty():
		enemy["intent"] = null
		return
	# target_ids: who it is aimed at, in seat order.
	var target_ids: Array = Targeting.choose_in_place(ruleset["constants"], state, move)
	enemy["intent"] = {"move_id": move_id, "target_ids": target_ids}
	enemy["move_history"].append(move_id)
	events.append(Event.make("intent_set", {"enemy_uid": enemy["uid"], "move_id": move_id,
		"target_ids": target_ids.duplicate()}))


## G30: the start of an enemy's own action in the enemy phase. Its Guard drops to 0, with
## guard_changed (delta = minus the Guard lost, guard = 0), only when it had Guard. Call it just
## before the enemy acts, or skips its action.
## enemy: the acting enemy's state, inside the working copy; changed here.
## events: the event list, appended to.
static func begin_action_in_place(enemy: Dictionary, events: Array) -> void:
	if enemy["guard"] == 0:
		return
	events.append(Event.make("guard_changed", {"target_id": enemy["uid"], "delta": -enemy["guard"], "guard": 0}))
	enemy["guard"] = 0


## Returns the move with this id from an enemy definition, or {} when there is none (including "").
## definition: an enemy definition, read-only. move_id: the move id to look for.
static func find_move(definition: Dictionary, move_id: String) -> Dictionary:
	for move: Dictionary in definition["moves"]:
		if move["id"] == move_id:
			return move
	return {}
