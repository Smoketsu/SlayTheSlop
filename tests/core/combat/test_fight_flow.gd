## Tests for starting a fight and the turn flow (core/combat/fight.gd, piles.gd, play.gd,
## party.gd; task 007). Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Fight := preload("res://core/combat/fight.gd")
const Party := preload("res://core/combat/party.gd")
const Piles := preload("res://core/combat/piles.gd")
const Rng := preload("res://core/rng/rng.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 4242


## Applies a request, asserting it is accepted, raises state_version by 1, and that every event
## and the new state are valid. Returns apply()'s result.
## rules: the ruleset. state: the state. request: the request.
func _ok(rules: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], "", "request %s should apply" % var_to_str(request))
	assert_eq(result["state"]["state_version"], state["state_version"] + 1, "state_version rises by exactly 1")
	_assert_valid(result["state"], result["events"])
	return result


## Asserts that every event passes event.gd check() and the state passes run_state.check().
## state: a run state. events: an event list.
func _assert_valid(state: Dictionary, events: Array) -> void:
	for event: Variant in events:
		assert_no_errors(Event.check(event), "event %s" % var_to_str(event))
	assert_no_errors(RunState.check(state), "state")


## Returns the "type" of each event, in order.
## events: an event list.
func _types(events: Array) -> Array:
	# types: the result.
	var types: Array = []
	for event: Dictionary in events:
		types.append(event["type"])
	return types


## Returns the events of one type, in order.
## events: an event list. type: the event type wanted.
func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event["type"] == type)


## build_run_state makes Dudes from their definitions and the constants.
func test_build_run_state() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# built: the result for two Dudes.
	var built: Dictionary = Party.build_run_state(rules, SEED, ["test_dude", "test_tiny"])
	assert_eq(built["error"], "")
	# state: the run.
	var state: Dictionary = built["state"]
	assert_no_errors(RunState.check(state), "built run")
	assert_eq(state["party_size"], 2)
	assert_eq(state["combat"], null)
	assert_eq(state["next_uid"], 14, "10 + 3 card uids used")
	# p1: the first Dude.
	var p1: Dictionary = state["dudes"][0]
	# p2: the second Dude.
	var p2: Dictionary = state["dudes"][1]
	assert_eq([p1["player_id"], p2["player_id"]], ["p1", "p2"])
	assert_eq([p1["hp"], p1["max_hp"], p2["hp"], p2["max_hp"]], [30, 30, 10, 10])
	assert_eq(p1["hype_per_turn"], rules["constants"]["BASE_HYPE"])
	assert_eq(p1["draw_per_turn"], rules["constants"]["BASE_DRAW"])
	assert_eq(p1["brew_slots"], 0, "BASE_BREW_SLOTS is not a constant yet (G22)")
	assert_eq(p1["gear"], ["test_gear"])
	assert_eq(p2["deck"], ["c11", "c12", "c13"])
	assert_eq(p2["cards"]["c12"], {"def_id": "neutral_test_brace", "upgraded": false})
	assert_true(state["rng"].has("shuffle:p2"), "streams created")
	for bad: Array in [[], ["test_dude", "test_dude", "test_dude", "test_dude", "test_dude"], ["nobody"], [7]]:
		assert_ne(Party.build_run_state(rules, SEED, bad)["error"], "", "error for %s" % str(bad))


