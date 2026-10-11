## Tests for picking a Dude with an "ally" card (Assist, Bro Hug) on the fight screen (task
## ally-pick). Lane: tools/client (Agent B).
##
## The core accepts any Dude who is not Passed Out, the player's own included (G62, Agent A's #96).
## The screen sends an ally card straight to the local player's own Dude when only one Dude can be
## targeted (solo), and asks "Pick a Dude." when several can (co-op shape), sending the clicked Dude's
## player_id. Every fight here runs on the real core and the real data, plus one in-memory test card
## shaped like Bro Hug (tom_bro_hug may not be in data/ yet). The screen's state is frozen read-only
## before every press, so any client write to game state fails the test.
extends "res://tests/framework/test_case.gd"

const FightScreen := preload("res://client/fight/fight_screen.tscn")
const Targeting := preload("res://client/fight/targeting.gd")
const Messages := preload("res://client/fight/messages.gd")
const Core := preload("res://core/core.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")
const Party := preload("res://core/combat/party.gd")
const Fight := preload("res://core/combat/fight.gd")
const RunState := preload("res://core/schema/run_state.gd")

## Run seed of every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 20261011
## Enemies of every fight in this file, left to right (ids from data/enemies/).
const FOES: Array[String] = ["goblin_pledge", "goblin_bouncer"]
## Id of the in-memory test card. Not a real content id; never saved or shipped.
const HUG_ID: String = "neutral_test_bro_hug"
## Guard the test card gives its target (Bro Hug's amount in the accepted proposal).
const HUG_GUARD: int = 7
## The test card, shaped like Bro Hug (target "ally", one guard effect), as a card_def.gd definition.
const HUG_CARD := {
	"id": HUG_ID, "name": "Bro Hug", "owner": "neutral", "type": "skill", "rarity": "common",
	"cost": 1, "target": "ally", "effects": [{"op": "guard", "amount": HUG_GUARD}],
	"keywords": ["assist"], "crunch": null, "upgrade": {}, "text": "Target Dude gains 7 Guard",
}


## A gateway that records every request and passes it to the real core; it can refuse the next
## request with a fixed reject first, to test what the screen does with that reject.
class RecordingGateway extends RefCounted:
	## Every request the screen sent, oldest first (copies). Only grows.
	var requests: Array = []
	## A reject code returned for the next request instead of applying it, then cleared; "" for none.
	## Set by the test.
	var reject_next: String = ""

	## Records the request, then refuses it with reject_next or applies it with the real core.
	## ruleset: read-only content. state: the current state. request: the request sent.
	func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
		requests.append(request.duplicate(true))
		if reject_next != "":
			# code: the reject to return this once.
			var code: String = reject_next
			reject_next = ""
			return {"state": state, "events": [], "reject": code}
		return Core.apply(ruleset, state, request)


## Solo: the ally card asks nothing, goes to the player's own Dude, is accepted by the core, and that
## Dude's Guard rises by the card's amount.
func test_solo_ally_card_targets_yourself() -> void:
	# rules: the real ruleset plus the test card. state: a solo fight with the card in p1's hand.
	var rules: Dictionary = _rules()
	var state: Dictionary = _fight(rules, 1)
	# uid: the test card's copy.
	var uid: String = _give_hug(state)
	# me: the local player. guard_before: their Guard before the play.
	var me: String = state["dudes"][0]["player_id"]
	var guard_before: int = state["dudes"][0]["guard"]
	assert_eq(state["dudes"][0]["chill"], 0, "no Chill, so the Guard gained is the card's amount")
	# gateway: records what the screen sends. screen: the fight screen on it.
	var gateway := RecordingGateway.new()
	var screen: Control = _screen(gateway, rules, state, me)
	assert_eq(Targeting.mode_in_state(HUG_CARD, screen._state), Targeting.NONE, "one pickable Dude: nothing to pick")
	_freeze(screen._state)
	screen.press_card(uid)
	assert_eq(gateway.requests.size(), 1, "sent at once, without asking")
	assert_eq(gateway.requests[0]["target_id"], me, "target_id is the local player")
	assert_eq(screen._state["state_version"], 1, "the core accepted it")
	assert_eq(screen._state["dudes"][0]["guard"], guard_before + HUG_GUARD, "Guard rose by the card's amount")
	assert_false(screen._state["dudes"][0]["hand"].has(uid), "the card left the hand")
	assert_no_errors(RunState.check(screen._state), "state after the play")
	_free(screen)


