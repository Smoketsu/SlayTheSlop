## Drinking a Brew: the use_brew request (task 021). Lane: core (Agent A).
## Format: core/schema/brew_def.gd. Ops: core/ops/README.md.
##
## GDD "Brews": "Drinking a Brew costs no Hype and can be done at any point in the player phase."
## Core.apply() has already checked the request's shape, player, seq, that the fight is in its
## player phase, and that the Dude is not Passed Out. check() then refuses, in order:
##   empty_slot  slot is not 0..brews.size() - 1: no Brew is held there. dude_state.brews is packed
##               (one entry per filled slot, in slot order), so every index past the last Brew,
##               and every index past brew_slots, is empty.
##   unplayable  the ruleset has no such Brew; or its effects are empty or use an op the core does
##               not have (so a Brew is never half drunk; Energy Drink waits on task 013's draw).
##   bad_target  target_id is not legal for the Brew's target (brew_def.gd TARGETS). "ally" is
##               always refused until Assist targeting exists (Smelling Salts' co-op use has no
##               effects, so it is unplayable before its target is checked).
## resolve_in_place() then, on the working copy:
##   1. removes the Brew from its slot (later Brews move down one slot) and adds 1 to brews_drunk;
##   2. emits brew_used;
##   3. runs the effects in order, stopping once the fight is decided. Effects are the Dude's own,
##      not attack damage (G3) and not from a card (G4), and the Dude's Gear reacts to them as to a
##      card's (Whole Can of Body Spray on Ick).
## Core.apply() then ends the fight if it is decided. No Hype is spent and cards_played_this_turn
## does not change.
##
## Solo variants: when party_size is 1 and the Brew has "solo", its solo target and effects are
## used instead (Smelling Salts).
##
## Pure: no file, clock, network or random access.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Ops := preload("res://core/ops/ops.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")

## party_size at which a Brew's "solo" variant is used.
const SOLO_PARTY_SIZE: int = 1


## Returns the reject reason for a use_brew request, or "" when it is legal (see the file header).
## Reads only.
## ruleset: the read-only content. state: the current run state. dude: the requesting Dude's state.
## request: a well-formed use_brew request.
static func check(ruleset: Dictionary, state: Dictionary, dude: Dictionary, request: Dictionary) -> String:
	if request["slot"] < 0 or request["slot"] >= dude["brews"].size():
		return "empty_slot"
	# definition: the Brew's definition, or {}.
	var definition: Dictionary = ruleset.get("brews", {}).get(dude["brews"][request["slot"]], {})
	if definition.is_empty():
		return "unplayable"
	# use: the target and effects that apply at this party size.
	var use: Dictionary = use_of(state, definition)
	if use["effects"].is_empty() or not Ops.check_all(use["effects"]).is_empty():
		return "unplayable"
	if not targets(state, dude, use["target"], request["target_id"])["ok"]:
		return "bad_target"
	return ""


## Returns {"target": String, "effects": Array}: the Brew's solo variant when party_size is
## SOLO_PARTY_SIZE and it has one, otherwise its own target and effects.
## state: the run state. definition: the Brew's definition.
static func use_of(state: Dictionary, definition: Dictionary) -> Dictionary:
	if state["party_size"] == SOLO_PARTY_SIZE and definition.has("solo"):
		return {"target": definition["solo"]["target"], "effects": definition["solo"]["effects"]}
	return {"target": definition["target"], "effects": definition["effects"]}


## Works out who a Brew's effects land on. Returns {"ok": bool, "targets": Array of ids}; ok is
## false when target_id is not legal (see brew_def.gd TARGETS).
## state: the run state. dude: the drinker. target: the Brew's target. target_id: from the request.
static func targets(state: Dictionary, dude: Dictionary, target: String, target_id: String) -> Dictionary:
	match target:
		"enemy":
			if Bodies.enemy_index(state, target_id) != -1:
				return {"ok": true, "targets": [target_id]}
		"all_enemies":
			if target_id == "":
				return {"ok": true, "targets": Bodies.enemy_uids(state)}
		"all_dudes":
			if target_id == "":
				return {"ok": true, "targets": Bodies.awake_dude_ids(state)}
		"self":
			if target_id == "" or target_id == dude["player_id"]:
				return {"ok": true, "targets": [dude["player_id"]]}
		"none":
			if target_id == "":
				return {"ok": true, "targets": []}
	return {"ok": false, "targets": []}


## Drinks a Brew that check() accepted (steps 1-3 in the file header).
## ruleset: the read-only content. state: the working copy, changed here.
## dude_index: the drinker's seat, 0-based. request: the use_brew request. events: appended to.
static func resolve_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, request: Dictionary, events: Array) -> void:
	# dude: the drinker, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# slot: the slot drunk from.
	var slot: int = request["slot"]
	# brew_id: the Brew in it.
	var brew_id: String = dude["brews"][slot]
	# use: the target and effects that apply at this party size.
	var use: Dictionary = use_of(state, ruleset["brews"][brew_id])
	# context: the drinker acts on the Brew's targets; not attack damage, not from a card.
	var context: Dictionary = Ops.make_context(ruleset, dude["player_id"],
		targets(state, dude, use["target"], request["target_id"])["targets"], false, false)
	dude["brews"].remove_at(slot)
	state["brews_drunk"] += 1
	events.append(Event.make("brew_used", {"player_id": dude["player_id"], "slot": slot, "brew_id": brew_id,
		"target_id": request["target_id"]}))
	GearTriggers.run_effects_in_place(ruleset, state, use["effects"], context, events)
