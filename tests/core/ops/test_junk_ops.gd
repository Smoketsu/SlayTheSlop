## Tests for the task 015 ops: add_card (every pile, shuffle_in with a fixed seed, count, who it
## lands on, from cards and from enemy moves), lose_hype and self_damage. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Ops := preload("res://core/ops/ops.gd")
const AddCard := preload("res://core/ops/add_card.gd")
const Rng := preload("res://core/rng/rng.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const Junk := preload("res://tests/core/combat/junk_fixtures.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 2016

## Where the Intern's shuffled-in Paperwork lands in p1's 5-card draw pile with SEED (0 = top).
## Recorded from a run of this code; a change means the shuffle stream or add_card changed.
const SHUFFLED_POSITION: int = 3

## The test Dude's HP (tests/core/combat/fixtures.gd test_dude max_hp), for readable assertions.
const DUDE_HP: int = 30


## Returns a solo test_dude fight against one enemy (uid e11) in turn 1's player phase.
## rules: the ruleset. enemy_id: the enemy definition id.
func _fight(rules: Dictionary, enemy_id: String = "test_turtle") -> Dictionary:
	return Fixtures.fight(rules, SEED, ["test_dude"], [enemy_id])


## Applies a request, asserting it is accepted and that every event and the new state are valid.
## Returns apply()'s result.
## rules: the ruleset. state: the state. request: the request.
func _ok(rules: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], "", "request %s should apply" % var_to_str(request))
	_assert_valid(result["state"], result["events"])
	return result


## Asserts that every event passes event.gd check() and the state passes run_state.check().
## state: a run state. events: an event list.
func _assert_valid(state: Dictionary, events: Array) -> void:
	for event: Variant in events:
		assert_no_errors(Event.check(event), "event %s" % var_to_str(event))
	assert_no_errors(RunState.check(state), "state")


## Returns the events of one type, in order.
## events: an event list. type: the event type wanted.
func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event["type"] == type)


## The three ops are registered; add_card aims enemy intents at Dudes, the other two do not.
func test_ops_are_registered() -> void:
	for op: String in ["add_card", "lose_hype", "self_damage"]:
		assert_true(Ops.is_known(op), op)
	assert_true(Ops.needs_target([{"op": "add_card", "card_id": "junk_burn", "to": "hand"}]))
	assert_false(Ops.needs_target([{"op": "lose_hype", "amount": 1}, {"op": "self_damage", "amount": 1}]))


## Ops.check accepts well-formed effects and reports each malformed one.
func test_check_fields() -> void:
	# good: valid effects.
	var good: Array = [{"op": "add_card", "card_id": "junk_paperwork", "to": "draw_pile", "shuffle_in": true, "count": 2},
		{"op": "add_card", "card_id": "junk_burn", "to": "hand"}, {"op": "add_card", "card_id": "junk_x", "to": "discard_pile", "shuffle_in": false},
		{"op": "lose_hype", "amount": 0}, {"op": "self_damage", "amount": 2}]
	for effect: Dictionary in good:
		assert_no_errors(Ops.check(effect), var_to_str(effect))
	# bad: invalid effects, one problem each.
	var bad: Array = [{"op": "add_card", "to": "hand"}, {"op": "add_card", "card_id": "", "to": "hand"},
		{"op": "add_card", "card_id": "junk_burn", "to": "deck"}, {"op": "add_card", "card_id": "junk_burn"},
		{"op": "add_card", "card_id": "junk_burn", "to": "hand", "shuffle_in": true},
		{"op": "add_card", "card_id": "junk_burn", "to": "draw_pile", "shuffle_in": 1},
		{"op": "add_card", "card_id": "junk_burn", "to": "hand", "count": 0},
		{"op": "add_card", "card_id": "junk_burn", "to": "hand", "count": 2.0},
		{"op": "add_card", "card_id": "junk_burn", "to": "hand", "pile": "x"},
		{"op": "lose_hype"}, {"op": "lose_hype", "amount": -1}, {"op": "lose_hype", "amount": 1, "hits": 2},
		{"op": "self_damage", "amount": 1.0}, {"op": "self_damage", "amount": 1, "target": "p1"}]
	for effect: Dictionary in bad:
		assert_eq(Ops.check(effect).size(), 1, var_to_str(effect))