## Co-op shape (2 Dudes): the ally card asks for a Dude; enemy clicks are ignored; clicking the other
## Dude's view sends target_id = that player_id, and only that Dude gains the Guard.
func test_coop_ally_card_asks_and_sends_the_clicked_dude() -> void:
	# rules: the real ruleset plus the test card. state: a 2-Dude fight, the card in p1's hand.
	var rules: Dictionary = _rules()
	var state: Dictionary = _fight(rules, 2)
	var uid: String = _give_hug(state)
	# me, mate: the local player and the teammate.
	var me: String = state["dudes"][0]["player_id"]
	var mate: String = state["dudes"][1]["player_id"]
	# guards: each Dude's Guard before the play, by seat.
	var guards: Array = [state["dudes"][0]["guard"], state["dudes"][1]["guard"]]
	# gateway, screen: as in the solo test.
	var gateway := RecordingGateway.new()
	var screen: Control = _screen(gateway, rules, state, me)
	assert_eq(Targeting.pickable_dudes(screen._state), [me, mate], "both Dudes pickable, in seat order")
	_freeze(screen._state)
	screen.press_card(uid)
	assert_eq(screen.message, "Pick a Dude.", "asks for a Dude")
	assert_eq(gateway.requests.size(), 0, "nothing sent before a Dude is picked")
	screen.press_enemy(screen._state["combat"]["enemies"][0]["uid"])
	assert_eq(gateway.requests.size(), 0, "an enemy click does not send an ally card")
	assert_eq(screen._pending_card, uid, "the card still waits for a Dude")
	screen._views[mate].pressed.emit()
	assert_eq(gateway.requests.size(), 1, "clicking the teammate's view sent the card")
	assert_eq(gateway.requests[0]["target_id"], mate, "target_id is the clicked Dude")
	assert_eq(screen._state["state_version"], 1, "the core accepted it")
	assert_eq(screen._state["dudes"][1]["guard"], guards[1] + HUG_GUARD + screen._state["dudes"][0]["chill"],
		"the teammate gained the Guard (plus the giver's Chill, G62)")
	assert_eq(screen._state["dudes"][0]["guard"], guards[0], "the player who hugs gains nothing")
	assert_eq(screen._pending_card, "", "nothing waits any more")
	_free(screen)


## Co-op shape: a Dude may pick their own Dude too (G62).
func test_coop_ally_card_can_pick_yourself() -> void:
	# rules, state, uid: a 2-Dude fight with the card in p1's hand.
	var rules: Dictionary = _rules()
	var state: Dictionary = _fight(rules, 2)
	var uid: String = _give_hug(state)
	# me: the local player.
	var me: String = state["dudes"][0]["player_id"]
	var gateway := RecordingGateway.new()
	var screen: Control = _screen(gateway, rules, state, me)
	_freeze(screen._state)
	screen.press_card(uid)
	screen.press_dude(me)
	assert_eq(gateway.requests.size(), 1)
	assert_eq(gateway.requests[0]["target_id"], me)
	assert_eq(screen._state["state_version"], 1, "the core accepted it")
	_free(screen)


