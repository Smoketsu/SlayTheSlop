## Starting a fight and running the GDD "Turn flow" (task 007). Lane: core (Agent A).
##
## Turn flow, exactly as the GDD lists it:
##   1. Intents: every enemy picks its next move and, for attacks, its target (intent_set).
##   2. Refresh: each Dude who is not Passed Out: Guard to 0, Hype to hype_per_turn,
##      cards_played_this_turn to 0, ready to false, draw draw_per_turn cards (G8 reshuffle).
##   3. Player phase: the core stops here and waits for requests (Core.apply()).
##   4. End of turn (when every Dude who is not Passed Out is ready): every hand is discarded.
##      Puppets, Auras and end-of-turn effects do not exist yet.
##   5. Enemy phase: enemies act left to right, each running its intended move. Then the next turn
##      starts at step 1, which is where the enemies "choose new intents".
## The fight is won when every enemy is dead and lost when every Dude is Passed Out; it is checked
## after every card and every enemy action (combat.result, phase "over", fight_ended).
##
## Enemy AI (task 011) lives in core/ai/. This file calls it at two points:
##   - Intents (step 1). For each enemy, Intents.set_intent_in_place picks the move (scripted
##     pattern, or a weighted draw from combat_ai that never picks one move three times in a row)
##     and the targets (1 Dude, MULTI_TARGET_COUNT Dudes at MULTI_TARGET_PARTY_SIZE players, or
##     every Dude for an area attack; never a Passed Out Dude).
##   - Enemy phase (step 5). Intents.begin_action_in_place drops the enemy's Guard to 0 at the
##     start of its own action, before it acts (G30).
## When the enemy acts, targets that have Passed Out since are skipped, not re-aimed (core/ai/targeting.gd).
##
## Passed Out Dudes skip Refresh (no Hype, no draw) and are not needed for Ready: they "skip turns"
## (GDD "Rules that change in co-op").
##
## Statuses (task 009) are core/combat/statuses.gd; this file only calls it, at lines marked
## "Task 009": Foggy at Refresh, Dude wear-off at End of turn, and, per enemy in the enemy phase,
## the Grossed Out / Armless skip check before it acts and its wear-off right after its slot.
## Gear (task 021) is core/combat/gear_triggers.gd; start_fight_in_place calls its fight_start and first_turn
## trigger points at lines marked "Task 021". Its fight_end point runs from Core.apply().
##
## Task 013 calls, at lines marked "Task 013": the Bro Meter constants in check_start, thorns reset
## at Refresh, Powers' "turn_start" triggers after every Refresh (core/combat/powers.gd), and pocketed
## cards kept in hand at End of turn.
##
## Junk card rules (task 015) are core/combat/card_triggers.gd; this file calls it at lines marked
## "Task 015": the Refresh draw runs on_draw triggers (a Bedbugs draw can decide the fight, which
## then ends before the player phase), End of turn runs on_end_of_turn_in_hand before each hand is
## discarded (a Burn can decide the fight, which then ends before the enemy phase), and the fight's
## end removes fight-only cards.
##
## Pure: randomness only through core/rng/rng.gd (via piles.gd); no file, clock or network access.
## Functions ending in _in_place change the working copy they are given (see core/combat/bodies.gd).
extends RefCounted

