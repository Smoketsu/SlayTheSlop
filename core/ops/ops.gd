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
## Task 031: trigger depth. Because trigger effects run through run(), a trigger can set off another
## trigger, and a Power that feeds itself (an "enemy_buffed" Power whose effects buff an enemy) would
## fire forever. The op context's "trigger_depth" (DEPTH_KEY) counts how deeply the current effects
## are nested inside Power triggers: 0 for a card, move, Brew, Gear or turn start's own effects,
## 1 inside a trigger they set off, 2 inside a trigger that one sets off, and so on. No trigger fires
## from effects already at depth MAX_TRIGGER_DEPTH (data/constants.json), so at most that many
## triggers nest in one chain. Reply Guy's Ick Grossing Out an enemy, which fires Friend Zone, is a
## legitimate chain of 2. The GDD is silent on this rule (gap G53).
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
# Task 021: ops for Gear and Brews.
const HealOp := preload("res://core/ops/heal.gd")
const GainStatOp := preload("res://core/ops/gain_stat.gd")
const RemoveDebuffsOp := preload("res://core/ops/remove_debuffs.gd")
const TapCardsOp := preload("res://core/ops/tap_cards.gd")
const PreventPassOutOp := preload("res://core/ops/prevent_pass_out.gd")
const SummonEnemyOp := preload("res://core/ops/summon_enemy.gd")
const StealDollaBillsOp := preload("res://core/ops/steal_dolla_bills.gd")
const FleeOp := preload("res://core/ops/flee.gd")
const GainSwoleOp := preload("res://core/ops/gain_swole.gd")
const ChargedHitOp := preload("res://core/ops/charged_hit.gd")

## Op name (the effect's "op" value) -> the script implementing it. Only the core lane changes this.
const OPS := {
	"apply_status": ApplyStatusOp,
	"damage": DamageOp,
	"draw": DrawOp,
	"gain_hype": GainHypeOp,
	"gain_stat": GainStatOp,
	"guard": GuardOp,
	"guard_per_broken_arm": GuardPerBrokenArmOp,
	"heal": HealOp,
	"prevent_pass_out": PreventPassOutOp,
	"remove_debuffs": RemoveDebuffsOp,
	"self_damage": SelfDamageOp,
	"tap_cards": TapCardsOp,
	"thorns": ThornsOp,
	# Task 017 (floor 1 enemies).
	"flee": FleeOp,
	"gain_swole": GainSwoleOp,
	"steal_dolla_bills": StealDollaBillsOp,
	"summon_enemy": SummonEnemyOp,
	# Task 015.
	"add_card": AddCardOp,
	"lose_hype": LoseHypeOp,
	# Task 019 (Goblin King Chad).
	"charged_hit": ChargedHitOp,
}

## Task 013: fields any effect may carry, whatever its op, and their types. Both are optional.
const GENERIC_FIELDS := {
	# A condition from core/ops/conditions.gd CONDITIONS; the effect runs only when it holds.
	"if": TYPE_STRING,
	# One of EFFECT_TARGETS: who this effect lands on instead of the card's or move's targets.
	"target": TYPE_STRING,
}

## Task 031: the op context key holding the trigger depth (see the file header), an int 0 or more.
## make_context() sets it; fire_power_triggers_in_place() raises it by 1 for a trigger's effects.
## Only the core lane changes this name.
const DEPTH_KEY: String = "trigger_depth"

## Task 031: ops that run further effects through run() themselves ("draw" runs each drawn card's
## on_draw effects, core/combat/card_triggers.gd) and whose own events never set off a Power
## trigger (draw's are deck_shuffled and card_moved). The nested run() calls already fired the
## triggers for the nested effects' events, so run() does not react to this op's events a second
## time. An op may be listed only if no event it emits itself is one core/combat/powers.gd reacts
## to. Only the core lane changes this.
const NESTING_OPS: Array[String] = ["draw"]

## Task 031: name of the constant holding the deepest trigger nesting allowed (data/constants.json
## MAX_TRIGGER_DEPTH, an int 1 or more). Only the core lane changes this name; the value is tuning.
const MAX_DEPTH_CONSTANT: String = "MAX_TRIGGER_DEPTH"

