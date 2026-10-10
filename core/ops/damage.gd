## The "damage" effect operation (tasks 007 and 009). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Fields: amount (int, 0 or more: base damage of one hit) and hits (int, 1 or more, optional,
## default DEFAULT_HITS: how many times the hit repeats). Recipients: the effect's targets, that is
## the card's chosen target(s) or the enemy intent's target_ids.
##
## Damage order (GDD "Combat rules"), for each hit, worked out by hit_amount():
##   step 1: base amount + the attacker's Swole (never below 0);
##   step 2: x NOODLE_MULT if the attacker has Noodle Arms;
##   step 3: x (1 - BROKEN_ARM_MAX_REDUCTION x k / n) if the attacker is an enemy with k of its n
##           arms broken (n above 0);
##   step 4: x EXPOSED_MULT if the target is Exposed;
##   step 5: round down ONCE, then Guard absorbs the damage and is reduced by what it absorbed (G2),
##           the rest comes off HP, HP never goes below 0, and a body at 0 HP dies or Passes Out.
## Steps 2-4 multiply exact ratios (core/ops/ratio.gd), never floats, so there is no drift.
##
## G3 (answered "accept"): only attack damage gets steps 1-4: damage effects on Attack cards, Bro
## Moves and enemy moves. The caller says which through context "attack" (core/combat/play.gd sets
## it for cards of type "attack", core/combat/fight.gd for every enemy move). A damage effect that is
## not an attack (for example on a Skill card) deals exactly amount: Swole is "added to every hit of
## every attack" (GDD "Stats"), so it is left out too. Self-damage, Burn and the like are other ops.
##
## Task 013, thorns (Chrome Dome, G9): after each hit an enemy lands on a Dude with thorns above 0,
## the enemy takes that much damage back (deal_in_place, not attack damage). If that kills the
## enemy, the rest of its hits do not happen. See core/ops/thorns.gd.
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const Statuses := preload("res://core/combat/statuses.gd")
const Ratio := preload("res://core/ops/ratio.gd")
const Periodic := preload("res://core/combat/periodic_statuses.gd")

## True: an enemy move with this op needs Dudes to aim at, so its intent shows targets.
const NEEDS_TARGET: bool = true

## Hits per damage effect when the effect has no "hits" field. Not a tuning number: "one hit" is
## what a damage effect without repeats means.
const DEFAULT_HITS: int = 1

## Fields a damage effect may have, besides "op", and their types. Anything else is an error.
const FIELDS := {
	# Base damage of one hit, before Swole. 0 or more.
	"amount": TYPE_INT,
	# How many times the hit repeats. 1 or more. Optional.
	"hits": TYPE_INT,
}


## Returns the problems with a damage effect's fields; empty means it can run.
## effect: one entry of a card's or move's effects. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op damage" % [path, field])
	if typeof(effect.get("amount")) != TYPE_INT or effect["amount"] < 0:
		errors.append("%s.amount: must be an int, 0 or more" % path)
	if effect.has("hits") and (typeof(effect["hits"]) != TYPE_INT or effect["hits"] < 1):
		errors.append("%s.hits: must be an int, 1 or more" % path)
	return errors


## Runs a damage effect: for each hit in turn, every target still alive takes one hit (hit 1 lands
## on every target, then hit 2 ...). Stops as soon as the fight is decided. The attacker's Swole and
## statuses, and the target's, are read again before each hit.
## state: the working copy. effect: a damage effect that passed check().
## context: {"actor_id": who deals it, "targets": Array of ids it lands on, "constants":
##           ruleset.constants, "attack": true when this is attack damage (G3), false or missing
##           otherwise}. events: the event list, appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# hits: how many times to repeat the hit.
	var hits: int = effect.get("hits", DEFAULT_HITS)
	# actor_was_alive: task 013, true when the attacker was in the fight as the effect began; if it
	# dies part way (to thorns), the rest of its hits do not happen.
	var actor_was_alive: bool = not Bodies.find_alive(state, context["actor_id"]).is_empty()
	for hit: int in hits:
		for target_id: String in context["targets"]:
			if Bodies.is_decided(state):
				return
			# target: the body taking the hit, or {} if it is gone.
			var target: Dictionary = Bodies.find_alive(state, target_id)
			if target.is_empty():
				continue
			# attacker: the body dealing the hit, or {} if it is gone.
			var attacker: Dictionary = Bodies.find_alive(state, context["actor_id"])
			if actor_was_alive and attacker.is_empty():
				return
			# thorns: task 013, damage an enemy attacker takes back from a Dude with thorns, read
			# before the hit (core/ops/thorns.gd; G9 per hit). 0 when the attacker is not an enemy.
			# A Faded attacker takes at most FADED_MAX_DAMAGE of it, like any hit (task 017).
			var thorns: int = target.get("thorns", 0) if Statuses.is_enemy(attacker) else 0
			deal_in_place(state, context["actor_id"], target_id,
				hit_amount(context["constants"], attacker, target, effect["amount"], context.get("attack", false)), events)
			if thorns > 0:
				deal_in_place(state, target_id, context["actor_id"], Periodic.cap_hit(context["constants"], attacker, thorns), events)