## From a card, add_card lands on the player whatever the card's target is: to the discard pile,
## the top of the draw pile and the hand (count 2). Run cards join the deck; fight-only ones do not.
func test_add_card_from_cards_to_each_pile() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# cases: [card played, target, added card, pile, copies].
	var cases: Array = [["neutral_test_brownie", "", "junk_hangover", "discard_pile", 1],
		["neutral_test_tattoo", "", "junk_regret", "draw_pile", 1],
		["neutral_test_red_tape", "e11", "junk_paperwork", "hand", 2]]
	for case: Array in cases:
		# state: a fresh fight with the card in hand.
		var state: Dictionary = _fight(rules)
		# played: the card being played.
		var played: String = Fixtures.give(state, 0, case[0])
		# first: the number of the first new card_uid.
		var first: int = state["next_uid"]
		# deck_size: the deck before.
		var deck_size: int = state["dudes"][0]["deck"].size()
		# result: after the play.
		var result: Dictionary = _ok(rules, state, Fixtures.play("p1", 0, played, case[1]))
		# dude: p1 afterwards.
		var dude: Dictionary = result["state"]["dudes"][0]
		# expected: the card_created events.
		var expected: Array = []
		for i: int in case[4]:
			# uid: the i-th new copy.
			var uid: String = "c%d" % (first + i)
			expected.append(Event.make("card_created", {"player_id": "p1", "card_uid": uid, "def_id": case[2], "to": case[3]}))
			assert_eq(dude["cards"][uid], {"def_id": case[2], "upgraded": false}, case[0])
			assert_true(dude[case[3]].has(uid), "%s in %s" % [uid, case[3]])
		assert_eq(_of_type(result["events"], "card_created"), expected, case[0])
		assert_eq(result["state"]["next_uid"], first + case[4])
		# lasts_run: whether the copies joined the run deck.
		var lasts_run: bool = Junk.JUNK[case[2]]["lasts"] == "run"
		assert_eq(dude["deck"].size(), deck_size + (case[4] if lasts_run else 0), "%s deck" % case[2])
		if case[3] == "draw_pile":
			assert_eq(dude["draw_pile"][0], "c%d" % first, "on top without shuffle_in")
	# hit: Red Tape's damage still went to the enemy.
	var state2: Dictionary = _fight(rules)
	# result2: Red Tape at e11.
	var result2: Dictionary = _ok(rules, state2, Fixtures.play("p1", 0, Fixtures.give(state2, 0, "neutral_test_red_tape"), "e11"))
	assert_eq(_of_type(result2["events"], "damage_dealt")[0]["target_id"], "e11")


## Fixed seed: an enemy move shuffles a Paperwork into its target's draw pile at the position drawn
## from that Dude's shuffle stream (SHUFFLED_POSITION), the same on every run; it is not in the deck.
func test_enemy_shuffles_paperwork_in_with_fixed_seed() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: turn 1 against the Intern (5 cards left in the draw pile).
	var state: Dictionary = _fight(rules, "test_intern")
	assert_eq(state["combat"]["enemies"][0]["intent"]["target_ids"], ["p1"], "the intent aims at p1")
	# results: two runs of the same turn.
	var results: Array = [_ok(rules, state, Fixtures.set_ready("p1", 0)), _ok(rules, state, Fixtures.set_ready("p1", 0))]
	assert_eq(results[0]["state"], results[1]["state"], "same seed, same result")
	# created: the Paperwork's card_created event.
	var created: Array = _of_type(results[0]["events"], "card_created")
	assert_eq(created.size(), 1)
	assert_eq(created[0]["to"], "draw_pile")
	assert_eq(created[0]["def_id"], "junk_paperwork")
	# hits: the Intern's 6 damage is an ordinary attack.
	assert_eq(_of_type(results[0]["events"], "damage_dealt")[0]["amount"], 6)
	# direct: the same op run straight on the turn 1 state, to see the position before any draw.
	var direct: Dictionary = state.duplicate(true)
	# pile_size: the draw pile's size before the op.
	var pile_size: int = direct["dudes"][0]["draw_pile"].size()
	# expected: next_int over 0..size from p1's shuffle stream.
	var expected: Dictionary = Rng.next_int(direct, Rng.key_for("shuffle", "p1"), 0, pile_size)
	assert_eq(expected["error"], "")
	assert_eq(expected["value"], SHUFFLED_POSITION, "recorded position for SEED")
	# events: from the direct run.
	var events: Array = []
	Ops.run(direct, {"op": "add_card", "card_id": "junk_paperwork", "to": "draw_pile", "shuffle_in": true},
		Ops.make_context(rules, "e11", ["p1"], true, false), events)
	# uid: the new Paperwork.
	var uid: String = events[0]["card_uid"]
	assert_eq(direct["dudes"][0]["draw_pile"].find(uid), SHUFFLED_POSITION)
	assert_eq(direct["dudes"][0]["draw_pile"].size(), pile_size + 1)
	assert_eq(direct["rng"], expected["state"]["rng"], "exactly one draw from shuffle:p1")
	assert_false(direct["dudes"][0]["deck"].has(uid), "Paperwork lasts the fight")
	_assert_valid(direct, events)