## Task 013: values of an effect's "target". "all_enemies": every enemy still in the fight when the
## effect runs, left to right. Only the core lane adds one.
const EFFECT_TARGETS: Array[String] = ["all_enemies"]


## Task 031: returns why the trigger-depth constant cannot be used, or "" when it can.
## Fight.check_start calls it, so a fight never starts with an unusable cap.
## constants: ruleset.constants.
static func check_constants(constants: Dictionary) -> String:
	if typeof(constants.get(MAX_DEPTH_CONSTANT)) != TYPE_INT or constants[MAX_DEPTH_CONSTANT] < 1:
		return "constant %s is missing or not an int 1 or more" % MAX_DEPTH_CONSTANT
	return ""


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
## fires the Power triggers that react to the op's events (task 013), at most MAX_TRIGGER_DEPTH deep
## and not again for an op in NESTING_OPS (task 031).
## state: the working copy, changed by the op. effect: the effect.
## context: {"actor_id": String, the player_id or enemy uid using the card or move;
##           "targets": Array of ids the effect lands on, chosen by the card's target or the intent;
##           "constants": ruleset.constants, read-only, for the ops' tuning numbers (task 009);
##           "attack": bool, true when damage effects here are attack damage (G3): a card of type
##                     "attack", a Bro Move, or an enemy move (task 009);
##           "from_card": bool, true when the effect comes from a card, for Hungover (task 009);
##           "ruleset": the whole read-only content, for Power triggers (task 013) and ops that
##                      read definitions (tap_cards, task 021; summon_enemy and gain_swole with a
##                      tag, task 017); without it no Power trigger fires;
##           "cards": ruleset.cards, read-only, card id -> definition, for add_card (task 015);
##           "trigger_depth": int, 0 or more, how deeply these effects are nested inside Power
##                            triggers (DEPTH_KEY, task 031); a context without it counts as 0}.
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
	# Task 031: a nesting op's events were already reacted to inside it (NESTING_OPS).
	if not ruleset.is_empty() and not NESTING_OPS.has(effect["op"]):
		fire_power_triggers_in_place(ruleset, state, Powers.reactions(ruleset, state, events, start), events,
			here.get(DEPTH_KEY, 0))


## Task 013: fires Power triggers, in order (records from core/combat/powers.gd reactions() or
## matching()). For each: skipped if its Dude is Passed Out by now or it is a "subject" trigger whose
## enemy has died; otherwise power_triggered, then its effects in order, with the Dude as the actor,
## not attack damage, from a card. Effects that fail check() are skipped. Stops once the fight is decided.
## Task 031: fires nothing when depth has reached MAX_TRIGGER_DEPTH, or when that constant is
## unusable (check_constants; a fight cannot start then). The triggers' effects run at depth + 1.
## ruleset: the read-only content. state: the working copy. records: the triggers to fire.
## events: the event list, appended to. depth: the trigger depth of the effects that set these
## triggers off (DEPTH_KEY), int 0 or more; 0 (the default) for a turn start or a test.
static func fire_power_triggers_in_place(ruleset: Dictionary, state: Dictionary, records: Array, events: Array,
		depth: int = 0) -> void:
	# constants: the tuning constants, for the depth cap.
	var constants: Dictionary = ruleset["constants"]
	if check_constants(constants) != "" or depth >= constants[MAX_DEPTH_CONSTANT]:
		return
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
		# Task 031: one level deeper than the effects that set this trigger off.
		context[DEPTH_KEY] = depth + 1
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
## Task 031: the new context's trigger_depth is the passed op context's, so effects run from inside
## an op (a draw's on_draw effects, core/combat/card_triggers.gd) stay in the same chain; it is 0
## when a ruleset is passed (a ruleset has no DEPTH_KEY entry).
static func make_context(ruleset: Dictionary, actor_id: String, targets: Array, attack: bool, from_card: bool) -> Dictionary:
	# content: the real ruleset, unwrapped when an op context was passed in its place.
	var content: Dictionary = ruleset.get("ruleset", ruleset)
	return {"actor_id": actor_id, "targets": targets, "constants": content["constants"],
		"attack": attack, "from_card": from_card, "ruleset": content, "cards": content.get("cards", {}),
		DEPTH_KEY: ruleset.get(DEPTH_KEY, 0)}
