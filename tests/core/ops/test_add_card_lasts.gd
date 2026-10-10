## Tests for task 033: add_card's optional "lasts" field. A copy made with lasts "fight" stays out of
## the run deck and is removed when the fight ends, even when its definition lasts the run (Beer
## Helmet's Hangover, I7). Rules: core/ops/add_card.gd, core/combat/card_triggers.gd. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Ops := preload("res://core/ops/ops.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const Junk := preload("res://tests/core/combat/junk_fixtures.gd")
const TomFixtures := preload("res://tests/core/ops/tom_fixtures.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 3333

## Hype that pays for neutral_test_big (cost 4) in the winning play.
const BIG_COST: int = 4


## Returns the events of one type, in order.
## events: an event list. type: the event type wanted.
func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event["type"] == type)


## Wins the fight at once: p1 plays a 99-damage card at e11 with the next seq. Asserts the play is
## accepted, the fight is won and the new state passes RunState.check. Returns apply()'s result.
## rules: the ruleset. state: a fight in the player phase with a single enemy e11.
func _win(rules: Dictionary, state: Dictionary) -> Dictionary:
	# big: the 99-damage card, put in hand.
	var big: String = Fixtures.give(state, 0, "neutral_test_big")
	state["dudes"][0]["hype"] = BIG_COST
	# result: the winning play.
	var result: Dictionary = Core.apply(rules, state, Fixtures.play("p1", state["dudes"][0]["last_seq"] + 1, big, "e11"))
	assert_eq(result["reject"], "", "the winning play is accepted")
	assert_eq(result["state"]["combat"]["result"], "won")
	assert_no_errors(RunState.check(result["state"]), "state after the fight")
	return result


## Ops.check accepts lasts "fight" and nothing else: a copy may last less than its definition,
## never more.
func test_lasts_field_is_checked() -> void:
	# base: an add_card effect without lasts.
	var base: Dictionary = {"op": "add_card", "card_id": "junk_hangover", "to": "draw_pile", "shuffle_in": true}
	# fight: the same with lasts "fight".
	var fight: Dictionary = base.duplicate()
	fight["lasts"] = "fight"
	assert_eq(Ops.check(fight), [] as Array[String])
	for bad: Variant in ["run", "forever", "", 1, true]:
		# effect: the same with a bad lasts.
		var effect: Dictionary = base.duplicate()
		effect["lasts"] = bad
		assert_eq(Ops.check(effect).size(), 1, "lasts %s" % var_to_str(bad))


## A run-long card (Hangover) copied with lasts "fight" is created like any copy but stays out of the
## run deck, and is removed (card_removed, from the pile it is in) when the fight ends. A copy made
## without lasts joins the deck and stays.
func test_fight_only_copy_of_a_run_card() -> void:
	# rules: the Junk ruleset.
	var rules: Dictionary = Junk.ruleset()
	# state: a solo fight against the Turtle (e11).
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_turtle"])
	assert_false(state.is_empty(), "the fight starts")
	# context: p1 acting on itself, as a Gear trigger does.
	var context: Dictionary = Ops.make_context(rules, "p1", ["p1"], false, false)
	# first: the number of the first new card_uid.
	var first: int = state["next_uid"]
	# events: what the two add_card effects emitted.
	var events: Array = []
	Ops.run(state, {"op": "add_card", "card_id": "junk_hangover", "to": "discard_pile", "count": 2, "lasts": "fight"},
		context, events)
	Ops.run(state, {"op": "add_card", "card_id": "junk_hangover", "to": "discard_pile"}, context, events)
	# brief: the two fight-only copies.
	var brief: Array = ["c%d" % first, "c%d" % (first + 1)]
	# kept: the copy made without lasts.
	var kept: String = "c%d" % (first + 2)
	assert_eq(_of_type(events, "card_created").map(func(event: Dictionary) -> String: return event["card_uid"]),
		brief + [kept], "card_created for every copy")
	# dude: p1, inside state.
	var dude: Dictionary = state["dudes"][0]
	for uid: String in brief:
		assert_true(dude["cards"].has(uid) and dude["discard_pile"].has(uid), "%s owned, in the discard pile" % uid)
		assert_false(dude["deck"].has(uid), "%s is not in the run deck" % uid)
	assert_true(dude["deck"].has(kept), "a copy without lasts joins the run deck")
	assert_no_errors(RunState.check(state), "state with fight-only copies")
	# result: the fight won.
	var result: Dictionary = _win(rules, state)
	assert_eq(_of_type(result["events"], "card_removed"), brief.map(func(uid: String) -> Dictionary:
		return Event.make("card_removed", {"player_id": "p1", "card_uid": uid, "from": "discard_pile"})))
	# after: p1 after the fight.
	var after: Dictionary = result["state"]["dudes"][0]
	for uid: String in brief:
		assert_false(after["cards"].has(uid), "%s is gone" % uid)
	assert_true(after["cards"].has(kept) and after["deck"].has(kept), "the run copy stays")


## A fight-only copy of a Power that is in play (in the powers list, not a pile) leaves the powers
## list too when the fight ends, reported from "deck" (in no pile), so the state stays valid.
func test_fight_only_power_leaves_the_powers_list() -> void:
	# rules: the Tom fixture ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: Tom against the Hitter (e11) with plenty of Hype.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_tom"], ["test_hitter"])
	assert_false(state.is_empty(), "the fight starts")
	state["dudes"][0]["hype"] = 99
	# reply: a Reply Guy copy, played, then made fight-only as an add_card with lasts "fight" would.
	var reply: String = Fixtures.give(state, 0, "tom_test_reply_guy")
	# played: apply()'s result for the Power.
	var played: Dictionary = Core.apply(rules, state, Fixtures.play("p1", 0, reply, ""))
	assert_eq(played["reject"], "")
	state = played["state"]
	state["dudes"][0]["deck"].erase(reply)
	assert_eq(state["dudes"][0]["powers"], [reply], "in play")
	# result: the fight won.
	var result: Dictionary = _win(rules, state)
	assert_true(result["events"].has(Event.make("card_removed", {"player_id": "p1", "card_uid": reply, "from": "deck"})))
	assert_false(result["state"]["dudes"][0]["powers"].has(reply), "left the powers list")
	assert_false(result["state"]["dudes"][0]["cards"].has(reply), "left the cards")
