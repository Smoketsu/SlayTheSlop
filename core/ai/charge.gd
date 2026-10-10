## Charged attacks held up by helpers: Goblin King Chad's Keg Stand (task 019). Lane: core (Agent A).
## Shapes: core/schema/enemy_def.gd CHARGE_DEF_SPEC (the definition's "charge") and
## core/schema/enemy_state.gd CHARGE_SPEC (the enemy's "charge" while it charges).
##
## GDD "Goblin King Chad": "Keg Stand. His Pledges lift him and he charges for 2 turns, then hits one
## Dude for 30. Each Pledge killed during the charge removes 10 damage. Kill both and he falls: he
## skips a turn and is Exposed for 2." With G12 (answered "accept"): he starts Keg Stand whenever 2
## Pledges are alive and he is not already charging.
##
## core/ai/intents.gd calls this file at each of the enemy's intents (turn flow step 1):
##   1. continue_in_place() before anything else. While a charge is in progress it decides the move:
##      the charge's move_id until the enemy has shown it "turns" times, then release_move_id. Once
##      the release has been chosen, the next intent ends the charge (if the release did not already
##      end it, core/ops/charged_hit.gd) and the enemy chooses normally again. So charging overrides
##      move rules, patterns and random choice: "every turn he is not charging" (Rage Cage) and Rush
##      wait until the charge is over.
##   2. start_in_place() after the move is chosen. When the move is the charge's move_id and no charge
##      is in progress (normally a move rule picked it), the charge starts: its helpers are the first
##      "helpers" OTHER enemies of helper_def_id, left to right, and charge_started is emitted. The
##      start counts as the first charging turn.
## Elsewhere: the fall (every helper dead) is core/combat/enemy_death.gd; the release's damage cut
## is the charged_hit op; the skip after a fall is core/combat/statuses.gd (reason "fallen").
##
## Pure and deterministic: no random draws; enemies are walked left to right. Functions ending in
## _in_place change the working copy they are given (see core/combat/bodies.gd).
extends RefCounted

const Event := preload("res://core/schema/event.gd")

## Turns already charged when a charge starts: the starting turn is the first charging turn.
## Not a tuning number.
const FIRST_TURN: int = 1


## Turn flow step 1, before move rules: returns the move a charge in progress dictates, or "" when
## the enemy is not charging (then it chooses as usual). Ends a charge whose release was the
## previous intent. Raises turns_charged when it dictates the charge's move again.
## ruleset: the read-only content. state: the working copy (unused but for symmetry with the other
## intent steps). enemy: the enemy choosing, inside state; its charge may change.
static func continue_in_place(ruleset: Dictionary, state: Dictionary, enemy: Dictionary) -> String:
	if enemy["charge"] == null:
		return ""
	# definition: the enemy's charge definition, or {} if it has none (a hand-made state).
	var definition: Dictionary = ruleset["enemies"][enemy["def_id"]].get("charge", {})
	if definition.is_empty() or (not enemy["move_history"].is_empty() and enemy["move_history"][-1] == definition["release_move_id"]):
		enemy["charge"] = null
		return ""
	if enemy["charge"]["turns_charged"] < definition["turns"]:
		enemy["charge"]["turns_charged"] += 1
		return definition["move_id"]
	return definition["release_move_id"]


## Turn flow step 1, after the move is chosen and intent_set emitted: starts a charge when the chosen
## move is the charge's move_id and none is in progress (see the file header), with charge_started.
## ruleset: the read-only content. state: the working copy, in a fight. enemy: the enemy, inside
## state. move_id: the move it just chose. events: the event list, appended to.
static func start_in_place(ruleset: Dictionary, state: Dictionary, enemy: Dictionary, move_id: String, events: Array) -> void:
	# definition: the enemy's charge definition, or {}.
	var definition: Dictionary = ruleset["enemies"][enemy["def_id"]].get("charge", {})
	if definition.is_empty() or enemy["charge"] != null or move_id != definition["move_id"]:
		return
	# helpers: uids of the enemies holding it up, left to right.
	var helpers: Array = []
	for other: Dictionary in state["combat"]["enemies"]:
		if helpers.size() < definition["helpers"] and other["uid"] != enemy["uid"] and other["def_id"] == definition["helper_def_id"]:
			helpers.append(other["uid"])
	enemy["charge"] = {"turns_charged": FIRST_TURN, "helper_uids": helpers, "fall_exposed": definition["fall_exposed"]}
	events.append(Event.make("charge_started", {"enemy_uid": enemy["uid"], "helper_uids": helpers.duplicate()}))


## Returns how many of a charge's helpers are no longer in the fight (killed during the charge).
## 0 when the enemy is not charging.
## state: the run state, in a fight. enemy: the charging enemy's state.
static func helpers_lost(state: Dictionary, enemy: Dictionary) -> int:
	if enemy.get("charge") == null:
		return 0
	# present: uids of the enemies still in the fight.
	var present: Array = state["combat"]["enemies"].map(func(other: Dictionary) -> String: return other["uid"])
	return enemy["charge"]["helper_uids"].filter(func(uid: String) -> bool: return not present.has(uid)).size()
