## Playing a card (GDD "How a card gets played in co-op", steps 2-3; task 007). Lane: core (Agent A).
##
## check() decides whether a play_card request is legal, reading the state only. resolve_in_place()
## then plays it on the working copy:
##   1. the card leaves the hand, its cost in Hype is spent, cards_played_this_turn rises by 1;
##   2. card_played, then hype_changed (when the cost is above 0);
##   3. each effect in order (core/ops/), stopping once the fight is decided;
##   4. the card goes to tapped_pile if it has the "tapped" keyword, otherwise to discard_pile (card_moved).
##      Task 013: a card of type "power" goes to the Dude's powers list instead (active for the fight).
##   5. Task 013: the solo Bro Meter may gain a point (core/combat/bro_meter.gd).
## Task 021 (core/combat/gear_triggers.gd): in step 3 the effects come from GearTriggers.card_effects (Championship
## Ring) and the player's Gear reacts after each one (Body Spray); after step 4, card_played Gear fires.
## Core.apply() then ends the fight if it is decided.
##
## Rules decided here (task 007's log lists them for the people to confirm):
##   - cost "x" is rejected as "unplayable": no op can use X yet (X cards are Cheney's, out of scope).
##   - A card with an op the core does not have, or with bad op fields, is "unplayable", so a card is
##     never half played. (apply_status exists since task 009, so Arm Bar and Well, Actually play.)
##   - Task 009 (G3): damage effects on a card of type "attack" are attack damage (Swole, Noodle
##     Arms, Exposed apply); on any other card type they are not.
##   - crunch true is "unplayable" (Nate only, not built). Task 025: an upgraded copy plays with its
##     upgraded definition (core/combat/upgrades.gd); one whose upgrade cannot apply is "unplayable".
##   - Targets: "enemy" needs the uid of an enemy still in the fight; "all_enemies" and "none" need
##     target_id ""; "self" takes "" or the player's own id. "ally" and "puppet" are "bad_target"
##     until Assist cards and Puppets are built.
##   - A Dude who is already ready may still play cards (the GDD does not forbid it).
##   - Task 015: while a card with play_limit_in_hand (Detention) is in the Dude's hand and they have
##     played that many cards this turn, every play is "unplayable" (core/combat/card_triggers.gd).
##
## Pure: no file, clock, network or random access.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const Ops := preload("res://core/ops/ops.gd")
const Bodies := preload("res://core/combat/bodies.gd")
const Powers := preload("res://core/combat/powers.gd")
const BroMeter := preload("res://core/combat/bro_meter.gd")
const CardTriggers := preload("res://core/combat/card_triggers.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")
const Upgrades := preload("res://core/combat/upgrades.gd")

## Card type (core/schema/card_def.gd TYPES) whose damage effects are attack damage (G3, task 009).
const ATTACK_TYPE: String = "attack"

## Task 013: the Dude state list a played Power goes to (core/schema/dude_state.gd "powers").
const POWERS_LIST: String = "powers"


## Returns the reject reason for a play_card request, or "" when it is legal. Checks, in order:
## not_in_hand, unplayable, no_hype, bad_target. Reads only; the caller has already checked the
## request's shape, player, seq, phase and that the Dude is not Passed Out.
## ruleset: the read-only content. state: the current run state. dude: the requesting Dude's state.
## request: a well-formed play_card request.
static func check(ruleset: Dictionary, state: Dictionary, dude: Dictionary, request: Dictionary) -> String:
	if not dude["hand"].has(request["card_uid"]):
		return "not_in_hand"
	# card: the card's definition, or {} when the ruleset lacks it.
	var card: Dictionary = card_def(ruleset, dude, request["card_uid"])
	if card.is_empty() or request["crunch"]:
		return "unplayable"
	# Task 015: Detention's limit while it is in hand.
	if CardTriggers.play_limit_reached(ruleset, dude):
		return "unplayable"
	if typeof(card["cost"]) != TYPE_INT or card["cost"] < 0:
		return "unplayable"
	if not Ops.check_all(card["effects"]).is_empty():
		return "unplayable"
	# Task 013: a Power whose trigger effects the core cannot run is not played either.
	for trigger: Dictionary in card.get("power_triggers", []):
		if not Ops.check_all(trigger["effects"]).is_empty():
			return "unplayable"
	if card["cost"] > dude["hype"]:
		return "no_hype"
	if not targets(state, dude, card, request["target_id"])["ok"]:
		return "bad_target"
	return ""


