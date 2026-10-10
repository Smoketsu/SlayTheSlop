## Powers: which active Power triggers fire, and on whom (task 013). Lane: core (Agent A).
##
## A played card of type "power" goes into its Dude's powers list (core/combat/play.gd) and stays
## active for the rest of the fight (GDD "Card types and keywords"). What it does is its
## definition's power_triggers (core/schema/card_def.gd): each trigger has a "when", a "target" and
## effects. This file finds the triggers that fire and their targets; core/ops/ops.gd runs them
## (fire_power_triggers_in_place), so this file never needs the op registry and there is no
## preload cycle.
##
## When triggers fire:
##   "turn_start":        once per turn, after every Dude's Refresh, before the player phase
##                        (core/combat/fight.gd). The turn a Power is played, it has not fired yet.
##   "enemy_buffed":      an enemy gained a buff (G10, answered "accept": Guard or Swole; healing is
##                        not a buff). Found from the events an op emitted: a guard_changed with a
##                        positive delta on an enemy (BUFF_EVENTS). No op raises an enemy's Swole
##                        yet; the op that does (task 017) must emit an event listed in BUFF_EVENTS.
##   "enemy_grossed_out": an enemy was Grossed Out (a grossed_out event).
## Order: by the events in the order they happened; for each, Dudes in seat order, each Dude's
## Powers oldest first, each Power's triggers in definition order. Two copies of one Power both
## fire. A Passed Out Dude's Powers do not fire.
##
## Targets: "subject" is the enemy the trigger is about (skipped if it has died since), "all_enemies"
## every enemy in the fight when it fires, left to right, "self" the Dude who played the Power. The
## Dude who played the Power is the actor, so Ick from a Power adds that Dude's Clout (G5).
##
## Reads only. Pure: no file, clock, network or random access.
extends RefCounted

const Bodies := preload("res://core/combat/bodies.gd")
const CardDef := preload("res://core/schema/card_def.gd")

## Event type -> the field naming the body whose buff it reports. A positive delta on an enemy is a
## buff (G10). Add the Swole event here when an op that raises an enemy's Swole is built.
const BUFF_EVENTS := {"guard_changed": "target_id"}

## Trigger "when" values (core/schema/card_def.gd POWER_WHENS), named here for the code that fires them.
const WHEN_TURN_START: String = "turn_start"

## See WHEN_TURN_START.
const WHEN_ENEMY_BUFFED: String = "enemy_buffed"

## See WHEN_TURN_START.
const WHEN_ENEMY_GROSSED_OUT: String = "enemy_grossed_out"


## Returns the triggers that fire because of the events from index from on, in order (see the
## file header). Each is a record for core/ops/ops.gd fire_power_triggers_in_place:
## {"player_id": the Power's Dude, "card_uid": the Power card, "when": the trigger's when,
##  "subject_id": the enemy uid it is about, "target": the trigger's target, "effects": its effects}.
## ruleset: the read-only content. state: the run state, in a fight. events: the event list.
## from: index of the first event to look at, 0..events.size().
static func reactions(ruleset: Dictionary, state: Dictionary, events: Array, from: int) -> Array:
	# records: the result.
	var records: Array = []
	for i: int in range(from, events.size()):
		# event: one event to react to.
		var event: Dictionary = events[i]
		if BUFF_EVENTS.has(event["type"]) and event["delta"] > 0 \
				and Bodies.enemy_index(state, event[BUFF_EVENTS[event["type"]]]) != -1:
			records.append_array(matching(ruleset, state, WHEN_ENEMY_BUFFED, event[BUFF_EVENTS[event["type"]]]))
		elif event["type"] == "grossed_out":
			records.append_array(matching(ruleset, state, WHEN_ENEMY_GROSSED_OUT, event["enemy_uid"]))
	return records


## Returns the records (see reactions()) of every active Power trigger with this when, for Dudes
## that are not Passed Out, in the order in the file header.
## ruleset: the read-only content. state: the run state. when: one of card_def.gd POWER_WHENS.
## subject_id: the enemy uid the trigger is about, "" for turn_start.
static func matching(ruleset: Dictionary, state: Dictionary, when: String, subject_id: String) -> Array:
	# records: the result.
	var records: Array = []
	for dude: Dictionary in state["dudes"]:
		if dude["passed_out"]:
			continue
		for uid: String in dude["powers"]:
			# definition: the Power card's definition, or {} if the ruleset lacks it.
			var definition: Dictionary = ruleset["cards"].get(dude["cards"][uid]["def_id"], {})
			for trigger: Dictionary in definition.get("power_triggers", []):
				if trigger["when"] == when:
					records.append({"player_id": dude["player_id"], "card_uid": uid, "when": when,
						"subject_id": subject_id, "target": trigger["target"], "effects": trigger["effects"]})
	return records


## Returns the ids a trigger's effects land on now (see the file header). [] for a "subject" whose
## enemy has died.
## state: the run state. record: one record from reactions() or matching().
static func targets_of(state: Dictionary, record: Dictionary) -> Array:
	match record["target"]:
		"subject":
			return [record["subject_id"]] if Bodies.enemy_index(state, record["subject_id"]) != -1 else []
		"all_enemies":
			return Bodies.enemy_uids(state)
		"self":
			return [record["player_id"]]
	return []


## True when the card is a Power: played, it goes to the Dude's powers list instead of a pile.
## card: a card definition.
static func is_power(card: Dictionary) -> bool:
	return card["type"] == CardDef.POWER_TYPE
