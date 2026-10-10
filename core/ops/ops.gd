## The effect operation registry (task 007). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Cards and enemy moves list effects; each effect is a Dictionary with an "op" name and that op's
## fields. This file maps op names to the script that checks and runs them. Adding an op: write
## core/ops/<op>.gd with NEEDS_TARGET, check(effect, path) and run(state, effect, context, events),
## add it to OPS, and document it in README.md. Content agents request new ops in a task (CLAUDE.md
## "Content is data").
##
## Task 013 adds, for every op:
##   - GENERIC_FIELDS any effect may carry: "if" (a condition, core/ops/conditions.gd) and "target"
##     (EFFECT_TARGETS: "all_enemies" makes this one effect land on every enemy in the fight, for
##     example Chest Bump's "Break 1 arm on every enemy" on a card that targets one enemy). check()
##     checks them and hands the op's own check() the effect without them.
##   - Power reactions: after each op runs, run() fires the active Power triggers that react to
##     what the op did (core/combat/powers.gd), so Reply Guy reacts to an enemy's Guard and Friend
##     Zone to a Grossed Out enemy wherever they happen. Trigger effects run through run() too.
##
## Pure: no file, clock, network or random access.
extends RefCounted

const DamageOp := preload("res://core/ops/damage.gd")
const GuardOp := preload("res://core/ops/guard.gd")
const ApplyStatusOp := preload("res://core/ops/apply_status.gd")
const DrawOp := preload("res://core/ops/draw.gd")
const GainHypeOp := preload("res://core/ops/gain_hype.gd")
const SelfDamageOp := preload("res://core/ops/self_damage.gd")
const GuardPerBrokenArmOp := preload("res://core/ops/guard_per_broken_arm.gd")
const ThornsOp := preload("res://core/ops/thorns.gd")
const Conditions := preload("res://core/ops/conditions.gd")
const Powers := preload("res://core/combat/powers.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const Event := preload("res://core/schema/event.gd")
# Task 015: Junk ops.
const AddCardOp := preload("res://core/ops/add_card.gd")
const LoseHypeOp := preload("res://core/ops/lose_hype.gd")

## Op name (the effect's "op" value) -> the script implementing it. Only the core lane changes this.
const OPS := {
	"apply_status": ApplyStatusOp,
	"damage": DamageOp,
	"draw": DrawOp,
	"gain_hype": GainHypeOp,
	"guard": GuardOp,
	"guard_per_broken_arm": GuardPerBrokenArmOp,
	"self_damage": SelfDamageOp,
	"thorns": ThornsOp,
	# Task 015.
	"add_card": AddCardOp,
	"lose_hype": LoseHypeOp,
}

## Task 013: fields any effect may carry, whatever its op, and their types. Both are optional.
const GENERIC_FIELDS := {
	# A condition from core/ops/conditions.gd CONDITIONS; the effect runs only when it holds.
	"if": TYPE_STRING,
	# One of EFFECT_TARGETS: who this effect lands on instead of the card's or move's targets.
	"target": TYPE_STRING,
}

## Task 013: values of an effect's "target". "all_enemies": every enemy still in the fight when the
## effect runs, left to right. Only the core lane adds one.
const EFFECT_TARGETS: Array[String] = ["all_enemies"]


## True when op names an operation the core can run.
## op: an effect's "op" value.
static func is_known(op: Variant) -> bool:
	return typeof(op) == TYPE_STRING and OPS.has(op)


## Returns the problems with one effect: an unknown op, a bad generic field, or bad fields for a
## known op. Empty means the effect can run. Content tests may call this to check data files.
## effect: one entry of a card's or enemy move's effects. path: label for messages.
static func check(effect: Variant, path: String = "effect") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	if typeof(effect) != TYPE_DICTIONARY:
		errors.append("%s: expected a Dictionary" % path)
		return errors
	if not is_known(effect.get("op")):
		errors.append("%s.op: %s is not an op the core has (see core/ops/README.md)" % [path, var_to_str(effect.get("op"))])
		return errors
	# bare: the effect without the generic fields, for the op's own check.
	var bare: Dictionary = effect.duplicate()
	for field: String in GENERIC_FIELDS:
		bare.erase(field)
	if effect.has("if") and (typeof(effect["if"]) != TYPE_STRING or not Conditions.CONDITIONS.has(effect["if"])):
		errors.append("%s.if: must be one of %s" % [path, ", ".join(PackedStringArray(Conditions.CONDITIONS))])
	if effect.has("target") and (typeof(effect["target"]) != TYPE_STRING or not EFFECT_TARGETS.has(effect["target"])):
		errors.append("%s.target: must be one of %s" % [path, ", ".join(PackedStringArray(EFFECT_TARGETS))])
	errors.append_array(OPS[effect["op"]].check(bare, path))
	return errors


## Returns the problems with a whole effects list, each labelled with its index.
## effects: a card's or move's effects list. path: label for messages.
static func check_all(effects: Array, path: String = "effects") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for i: int in effects.size():
		errors.append_array(check(effects[i], "%s[%d]" % [path, i]))
	return errors


## True when an enemy move with these effects aims at Dudes (any of its ops has NEEDS_TARGET).
## Unknown ops count as not needing a target.
## effects: an enemy move's effects list.
static func needs_target(effects: Array) -> bool:
	for effect: Variant in effects:
		if typeof(effect) == TYPE_DICTIONARY and is_known(effect.get("op")) and OPS[effect["op"]].NEEDS_TARGET:
			return true
	return false


## Runs one effect that passed check(): applies its "target" and "if" (task 013), runs the op, then
## fires the Power triggers that react to the op's events (task 013).
## state: the working copy, changed by the op. effect: the effect.
## context: {"actor_id": String, the player_id or enemy uid using the card or move;
##           "targets": Array of ids the effect lands on, chosen by the card's target or the intent;
##           "constants": ruleset.constants, read-only, for the ops' tuning numbers (task 009);
##           "attack": bool, true when damage effects here are attack damage (G3): a card of type
##                     "attack", a Bro Move, or an enemy move (task 009);
##           "from_card": bool, true when the effect comes from a card, for Hungover (task 009);
##           "ruleset": the read-only content, for Power triggers (task 013); without it no
##                      trigger fires;
##           "cards": ruleset.cards, read-only, card id -> definition, for add_card (task 015)}.
## make_context() builds one. events: the event list, appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# here: the context for this effect, with the effect's own target when it has one.
	var here: Dictionary = context
	if effect.get("target", "") == "all_enemies":
		here = context.duplicate()
		here["targets"] = Bodies.enemy_uids(state)
	if effect.has("if") and not Conditions.holds(state, effect["if"], here["targets"]):
		return
	# start: index of the first event this op emits.
	var start: int = events.size()
	OPS[effect["op"]].run(state, effect, here, events)
	# ruleset: the content, for the triggers.
	var ruleset: Dictionary = context.get("ruleset", {})
	if not ruleset.is_empty():
		fire_power_triggers_in_place(ruleset, state, Powers.reactions(ruleset, state, events, start), events)


## Task 013: fires Power triggers, in order (records from core/combat/powers.gd reactions() or
## matching()). For each: skipped if its Dude is Passed Out by now or it is a "subject" trigger whose
## enemy has died; otherwise power_triggered, then its effects in order, with the Dude as the actor,
## not attack damage, from a card. Effects that fail check() are skipped. Stops once the fight is decided.
## ruleset: the read-only content. state: the working copy. records: the triggers to fire.
## events: the event list, appended to.
static func fire_power_triggers_in_place(ruleset: Dictionary, state: Dictionary, records: Array, events: Array) -> void:
	for record: Dictionary in records:
		if Bodies.is_decided(state):
			return
		if Bodies.find_alive(state, record["player_id"]).is_empty():
			continue
		# targets: who its effects land on now.
		var targets: Array = Powers.targets_of(state, record)
		if record["target"] == "subject" and targets.is_empty():
			continue
		events.append(Event.make("power_triggered", {"player_id": record["player_id"], "card_uid": record["card_uid"],
			"when": record["when"], "subject_id": record["subject_id"]}))
		# context: the Power's Dude acting on the targets.
		var context: Dictionary = make_context(ruleset, record["player_id"], targets, false, true)
		for effect: Variant in record["effects"]:
			if Bodies.is_decided(state):
				return
			if check(effect).is_empty():
				run(state, effect, context, events)


## Returns the context run() needs (see run()).
## ruleset: the read-only content; its constants and (task 015) cards go in the context, and itself
## for Power triggers (task 013). An op context also works here (task 015 passes one where a ruleset
## is expected): its "ruleset" entry is used. actor_id: who uses the card or move. targets: ids the
## effects land on. attack: true for attack damage (G3). from_card: true when the effects come from a card.
static func make_context(ruleset: Dictionary, actor_id: String, targets: Array, attack: bool, from_card: bool) -> Dictionary:
	# content: the real ruleset, unwrapped when an op context was passed in its place.
	var content: Dictionary = ruleset.get("ruleset", ruleset)
	return {"actor_id": actor_id, "targets": targets, "constants": content["constants"],
		"attack": attack, "from_card": from_card, "ruleset": content, "cards": content.get("cards", {})}