## count with shuffle_in: each copy draws its own position, in order, from the shuffle stream.
func test_count_shuffles_each_copy() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: turn 1.
	var state: Dictionary = _fight(rules)
	# model: the expected pile, built with the same draws by hand.
	var model: Dictionary = state.duplicate(true)
	# first: the first new uid number.
	var first: int = state["next_uid"]
	for i: int in 3:
		# drawn: the position for copy i.
		var drawn: Dictionary = Rng.next_int(model, Rng.key_for("shuffle", "p1"), 0, model["dudes"][0]["draw_pile"].size())
		model["rng"] = drawn["state"]["rng"]
		model["dudes"][0]["draw_pile"].insert(drawn["value"], "c%d" % (first + i))
	# events: from the op.
	var events: Array = []
	Ops.run(state, {"op": "add_card", "card_id": "junk_hangover", "to": "draw_pile", "shuffle_in": true, "count": 3},
		Ops.make_context(rules, "p1", [], false, true), events)
	assert_eq(state["dudes"][0]["draw_pile"], model["dudes"][0]["draw_pile"])
	assert_eq(state["rng"], model["rng"])
	assert_eq(_of_type(events, "card_created").size(), 3)
	_assert_valid(state, events)


## An enemy move adds Detention to its target's discard pile (Hall Monitor Golem's shape), after
## the End of turn discard, so it is the last card of the pile.
func test_enemy_adds_detention_to_discard() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: turn 1 against the Monitor.
	var state: Dictionary = _fight(rules, "test_monitor")
	assert_eq(state["combat"]["enemies"][0]["intent"]["target_ids"], ["p1"])
	# uid: the card_uid the Detention will get.
	var uid: String = "c%d" % state["next_uid"]
	# result: end turn 1.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq(_of_type(result["events"], "card_created"), [Event.make("card_created",
		{"player_id": "p1", "card_uid": uid, "def_id": "junk_detention", "to": "discard_pile"})])
	# dude: p1 in turn 2.
	var dude: Dictionary = result["state"]["dudes"][0]
	assert_eq(dude["discard_pile"].back(), uid, "on top of the discard pile (turn 2 drew without a reshuffle)")
	assert_false(dude["deck"].has(uid), "Detention lasts the fight")


## Who add_card lands on: the actor when it is a Dude; else the Dudes among the targets that are
## not Passed Out; enemy ids among the targets are ignored.
func test_add_card_recipients() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: a two-Dude fight.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_tiny"], ["test_turtle"])
	# enemy: the Turtle's uid.
	var enemy: String = state["combat"]["enemies"][0]["uid"]
	assert_eq(AddCard.recipients(state, {"actor_id": enemy, "targets": ["p1", "p2"]}), ["p1", "p2"])
	assert_eq(AddCard.recipients(state, {"actor_id": "p2", "targets": [enemy]}), ["p2"])
	state["dudes"][1]["passed_out"] = true
	assert_eq(AddCard.recipients(state, {"actor_id": enemy, "targets": ["p1", "p2", enemy]}), ["p1"])
	# events: an enemy adding a Burn to both hands.
	var events: Array = []
	Ops.run(state, {"op": "add_card", "card_id": "junk_burn", "to": "hand"}, Ops.make_context(rules, enemy, ["p1", "p2"], true, false), events)
	assert_eq(events.size(), 1, "only p1 gets one")
	_assert_valid(state, events)


## An unknown card_id creates nothing at run time, and the ruleset build reports it in a card, a
## trigger list and an enemy move.
func test_unknown_card_id() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: turn 1.
	var state: Dictionary = _fight(rules)
	# before: a copy to compare with.
	var before: Dictionary = state.duplicate(true)
	# events: from the op.
	var events: Array = []
	Ops.run(state, {"op": "add_card", "card_id": "junk_nope", "to": "hand"}, Ops.make_context(rules, "p1", [], false, true), events)
	assert_eq(events, [])
	assert_eq(state, before)
	# card: a card naming the unknown id in effects and on_draw.
	var card: Dictionary = {"id": "neutral_test_ghost", "name": "Ghost", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 0, "target": "none", "effects": [{"op": "add_card", "card_id": "junk_nope", "to": "hand"}],
		"keywords": [], "crunch": null, "upgrade": {}, "on_draw": [{"op": "add_card", "card_id": "junk_nope2", "to": "hand"}]}
	# enemy: an enemy move naming another unknown id.
	var enemy: Dictionary = {"id": "test_ghost", "name": "Ghost", "floor": 1, "tier": "normal", "max_hp": 5, "arm_count": 0,
		"moves": [{"id": "boo", "weight": 1, "intent": "debuff", "effects": [{"op": "add_card", "card_id": "junk_nope3", "to": "hand"}]}]}
	# built: the build result with both added.
	var built: Dictionary = Junk.build_result({"data/cards/neutral_test_ghost.json": JSON.stringify(card),
		"data/enemies/test_ghost.json": JSON.stringify(enemy)})
	assert_false(built["ok"])
	assert_eq(built["errors"].size(), 3, str(built["errors"]))
	for name: String in ["junk_nope\"", "junk_nope2", "junk_nope3"]:
		assert_true(" ".join(built["errors"]).contains(name), name)


