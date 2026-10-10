## Tests for drinking Brews, the use_brew request (core/combat/brews.gd, task 021): its rejects, its
## bookkeeping, and one test per GDD Brew whose ops exist. Lane: core (Agent A).
##
## Uses tests/core/items/item_fixtures.gd until task 014's real data merges. Energy Drink and
## Special Brownie wait on tasks 013 and 015; their tests are listed in the task 021 log, not here.
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Event := preload("res://core/schema/event.gd")
const Request := preload("res://core/schema/request.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Party := preload("res://core/combat/party.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const ItemFixtures := preload("res://tests/core/items/item_fixtures.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 21022


## Returns a solo fight against one Dummy (20 HP, hits for 5) with p1 holding these Brews.
## rules: the item ruleset. brew_ids: p1's Brews, slot order.
func _fight(rules: Dictionary, brew_ids: Array) -> Dictionary:
	return ItemFixtures.fight(rules, SEED, [], brew_ids, ["test_dummy"])["state"]


## Applies a request that must be applied: checks state_version + 1, every event and the new state.
## Returns the result.
## rules: the ruleset. state: the state. request: the request.
func _apply(rules: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], "", "request %s should apply" % var_to_str(request))
	if result["reject"] != "":
		return result
	assert_eq(result["state"]["state_version"], state["state_version"] + 1, "state_version rises by exactly 1")
	for event: Variant in result["events"]:
		assert_no_errors(Event.check(event), "event %s" % var_to_str(event))
	assert_no_errors(RunState.check(result["state"]), "state after %s" % request["type"])
	return result


## Asserts that request is refused with reason and changes nothing.
## rules: the ruleset. state: the state. request: the request. reason: the expected code.
func _assert_rejected(rules: Dictionary, state: Dictionary, request: Dictionary, reason: String) -> void:
	# before: a deep copy of the state.
	var before: Dictionary = state.duplicate(true)
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], reason, "reject for %s" % var_to_str(request))
	assert_true(is_same(result["state"], state), reason + ": the state passed in comes back")
	assert_eq(result["state"], before, reason + ": unchanged")
	assert_eq(result["events"], [], reason + ": no events")
	assert_true(Request.REJECT_REASONS.has(reason), reason + " is a known reject code")


## Light Beer ("Heal 10 HP") and the use_brew bookkeeping: no Hype spent, the slot empties and later
## Brews move down, brews_drunk + 1, cards_played_this_turn unchanged, last_seq set, events in order.
func test_light_beer_and_bookkeeping() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight with two Brews, p1 at 15 HP.
	var state: Dictionary = _fight(rules, ["light_beer", "protein_shake"])
	state["dudes"][0]["hp"] = 15
	# result: drinking slot 0.
	var result: Dictionary = _apply(rules, state, ItemFixtures.drink("p1", 0, 0))
	# dude: p1 afterwards.
	var dude: Dictionary = result["state"]["dudes"][0]
	assert_eq(dude["hp"], 25)
	assert_eq(dude["brews"], ["protein_shake"], "slot emptied, the next Brew moves down")
	assert_eq(dude["hype"], state["dudes"][0]["hype"], "no Hype spent")
	assert_eq(dude["cards_played_this_turn"], 0)
	assert_eq(dude["last_seq"], 0)
	assert_eq(result["state"]["brews_drunk"], 1)
	assert_eq(result["events"], [
		Event.make("brew_used", {"player_id": "p1", "slot": 0, "brew_id": "light_beer", "target_id": ""}),
		Event.make("healed", {"target_id": "p1", "amount": 10, "hp": 25}),
	])
	# capped: at 28 HP the heal stops at max HP.
	var capped: Dictionary = _fight(rules, ["light_beer"])
	capped["dudes"][0]["hp"] = 28
	assert_eq(_apply(rules, capped, ItemFixtures.drink("p1", 0, 0, "p1"))["state"]["dudes"][0]["hp"], 30)


