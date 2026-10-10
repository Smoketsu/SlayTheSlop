## Enemy behaviors that are not a plain move (task 017, GDD "Floor 1: The Basement"). Lane: core (Agent A).
## Shapes: core/schema/enemy_def.gd (tags, arrives_with, move_rules, triggers, split,
## periodic_statuses, drops_brews). Catalogue for content writers: core/ops/README.md.
##
## The turn flow (core/combat/fight.gd) and Core.apply() (core/core.gd) call this file at a few
## marked points; the rest of the behaviors live where they act:
##   - check_start():               a fight refuses enemies whose escorts, split targets or summoned
##                                  enemies are unknown, and a missing FADED_MAX_DAMAGE.
##   - start_of_turn_in_place():    turn flow step 1, before intents: periodic statuses (Boo-zer's
##                                  Faded, core/combat/periodic_statuses.gd).
##   - after_card_played_in_place(): after a card has fully resolved: "cards_played" triggers
##                                  (Kobold RA's Noise Complaint, Hall Monitor Golem's Detention).
##   - after_enemy_effect_in_place(): after each effect of an enemy's move: "unblocked_damage"
##                                  triggers (Sewer Gator's Swole).
##   - settle_in_place():           after every applied request and after each enemy's slot in the
##                                  enemy phase: enemies at or below their split point split (Keg Slime).
## Elsewhere: move rules at intents (core/ai/move_rules.gd), escorts at fight start
## (core/combat/lineup.gd), the haul and Brew drops on death (core/combat/enemy_death.gd), the
## Faded damage cap (core/ops/damage.gd), and the ops summon_enemy, steal_dolla_bills, flee and
## gain_swole (core/ops/).
##
## Rules decided here where the GDD is silent (task 017's log lists them for the people):
##   - Triggers: a trigger's effects run with the enemy as actor and the named Dude as the only
##     target, in definition order, enemies left to right. Their damage is not attack damage (G3:
##     "Noise Complaint ignores them"), so it is exactly the amount, and Guard still absorbs it. A
##     trigger fires even while its enemy waits to skip an action (Grossed Out, Armless): it is not
##     an action. Effects stop once the fight is decided.
##   - "cards_played" fires when the player's cards_played_this_turn reaches "cards" (and, with
##     repeat, each multiple of it), after the card has resolved and gone to its pile. Kobold RA's
##     "plays 5 or more cards" is therefore once per turn, on the fifth card. A Passed Out player is
##     not a target.
##   - "unblocked_damage" counts each damage_dealt by the enemy's own move with hp_lost above 0 on a
##     Dude, and fires once per such hit after the effect that dealt them (so a Death Roll's three
##     hits are dealt with the Swole it had before the roll).
##   - Split: an enemy whose hp is above 0 and at or below at_hp_percent of its max_hp is removed
##     (enemy_split) and replaced, at its position, by split.count enemies of split.into at full HP
##     (enemy_spawned for each, left to right). Its statuses, Ick, Guard and intent do not carry
##     over. A hit that kills it outright leaves nothing to split. Split checks happen at the points
##     listed above, so the rest of a multi-hit card still lands on the enemy before it splits.
##     Enemies that split in the player phase choose their intents at once, so they act in the coming
##     enemy phase; those that split in the enemy phase wait for the next turn's intents.
##
## Pure and deterministic: randomness only through core/rng (intents of split enemies); enemies
## are walked left to right, triggers and rules in definition order. Functions ending in _in_place
## change the working copy they are given (see core/combat/bodies.gd).
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Ops := preload("res://core/ops/ops.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const Lineup := preload("res://core/combat/lineup.gd")
const Periodic := preload("res://core/combat/periodic_statuses.gd")
const Intents := preload("res://core/ai/intents.gd")

## Trigger kind (enemy_def.gd TRIGGER_KINDS) for "a player has played their n-th card this turn".
const ON_CARDS_PLAYED: String = "cards_played"

## Trigger kind (enemy_def.gd TRIGGER_KINDS) for "a hit of its move took HP off a Dude".
const ON_UNBLOCKED_DAMAGE: String = "unblocked_damage"

## Op whose enemy_id names an enemy a fight may come to hold (core/ops/summon_enemy.gd).
const SUMMON_OP: String = "summon_enemy"


## Returns why the behaviors of these enemies cannot run, or "" when they can. Walks every enemy the
## fight could come to hold (the lineup with its escorts, the enemies they split into and summon,
## and theirs in turn): each must be in the ruleset and have a tier whose ICK_BASE_* constant is an
## int. Also needs constant FADED_MAX_DAMAGE. Reads only.
## ruleset: the read-only content. enemy_def_ids: the enemies asked for, left to right, all known.
static func check_start(ruleset: Dictionary, enemy_def_ids: Array) -> String:
	# constant_error: why a constant this file's rules need is unusable, or "".
	var constant_error: String = Periodic.check_constants(ruleset["constants"])
	if constant_error != "":
		return constant_error
	# pending: definition ids still to visit.
	var pending: Array = Lineup.expand(ruleset, enemy_def_ids)
	# seen: definition ids already visited.
	var seen: Dictionary = {}
	while not pending.is_empty():
		# def_id: the definition being visited.
		var def_id: Variant = pending.pop_front()
		if seen.has(def_id):
			continue
		seen[def_id] = true
		if typeof(def_id) != TYPE_STRING or not ruleset["enemies"].has(def_id):
			return "unknown enemy %s (an escort, split or summon target)" % var_to_str(def_id)
		# definition: the visited enemy's fixed values.
		var definition: Dictionary = ruleset["enemies"][def_id]
		# constant: its tier's Ick base constant.
		var constant: String = Lineup.ICK_BASE_BY_TIER.get(definition["tier"], "")
		if constant == "" or typeof(ruleset["constants"].get(constant)) != TYPE_INT:
			return "constant %s for enemy %s is missing or not an int" % [constant, def_id]
		pending.append_array(definition.get("arrives_with", []))
		if definition.has("split"):
			pending.append(definition["split"]["into"])
		for move: Dictionary in definition["moves"]:
			for effect: Variant in move["effects"]:
				if typeof(effect) == TYPE_DICTIONARY and effect.get("op") == SUMMON_OP:
					pending.append(effect.get("enemy_id"))
	return ""


## Turn flow step 1, before intents: periodic statuses for the new turn (core/combat/periodic_statuses.gd).
## ruleset: the read-only content. state: the working copy, in a fight. events: the event list, appended to.
static func start_of_turn_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	Periodic.update_in_place(ruleset, state, events)


## After a card has fully resolved: fires every "cards_played" trigger that the player's
## cards_played_this_turn sets off (see the file header), enemies left to right.
## ruleset: the read-only content. state: the working copy, in a fight. dude_index: the seat of the
## player who played, 0-based. events: the event list, appended to.
static func after_card_played_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, events: Array) -> void:
	# dude: the player's Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# played: cards this player has played this turn, the card just played included.
	var played: int = dude["cards_played_this_turn"]
	for uid: String in Bodies.enemy_uids(state):
		# enemy: the watching enemy, or {} if it left the fight meanwhile.
		var enemy: Dictionary = Bodies.find_alive(state, uid)
		if enemy.is_empty():
			continue
		for trigger: Dictionary in ruleset["enemies"][enemy["def_id"]].get("triggers", []):
			if Bodies.is_decided(state) or dude["passed_out"] or Bodies.find_alive(state, uid).is_empty():
				return
			if trigger["on"] == ON_CARDS_PLAYED and fires_on_count(trigger, played):
				run_trigger_in_place(ruleset, state, enemy, trigger, dude["player_id"], events)


