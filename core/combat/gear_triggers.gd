## Gear in play: gaining Gear, its stat changes, its trigger points and its modifiers (task 021).
## Lane: core (Agent A). Format: core/schema/gear_def.gd. Catalogue: core/ops/README.md "Gear".
##
## The rest of the core calls into this file at small, marked points ("Task 021"):
##   core/combat/party.gd  gain_in_place() for each starting Gear.
##   core/combat/fight.gd  fight_start_in_place() after fight_started (draw piles already shuffled),
##                         before turn 1's intents and Refresh: Hype is not yet filled and no card
##                         drawn, so a Hangover added here can be drawn in turn 1;
##                         first_turn_in_place() right after turn 1's Refresh of every Dude: Hype is
##                         already refilled and the hand drawn, so "+1 Hype" or "draw 2 extra" here
##                         adds to them.
##   core/combat/play.gd   card_effects() (Championship Ring), after_effect_in_place() after each
##                         card effect (Whole Can of Body Spray), card_played_in_place() after the
##                         card has gone to its pile.
##   core/core.gd          after_request_in_place() after every applied request: when the request
##                         ended the fight, fight_end_in_place() runs.
##   core/combat/brews.gd  run_effects_in_place() for a Brew's effects.
##
## Rules (task 021; the ones the GDD does not state are listed in the task log for the people):
##   - Stats ("+1 Swole") are added once when the Gear is gained; Gear is never lost in the slice.
##   - Order: Dudes in seat order; each Dude's Gear in the order gained; each Gear's triggers in
##     definition order. So Tom's starting Gear always fires before Gear found later.
##   - A trigger whose effects use an op the core does not have, or bad op fields, is skipped whole
##     (never half run), as an enemy move's effect is. check() reports these for content tests.
##   - Passed Out Dudes' Gear does not fire. A condition (hp_below_percent) is read when it fires.
##   - fight_end fires only for a fight that was won ("lost" ends the run). Fight-only stat changes
##     (combat.fight_stat_changes) are taken back first, whatever the result.
##   - ick_applied fires once per enemy per Ick application by the owner (the status_changed "ick"
##     event with a positive delta, which already includes Clout, G5). Its effects do not set off
##     ick_applied again.
##   - Effects from Gear are not attack damage (G3) and not "from cards" (Hungover, G4).
##
## Functions ending in _in_place change the working copy they are given (see bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Ops := preload("res://core/ops/ops.gd")
const GainStat := preload("res://core/ops/gain_stat.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## Status id whose application sets off ick_applied triggers (core/schema/README.md "Status ids").
const ICK_STATUS: String = "ick"

## Effect field that amount_per_stack multiplies (core/schema/gear_def.gd TRIGGER_OPTIONAL).
const AMOUNT_FIELD: String = "amount"

## Effect op whose amount a card_damage modifier raises (core/schema/gear_def.gd MODIFIER_KINDS).
const DAMAGE_OP: String = "damage"

## Percent that leaves a value unchanged, for the _percent modifiers. Not tuning: 100% is "all of it".
const WHOLE_PERCENT: int = 100

## Fight result on which fight_end triggers fire (core/schema/combat_state.gd RESULTS).
const WON: String = "won"


## Returns the problems with a Gear definition's effects that the schema cannot see: unknown ops or
## bad op fields in its triggers (core/ops/ops.gd check). Empty means every trigger can fire.
## Content tests may call it on every data/gear/ file.
## definition: a Gear definition that passed core/schema/gear_def.gd check(). path: label for messages.
static func check(definition: Dictionary, path: String = "gear") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for i: int in definition["triggers"].size():
		errors.append_array(Ops.check_all(definition["triggers"][i]["effects"], "%s.triggers[%d].effects" % [path, i]))
	return errors


## Gives a Dude a Gear: its id is appended to gear (gear_gained), then each of its stats is added
## in sorted stat order (stat_changed). A Gear the ruleset lacks is added by id with no effect.
## ruleset: the read-only content. dude: the Dude, inside the working copy (or a Dude being built).
## gear_id: the Gear's id. events: the event list, appended to.
static func gain_in_place(ruleset: Dictionary, dude: Dictionary, gear_id: String, events: Array) -> void:
	dude["gear"].append(gear_id)
	events.append(Event.make("gear_gained", {"player_id": dude["player_id"], "gear_id": gear_id}))
	# definition: the Gear's definition, or {}.
	var definition: Dictionary = definition_of(ruleset, gear_id)
	if definition.is_empty():
		return
	# stats: the stat names, sorted.
	var stats: Array = definition["stats"].keys()
	stats.sort()
	for stat: String in stats:
		if GainStat.has_stat(dude, stat):
			GainStat.change_in_place(dude, dude["player_id"], stat, definition["stats"][stat], events)


## Returns a Gear's definition, or {} when the ruleset does not have it (or has no Gear at all).
## ruleset: the read-only content. gear_id: the Gear's id.
static func definition_of(ruleset: Dictionary, gear_id: String) -> Dictionary:
	return ruleset.get("gear", {}).get(gear_id, {})


## Trigger point fight_start: every Dude's fight_start triggers fire, in order.
## ruleset: the read-only content. state: the working copy, in a new fight. events: appended to.
static func fight_start_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	_fire_all_in_place(ruleset, state, "fight_start", events)


## Trigger point first_turn: every Dude's first_turn triggers fire, in order.
## ruleset: the read-only content. state: the working copy, in turn 1's player phase. events: appended to.
static func first_turn_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	_fire_all_in_place(ruleset, state, "first_turn", events)


## Trigger point fight_end: takes back fight-only stat changes, then, if the fight was won, every
## Dude's fight_end triggers fire, in order.
## ruleset: the read-only content. state: the working copy, its fight just over. events: appended to.
static func fight_end_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	GainStat.undo_fight_changes_in_place(state, events)
	if state["combat"]["result"] == WON:
		_fire_all_in_place(ruleset, state, "fight_end", events)


## Called by Core.apply() after every applied request: runs fight_end_in_place() when this request
## ended the fight (the fight was running in before and is over in state).
## ruleset: the read-only content. before: the state the request was applied to (read only).
## state: the working copy after the request. events: appended to.
static func after_request_in_place(ruleset: Dictionary, before: Dictionary, state: Dictionary, events: Array) -> void:
	if before["combat"] == null or before["combat"]["phase"] == "over":
		return
	if state["combat"] != null and state["combat"]["phase"] == "over":
		fight_end_in_place(ruleset, state, events)


## Trigger point card_played: after a Dude's card has resolved and gone to its pile, that Dude's
## card_played triggers whose card_type / min_cost match the card fire, unless the fight is over.
## ruleset: the read-only content. state: the working copy. dude_index: the player's seat, 0-based.
## card: the played card's definition. targets: the ids the card's effects landed on. events: appended to.
static func card_played_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, card: Dictionary,
		targets: Array, events: Array) -> void:
	if not _fight_running(state) or Bodies.is_decided(state):
		return
	for gear_id: String in state["dudes"][dude_index]["gear"].duplicate():
		for trigger: Dictionary in triggers_of(ruleset, gear_id, "card_played"):
			if card_matches(trigger, card):
				_fire_in_place(ruleset, state, dude_index, gear_id, trigger, targets, 0, events)