## Every refusal, each leaving the state untouched.
func test_rejects() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight with two Brews.
	var state: Dictionary = _fight(rules, ["light_beer", "shot_of_courage"])
	for slot: int in [2, -1, 9]:
		_assert_rejected(rules, state, ItemFixtures.drink("p1", 0, slot), "empty_slot")
	_assert_rejected(rules, state, ItemFixtures.drink("p1", 0, 0, "e11"), "bad_target")
	_assert_rejected(rules, state, ItemFixtures.drink("p1", 0, 1, "p1"), "bad_target")
	_assert_rejected(rules, state, ItemFixtures.drink("p1", 0, 1, "e11"), "bad_target")
	_assert_rejected(rules, state, ItemFixtures.drink("p9", 0, 0), "unknown_player")
	# drunk: after drinking slot 0 with seq 0, seq 0 is stale.
	var drunk: Dictionary = _apply(rules, state, ItemFixtures.drink("p1", 0, 0))["state"]
	_assert_rejected(rules, drunk, ItemFixtures.drink("p1", 0, 0), "stale_seq")
	# odd: unknown and unrunnable Brews, and an enemy-targeted one.
	var odd: Dictionary = _fight(rules, ["no_such_brew", "test_mystery_brew", "test_dart"])
	_assert_rejected(rules, odd, ItemFixtures.drink("p1", 0, 0), "unplayable")
	_assert_rejected(rules, odd, ItemFixtures.drink("p1", 0, 1), "unplayable")
	_assert_rejected(rules, odd, ItemFixtures.drink("p1", 0, 2), "bad_target")
	_assert_rejected(rules, odd, ItemFixtures.drink("p1", 0, 2, "e99"), "bad_target")
	assert_eq(_apply(rules, odd, ItemFixtures.drink("p1", 0, 2, "e11"))["state"]["combat"]["enemies"][0]["statuses"],
		{"noodle_arms": 1}, "the enemy-targeted Brew works on a live enemy")
	# outside: the same Dude outside any fight.
	var outside: Dictionary = Party.build_run_state(rules, SEED, ["test_dude"])["state"]
	outside["dudes"][0]["brew_slots"] = 1
	outside["dudes"][0]["brews"] = ["light_beer"]
	_assert_rejected(rules, outside, ItemFixtures.drink("p1", 0, 0), "wrong_phase")
	# out: p1 Passed Out in a two-player fight.
	var out: Dictionary = ItemFixtures.fight(rules, SEED, [], ["light_beer"], ["test_dummy"], ["test_dude", "test_tiny"])["state"]
	out["dudes"][0]["hp"] = 0
	out["dudes"][0]["passed_out"] = true
	_assert_rejected(rules, out, ItemFixtures.drink("p1", 0, 0), "passed_out")


## A Brew can be drunk while the player is already Ready (still the player phase), and in a later turn.
func test_any_time_in_player_phase() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a two-player fight; p1 presses Ready, so the phase stays "player" until p2 does.
	var state: Dictionary = ItemFixtures.fight(rules, SEED, [], ["light_beer", "light_beer"], ["test_turtle"],
		["test_dude", "test_tiny"])["state"]
	state = _apply(rules, state, Fixtures.set_ready("p1", 0))["state"]
	state = _apply(rules, state, ItemFixtures.drink("p1", 1, 0))["state"]
	assert_eq(state["brews_drunk"], 1)
	state = _apply(rules, state, Fixtures.set_ready("p2", 0))["state"]
	assert_eq(state["combat"]["turn"], 2)
	state = _apply(rules, state, ItemFixtures.drink("p1", 2, 0))["state"]
	assert_eq([state["brews_drunk"], state["dudes"][0]["brews"]], [2, []])