const CombatState := preload("res://core/schema/combat_state.gd")
const EnemyState := preload("res://core/schema/enemy_state.gd")
const Event := preload("res://core/schema/event.gd")
const Rng := preload("res://core/rng/rng.gd")
const Ops := preload("res://core/ops/ops.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const Piles := preload("res://core/combat/piles.gd")
const Scaling := preload("res://core/combat/party_scaling.gd")
const Intents := preload("res://core/ai/intents.gd")
const Statuses := preload("res://core/combat/statuses.gd")
const Powers := preload("res://core/combat/powers.gd")
const BroMeter := preload("res://core/combat/bro_meter.gd")
const ThornsOp := preload("res://core/ops/thorns.gd")
const CardTriggers := preload("res://core/combat/card_triggers.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")

## Enemy tier (core/schema/enemy_def.gd TIERS) -> name of the constant with its solo starting Ick
## threshold (GDD "Statuses"). Changes only with the GDD's tiers.
const ICK_BASE_BY_TIER := {"normal": "ICK_BASE_NORMAL", "rival": "ICK_BASE_RIVAL", "boss": "ICK_BASE_BOSS"}

## Prefix of an enemy uid; the number after it comes from run_state.next_uid (core/schema/README.md "Ids").
const ENEMY_UID_PREFIX: String = "e"


## Starts a fight against the given enemies and runs turn 1 up to the player phase. Not a request:
## the run flow (task 025) or a test calls it. It does not change state_version, which counts
## applied requests only; when the run flow starts a fight inside a request, that request raises it.
## Enemies get uids from next_uid, max_hp and hp = the definition's max_hp scaled by party size
## (rounded down), arm_count from the definition, and ick_threshold = ICK_BASE_<tier> scaled by party
## size (rounded up). Each Dude's run deck is shuffled into their draw pile with their shuffle stream.
## Events: fight_started, then turn 1's turn_started, intent_set and Refresh events.
## ruleset: the read-only content (core/ruleset/ruleset.gd). state: a run state with Dudes and random
## streams (core/combat/party.gd builds one); not changed. enemy_def_ids: enemy definition ids, left to right.
## Returns {"state": the new state, "events": Array, "error": ""}, or, when the fight cannot start,
## {"state": the given state unchanged, "events": [], "error": why}.
static func start_fight(ruleset: Dictionary, state: Dictionary, enemy_def_ids: Array) -> Dictionary:
	# error: why the fight cannot start, or "".
	var error: String = check_start(ruleset, state, enemy_def_ids)
	if error != "":
		return {"state": state, "events": [], "error": error}
	# next: the deep, writable copy that becomes the new state.
	var next: Dictionary = state.duplicate(true)
	# events: what happened, in order.
	var events: Array = []
	start_fight_in_place(ruleset, next, enemy_def_ids, events)
	return {"state": next, "events": events, "error": ""}


## Returns why a fight cannot start, or "" when it can: a fight is already running, there are no
## Dudes, no or unknown enemies, a constant start_fight or the enemy AI needs is missing, or a
## Dude's shuffle stream or the combat_ai stream is missing.
## ruleset: the read-only content. state: the run state. enemy_def_ids: the enemies asked for.
static func check_start(ruleset: Dictionary, state: Dictionary, enemy_def_ids: Array) -> String:
	if state.get("combat") != null and state["combat"]["phase"] != "over":
		return "a fight is already running"
	if state.get("dudes", []).is_empty():
		return "the run has no Dudes"
	if enemy_def_ids.is_empty():
		return "a fight needs at least one enemy"
	# constants: the tuning constants.
	var constants: Dictionary = ruleset["constants"]
	if not [TYPE_INT, TYPE_FLOAT].has(typeof(constants.get("HP_SCALE_PER_EXTRA_PLAYER"))):
		return "constant HP_SCALE_PER_EXTRA_PLAYER is missing or not a number"
	# status_error: task 009, why a constant the damage order or statuses need is unusable, or "".
	var status_error: String = Statuses.check_constants(constants)
	if status_error != "":
		return status_error
	# Task 013: the Bro Meter's constants.
	if BroMeter.check_constants(constants) != "":
		return BroMeter.check_constants(constants)
	for def_id: Variant in enemy_def_ids:
		if typeof(def_id) != TYPE_STRING or not ruleset["enemies"].has(def_id):
			return "unknown enemy %s" % var_to_str(def_id)
		# constant: the Ick base constant this enemy's tier needs.
		var constant: String = ICK_BASE_BY_TIER.get(ruleset["enemies"][def_id]["tier"], "")
		if constant == "" or typeof(constants.get(constant)) != TYPE_INT:
			return "constant %s for enemy %s is missing or not an int" % [constant, def_id]
	for dude: Dictionary in state["dudes"]:
		if not state["rng"].has(Rng.key_for("shuffle", dude["player_id"])):
			return "random stream shuffle:%s is missing (build the run with Rng.with_new_streams)" % dude["player_id"]
	# Task 011: the enemy AI's own needs (constants, combat_ai stream).
	return Intents.check_start(ruleset, state)


## start_fight()'s work, on a working copy, for code that is already inside apply(). The caller must
## have checked check_start() first.
## ruleset: the read-only content. state: the working copy, changed here.
## enemy_def_ids: enemy definition ids, left to right. events: the event list, appended to.
static func start_fight_in_place(ruleset: Dictionary, state: Dictionary, enemy_def_ids: Array, events: Array) -> void:
	# combat: the new fight.
	var combat: Dictionary = CombatState.blank()
	# uids: the new enemies' uids, left to right, for fight_started.
	var uids: Array = []
	for def_id: String in enemy_def_ids:
		# definition: the enemy's fixed values.
		var definition: Dictionary = ruleset["enemies"][def_id]
		# uid: this enemy's id in the fight.
		var uid: String = ENEMY_UID_PREFIX + str(state["next_uid"])
		state["next_uid"] += 1
		# enemy: the new enemy state.
		var enemy: Dictionary = EnemyState.blank(uid, def_id)
		enemy["max_hp"] = Scaling.scale_down(definition["max_hp"], ruleset["constants"], state["party_size"])
		enemy["hp"] = enemy["max_hp"]
		enemy["arm_count"] = definition["arm_count"]
		enemy["ick_threshold"] = Scaling.scale_up(ruleset["constants"][ICK_BASE_BY_TIER[definition["tier"]]],
			ruleset["constants"], state["party_size"])
		combat["enemies"].append(enemy)
		uids.append(uid)
	state["combat"] = combat
	for i: int in state["dudes"].size():
		Piles.prepare_for_fight_in_place(state, i)
	events.append(Event.make("fight_started", {"enemy_uids": uids}))
	# Task 021: Gear that fires at the start of the fight (Arm Wrestling Table), before turn 1.
	GearTriggers.fight_start_in_place(ruleset, state, events)
	start_turn_in_place(ruleset, state, events)
	# Task 021: Gear that fires on the first turn, right after its Refresh (Backwards Cap).
	GearTriggers.first_turn_in_place(ruleset, state, events)


## Turn flow steps 1-2, then stops in step 3: the turn number rises by 1 (turn_started), every
## enemy sets its intent (intent_set), and every Dude who is not Passed Out is refreshed.
## ruleset: the read-only content. state: the working copy, in a running fight. events: appended to.
static func start_turn_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	# combat: the fight, inside state.
	var combat: Dictionary = state["combat"]
	combat["turn"] += 1
	events.append(Event.make("turn_started", {"turn": combat["turn"]}))
	combat["phase"] = "intents"
	for enemy: Dictionary in combat["enemies"]:
		# Task 011: move, targets, move_history and intent_set (core/ai/intents.gd).
		Intents.set_intent_in_place(ruleset, state, enemy, events)
	combat["phase"] = "refresh"
	for i: int in state["dudes"].size():
		if not state["dudes"][i]["passed_out"]:
			_refresh_in_place(ruleset, state, i, events)
	# Task 013: active Powers' "turn_start" triggers (Friend Zone), after every Refresh.
	Ops.fire_power_triggers_in_place(ruleset, state, Powers.matching(ruleset, state, Powers.WHEN_TURN_START, ""), events)
	# Task 015: an on_draw trigger (Bedbugs) can Pass Out the last Dude during Refresh.
	if finish_if_decided_in_place(ruleset, state, events):
		return
	combat["phase"] = "player"


## Turn flow step 2 for one Dude. Emits guard_changed, hype_changed and ready_changed only for values
## that actually change, then the draw's deck_shuffled and card_moved events.
## ruleset: the read-only content, for on_draw triggers (task 015). state: the working copy.
## dude_index: the Dude's seat, 0-based. events: the event list, appended to.
static func _refresh_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, events: Array) -> void:
	# dude: the Dude being refreshed, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# player_id: the Dude's id, for events.
	var player_id: String = dude["player_id"]
	if dude["guard"] != 0:
		events.append(Event.make("guard_changed", {"target_id": player_id, "delta": -dude["guard"], "guard": 0}))
		dude["guard"] = 0
	if dude["hype"] != dude["hype_per_turn"]:
		events.append(Event.make("hype_changed", {"player_id": player_id,
			"delta": dude["hype_per_turn"] - dude["hype"], "hype": dude["hype_per_turn"]}))
		dude["hype"] = dude["hype_per_turn"]
	dude["cards_played_this_turn"] = 0
	# Task 013: thorns (Chrome Dome) last until this Refresh.
	ThornsOp.reset_in_place(dude, events)
	if dude["ready"]:
		dude["ready"] = false
		events.append(Event.make("ready_changed", {"player_id": player_id, "ready": false}))
	# Task 009: Foggy draws fewer cards, then loses a stack (G1). Task 015: on_draw triggers run per card.
	CardTriggers.draw_in_place(ruleset, state, dude_index, Statuses.refresh_draw_count(dude), events)
	Statuses.after_refresh_in_place(state, dude_index, events)