## A Passed Out Dude cannot be picked: their view is disabled and clicking it sends nothing; a Dude
## who is up can still be picked afterwards. With every teammate Passed Out, only the player's own Dude
## is left, so the card goes there without asking.
func test_passed_out_dude_is_not_pickable() -> void:
	# rules: the real ruleset plus the test card. state: 3 Dudes, the last one Passed Out (test setup on
	# a fresh state, before the screen gets it).
	var rules: Dictionary = _rules()
	var state: Dictionary = _fight(rules, 3)
	state["dudes"][2]["passed_out"] = true
	state["dudes"][2]["hp"] = 0
	var uid: String = _give_hug(state)
	# me, up, down: the local player, the teammate who is up, the one Passed Out.
	var me: String = state["dudes"][0]["player_id"]
	var up: String = state["dudes"][1]["player_id"]
	var down: String = state["dudes"][2]["player_id"]
	var gateway := RecordingGateway.new()
	var screen: Control = _screen(gateway, rules, state, me)
	assert_eq(Targeting.pickable_dudes(screen._state), [me, up], "the Passed Out Dude is left out")
	_freeze(screen._state)
	screen.press_card(uid)
	assert_eq(screen.message, "Pick a Dude.")
	assert_true(screen._views[down].disabled, "the Passed Out Dude's view is disabled")
	screen._views[down].pressed.emit()
	screen.press_dude(down)
	assert_eq(gateway.requests.size(), 0, "clicking a Passed Out Dude sends nothing")
	assert_eq(screen._pending_card, uid, "the card still waits for a Dude")
	screen._views[up].pressed.emit()
	assert_eq(gateway.requests.size(), 1, "a Dude who is up can still be picked")
	assert_eq(gateway.requests[0]["target_id"], up)
	_free(screen)
	# alone: 2 Dudes, the teammate Passed Out: the card goes to the player's own Dude at once.
	var alone: Dictionary = _fight(rules, 2)
	alone["dudes"][1]["passed_out"] = true
	alone["dudes"][1]["hp"] = 0
	var alone_uid: String = _give_hug(alone)
	var alone_gateway := RecordingGateway.new()
	screen = _screen(alone_gateway, rules, alone, me)
	_freeze(screen._state)
	screen.press_card(alone_uid)
	assert_eq(alone_gateway.requests.size(), 1, "one pickable Dude: sent without asking")
	assert_eq(alone_gateway.requests[0]["target_id"], me)
	assert_eq(screen._state["state_version"], 1, "the core accepted it")
	_free(screen)


## A bad_target reject on an ally card (for example the picked Dude Passed Out meanwhile in co-op)
## re-arms the pick, as enemy targeting does; the next Dude click sends it again.
func test_bad_target_rearms_the_dude_pick() -> void:
	# rules, state, uid: a 2-Dude fight with the card in p1's hand.
	var rules: Dictionary = _rules()
	var state: Dictionary = _fight(rules, 2)
	var uid: String = _give_hug(state)
	var me: String = state["dudes"][0]["player_id"]
	var mate: String = state["dudes"][1]["player_id"]
	# gateway: refuses the first request with bad_target.
	var gateway := RecordingGateway.new()
	gateway.reject_next = "bad_target"
	var screen: Control = _screen(gateway, rules, state, me)
	_freeze(screen._state)
	screen.press_card(uid)
	screen.press_dude(mate)
	assert_eq(screen.message, Messages.reject("bad_target"), "the reject is shown")
	assert_eq(screen._pending_card, uid, "bad_target asks for a new Dude")
	assert_eq(screen._pending_pick, Targeting.DUDE, "still a Dude pick, not an enemy one")
	screen.press_dude(mate)
	assert_eq(gateway.requests.size(), 2, "sent again")
	assert_eq(gateway.requests[1]["seq"], gateway.requests[0]["seq"] + 1, "with the next seq")
	assert_eq(screen._state["state_version"], 1, "the core accepted the second one")
	_free(screen)