## Protein Shake: "Gain 3 Swole for this fight": Swole + 3 now (a Jab deals 9), recorded in
## fight_stat_changes, and taken back when the fight ends; Gear Swole stays.
func test_protein_shake() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight with the shake and the Lifting Belt (+1 Swole for the run).
	var state: Dictionary = ItemFixtures.fight(rules, SEED, ["lifting_belt"], ["protein_shake"], ["test_dummy"])["state"]
	state = _apply(rules, state, ItemFixtures.drink("p1", 0, 0))["state"]
	assert_eq(state["dudes"][0]["swole"], 4)
	assert_eq(state["combat"]["fight_stat_changes"], {"p1": {"swole": 3}})
	# jab: a Jab in hand.
	var jab: String = Fixtures.give(state, 0, "neutral_test_jab")
	state = _apply(rules, state, Fixtures.play("p1", 1, jab, "e11"))["state"]
	assert_eq(state["combat"]["enemies"][0]["hp"], 10, "6 + 4 Swole")
	state["combat"]["enemies"][0]["hp"] = 1
	# finisher: a Jab to end the fight.
	var finisher: String = Fixtures.give(state, 0, "neutral_test_jab")
	# result: the winning play.
	var result: Dictionary = _apply(rules, state, Fixtures.play("p1", 2, finisher, "e11"))
	assert_eq(result["state"]["dudes"][0]["swole"], 1, "the fight's +3 is gone; the belt's +1 stays")
	assert_eq(result["state"]["combat"]["fight_stat_changes"], {})
	# ended: where fight_ended is.
	var ended: int = result["events"].find(Event.make("fight_ended", {"result": "won"}))
	assert_eq(result["events"][ended + 1], Event.make("stat_changed", {"target_id": "p1", "stat": "swole", "delta": -3, "value": 1}))


## Shot of Courage: "Apply 3 Exposed to all enemies"; a Jab then deals 6 x 1.5.
func test_shot_of_courage() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight against a Dummy and a Turtle.
	var state: Dictionary = ItemFixtures.fight(rules, SEED, [], ["shot_of_courage"], ["test_dummy", "test_turtle"])["state"]
	state = _apply(rules, state, ItemFixtures.drink("p1", 0, 0))["state"]
	assert_eq([state["combat"]["enemies"][0]["statuses"], state["combat"]["enemies"][1]["statuses"]],
		[{"exposed": 3}, {"exposed": 3}])
	# jab: a Jab in hand.
	var jab: String = Fixtures.give(state, 0, "neutral_test_jab")
	assert_eq(_apply(rules, state, Fixtures.play("p1", 1, jab, "e11"))["state"]["combat"]["enemies"][0]["hp"], 11)


## Hair of the Dog: "Remove all your debuffs and Tap every Junk card in your hand". Debuffs are G27's
## four; other cards stay in hand.
func test_hair_of_the_dog() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a fight with p1 carrying all four debuffs and two Junk cards in hand.
	var state: Dictionary = _fight(rules, ["hair_of_the_dog"])
	state["dudes"][0]["statuses"] = {"exposed": 2, "foggy": 1, "hungover": 1, "noodle_arms": 3}
	# junk: two Junk cards.
	var junk: Array = [Fixtures.give(state, 0, "junk_test_dud"), Fixtures.give(state, 0, "junk_test_dud")]
	# hand: the hand before, Junk included.
	var hand: Array = state["dudes"][0]["hand"].duplicate()
	# result: drinking it.
	var result: Dictionary = _apply(rules, state, ItemFixtures.drink("p1", 0, 0))
	# dude: p1 afterwards.
	var dude: Dictionary = result["state"]["dudes"][0]
	assert_eq(dude["statuses"], {})
	assert_eq(dude["tapped_pile"], junk)
	assert_eq(dude["hand"], hand.filter(func(uid: String) -> bool: return not junk.has(uid)), "other cards stay")
	assert_eq(ItemFixtures.of_type(result["events"], "status_changed").map(func(e: Dictionary) -> String: return e["status"]),
		["exposed", "foggy", "hungover", "noodle_arms"])
	assert_eq(ItemFixtures.of_type(result["events"], "card_moved").size(), 2)


## Party Bowl: "Every player heals 8 HP": solo, the drinker; in co-op every Dude who is not Passed
## Out, each capped at max HP.
func test_party_bowl() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# solo: a solo fight at 10 HP.
	var solo: Dictionary = _fight(rules, ["party_bowl"])
	solo["dudes"][0]["hp"] = 10
	assert_eq(_apply(rules, solo, ItemFixtures.drink("p1", 0, 0))["state"]["dudes"][0]["hp"], 18)
	# duo: p1 (30 max) at 10 and p2 (10 max) at 3.
	var duo: Dictionary = ItemFixtures.fight(rules, SEED, [], ["party_bowl"], ["test_turtle"], ["test_dude", "test_tiny"])["state"]
	duo["dudes"][0]["hp"] = 10
	duo["dudes"][1]["hp"] = 3
	# after: both Dudes after the bowl.
	var after: Array = _apply(rules, duo, ItemFixtures.drink("p1", 0, 0))["state"]["dudes"]
	assert_eq([after[0]["hp"], after[1]["hp"]], [18, 10])
	# down: p2 Passed Out is not healed.
	duo["dudes"][1]["hp"] = 0
	duo["dudes"][1]["passed_out"] = true
	after = _apply(rules, duo, ItemFixtures.drink("p1", 0, 0))["state"]["dudes"]
	assert_eq([after[0]["hp"], after[1]["hp"], after[1]["passed_out"]], [18, 0, true])