## True when every Dude who is not Passed Out is ready, so the player phase can end.
## state: the run state, in a fight.
static func everyone_ready(state: Dictionary) -> bool:
	for dude: Dictionary in state["dudes"]:
		if not dude["passed_out"] and not dude["ready"]:
			return false
	return true


## Turn flow steps 4 and 5, then the next turn's steps 1-2: every hand is discarded, enemies act
## left to right, and unless the fight ended a new turn starts and stops in the player phase.
## ruleset: the read-only content. state: the working copy, in the player phase. events: appended to.
static func end_player_phase_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	# combat: the fight, inside state.
	var combat: Dictionary = state["combat"]
	combat["phase"] = "end_of_turn"
	for i: int in state["dudes"].size():
		# Task 015: Burn and other on_end_of_turn_in_hand triggers, before the hand is discarded.
		CardTriggers.end_of_turn_in_hand_in_place(ruleset, state, i, events)
		# Task 013: pocketed cards stay in hand.
		Piles.discard_hand_in_place(state, i, events, Piles.pocketed_in_hand(ruleset, state["dudes"][i]))
	# Task 009: Dudes' statuses wear off at End of turn (G1).
	Statuses.end_of_turn_in_place(state, events)
	# Task 015: an end-of-turn trigger can Pass Out the last Dude; the enemies then do not act.
	if finish_if_decided_in_place(ruleset, state, events):
		return
	combat["phase"] = "enemy"
	for uid: String in Bodies.enemy_uids(state):
		# enemy: the acting enemy, or {} if it died earlier this phase.
		var enemy: Dictionary = Bodies.find_alive(state, uid)
		if enemy.is_empty():
			continue
		# Task 011, G30: the enemy's Guard drops to 0 at the start of its own action, even one it skips.
		Intents.begin_action_in_place(enemy, events)
		# Task 009: a Grossed Out or Armless enemy skips instead of acting (G6, G7).
		if not Statuses.skip_action_in_place(ruleset, enemy, events):
			_enemy_act_in_place(ruleset, state, enemy, events)
		# Task 009: the enemy's statuses wear off right after its slot (G1).
		Statuses.after_enemy_slot_in_place(state, uid, events)
		if finish_if_decided_in_place(ruleset, state, events):
			return
	start_turn_in_place(ruleset, state, events)