## Enemy targeting is unchanged in co-op shape: an enemy card waits for an enemy and ignores Dude
## clicks.
func test_enemy_card_ignores_dude_clicks() -> void:
	# rules, state: a 2-Dude fight.
	var rules: Dictionary = _rules()
	var state: Dictionary = _fight(rules, 2)
	var me: String = state["dudes"][0]["player_id"]
	var gateway := RecordingGateway.new()
	var screen: Control = _screen(gateway, rules, state, me)
	# uid: the first card in p1's hand that targets an enemy.
	var uid: String = ""
	for hand_uid: String in screen._state["dudes"][0]["hand"]:
		if uid == "" and rules["cards"][screen._state["dudes"][0]["cards"][hand_uid]["def_id"]]["target"] == "enemy":
			uid = hand_uid
	assert_ne(uid, "", "an enemy card in hand")
	_freeze(screen._state)
	screen.press_card(uid)
	assert_eq(screen.message, "Pick an enemy.")
	screen.press_dude(state["dudes"][1]["player_id"])
	assert_eq(gateway.requests.size(), 0, "a Dude click does not send an enemy card")
	screen.press_enemy(screen._state["combat"]["enemies"][0]["uid"])
	assert_eq(gateway.requests.size(), 1, "an enemy click does")
	assert_eq(screen._state["state_version"], 1, "the core accepted it")
	_free(screen)


## Returns the real ruleset built from data/ plus HUG_CARD (as if it were a file in data/cards/).
func _rules() -> Dictionary:
	# files: every data file's text, plus the test card's.
	var files: Dictionary = DataFiles.read_all()
	files["data/cards/%s.json" % HUG_ID] = JSON.stringify(HUG_CARD)
	# built: the ruleset build result.
	var built: Dictionary = Ruleset.build(files)
	assert_true(built["ok"], "the test ruleset builds: %s" % "; ".join(built["errors"]))
	return built["ruleset"]


## Returns a fresh fight on the real core's builders, in turn 1's player phase against FOES, with
## party_size Dudes, all the first Dude in the data by id (so no Dude is named here).
## rules: the ruleset. party_size: how many Dudes, 1 to 4.
func _fight(rules: Dictionary, party_size: int) -> Dictionary:
	# dude_ids: the Dude definitions in the data, sorted. seats: one per player.
	var dude_ids: Array = rules["dudes"].keys()
	dude_ids.sort()
	var seats: Array = []
	for seat: int in party_size:
		seats.append(dude_ids[0])
	# party: the run state.
	var party: Dictionary = Party.build_run_state(rules, SEED, seats)
	assert_eq(party["error"], "", "build_run_state")
	# started: the fight.
	var started: Dictionary = Fight.start_fight(rules, party["state"], FOES)
	assert_eq(started["error"], "", "start_fight")
	assert_eq(started["state"]["party_size"], party_size)
	return started["state"]


## Puts a new copy of HUG_CARD in the first Dude's hand (test setup on a fresh state, before any
## screen gets it) and returns its card_uid.
## state: a fight from _fight().
func _give_hug(state: Dictionary) -> String:
	# uid: the new copy's card_uid, from the state's uid counter.
	var uid: String = "c%d" % state["next_uid"]
	state["next_uid"] += 1
	state["dudes"][0]["cards"][uid] = {"def_id": HUG_ID, "upgraded": false}
	state["dudes"][0]["hand"].append(uid)
	state["dudes"][0]["deck"].append(uid)
	return uid


## Returns a fight screen in the tree with no animation time.
## gateway: what requests go to. rules: the ruleset. state: the fight. player_id: the local player.
func _screen(gateway: Object, rules: Dictionary, state: Dictionary, player_id: String) -> Control:
	# screen: the new screen.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.setup(gateway, rules, state, player_id)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


## Removes a screen from the tree and frees it now.
## screen: a screen from _screen().
func _free(screen: Control) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()


## Makes value read-only at every level (make_read_only() alone is shallow).
## value: a Dictionary or Array from a state.
func _freeze(value: Variant) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key: Variant in value:
			_freeze(value[key])
		value.make_read_only()
	elif typeof(value) == TYPE_ARRAY:
		for item: Variant in value:
			_freeze(item)
		value.make_read_only()