## start_fight builds the enemies, shuffles the deck with the shuffle stream, and runs turn 1 to the
## player phase. It changes neither its input nor state_version.
func test_start_fight() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# run: a solo run outside a fight.
	var run: Dictionary = Party.build_run_state(rules, SEED, ["test_dude"])["state"]
	# before: a copy, to prove run is not changed.
	var before: Dictionary = run.duplicate(true)
	# started: start_fight()'s result.
	var started: Dictionary = Fight.start_fight(rules, run, ["test_dummy", "test_turtle", "test_rival", "test_boss"])
	assert_eq(started["error"], "")
	assert_eq(run, before, "start_fight does not change its input")
	# state: the started fight.
	var state: Dictionary = started["state"]
	_assert_valid(state, started["events"])
	assert_eq(state["state_version"], 0, "starting a fight is not a request")
	# combat: the fight.
	var combat: Dictionary = state["combat"]
	assert_eq([combat["turn"], combat["phase"], combat["result"]], [1, "player", ""])
	# uids: the enemies' uids.
	var uids: Array = combat["enemies"].map(func(enemy: Dictionary) -> String: return enemy["uid"])
	assert_eq(uids, ["e11", "e12", "e13", "e14"], "uids from next_uid")
	assert_eq(state["next_uid"], 15)
	assert_eq(combat["enemies"][0]["hp"], 20)
	assert_eq(combat["enemies"][0]["max_hp"], 20)
	assert_eq(combat["enemies"][0]["arm_count"], 2)
	assert_eq(combat["enemies"][1]["arm_count"], 0)
	assert_eq(combat["enemies"].map(func(enemy: Dictionary) -> int: return enemy["ick_threshold"]),
		[rules["constants"]["ICK_BASE_NORMAL"], rules["constants"]["ICK_BASE_NORMAL"],
			rules["constants"]["ICK_BASE_RIVAL"], rules["constants"]["ICK_BASE_BOSS"]], "solo Ick thresholds")
	# expected: the deck shuffled with p1's shuffle stream.
	var expected: Dictionary = Rng.shuffle(run, "shuffle:p1", run["dudes"][0]["deck"])
	# dude: p1 in the fight.
	var dude: Dictionary = state["dudes"][0]
	assert_eq(dude["hand"] + dude["draw_pile"], expected["value"], "draw pile is the shuffled deck; hand is its top 5")
	assert_eq(dude["hand"].size(), rules["constants"]["BASE_DRAW"])
	assert_eq(state["rng"]["shuffle:p1"], expected["state"]["rng"]["shuffle:p1"], "shuffle stream advanced")
	assert_eq(state["rng"]["combat_ai"], run["rng"]["combat_ai"], "other streams untouched")
	assert_eq(dude["hype"], rules["constants"]["BASE_HYPE"])
	assert_eq(_types(started["events"]), ["fight_started", "turn_started", "intent_set", "intent_set", "intent_set",
		"intent_set", "hype_changed", "card_moved", "card_moved", "card_moved", "card_moved", "card_moved"])
	assert_eq(started["events"][0]["enemy_uids"], uids)


## start_fight refuses bad input and returns the state unchanged.
func test_start_fight_errors() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# run: a solo run outside a fight.
	var run: Dictionary = Party.build_run_state(rules, SEED, ["test_dude"])["state"]
	for ids: Array in [[], ["no_such_enemy"], [3]]:
		# result: start_fight()'s refusal.
		var result: Dictionary = Fight.start_fight(rules, run, ids)
		assert_ne(result["error"], "", "error for %s" % str(ids))
		assert_true(is_same(result["state"], run), "state returned unchanged")
		assert_eq(result["events"], [])
	# fighting: a run already in a fight.
	var fighting: Dictionary = Fight.start_fight(rules, run, ["test_dummy"])["state"]
	assert_ne(Fight.start_fight(rules, fighting, ["test_dummy"])["error"], "", "a fight is already running")
	# no_streams: a run without random streams.
	var no_streams: Dictionary = run.duplicate(true)
	no_streams["rng"] = {}
	assert_ne(Fight.start_fight(rules, no_streams, ["test_dummy"])["error"], "", "missing shuffle stream")


## Enemy HP scales by 1 + 0.8 x (players - 1), rounded down; Ick thresholds scale by the same and
## round up (GDD "Difficulty scaling"). Exact for every party size.
func test_party_scaling() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# cases: party size -> [Pledge HP, normal Ick, Rival HP, Rival Ick], from 12 and 60 HP, Ick 5 and 8.
	var cases: Dictionary = {1: [12, 5, 60, 8], 2: [21, 9, 108, 15], 3: [31, 13, 156, 21], 4: [40, 17, 204, 28]}
	for size: int in [1, 2, 3, 4]:
		# ids: that many Dudes.
		var ids: Array = []
		ids.resize(size)
		ids.fill("test_dude")
		# state: a fight against a Pledge and a Rival.
		var state: Dictionary = Fixtures.fight(rules, SEED, ids, ["test_pledge", "test_rival"])
		# enemies: the two enemies.
		var enemies: Array = state["combat"]["enemies"]
		assert_eq([enemies[0]["max_hp"], enemies[0]["ick_threshold"], enemies[1]["max_hp"], enemies[1]["ick_threshold"]],
			cases[size], "party of %d" % size)
		assert_eq(enemies[0]["hp"], enemies[0]["max_hp"])


