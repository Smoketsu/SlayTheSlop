## What a bot may send right now: the legal requests of one player, found the way a client finds
## them (task 022). Lane: tools (Agent B).
##
## A bot sees what a player sees: its own hand, Brew slots and Bro Move, the enemies in the fight and
## the Dudes at the table, and the target each card, Brew or Bro Move asks for (its definition, the
## card text). It builds every request that could be sent with those, then keeps the ones
## Core.validate() accepts. It never reads the draw pile, the random streams (run_state.rng) or an
## enemy's future, and it never changes a state: only Core.apply() does, in the simulation.
##
## Order of the list (the "canonical order" bots break ties with):
##   1. play_card: each card in hand order; for each, its targets (enemies left to right for target
##      "enemy", Dudes in seat order for "ally", "" for anything else).
##   2. use_brew: each Brew slot from 0, targets as above.
##   3. use_bro_move: targets as above.
##   4. set_ready true, last. set_ready false is never offered: a bot that has pressed Ready waits for
##      the others, so un-readying would only be a wasted request.
extends RefCounted

const Core := preload("res://core/core.gd")
const Upgrades := preload("res://core/combat/upgrades.gd")
const Brews := preload("res://core/combat/brews.gd")
const BroMove := preload("res://core/combat/bro_move.gd")

## Target kind (card_def.gd / brew_def.gd "target") that names one enemy. Fixed by the schema.
const TARGET_ENEMY: String = "enemy"

## Target kind that names one Dude, the player's own included (Assist). Fixed by the schema.
const TARGET_ALLY: String = "ally"

## Request types a bot may send, as core/schema/request.gd names them. Fixed by the schema.
const PLAY_CARD: String = "play_card"
## Drinks a Brew.
const USE_BREW: String = "use_brew"
## Plays the Dude's Bro Move.
const USE_BRO_MOVE: String = "use_bro_move"
## Presses (or releases) Ready.
const SET_READY: String = "set_ready"


## Returns a request Dictionary with the common fields filled in (core/schema/request.gd COMMON).
## type: the request type. player_id: the sender, "p1".."p4". seq: its seq, above the Dude's
## last_seq. fields: the type's own fields; copied, not changed.
static func request(type: String, player_id: String, seq: int, fields: Dictionary = {}) -> Dictionary:
	# out: the request.
	var out: Dictionary = fields.duplicate()
	out["type"] = type
	out["player_id"] = player_id
	out["seq"] = seq
	return out


## Returns the next seq a player sends: one above their Dude's last_seq.
## state: the run state. player_index: the Dude's seat, 0-based.
static func next_seq(state: Dictionary, player_index: int) -> int:
	return state["dudes"][player_index]["last_seq"] + 1


## Returns the target ids a player could pick for a target kind, in canonical order.
## state: the run state, in a fight. target_kind: a card or Brew "target" value, or "" when unknown.
static func target_ids(state: Dictionary, target_kind: String) -> Array:
	# ids: the result.
	var ids: Array = []
	match target_kind:
		TARGET_ENEMY:
			for enemy: Dictionary in state["combat"]["enemies"]:
				ids.append(enemy["uid"])
		TARGET_ALLY:
			for dude: Dictionary in state["dudes"]:
				ids.append(dude["player_id"])
		_:
			ids.append("")
	return ids


## Returns every request the player could send now that Core.validate() accepts, in canonical order
## (file header), without set_ready. Empty outside the player phase or when the player can do nothing
## but Ready.
## rules: the read-only ruleset. state: the run state. player_index: the Dude's seat, 0-based.
## seq: the seq the requests carry.
static func legal_plays(rules: Dictionary, state: Dictionary, player_index: int, seq: int) -> Array:
	# plays: the accepted requests.
	var plays: Array = []
	if state["combat"] == null or state["combat"]["phase"] != "player":
		return plays
	# dude: the player's Dude.
	var dude: Dictionary = state["dudes"][player_index]
	# player_id: its id.
	var player_id: String = dude["player_id"]
	# candidates: every request built, before validate().
	var candidates: Array = []
	for uid: String in dude["hand"]:
		# card: the copy's definition (upgraded when Lifted), or {}.
		var card: Dictionary = Upgrades.definition_of(rules, dude, uid)
		for target: String in target_ids(state, card.get("target", "")):
			candidates.append(request(PLAY_CARD, player_id, seq, {"card_uid": uid, "target_id": target, "crunch": false}))
	for slot: int in dude["brews"].size():
		# brew: the Brew's definition, or {}.
		var brew: Dictionary = rules.get("brews", {}).get(dude["brews"][slot], {})
		# brew_target: the target the Brew asks for at this party size, or "".
		var brew_target: String = "" if brew.is_empty() else Brews.use_of(state, brew)["target"]
		for target: String in target_ids(state, brew_target):
			candidates.append(request(USE_BREW, player_id, seq, {"slot": slot, "target_id": target}))
	# bro_card: the Bro Move's card definition, or {}.
	var bro_card: Dictionary = BroMove.card_def(rules, dude)
	for target: String in target_ids(state, bro_card.get("target", "")):
		candidates.append(request(USE_BRO_MOVE, player_id, seq, {"target_id": target}))
	for candidate: Dictionary in candidates:
		if Core.validate(rules, state, candidate) == "":
			plays.append(candidate)
	return plays


## Returns the set_ready request that ends the player's turn, or {} when the core would refuse it.
## rules: the read-only ruleset. state: the run state. player_index: the Dude's seat, 0-based.
## seq: the seq it carries.
static func ready_request(rules: Dictionary, state: Dictionary, player_index: int, seq: int) -> Dictionary:
	# ready: the request.
	var ready: Dictionary = request(SET_READY, state["dudes"][player_index]["player_id"], seq, {"ready": true})
	return ready if Core.validate(rules, state, ready) == "" else {}


## Returns every legal request in canonical order: legal_plays() then the set_ready, when legal.
## rules: the read-only ruleset. state: the run state. player_index: the Dude's seat, 0-based.
## seq: the seq the requests carry.
static func legal_requests(rules: Dictionary, state: Dictionary, player_index: int, seq: int) -> Array:
	# all: the plays, then Ready.
	var all: Array = legal_plays(rules, state, player_index, seq)
	# ready: the set_ready request, or {}.
	var ready: Dictionary = ready_request(rules, state, player_index, seq)
	if not ready.is_empty():
		all.append(ready)
	return all


## Returns the seed of a bot's own random generator: a hash of the seed under test and the bot's
## player_id, so each seat of each seed has its own fixed sequence. Never the run's streams.
## run_seed: the seed under test, any 64-bit int. player_id: the bot's seat, "p1".."p4".
static func bot_seed(run_seed: int, player_id: String) -> int:
	return ("%d:%s" % [run_seed, player_id]).hash()