## One enemy carries out its intent: enemy_acted, then each effect of the move in order, aimed at
## the intent's targets that are not Passed Out. Effects whose op the core does not have yet, or
## whose fields are bad, are skipped (enemies have no reject path; content tests should catch
## these with Ops.check()). Does nothing if the enemy has no intent or the move is not found.
## ruleset: the read-only content. state: the working copy. enemy: the acting enemy, inside state.
## events: the event list, appended to.
static func _enemy_act_in_place(ruleset: Dictionary, state: Dictionary, enemy: Dictionary, events: Array) -> void:
	if enemy["intent"] == null:
		return
	# move: the intended move's definition, or {} if not found.
	var move: Dictionary = {}
	for candidate: Dictionary in ruleset["enemies"][enemy["def_id"]]["moves"]:
		if candidate["id"] == enemy["intent"]["move_id"]:
			move = candidate
			break
	if move.is_empty():
		return
	events.append(Event.make("enemy_acted", {"enemy_uid": enemy["uid"], "move_id": move["id"]}))
	# targets: the intent's targets still standing.
	var targets: Array = []
	for target_id: String in enemy["intent"]["target_ids"]:
		if not Bodies.find_alive(state, target_id).is_empty():
			targets.append(target_id)
	# context: who acts and who the effects land on, for the ops.
	# Task 009: every enemy move's damage is attack damage (G3); it is not from a card.
	var context: Dictionary = Ops.make_context(ruleset, enemy["uid"], targets, true, false)
	for effect: Dictionary in move["effects"]:
		if Bodies.is_decided(state):
			return
		if Ops.check(effect).is_empty():
			Ops.run(state, effect, context, events)


## Ends the fight if it is decided: "lost" when every Dude is Passed Out (checked first, because
## then "the run ends", GDD), otherwise "won" when every enemy is dead. Sets combat.result and
## phase "over" and emits fight_ended. Task 015: then removes every fight-only card (definition
## lasts "fight") from each Dude, with card_removed. Returns true when the fight is over (now or already).
## ruleset: the read-only content, for the cards' lasts (task 015).
## state: the working copy, in a fight. events: the event list, appended to.
static func finish_if_decided_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> bool:
	# combat: the fight, inside state.
	var combat: Dictionary = state["combat"]
	if combat["phase"] == "over":
		return true
	# result: "lost", "won" or "" while the fight goes on.
	var result: String = ""
	if Bodies.awake_dude_ids(state).is_empty():
		result = "lost"
	elif combat["enemies"].is_empty():
		result = "won"
	if result == "":
		return false
	combat["result"] = result
	combat["phase"] = "over"
	events.append(Event.make("fight_ended", {"result": result}))
	# Task 015: fight-only Junk (Paperwork, Detention, Burn) leaves when the fight ends.
	CardTriggers.remove_fight_only_in_place(ruleset, state, events)
	return true