## Intents (stub for task 011): the first move; attacks aim at the first Dude not Passed Out, other
## moves at nobody.
func test_stub_intents() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a two-Dude fight against a Dummy and a Turtle.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["test_dummy", "test_turtle"])
	assert_eq(state["combat"]["enemies"][0]["intent"], {"move_id": "swing", "target_ids": ["p1"]})
	assert_eq(state["combat"]["enemies"][1]["intent"], {"move_id": "shell", "target_ids": []})
	state["dudes"][0]["hp"] = 0
	state["dudes"][0]["passed_out"] = true
	assert_eq(Fight.stub_intent(rules, state, state["combat"]["enemies"][0]), {"move_id": "swing", "target_ids": ["p2"]})


## Playing a card: Hype spent, card to discard, cards_played_this_turn + 1, events in order.
func test_play_card() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight with a Jab, a Bash and a Freebie added to the hand.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_dummy", "test_turtle"])
	# jab: an added Jab.
	var jab: String = Fixtures.give(state, 0, "neutral_test_jab")
	# bash: an added Bash (damage, then Guard).
	var bash: String = Fixtures.give(state, 0, "neutral_test_bash")
	# freebie: an added cost-0 card.
	var freebie: String = Fixtures.give(state, 0, "neutral_test_freebie")
	# result: after the Jab on the Dummy.
	var result: Dictionary = _ok(rules, state, Fixtures.play("p1", 0, jab, "e11"))
	assert_eq(result["events"], [
		Event.make("card_played", {"player_id": "p1", "card_uid": jab, "target_id": "e11"}),
		Event.make("hype_changed", {"player_id": "p1", "delta": -1, "hype": 2}),
		Event.make("damage_dealt", {"source_id": "p1", "target_id": "e11", "amount": 6, "blocked": 0, "hp_lost": 6}),
		Event.make("card_moved", {"player_id": "p1", "card_uid": jab, "from": "hand", "to": "discard_pile"}),
	])
	# dude: p1 afterwards.
	var dude: Dictionary = result["state"]["dudes"][0]
	assert_eq([dude["hype"], dude["cards_played_this_turn"], dude["discard_pile"]], [2, 1, [jab]])
	assert_false(dude["hand"].has(jab))
	assert_eq(result["state"]["combat"]["enemies"][0]["hp"], 14)
	# Bash: damage lands on the enemy, Guard on the player.
	result = _ok(rules, result["state"], Fixtures.play("p1", 1, bash, "e11"))
	assert_eq(result["state"]["combat"]["enemies"][0]["hp"], 11)
	assert_eq(result["state"]["combat"]["enemies"][0]["guard"], 0, "guard op does not land on the target")
	assert_eq(result["state"]["dudes"][0]["guard"], 3)
	# Freebie costs 0: no hype_changed.
	result = _ok(rules, result["state"], Fixtures.play("p1", 2, freebie, ""))
	assert_eq(_types(result["events"]), ["card_played", "guard_changed", "card_moved"])
	assert_eq(result["state"]["dudes"][0]["cards_played_this_turn"], 3)


## An all_enemies card hits every enemy; a Tapped card goes to the tapped pile.
func test_all_enemies_and_tapped() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight with a Sweep in hand.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_dummy", "test_turtle"])
	# sweep: the added card.
	var sweep: String = Fixtures.give(state, 0, "neutral_test_sweep")
	# result: after the Sweep.
	var result: Dictionary = _ok(rules, state, Fixtures.play("p1", 0, sweep, ""))
	# hits: the damage events.
	var hits: Array = _of_type(result["events"], "damage_dealt")
	assert_eq(hits.map(func(event: Dictionary) -> String: return event["target_id"]), ["e11", "e12"])
	assert_eq(result["state"]["dudes"][0]["tapped_pile"], [sweep])
	assert_false(result["state"]["dudes"][0]["discard_pile"].has(sweep))
	assert_eq(result["events"][-1], Event.make("card_moved", {"player_id": "p1", "card_uid": sweep, "from": "hand", "to": "tapped_pile"}))