## Trigger point ick_applied, checked after one effect ran: for each Ick application by the actor in
## events[first..] (status_changed, status "ick", delta above 0, on an enemy), the actor's
## ick_applied triggers fire with that enemy as trigger_target and the delta as the stacks.
## ruleset: the read-only content. state: the working copy. actor_id: who ran the effect; only a
## Dude's Gear reacts. events: the event list, appended to. first: index in events where the
## effect's own events start.
static func after_effect_in_place(ruleset: Dictionary, state: Dictionary, actor_id: String, events: Array, first: int) -> void:
	# index: the actor's seat, or -1 for an enemy.
	var index: int = Bodies.dude_index(state, actor_id)
	if index == -1:
		return
	# applied: [enemy uid, Ick added] for each Ick application found, in event order.
	var applied: Array = []
	for i: int in range(first, events.size()):
		# event: one event the effect produced.
		var event: Dictionary = events[i]
		if event["type"] == "status_changed" and event["status"] == ICK_STATUS and event["delta"] > 0 \
				and Bodies.dude_index(state, event["target_id"]) == -1:
			applied.append([event["target_id"], event["delta"]])
	for entry: Array in applied:
		for gear_id: String in state["dudes"][index]["gear"].duplicate():
			for trigger: Dictionary in triggers_of(ruleset, gear_id, "ick_applied"):
				_fire_in_place(ruleset, state, index, gear_id, trigger, [entry[0]], entry[1], events)


