## Tests for the six Junk cards (GDD "Junk cards"; task 015): Hangover, Regret, Bedbugs, Paperwork,
## Detention and Burn, with the GDD's numbers, and fight-only Junk leaving when the fight ends.
## Rules: core/combat/card_triggers.gd. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const CardTriggers := preload("res://core/combat/card_triggers.gd")
const Ops := preload("res://core/ops/ops.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const Junk := preload("res://tests/core/combat/junk_fixtures.gd")
const CardDef := preload("res://core/schema/card_def.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 1515

## The test Dude's HP (tests/core/combat/fixtures.gd test_dude max_hp), for readable assertions.
const DUDE_HP: int = 30


## Returns a solo test_dude fight against one enemy (uid e11) in turn 1's player phase.
## rules: the ruleset. enemy_id: the enemy definition id; the Turtle only gains Guard.
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


## Returns the index of the first event equal to wanted, or -1.
## events: an event list. wanted: the exact event.
func _index_of(events: Array, wanted: Dictionary) -> int:
	for i: int in events.size():
		if events[i] == wanted:
			return i
	return -1


## The six definitions pass card_def.gd check(), use rarity "special" (G17) and the GDD's costs and
## Lasts column.
func test_junk_definitions_are_valid() -> void:
	# lasts: id -> the GDD's Lasts column.
	var lasts: Dictionary = {"junk_hangover": "run", "junk_regret": "run", "junk_bedbugs": "run",
		"junk_paperwork": "fight", "junk_detention": "fight", "junk_burn": "fight"}
	for id: String in Junk.JUNK:
		assert_no_errors(CardDef.check(Junk.JUNK[id]), id)
		assert_eq(Junk.JUNK[id]["rarity"], "special", id)
		assert_eq(Junk.JUNK[id]["cost"], 1 if id == "junk_paperwork" else -1, id + " cost")
		assert_eq(Junk.JUNK[id]["lasts"], lasts[id], id + " lasts")
	assert_false(Junk.ruleset().is_empty(), "the Junk ruleset builds")


## Hangover: when drawn at Refresh, lose 1 Hype (3 -> 2), right after the card reaches the hand.
func test_hangover_loses_1_hype_when_drawn() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: turn 1, a Hangover on top of p1's draw pile.
	var state: Dictionary = _fight(rules)
	# uid: the Hangover.
	var uid: String = Junk.own(state, 0, "junk_hangover", "draw_pile")
	# result: end turn 1; turn 2's Refresh draws the Hangover first.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	# drawn_at: index of the Hangover's draw event.
	var drawn_at: int = _index_of(result["events"], Event.make("card_moved",
		{"player_id": "p1", "card_uid": uid, "from": "draw_pile", "to": "hand"}))
	assert_true(drawn_at != -1, "the Hangover is drawn")
	assert_eq(result["events"][drawn_at + 1], Event.make("hype_changed", {"player_id": "p1", "delta": -1, "hype": 2}))
	assert_eq(result["state"]["dudes"][0]["hype"], 2, "3 Hype - 1")
	assert_eq(result["state"]["combat"]["phase"], "player")


## Hangover at 0 Hype loses nothing and emits no hype_changed; two Hangovers lose 2.
func test_hangover_hype_stops_at_0() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: two Hangovers on top, 1 Hype.
	var state: Dictionary = _fight(rules)
	state["dudes"][0]["hype"] = 1
	Junk.own(state, 0, "junk_hangover", "draw_pile")
	Junk.own(state, 0, "junk_hangover", "draw_pile")
	# events: from drawing both.
	var events: Array = []
	assert_eq(CardTriggers.draw_in_place(rules, state, 0, 2, events), 2)
	assert_eq(state["dudes"][0]["hype"], 0, "1 Hype, lose 1, then nothing left to lose")
	assert_eq(_of_type(events, "hype_changed"), [Event.make("hype_changed", {"player_id": "p1", "delta": -1, "hype": 0})])
	_assert_valid(state, events)


## A mid-turn draw (task 013's "draw" op, as Wrist Lock uses) also runs on_draw: drawing a Hangover
## with the op costs 1 Hype right after its card_moved, as at Refresh.
func test_draw_op_runs_on_draw() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: turn 1's player phase, a Hangover on top of p1's draw pile, 3 Hype.
	var state: Dictionary = _fight(rules)
	# uid: the Hangover.
	var uid: String = Junk.own(state, 0, "junk_hangover", "draw_pile")
	# hype: p1's Hype before the draw.
	var hype: int = state["dudes"][0]["hype"]
	# events: from the draw op.
	var events: Array = []
	Ops.run(state, {"op": "draw", "amount": 1}, Ops.make_context(rules, "p1", [], false, true), events)
	assert_eq(events, [
		Event.make("card_moved", {"player_id": "p1", "card_uid": uid, "from": "draw_pile", "to": "hand"}),
		Event.make("hype_changed", {"player_id": "p1", "delta": -1, "hype": hype - 1}),
	])
	assert_eq(state["dudes"][0]["hype"], hype - 1, "the Hangover's on_draw ran")
	_assert_valid(state, events)


## Regret: unplayable, nothing happens when drawn, cannot be removed at Baileys (data), lasts the run.
func test_regret() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: a Regret in hand and one on top of the draw pile.
	var state: Dictionary = _fight(rules)
	# uid: the Regret in hand.
	var uid: String = Junk.own(state, 0, "junk_regret", "hand")
	Junk.own(state, 0, "junk_regret", "draw_pile")
	assert_eq(Core.apply(rules, state, Fixtures.play("p1", 0, uid, ""))["reject"], "unplayable")
	assert_eq(rules["cards"]["junk_regret"]["removable"], false, "Baileys reads removable (task 025)")
	# events: from drawing the other Regret.
	var events: Array = []
	CardTriggers.draw_in_place(rules, state, 0, 1, events)
	assert_eq(events.size(), 1, "only the card_moved of the draw")
	assert_true(state["dudes"][0]["deck"].has(uid), "a run card is in the run deck")


## Bedbugs: when drawn, take 1 damage, which is not attack damage (G3): source "", through Guard.
func test_bedbugs_deals_1_damage_when_drawn() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: turn 1, Bedbugs on top of p1's draw pile.
	var state: Dictionary = _fight(rules)
	# uid: the Bedbugs.
	var uid: String = Junk.own(state, 0, "junk_bedbugs", "draw_pile")
	# result: end turn 1; turn 2's Refresh draws the Bedbugs first (the Turtle does not attack).
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	# drawn_at: index of the Bedbugs' draw event.
	var drawn_at: int = _index_of(result["events"], Event.make("card_moved",
		{"player_id": "p1", "card_uid": uid, "from": "draw_pile", "to": "hand"}))
	assert_true(drawn_at != -1, "the Bedbugs are drawn")
	assert_eq(result["events"][drawn_at + 1], Event.make("damage_dealt",
		{"source_id": "", "target_id": "p1", "amount": 1, "blocked": 0, "hp_lost": 1}))
	assert_eq(result["state"]["dudes"][0]["hp"], DUDE_HP - 1)
	# guarded: the same draw with 4 Guard: the Guard takes it.
	var guarded: Dictionary = _fight(rules)
	guarded["dudes"][0]["guard"] = 4
	Junk.own(guarded, 0, "junk_bedbugs", "draw_pile")
	# events: from that draw.
	var events: Array = []
	CardTriggers.draw_in_place(rules, guarded, 0, 1, events)
	assert_eq(_of_type(events, "damage_dealt"), [Event.make("damage_dealt",
		{"source_id": "", "target_id": "p1", "amount": 1, "blocked": 1, "hp_lost": 0})])
	assert_eq(guarded["dudes"][0]["guard"], 3)


## Bedbugs that Pass Out the only Dude at Refresh lose the fight there: no player phase, no more draws.
func test_bedbugs_can_end_the_fight_at_refresh() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: p1 at 1 HP with Bedbugs on top.
	var state: Dictionary = _fight(rules)
	state["dudes"][0]["hp"] = 1
	Junk.own(state, 0, "junk_bedbugs", "draw_pile")
	# result: end turn 1.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq(result["state"]["combat"]["result"], "lost")
	assert_eq(result["state"]["combat"]["phase"], "over")
	assert_eq(result["state"]["dudes"][0]["hand"].size(), 1, "drawing stops once Passed Out")
	assert_eq(_of_type(result["events"], "fight_ended"), [Event.make("fight_ended", {"result": "lost"})])
	assert_eq(_of_type(result["events"], "dude_passed_out").size(), 1)


## Paperwork: costs 1 Hype, does nothing, Tapped; with no Hype it is no_hype.
func test_paperwork() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: Paperwork in hand, 3 Hype.
	var state: Dictionary = _fight(rules)
	# uid: the Paperwork.
	var uid: String = Junk.own(state, 0, "junk_paperwork", "hand")
	# result: Paperwork played.
	var result: Dictionary = _ok(rules, state, Fixtures.play("p1", 0, uid, ""))
	assert_eq(result["events"], [
		Event.make("card_played", {"player_id": "p1", "card_uid": uid, "target_id": ""}),
		Event.make("hype_changed", {"player_id": "p1", "delta": -1, "hype": 2}),
		Event.make("card_moved", {"player_id": "p1", "card_uid": uid, "from": "hand", "to": "tapped_pile"}),
	], "spend 1, nothing else, then Tapped")
	assert_true(result["state"]["dudes"][0]["tapped_pile"].has(uid))
	# broke: the same state with 0 Hype.
	var broke: Dictionary = state.duplicate(true)
	broke["dudes"][0]["hype"] = 0
	assert_eq(Core.apply(rules, broke, Fixtures.play("p1", 0, uid, ""))["reject"], "no_hype")


## Detention: while it is in hand, the 4th card of the turn is allowed and the 5th is unplayable;
## Detention itself is unplayable; once it leaves the hand the limit is gone.
func test_detention_limits_plays_to_4() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: Detention and five 0-cost Freebies in hand.
	var state: Dictionary = _fight(rules)
	# detention: the Detention's uid.
	var detention: String = Junk.own(state, 0, "junk_detention", "hand")
	# freebies: the Freebies' uids.
	var freebies: Array = []
	for i: int in 5:
		freebies.append(Junk.own(state, 0, "neutral_test_freebie", "hand"))
	assert_eq(Core.apply(rules, state, Fixtures.play("p1", 0, detention, ""))["reject"], "unplayable", "Detention itself")
	for i: int in 4:
		state = _ok(rules, state, Fixtures.play("p1", i, freebies[i], ""))["state"]
	assert_eq(state["dudes"][0]["cards_played_this_turn"], 4)
	assert_eq(Core.apply(rules, state, Fixtures.play("p1", 4, freebies[4], ""))["reject"], "unplayable", "5th card")
	# freed: the same moment with Detention moved out of the hand (as Hair of the Dog will, task 021).
	var freed: Dictionary = state.duplicate(true)
	freed["dudes"][0]["hand"].erase(detention)
	freed["dudes"][0]["discard_pile"].append(detention)
	_ok(rules, freed, Fixtures.play("p1", 4, freebies[4], ""))


## Detention counts cards played before it arrived: after 4 plays, a Detention reaching the hand
## stops the 5th.
func test_detention_counts_earlier_plays() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: five Freebies in hand, no Detention yet.
	var state: Dictionary = _fight(rules)
	# freebies: the Freebies' uids.
	var freebies: Array = []
	for i: int in 5:
		freebies.append(Junk.own(state, 0, "neutral_test_freebie", "hand"))
	for i: int in 4:
		state = _ok(rules, state, Fixtures.play("p1", i, freebies[i], ""))["state"]
	# late: the state with a Detention arriving in hand now.
	var late: Dictionary = state.duplicate(true)
	Junk.own(late, 0, "junk_detention", "hand")
	assert_eq(Core.apply(rules, late, Fixtures.play("p1", 4, freebies[4], ""))["reject"], "unplayable")
	_ok(rules, state, Fixtures.play("p1", 4, freebies[4], ""))


## Burn: in hand at end of turn, take 2 damage before the hand is discarded; not attack damage, so
## Exposed does not raise it (G3), and Guard takes it first. A Burn in the discard pile does nothing.
func test_burn_deals_2_at_end_of_turn() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: a Burn in hand, one in the discard pile, 1 Guard and 2 Exposed.
	var state: Dictionary = _fight(rules)
	# uid: the Burn in hand.
	var uid: String = Junk.own(state, 0, "junk_burn", "hand")
	Junk.own(state, 0, "junk_burn", "discard_pile")
	state["dudes"][0]["guard"] = 1
	state["dudes"][0]["statuses"] = {"exposed": 2}
	# result: end turn 1.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	# hits: the damage events.
	var hits: Array = _of_type(result["events"], "damage_dealt")
	assert_eq(hits, [Event.make("damage_dealt", {"source_id": "", "target_id": "p1", "amount": 2, "blocked": 1, "hp_lost": 1})])
	assert_true(result["events"].find(hits[0]) < _index_of(result["events"], Event.make("card_moved",
		{"player_id": "p1", "card_uid": uid, "from": "hand", "to": "discard_pile"})), "before the discard")
	assert_eq(result["state"]["dudes"][0]["hp"], DUDE_HP - 1)


## Two Burns an enemy puts in the hand (add_card, count 2) deal 2 each at the next end of turn.
func test_two_burns_from_an_enemy() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: a fight against the Imp, which adds 2 Burns to p1's hand each turn.
	var state: Dictionary = _fight(rules, "test_imp")
	# turn2: after turn 1; the Burns are in hand for turn 2.
	var turn2: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq(_of_type(turn2["events"], "card_created").size(), 2)
	assert_eq(turn2["state"]["dudes"][0]["hp"], DUDE_HP, "no Burn damage in turn 1")
	# turn3: after turn 2.
	var turn3: Dictionary = _ok(rules, turn2["state"], Fixtures.set_ready("p1", 1))
	assert_eq(_of_type(turn3["events"], "damage_dealt").size(), 2)
	assert_eq(turn3["state"]["dudes"][0]["hp"], DUDE_HP - 4, "2 + 2")


## A Burn that Passes Out the only Dude ends the fight before the enemy phase.
func test_burn_can_end_the_fight() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: p1 at 2 HP with a Burn in hand.
	var state: Dictionary = _fight(rules)
	state["dudes"][0]["hp"] = 2
	Junk.own(state, 0, "junk_burn", "hand")
	# result: end turn 1.
	var result: Dictionary = _ok(rules, state, Fixtures.set_ready("p1", 0))
	assert_eq(result["state"]["combat"]["result"], "lost")
	assert_eq(_of_type(result["events"], "enemy_acted"), [], "the enemies do not act")


## When the fight ends, fight-only Junk (Paperwork, Detention, Burn) leaves the Dude's cards, deck
## and every pile, with card_removed in pile order; run Junk (Hangover, Regret, Bedbugs) stays.
func test_fight_only_junk_is_removed_when_the_fight_ends() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: Junk spread over every pile, plus a Paperwork that is only in the deck.
	var state: Dictionary = _fight(rules)
	# gone: [uid, pile] of each fight-only copy, in the order card_removed should name them.
	var gone: Array = []
	gone.append([Junk.own(state, 0, "junk_paperwork", "draw_pile"), "draw_pile"])
	gone.append([Junk.own(state, 0, "junk_burn", "hand"), "hand"])
	gone.append([Junk.own(state, 0, "junk_detention", "discard_pile"), "discard_pile"])
	gone.append([Junk.own(state, 0, "junk_paperwork", "tapped_pile"), "tapped_pile"])
	# deck_only: a fight-only copy in the deck and no pile (only a hand-built state has one).
	var deck_only: String = Junk.own(state, 0, "junk_paperwork", "tapped_pile")
	state["dudes"][0]["tapped_pile"].erase(deck_only)
	state["dudes"][0]["deck"].append(deck_only)
	gone.append([deck_only, "deck"])
	# kept: the run Junk.
	var kept: Array = [Junk.own(state, 0, "junk_hangover", "draw_pile"), Junk.own(state, 0, "junk_regret", "discard_pile"),
		Junk.own(state, 0, "junk_bedbugs", "hand")]
	# big: a 99-damage card to win at once.
	var big: String = Junk.own(state, 0, "neutral_test_big", "hand")
	state["dudes"][0]["hype"] = 4
	# result: the Turtle dies.
	var result: Dictionary = _ok(rules, state, Fixtures.play("p1", 0, big, "e11"))
	assert_eq(result["state"]["combat"]["result"], "won")
	# expected: the card_removed events in order.
	var expected: Array = gone.map(func(entry: Array) -> Dictionary: return Event.make("card_removed",
		{"player_id": "p1", "card_uid": entry[0], "from": entry[1]}))
	assert_eq(_of_type(result["events"], "card_removed"), expected)
	assert_true(result["events"].find(expected[0]) > _index_of(result["events"], Event.make("fight_ended", {"result": "won"})),
		"after fight_ended")
	# dude: p1 after the fight.
	var dude: Dictionary = result["state"]["dudes"][0]
	for entry: Array in gone:
		assert_false(dude["cards"].has(entry[0]), "%s left cards" % entry[0])
		assert_false(dude["deck"].has(entry[0]), "%s left the deck" % entry[0])
	for uid: String in kept:
		assert_true(dude["cards"].has(uid) and dude["deck"].has(uid), "%s stays for the run" % uid)