## Solo set_ready runs steps 4, 5, 1 and 2 in order and stops in the next player phase.
func test_solo_turn_flow() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight in turn 1, with one card played so Hype and Guard need a Refresh.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_dummy", "test_turtle"])
	state = _ok(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, "neutral_test_bash"), "e11"))["state"]
	# hand: the five cards left in hand, to be discarded.
	var hand: Array = state["dudes"][0]["hand"].duplicate()
	# draw: the draw pile before the turn ends; turn 2 draws its top 5.
	var draw: Array = state["dudes"][0]["draw_pile"].duplicate()
	# result: after Ready.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 1))
	# next: the state in turn 2.
	var next: Dictionary = result["state"]
	assert_eq([next["combat"]["turn"], next["combat"]["phase"]], [2, "player"])
	# expected: the full event list for the turn change.
	var expected: Array = [Event.make("ready_changed", {"player_id": "p1", "ready": true})]
	for uid: String in hand:
		expected.append(Event.make("card_moved", {"player_id": "p1", "card_uid": uid, "from": "hand", "to": "discard_pile"}))
	expected.append_array([
		Event.make("enemy_acted", {"enemy_uid": "e11", "move_id": "swing"}),
		Event.make("damage_dealt", {"source_id": "e11", "target_id": "p1", "amount": 5, "blocked": 3, "hp_lost": 2}),
		Event.make("enemy_acted", {"enemy_uid": "e12", "move_id": "shell"}),
		Event.make("guard_changed", {"target_id": "e12", "delta": 4, "guard": 4}),
		Event.make("turn_started", {"turn": 2}),
		Event.make("intent_set", {"enemy_uid": "e11", "move_id": "swing", "target_ids": ["p1"]}),
		Event.make("intent_set", {"enemy_uid": "e12", "move_id": "shell", "target_ids": []}),
		Event.make("hype_changed", {"player_id": "p1", "delta": 1, "hype": 3}),
		Event.make("ready_changed", {"player_id": "p1", "ready": false}),
	])
	for i: int in 5:
		expected.append(Event.make("card_moved", {"player_id": "p1", "card_uid": draw[i], "from": "draw_pile", "to": "hand"}))
	assert_eq(result["events"], expected, "turn change events")
	# dude: p1 in turn 2.
	var dude: Dictionary = next["dudes"][0]
	assert_eq([dude["hp"], dude["guard"], dude["hype"], dude["ready"], dude["cards_played_this_turn"]], [28, 0, 3, false, 0])
	assert_eq(dude["hand"], draw.slice(0, 5))
	assert_eq(next["combat"]["enemies"][1]["guard"], 4, "enemy Guard is not reset (GDD silent)")


## Co-op: the turn ends only when every Dude who is not Passed Out is ready; un-readying works.
func test_two_dudes_ready() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a two-Dude fight.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["test_dummy"])
	assert_eq(state["dudes"][1]["hand"].size(), 5, "every Dude draws")
	assert_ne(state["rng"]["shuffle:p1"], state["rng"]["shuffle:p2"], "each Dude has their own shuffle stream")
	# result: after p1 is ready.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq([result["state"]["combat"]["turn"], result["state"]["combat"]["phase"]], [1, "player"], "p2 not ready yet")
	assert_eq(result["events"], [Event.make("ready_changed", {"player_id": "p1", "ready": true})])
	result = _ok(rules, result["state"], Fixtures.set_ready("p1", 1, false))
	result = _ok(rules, result["state"], Fixtures.set_ready("p2", 0))
	assert_eq(result["state"]["combat"]["turn"], 1, "p1 took Ready back")
	result = _ok(rules, result["state"], Fixtures.set_ready("p1", 2))
	assert_eq(result["state"]["combat"]["turn"], 2, "both ready: the turn ends")
	assert_eq([result["state"]["dudes"][0]["ready"], result["state"]["dudes"][1]["ready"]], [false, false])
	# out: the turn-2 state with p2 Passed Out; p1's Ready alone ends the turn.
	var out: Dictionary = result["state"].duplicate(true)
	out["dudes"][1]["hp"] = 0
	out["dudes"][1]["passed_out"] = true
	result = _ok(rules, out, Fixtures.set_ready("p1", 3))
	assert_eq(result["state"]["combat"]["turn"], 3, "a Passed Out Dude is not waited for")
	assert_eq(result["state"]["dudes"][1]["hand"], [], "a Passed Out Dude skips Refresh")