## Runs a list of effects in order for an actor, as a card does, and lets the actor's Gear react to
## each one (after_effect_in_place). Stops once a running fight is decided. Every effect must have
## passed Ops.check().
## ruleset: the read-only content. state: the working copy. effects: the effects to run.
## context: from Ops.make_context(). events: the event list, appended to.
## react: false stops Gear reacting (used for effects that a reaction itself runs).
static func run_effects_in_place(ruleset: Dictionary, state: Dictionary, effects: Array, context: Dictionary,
		events: Array, react: bool = true) -> void:
	for effect: Dictionary in effects:
		if _fight_running(state) and Bodies.is_decided(state):
			return
		# first: where this effect's events start.
		var first: int = events.size()
		Ops.run(state, effect, context, events)
		if react:
			after_effect_in_place(ruleset, state, context["actor_id"], events, first)


## Returns the effects a Dude's card runs: the card's own, with each card_damage modifier of the
## Dude's Gear that matches the card (card_type, min_cost) added to the amount of every damage
## effect. The amount is per hit and before Swole, so it goes through the damage order like base
## damage. Returns the card's own list unchanged when no modifier applies.
## ruleset: the read-only content. dude: the player's Dude. card: the card's definition.
static func card_effects(ruleset: Dictionary, dude: Dictionary, card: Dictionary) -> Array:
	# bonus: damage added to each hit.
	var bonus: int = 0
	for gear_id: String in dude["gear"]:
		for modifier: Dictionary in definition_of(ruleset, gear_id).get("modifiers", []):
			if modifier["kind"] == "card_damage" and card_matches(modifier, card):
				bonus += modifier["amount"]
	if bonus == 0:
		return card["effects"]
	# effects: the card's effects with the bonus added.
	var effects: Array = []
	for effect: Dictionary in card["effects"]:
		if effect.get("op") == DAMAGE_OP and typeof(effect.get(AMOUNT_FIELD)) == TYPE_INT:
			# raised: a writable copy of the damage effect.
			var raised: Dictionary = effect.duplicate()
			raised[AMOUNT_FIELD] = effect[AMOUNT_FIELD] + bonus
			effects.append(raised)
		else:
			effects.append(effect)
	return effects


## Returns value scaled by every modifier of this kind on the Dude's Gear, in Gear order: value x
## amount / 100 for each, rounded down once at the end (G26). value when the Dude has none.
## ruleset: the read-only content. dude: the Dude. kind: "shop_price_percent" or
## "fight_dolla_bills_percent". value: the normal value, 0 or more.
static func percent_of(ruleset: Dictionary, dude: Dictionary, kind: String, value: int) -> int:
	# numerator / denominator: the scaled value as an exact fraction.
	var numerator: int = value
	# denominator: WHOLE_PERCENT once per modifier applied.
	var denominator: int = 1
	for gear_id: String in dude["gear"]:
		for modifier: Dictionary in definition_of(ruleset, gear_id).get("modifiers", []):
			if modifier["kind"] == kind:
				numerator *= modifier["amount"]
				denominator *= WHOLE_PERCENT
	return numerator / denominator


## Returns a Baileys price for this Dude: the normal price with Medical Card and the like applied
## (shop_price_percent, rounded down; G26: every Baileys price, card removal included). For the
## run lane's shop (task 025).
## ruleset: the read-only content. dude: the buyer. price: the normal price in Dolla Bills, 0 or more.
static func shop_price(ruleset: Dictionary, dude: Dictionary, price: int) -> int:
	return percent_of(ruleset, dude, "shop_price_percent", price)


## Returns the Dolla Bills a Dude earns from a fight: the normal reward with Dad's Platinum Card and
## the like applied (fight_dolla_bills_percent, rounded down). For the run lane's rewards (task 025).
## ruleset: the read-only content. dude: the earner. amount: the normal reward, 0 or more.
static func fight_dolla_bills(ruleset: Dictionary, dude: Dictionary, amount: int) -> int:
	return percent_of(ruleset, dude, "fight_dolla_bills_percent", amount)