## Damage order steps 1-4 and step 5's rounding: returns the damage of one hit before Guard.
## Reads only. See the file header for each step. Task 017: on a Faded target the result is then
## capped at FADED_MAX_DAMAGE, attack or not (core/combat/periodic_statuses.gd).
## constants: ruleset.constants; reads NOODLE_MULT, BROKEN_ARM_MAX_REDUCTION, EXPOSED_MULT.
## attacker: the Dude or enemy dealing the hit, or {} when it is gone (no Swole, no statuses).
## target: the Dude or enemy taking it. base: the effect's amount, 0 or more.
## attack: true for attack damage (G3); false skips steps 1-4 and returns base.
static func hit_amount(constants: Dictionary, attacker: Dictionary, target: Dictionary, base: int, attack: bool) -> int:
	if not attack:
		return Periodic.cap_hit(constants, target, maxi(0, base))
	# raw: step 1, base + Swole, never below 0.
	var raw: int = maxi(0, base + attacker.get("swole", 0))
	return Periodic.cap_hit(constants, target, Ratio.floor_times(raw, multiplier(constants, attacker, target)))


## Damage order steps 2-4 as one exact ratio (core/ops/ratio.gd): Noodle Arms, Broken Arm (enemy
## attackers only) and Exposed. Reads only.
## constants: ruleset.constants. attacker: the attacker's state, or {}. target: the target's state.
static func multiplier(constants: Dictionary, attacker: Dictionary, target: Dictionary) -> Array:
	# product: the ratio built up step by step.
	var product: Array = Ratio.ONE
	if not attacker.is_empty() and Statuses.stacks(attacker, "noodle_arms") > 0:
		product = Ratio.times(product, Ratio.from_constant(constants["NOODLE_MULT"]))
	if not attacker.is_empty() and Statuses.is_enemy(attacker) and attacker["arm_count"] > 0:
		product = Ratio.times(product, broken_arm_factor(constants, attacker["broken_arms"], attacker["arm_count"]))
	if Statuses.stacks(target, "exposed") > 0:
		product = Ratio.times(product, Ratio.from_constant(constants["EXPOSED_MULT"]))
	return product


## Returns 1 - BROKEN_ARM_MAX_REDUCTION x broken / arms as an exact ratio (GDD "Statuses", Broken Arm).
## constants: ruleset.constants; BROKEN_ARM_MAX_REDUCTION must be 0..1 (Statuses.check_constants).
## broken: arms broken, 0..arms. arms: the enemy's arm_count, 1 or more.
static func broken_arm_factor(constants: Dictionary, broken: int, arms: int) -> Array:
	# reduction: BROKEN_ARM_MAX_REDUCTION as a ratio [p, q]. The result, (q x arms - p x broken) /
	# (q x arms), is 1 - (p / q) x (broken / arms).
	var reduction: Array = Ratio.from_constant(constants[Statuses.BROKEN_ARM_CONSTANT])
	return Ratio.reduced(reduction[1] * arms - reduction[0] * broken, reduction[1] * arms)


## Damage order step 5 for one hit of final size amount: Guard absorbs and is used up, the rest
## comes off HP (never below 0), then a body at 0 HP dies or Passes Out. Emits damage_dealt (and
## enemy_died or dude_passed_out). Guard lost here gets no guard_changed event: damage_dealt.blocked
## says it. Does nothing if target_id names no living body.
## state: the working copy. source_id: who deals it ("" for no attacker). target_id: who takes it.
## amount: damage after steps 1-4, already rounded down, 0 or more. events: the event list, appended to.
static func deal_in_place(state: Dictionary, source_id: String, target_id: String, amount: int, events: Array) -> void:
	# body: the target, inside state.
	var body: Dictionary = Bodies.find_alive(state, target_id)
	if body.is_empty():
		return
	# blocked: damage Guard absorbs.
	var blocked: int = mini(body["guard"], amount)
	body["guard"] -= blocked
	# hp_lost: damage that reaches HP, capped at what HP is left.
	var hp_lost: int = mini(body["hp"], amount - blocked)
	body["hp"] -= hp_lost
	events.append(Event.make("damage_dealt", {"source_id": source_id, "target_id": target_id,
		"amount": amount, "blocked": blocked, "hp_lost": hp_lost}))
	if body["hp"] == 0:
		Bodies.knock_out_in_place(state, target_id, events)