## Smelling Salts, solo: "the next time you would pass out this fight, stay at 1 HP instead". Once:
## the second knock-out passes out. In co-op its waking rule is not built, so it is unplayable.
func test_smelling_salts() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: a solo fight against a Brute that hits for 50; p1 has 30 HP.
	var state: Dictionary = ItemFixtures.fight(rules, SEED, [], ["smelling_salts"], ["test_brute"])["state"]
	state = _apply(rules, state, ItemFixtures.drink("p1", 0, 0))["state"]
	assert_eq(state["combat"]["pass_out_saves"], {"p1": 1})
	# result: ending the turn; the Brute's hit would knock p1 out.
	var result: Dictionary = _apply(rules, state, Fixtures.set_ready("p1", 1))
	state = result["state"]
	assert_eq([state["dudes"][0]["hp"], state["dudes"][0]["passed_out"], state["combat"]["phase"]], [1, false, "player"])
	assert_eq(state["combat"]["pass_out_saves"], {}, "used up")
	# hit: where the Brute's hit landed.
	var hit: int = result["events"].find(Event.make("damage_dealt", {"source_id": "e11", "target_id": "p1", "amount": 50,
		"blocked": 0, "hp_lost": 30}))
	assert_eq(result["events"][hit + 1], Event.make("pass_out_prevented", {"player_id": "p1", "hp": 1}))
	assert_eq(ItemFixtures.of_type(result["events"], "dude_passed_out"), [])
	state = _apply(rules, state, Fixtures.set_ready("p1", 2))["state"]
	assert_eq([state["dudes"][0]["passed_out"], state["combat"]["result"]], [true, "lost"], "only once")
	# duo: the same Brew in a two-player fight.
	var duo: Dictionary = ItemFixtures.fight(rules, SEED, [], ["smelling_salts"], ["test_turtle"], ["test_dude", "test_tiny"])["state"]
	_assert_rejected(rules, duo, ItemFixtures.drink("p1", 0, 0, "p2"), "unplayable")


## Gear reacts to a Brew's effects as to a card's (test Brews, since no slice Brew applies Ick or
## deals damage): Body Spray fires on a Brew's Ick, and a Brew that wins the fight runs fight_end
## Gear (Unused Gym Membership) in the same request. Brew damage is not attack damage.
func test_gear_reacts_to_brews() -> void:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# state: Body Spray and Tom's starting Gear, an Ick Brew and a damage Brew, p1 at 10 HP and
	# 2 Swole (which must not raise Brew damage).
	var state: Dictionary = ItemFixtures.fight(rules, SEED, ["tom_unused_gym_membership", "tom_whole_can_of_body_spray"],
		["test_stink", "test_bomb"], ["test_dummy"])["state"]
	state["dudes"][0]["hp"] = 10
	state["dudes"][0]["swole"] = 2
	state = _apply(rules, state, ItemFixtures.drink("p1", 0, 0, "e11"))["state"]
	assert_eq(state["combat"]["enemies"][0]["hp"], 16, "2 Ick -> 4 Body Spray damage")
	state["combat"]["enemies"][0]["hp"] = 5
	# result: the damage Brew finishes the Dummy.
	var result: Dictionary = _apply(rules, state, ItemFixtures.drink("p1", 1, 0, "e11"))
	assert_eq(result["state"]["combat"]["result"], "won")
	assert_eq(result["state"]["dudes"][0]["hp"], 16, "fight_end Gear ran: 10 + 6")
	assert_true(result["events"].has(Event.make("damage_dealt", {"source_id": "p1", "target_id": "e11", "amount": 5,
		"blocked": 0, "hp_lost": 5})), "exactly 5: Swole does not apply to Brew damage")
