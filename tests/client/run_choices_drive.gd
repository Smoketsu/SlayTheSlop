## Plays a fixed-seed solo floor 1 run on the real data through the map and offer screens (task 020),
## for tests/client/test_map_screen.gd and test_offer_screen.gd. Lane: tools (Agent B).
##
## Not a test file (no test_ prefix). Decisions come from Agent A's run bot
## (tests/run/fixtures/run_bot.gd, preloaded read-only): it follows the map path that visits the most
## node types and answers each offer with a fixed policy; fights are played with its bot requests
## straight through Core.apply(). Every vote and every offer answer, though, is made by pressing the
## real screen (press_node, press_option, press_pick, press_skip) on a screen redrawn from the current
## state, and the request the screen emits, once player_id and seq are added as the run screen adds
## them, must be exactly the bot's request. So every node choice of the run goes through the screens.
extends RefCounted

const Bot := preload("res://tests/run/fixtures/run_bot.gd")
const Check := preload("res://tests/data/content_check.gd")
const NewRun := preload("res://core/run/new_run.gd")
const Core := preload("res://core/core.gd")
const MapScreen := preload("res://client/run/map_screen.gd")
const OfferScreen := preload("res://client/run/offer_screen.gd")

## The run's seed. On the real data as merged for task 020 (Godot 4.7.2-stable), seed 1's floor 1 map
## has a path through every node type, and the bot reaches every offer kind and beats the boss. If a
## data or rules change breaks that, pick another seed that does and say why in the PR.
const SEED: int = 1

## How many Dudes play: 1, the solo slice. Which Dude is read from the ruleset by dude_ids(), never
## named here.
const PARTY_SIZE: int = 1

## Most requests one run may take before the drive gives up (a guard against a stuck loop, not a rule).
const REQUEST_LIMIT: int = 20000


## Returns the solo party's Dude ids: the first PARTY_SIZE Dude ids of the ruleset, sorted.
## rules: the ruleset.
static func dude_ids(rules: Dictionary) -> Array:
	# ids: every Dude id, sorted.
	var ids: Array = rules["dudes"].keys()
	ids.sort()
	return ids.slice(0, PARTY_SIZE)


## Returns a new run on the real data at run_seed, or {} when the data or the run does not start.
## Result: {"rules": the real ruleset, "state": the new run's state}.
## run_seed: the seed.
static func start(run_seed: int = SEED) -> Dictionary:
	# rules: the real ruleset.
	var rules: Dictionary = Check.real_ruleset()
	if rules.is_empty():
		return {}
	# started: NewRun.start()'s result.
	var started: Dictionary = NewRun.start(rules, run_seed, dude_ids(rules))
	if started["error"] != "":
		return {}
	return {"rules": rules, "state": started["state"]}


## Plays the whole run through the screens. Returns {"rules", "start": the first state, "final": the
## last state, "map_states": every state a vote was made on, "offer_states": every state an offer was
## answered on (the player's first offer open), "requests": every request applied, "problems": what
## went wrong (a screen request that differs from the bot's, a reject), "plan": the bot's path}, or {}
## when the run cannot start.
## run_seed: the seed.
static func play(run_seed: int = SEED) -> Dictionary:
	# begun: the rules and the first state.
	var begun: Dictionary = start(run_seed)
	if begun.is_empty():
		return {}
	# rules: the real ruleset.
	var rules: Dictionary = begun["rules"]
	# state: the state as the run goes on.
	var state: Dictionary = begun["state"]
	# plan: the bot's path.
	var plan: Array = Bot.best_path(state["map"])
	# map_screen, offer_screen: the screens under test, never in the scene tree.
	var map_screen: Control = MapScreen.new()
	var offer_screen: Control = OfferScreen.new()
	# emitted: what the screens emitted since the last press.
	var emitted: Array = []
	map_screen.request_made.connect(func(request: Dictionary) -> void: emitted.append(request))
	offer_screen.request_made.connect(func(request: Dictionary) -> void: emitted.append(request))
	# result: what play() returns.
	var result: Dictionary = {"rules": rules, "start": state, "map_states": [], "offer_states": [],
		"requests": [], "problems": [], "plan": plan}
	for _step: int in REQUEST_LIMIT:
		# wanted: the bot's next request, or {} at the end of the run.
		var wanted: Dictionary = Bot.next_request(rules, state, plan)
		if wanted.is_empty():
			break
		# player_id: the sender.
		var player_id: String = wanted["player_id"]
		emitted.clear()
		match wanted["type"]:
			"vote_node":
				result["map_states"].append(state)
				map_screen.show_state(rules, state, player_id)
				map_screen.press_node(wanted["node_id"])
			"choose_reward":
				result["offer_states"].append(state)
				offer_screen.show_state(rules, state, player_id)
				press_like(offer_screen, wanted)
		# sent: the request applied: the screen's, completed as the run screen does, or the bot's fight move.
		var sent: Dictionary = wanted
		if wanted["type"] in ["vote_node", "choose_reward"]:
			if emitted.size() != 1:
				result["problems"].append("expected one request for %s, got %s" % [str(wanted), str(emitted)])
				break
			sent = completed(emitted[0], player_id, wanted["seq"])
			if sent != wanted:
				result["problems"].append("screen sent %s, the bot wanted %s" % [str(sent), str(wanted)])
				break
		# applied: Core.apply()'s result.
		var applied: Dictionary = Core.apply(rules, state, sent)
		if applied["reject"] != "":
			result["problems"].append("rejected %s: %s" % [applied["reject"], str(sent)])
			break
		result["requests"].append(sent)
		state = applied["state"]
	map_screen.free()
	offer_screen.free()
	result["final"] = state
	return result


## Presses the offer screen the way a player would to send the given choose_reward: Skip / Leave for
## -1, the option then the card for a Lift or removal, else the option.
## screen: an offer screen showing the request's offer. request: a choose_reward request.
static func press_like(screen: Control, request: Dictionary) -> void:
	if request["choice_index"] == -1:
		screen.press_skip()
	elif request.has("card_uid"):
		screen.press_option(request["choice_index"])
		screen.press_pick(request["card_uid"])
	else:
		screen.press_option(request["choice_index"])


## Returns a screen's request with player_id and seq added, as the run screen adds them.
## request: the emitted type and own fields. player_id: the sender. seq: the seq to send.
static func completed(request: Dictionary, player_id: String, seq: int) -> Dictionary:
	# out: a copy with the common fields.
	var out: Dictionary = request.duplicate()
	out["player_id"] = player_id
	out["seq"] = seq
	return out


## Returns the first state in a list whose local Dude's first open offer is of this kind, or {}.
## states: run states (play()'s "offer_states"). kind: an offer kind.
static func first_with_offer(states: Array, kind: String) -> Dictionary:
	for state: Dictionary in states:
		if state["dudes"][0]["offers"][0]["kind"] == kind:
			return state
	return {}