## Returns the definition of a card copy the Dude owns, or {} when the ruleset does not have it.
## Task 025: an upgraded copy's upgraded definition, or {} when its upgrade cannot apply.
## ruleset: the read-only content. dude: the owner's Dude state. card_uid: a key of dude.cards.
static func card_def(ruleset: Dictionary, dude: Dictionary, card_uid: String) -> Dictionary:
	return Upgrades.definition_of(ruleset, dude, card_uid)


## Works out who a card's effects land on. Returns {"ok": bool, "targets": Array of ids}; ok is
## false when target_id is not legal for the card (see the file header).
## state: the run state. dude: the player's Dude. card: the card definition. target_id: from the request.
static func targets(state: Dictionary, dude: Dictionary, card: Dictionary, target_id: String) -> Dictionary:
	match card["target"]:
		"enemy":
			if Bodies.enemy_index(state, target_id) != -1:
				return {"ok": true, "targets": [target_id]}
		"all_enemies":
			if target_id == "":
				return {"ok": true, "targets": Bodies.enemy_uids(state)}
		"self":
			if target_id == "" or target_id == dude["player_id"]:
				return {"ok": true, "targets": [dude["player_id"]]}
		"none":
			if target_id == "":
				return {"ok": true, "targets": []}
	return {"ok": false, "targets": []}


## Plays a card that check() accepted (steps 1-4 in the file header).
## ruleset: the read-only content. state: the working copy, changed here.
## dude_index: the player's seat, 0-based. request: the play_card request. events: appended to.
static func resolve_in_place(ruleset: Dictionary, state: Dictionary, dude_index: int, request: Dictionary, events: Array) -> void:
	# dude: the player's Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# uid: the card copy being played.
	var uid: String = request["card_uid"]
	# card: its definition.
	var card: Dictionary = card_def(ruleset, dude, uid)
	# cost: Hype spent, 0 or more.
	var cost: int = card["cost"]
	# context: who plays it and who its effects land on, for the ops.
	# Task 009: a card's damage is attack damage (G3) only when the card is an Attack; every card's
	# effects are "from cards" for Hungover (G4).
	var context: Dictionary = Ops.make_context(ruleset, dude["player_id"],
		targets(state, dude, card, request["target_id"])["targets"], card["type"] == ATTACK_TYPE, true)
	# Task 037: these are a played card's effects, so its self_damage fires "self_damaged" Powers.
	context[Ops.PLAYED_CARD_KEY] = true
	dude["hand"].erase(uid)
	dude["hype"] -= cost
	dude["cards_played_this_turn"] += 1
	events.append(Event.make("card_played", {"player_id": dude["player_id"], "card_uid": uid,
		"target_id": request["target_id"]}))
	if cost != 0:
		events.append(Event.make("hype_changed", {"player_id": dude["player_id"], "delta": -cost, "hype": dude["hype"]}))
	# Task 021: Gear card_damage modifiers (Championship Ring) raise the card's damage effects.
	for effect: Dictionary in GearTriggers.card_effects(ruleset, dude, card):
		if Bodies.is_decided(state):
			break
		# first: task 021, where this effect's events start, so the player's Gear can react to them.
		var first: int = events.size()
		Ops.run(state, effect, context, events)
		GearTriggers.after_effect_in_place(ruleset, state, dude["player_id"], events, first)
	# pile: where the card goes once played. Task 013: a Power goes to the Dude's powers list and
	# stays active for the fight (core/combat/powers.gd).
	var pile: String = "tapped_pile" if card["keywords"].has("tapped") else "discard_pile"
	if Powers.is_power(card):
		pile = POWERS_LIST
	dude[pile].append(uid)
	events.append(Event.make("card_moved", {"player_id": dude["player_id"], "card_uid": uid, "from": "hand", "to": pile}))
	# Task 021: the player's Gear that fires after a card is played.
	GearTriggers.card_played_in_place(ruleset, state, dude_index, card, context["targets"], events)
	# Task 013: the solo Bro Meter counts cards played this turn (core/combat/bro_meter.gd).
	BroMeter.after_card_played_in_place(ruleset, state, dude, events)