## lose_hype: the actor loses up to amount Hype (never below 0), with hype_changed only when it
## changes; an enemy actor has no Hype.
func test_lose_hype() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# cases: [Hype before, amount, Hype after, events expected].
	var cases: Array = [[3, 1, 2, 1], [2, 5, 0, 1], [0, 1, 0, 0], [3, 0, 3, 0]]
	for case: Array in cases:
		# state: turn 1 with the Hype set.
		var state: Dictionary = _fight(rules)
		state["dudes"][0]["hype"] = case[0]
		# events: from the op.
		var events: Array = []
		Ops.run(state, {"op": "lose_hype", "amount": case[1]}, Ops.make_context(rules, "p1", ["p1"], false, true), events)
		assert_eq(state["dudes"][0]["hype"], case[2], var_to_str(case))
		assert_eq(events.size(), case[3], var_to_str(case))
		if case[3] == 1:
			assert_eq(events[0], Event.make("hype_changed", {"player_id": "p1", "delta": case[2] - case[0], "hype": case[2]}))
	# state: an enemy using lose_hype.
	var state: Dictionary = _fight(rules)
	# before: a copy to compare with.
	var before: Dictionary = state.duplicate(true)
	# events: from the op.
	var events: Array = []
	Ops.run(state, {"op": "lose_hype", "amount": 1}, Ops.make_context(rules, "e11", ["p1"], true, false), events)
	assert_eq(state, before, "enemies have no Hype; p1 is not the actor")


## self_damage: exactly amount (no Swole, Noodle Arms or Exposed: G3), through Guard then HP,
## source_id "", and a Dude at 0 HP Passes Out.
func test_self_damage() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: p1 with 2 Swole, Noodle Arms, Exposed and 1 Guard.
	var state: Dictionary = _fight(rules)
	state["dudes"][0]["swole"] = 2
	state["dudes"][0]["statuses"] = {"exposed": 1, "noodle_arms": 1}
	state["dudes"][0]["guard"] = 1
	# events: from a 3-damage self_damage.
	var events: Array = []
	Ops.run(state, {"op": "self_damage", "amount": 3}, Ops.make_context(rules, "p1", ["e11"], true, true), events)
	assert_eq(events, [Event.make("damage_dealt", {"source_id": "", "target_id": "p1", "amount": 3, "blocked": 1, "hp_lost": 2})])
	assert_eq(state["dudes"][0]["hp"], DUDE_HP - 2)
	# low: p1 at 2 HP takes 4.
	var low: Dictionary = _fight(rules)
	low["dudes"][0]["hp"] = 2
	events = []
	Ops.run(low, {"op": "self_damage", "amount": 4}, Ops.make_context(rules, "p1", [], false, true), events)
	assert_eq(events, [Event.make("damage_dealt", {"source_id": "", "target_id": "p1", "amount": 4, "blocked": 0, "hp_lost": 2}),
		Event.make("dude_passed_out", {"player_id": "p1"})])
	_assert_valid(low, events)


## A playable card with lose_hype and self_damage plays through apply(): Bad Idea at the Turtle
## costs 0, loses 2 Hype and deals 4 to the player, not the target.
func test_ops_on_a_played_card() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: turn 1, 3 Hype.
	var state: Dictionary = _fight(rules)
	# result: Bad Idea played at e11.
	var result: Dictionary = _ok(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, "neutral_test_bad_idea"), "e11"))
	assert_eq(result["state"]["dudes"][0]["hype"], 1)
	assert_eq(result["state"]["dudes"][0]["hp"], DUDE_HP - 4)
	assert_eq(result["state"]["combat"]["enemies"][0]["hp"], 14, "the Turtle is untouched")