## G8: an empty draw pile is refilled by shuffling the discard pile with the shuffle stream; with
## both empty the draw does nothing; there is no hand limit.
func test_draw_reshuffle() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight for a Dude with a 3-card deck, who wanted 5 cards.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_tiny"], ["test_turtle"])
	# dude: the Dude in turn 1.
	var dude: Dictionary = state["dudes"][0]
	assert_eq([dude["hand"].size(), dude["draw_pile"].size(), dude["discard_pile"].size()], [3, 0, 0],
		"both piles empty: the rest of the draw does nothing")
	# result: after Ready; turn 2 must reshuffle the 3 discarded cards.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	# expected: the discard pile (the old hand, in order) shuffled with p1's stream.
	var expected: Dictionary = Rng.shuffle(state, "shuffle:p1", dude["hand"])
	assert_eq(result["state"]["dudes"][0]["hand"], expected["value"], "drawn in the reshuffled order")
	assert_eq(result["state"]["rng"]["shuffle:p1"], expected["state"]["rng"]["shuffle:p1"])
	assert_eq(result["state"]["rng"]["map"], state["rng"]["map"], "only the shuffle stream moves")
	assert_eq(_of_type(result["events"], "deck_shuffled"), [Event.make("deck_shuffled", {"player_id": "p1"})])
	# piles: a hand-made state with 1 card to draw and 2 discarded, drawing 3, then 6 more (no limit).
	var piles: Dictionary = state.duplicate(true)
	piles["dudes"][0]["hand"] = []
	piles["dudes"][0]["draw_pile"] = ["c1"]
	piles["dudes"][0]["discard_pile"] = ["c2", "c3"]
	# events: what the draw emitted.
	var events: Array = []
	assert_eq(Piles.draw_in_place(piles, 0, 3, events), 3)
	assert_eq(piles["dudes"][0]["hand"][0], "c1", "the top card is drawn before any reshuffle")
	assert_eq(_types(events), ["card_moved", "deck_shuffled", "card_moved", "card_moved"])
	events = []
	assert_eq(Piles.draw_in_place(piles, 0, 6, events), 0, "nothing left anywhere")
	assert_eq(events, [])
	assert_eq(piles["dudes"][0]["hand"].size(), 3)


## The fight is won when every enemy is dead: enemy_died, the card still moves, then fight_ended.
func test_win() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a solo fight against a Dummy at 2 HP.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_dummy"])
	state["combat"]["enemies"][0]["hp"] = 2
	# double: a two-hit card; the second hit must not land.
	var double: String = Fixtures.give(state, 0, "neutral_test_double")
	# result: after the killing card.
	var result: Dictionary = _ok(rules, state, Fixtures.play("p1", 0, double, "e11"))
	assert_eq(_types(result["events"]), ["card_played", "hype_changed", "damage_dealt", "enemy_died", "card_moved", "fight_ended"])
	assert_eq(_of_type(result["events"], "damage_dealt")[0]["hp_lost"], 2, "HP stops at 0")
	assert_eq(result["events"][-1], Event.make("fight_ended", {"result": "won"}))
	# combat: the ended fight.
	var combat: Dictionary = result["state"]["combat"]
	assert_eq([combat["phase"], combat["result"], combat["enemies"]], ["over", "won", []])
	assert_eq(Core.apply(rules, result["state"], Fixtures.set_ready("p1", 1))["reject"], "wrong_phase")


## The fight is lost when every Dude is Passed Out; in co-op it goes on while anyone is standing.
func test_loss() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# solo: a solo fight against a Brute that hits for 50.
	var solo: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_brute"])
	# result: after Ready.
	var result: Dictionary = _ok(rules, solo, Fixtures.set_ready("p1", 0))
	assert_eq(_types(result["events"]).slice(-4), ["enemy_acted", "damage_dealt", "dude_passed_out", "fight_ended"])
	assert_eq(result["events"][-1]["result"], "lost")
	assert_eq([result["state"]["combat"]["phase"], result["state"]["combat"]["result"]], ["over", "lost"])
	assert_eq([result["state"]["dudes"][0]["hp"], result["state"]["dudes"][0]["passed_out"]], [0, true])
	# duo: two Dudes against the Brute; it knocks out p1, then p2 a turn later.
	var duo: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["test_brute"])
	duo = _ok(rules, duo, Fixtures.set_ready("p1", 0))["state"]
	result = _ok(rules, duo, Fixtures.set_ready("p2", 0))
	assert_eq([result["state"]["combat"]["turn"], result["state"]["combat"]["phase"]], [2, "player"], "p2 still standing")
	assert_true(result["state"]["dudes"][0]["passed_out"])
	assert_eq(result["state"]["combat"]["enemies"][0]["intent"]["target_ids"], ["p2"], "aims at the standing Dude")
	assert_eq(Core.apply(rules, result["state"], Fixtures.set_ready("p1", 1))["reject"], "passed_out")
	result = _ok(rules, result["state"], Fixtures.set_ready("p2", 1))
	assert_eq(result["state"]["combat"]["result"], "lost")