## True when a "cards_played" trigger fires at this count: count equals its "cards", or, with
## "repeat", count is a positive multiple of it.
## trigger: a cards_played trigger (cards 1 or more). count: cards played this turn, 0 or more.
static func fires_on_count(trigger: Dictionary, count: int) -> bool:
	if trigger["repeat"]:
		return count > 0 and count % trigger["cards"] == 0
	return count == trigger["cards"]


## After one effect of an enemy's move: for every hit in that effect's events (from first_event on)
## that the enemy dealt to a Dude with hp_lost above 0, fires the enemy's "unblocked_damage"
## triggers once, aimed at the Dude hit. Stops when the enemy is gone or the fight is decided.
## ruleset: the read-only content. state: the working copy, in a fight. enemy_uid: the acting enemy.
## events: the event list, appended to. first_event: index in events where the effect's events start.
static func after_enemy_effect_in_place(ruleset: Dictionary, state: Dictionary, enemy_uid: String,
		events: Array, first_event: int) -> void:
	# enemy: the acting enemy, or {} if it is gone.
	var enemy: Dictionary = Bodies.find_alive(state, enemy_uid)
	if enemy.is_empty():
		return
	# triggers: its unblocked_damage triggers, in definition order.
	var triggers: Array = ruleset["enemies"][enemy["def_id"]].get("triggers", []).filter(
		func(trigger: Dictionary) -> bool: return trigger["on"] == ON_UNBLOCKED_DAMAGE)
	if triggers.is_empty():
		return
	# hit_dudes: the Dude hit by each unblocked hit, in order; read before any trigger adds events.
	var hit_dudes: Array = []
	for i: int in range(first_event, events.size()):
		# event: one event of the effect.
		var event: Dictionary = events[i]
		if event["type"] == "damage_dealt" and event["source_id"] == enemy_uid and event["hp_lost"] > 0 \
				and Bodies.dude_index(state, event["target_id"]) != -1:
			hit_dudes.append(event["target_id"])
	for target_id: String in hit_dudes:
		for trigger: Dictionary in triggers:
			if Bodies.is_decided(state) or Bodies.find_alive(state, enemy_uid).is_empty():
				return
			run_trigger_in_place(ruleset, state, enemy, trigger, target_id, events)