## True when a card passes a trigger's or modifier's card filter (card_type, min_cost; absent
## fields pass). A cost that is not an int ("x") never passes min_cost.
## entry: the trigger or modifier. card: the card's definition.
static func card_matches(entry: Dictionary, card: Dictionary) -> bool:
	if entry.has("card_type") and card["type"] != entry["card_type"]:
		return false
	if entry.has("min_cost") and (typeof(card["cost"]) != TYPE_INT or card["cost"] < entry["min_cost"]):
		return false
	return true


## Returns a Gear's triggers for one trigger point, in definition order ([] for unknown Gear).
## ruleset: the read-only content. gear_id: the Gear's id. when: a trigger point.
static func triggers_of(ruleset: Dictionary, gear_id: String, when: String) -> Array:
	# found: the matching triggers.
	var found: Array = []
	for trigger: Dictionary in definition_of(ruleset, gear_id).get("triggers", []):
		if trigger["when"] == when:
			found.append(trigger)
	return found


## Fires one trigger point for every Dude's Gear: seat order, Gear order, trigger order.
## ruleset: the read-only content. state: the working copy, with a fight. when: the trigger point.
## events: the event list, appended to.
static func _fire_all_in_place(ruleset: Dictionary, state: Dictionary, when: String, events: Array) -> void:
	for i: int in state["dudes"].size():
		for gear_id: String in state["dudes"][i]["gear"].duplicate():
			for trigger: Dictionary in triggers_of(ruleset, gear_id, when):
				_fire_in_place(ruleset, state, i, gear_id, trigger, [], 0, events)


## Fires one trigger for its owner, if it may fire now (see the file header): emits gear_triggered,
## then runs its effects on its targets. Does nothing when the owner is Passed Out, its condition
## fails, a running fight is already decided, or an effect cannot run.
## ruleset: the read-only content. state: the working copy. dude_index: the owner's seat, 0-based.
## gear_id: the Gear. trigger: one of its triggers. trigger_targets: the ids "trigger_target" means
## ([] when the point has none). stacks: the Ick applied, for amount_per_stack (0 otherwise).
## events: the event list, appended to.
static func _fire_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, gear_id: String,
		trigger: Dictionary, trigger_targets: Array, stacks: int, events: Array) -> void:
	# dude: the owner, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	if dude["passed_out"]:
		return
	if trigger.has("hp_below_percent") and dude["hp"] * WHOLE_PERCENT >= dude["max_hp"] * trigger["hp_below_percent"]:
		return
	if _fight_running(state) and Bodies.is_decided(state):
		return
	if not Ops.check_all(trigger["effects"]).is_empty():
		return
	# effects: the trigger's effects, scaled by stacks when amount_per_stack is set.
	var effects: Array = trigger["effects"]
	if trigger.get("amount_per_stack", false):
		effects = []
		for effect: Dictionary in trigger["effects"]:
			# scaled: a writable copy with amount multiplied by stacks.
			var scaled: Dictionary = effect.duplicate()
			if typeof(scaled.get(AMOUNT_FIELD)) == TYPE_INT:
				scaled[AMOUNT_FIELD] = scaled[AMOUNT_FIELD] * stacks
			effects.append(scaled)
	events.append(Event.make("gear_triggered", {"player_id": dude["player_id"], "gear_id": gear_id, "when": trigger["when"]}))
	# context: the owner acts; not attack damage (G3), not from a card (G4).
	var context: Dictionary = Ops.make_context(ruleset, dude["player_id"],
		_targets(state, dude, trigger["target"], trigger_targets), false, false)
	run_effects_in_place(ruleset, state, effects, context, events, trigger["when"] != "ick_applied")


## Returns the ids a trigger's effects land on (core/schema/gear_def.gd TRIGGER_TARGETS).
## state: the working copy. dude: the owner. target: the trigger's target. trigger_targets: what
## "trigger_target" means here.
static func _targets(state: Dictionary, dude: Dictionary, target: String, trigger_targets: Array) -> Array:
	match target:
		"self":
			return [dude["player_id"]]
		"all_enemies":
			return Bodies.enemy_uids(state)
		"all_dudes":
			return Bodies.awake_dude_ids(state)
		"trigger_target":
			return trigger_targets.duplicate()
	return []


## True when there is a fight that has not ended.
## state: a run state.
static func _fight_running(state: Dictionary) -> bool:
	return state["combat"] != null and state["combat"]["phase"] != "over"