## Fires one trigger: enemy_triggered, then each of its effects in order with the enemy as actor and
## target_id as the only target (not attack damage, not from a card). Effects with an unknown op or
## bad fields are skipped, as in enemy moves. Stops once the fight is decided.
## ruleset: the read-only content. state: the working copy. enemy: the enemy, inside state.
## trigger: one of its triggers. target_id: the Dude it lands on. events: the event list, appended to.
static func run_trigger_in_place(ruleset: Dictionary, state: Dictionary, enemy: Dictionary, trigger: Dictionary,
		target_id: String, events: Array) -> void:
	events.append(Event.make("enemy_triggered", {"enemy_uid": enemy["uid"], "trigger_id": trigger["id"],
		"target_id": target_id}))
	# context: the trigger's actor and target for the ops.
	var context: Dictionary = Ops.make_context(ruleset, enemy["uid"], [target_id], false, false)
	for effect: Variant in trigger["effects"]:
		if Bodies.is_decided(state):
			return
		if Ops.check(effect).is_empty():
			Ops.run(state, effect, context, events)


## Splits every enemy that is at or below its split point (see the file header), left to right. Does
## nothing outside a running fight. In the player phase the new enemies choose their intents at once.
## ruleset: the read-only content. state: the working copy. events: the event list, appended to.
static func settle_in_place(ruleset: Dictionary, state: Dictionary, events: Array) -> void:
	if state["combat"] == null or state["combat"]["phase"] == "over":
		return
	for uid: String in Bodies.enemy_uids(state):
		# index: the enemy's position, or -1 if it left the fight meanwhile.
		var index: int = Bodies.enemy_index(state, uid)
		if index == -1:
			continue
		# enemy: the enemy being checked, inside state.
		var enemy: Dictionary = state["combat"]["enemies"][index]
		# split: its split rule, or {}.
		var split: Dictionary = ruleset["enemies"][enemy["def_id"]].get("split", {})
		if split.is_empty() or not should_split(enemy, split):
			continue
		state["combat"]["enemies"].remove_at(index)
		events.append(Event.make("enemy_split", {"enemy_uid": uid}))
		for i: int in split["count"]:
			# spawned: the new enemy, or {} if its definition is missing.
			var spawned: Dictionary = Lineup.spawn_in_place(ruleset, state, split["into"], index + i, events)
			if not spawned.is_empty() and state["combat"]["phase"] == "player":
				Intents.set_intent_in_place(ruleset, state, spawned, events)


## True when an enemy must split: its hp is above 0 and hp x 100 <= at_hp_percent x max_hp.
## enemy: an enemy state. split: its definition's split rule (core/schema/enemy_def.gd SPLIT_SPEC).
static func should_split(enemy: Dictionary, split: Dictionary) -> bool:
	return enemy["hp"] > 0 and enemy["hp"] * 100 <= split["at_hp_percent"] * enemy["max_hp"]
