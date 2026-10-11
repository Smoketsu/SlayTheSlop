## Tests for task 035: cards with target "ally" (Assist cards, Bro Hug). The player picks a Dude who
## is not Passed Out, their own included (G62), and the card's guard effects give the Guard to that
## Dude: the giver's Chill applies, the receiver's Hungover reduces it. Rules: core/combat/play.gd
## targets(), core/ops/guard.gd ON_TARGETS_KEY. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Event := preload("res://core/schema/event.gd")
const Ratio := preload("res://core/ops/ratio.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const TomFixtures := preload("res://tests/core/ops/tom_fixtures.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 3535

## Hype given to the player before each play, so cost never gets in the way.
const PLENTY_OF_HYPE: int = 99

## Id of the Bro Hug test card, shaped as task 012's proposal writes tom_bro_hug.
const BRO_HUG_ID: String = "neutral_test_bro_hug"

## Guard Bro Hug gives (its proposed base amount).
const BRO_HUG_GUARD: int = 7

## This file's own test cards, by id, added to the Tom fixture ruleset (which already holds
## tests/core/combat/fixtures.gd's "neutral_test_spot", an ally card giving 4 Guard).
const CARDS := {
	BRO_HUG_ID: {"id": BRO_HUG_ID, "name": "Bro Hug", "owner": "neutral", "type": "skill", "rarity": "common",
		"cost": 1, "target": "ally", "effects": [{"op": "guard", "amount": BRO_HUG_GUARD}],
		"keywords": ["assist"], "crunch": null, "upgrade": {}, "text": "Target Dude gains 7 Guard"},
}


## Returns the Tom fixture ruleset with this file's cards added; asserts it built.
func _rules() -> Dictionary:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset(CARDS)
	assert_false(rules.is_empty(), "the test ruleset builds")
	return rules


## Returns a fight of test_dude players (p1, p2 ...) against the Turtle (e-uid after their cards), in
## turn 1's player phase, every Dude with PLENTY_OF_HYPE Hype and no Guard.
## rules: the ruleset. party_size: how many Dudes, 1 or more.
func _fight(rules: Dictionary, party_size: int) -> Dictionary:
	# dude_ids: one test_dude per seat.
	var dude_ids: Array = []
	for seat: int in party_size:
		dude_ids.append("test_dude")
	# state: the fight.
	var state: Dictionary = Fixtures.fight(rules, SEED, dude_ids, ["test_turtle"])
	assert_false(state.is_empty(), "the fight starts")
	for dude: Dictionary in state["dudes"]:
		dude["hype"] = PLENTY_OF_HYPE
		dude["guard"] = 0
	return state


## Gives p1 a copy of a card and plays it at target_id. Returns apply()'s result.
## rules: the ruleset. state: a fight. card_id: the card. target_id: the request's target_id.
func _play(rules: Dictionary, state: Dictionary, card_id: String, target_id: String) -> Dictionary:
	# uid: the copy put in p1's hand.
	var uid: String = Fixtures.give(state, 0, card_id)
	return Core.apply(rules, state, Fixtures.play("p1", state["dudes"][0]["last_seq"] + 1, uid, target_id))


## Returns the guard_changed events of a result, in order.
## result: apply()'s result.
func _guard_events(result: Dictionary) -> Array:
	return result["events"].filter(func(event: Dictionary) -> bool: return event["type"] == "guard_changed")


## Solo: Bro Hug on the player's own Dude gives them 7 Guard (GDD "Assist": in solo it targets yourself).
func test_solo_bro_hug_guards_yourself() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# result: Bro Hug on p1.
	var result: Dictionary = _play(rules, _fight(rules, 1), BRO_HUG_ID, "p1")
	assert_eq(result["reject"], "")
	assert_eq(_guard_events(result), [Event.make("guard_changed", {"target_id": "p1", "delta": BRO_HUG_GUARD, "guard": BRO_HUG_GUARD})])


## Illegal ally targets are bad_target and change nothing: no target, an enemy, an unknown id, and
## (co-op) a Passed Out Dude.
func test_bad_ally_targets() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: two Dudes, p2 Passed Out.
	var state: Dictionary = _fight(rules, 2)
	state["dudes"][1]["passed_out"] = true
	state["dudes"][1]["hp"] = 0
	# enemy: the Turtle's uid.
	var enemy: String = state["combat"]["enemies"][0]["uid"]
	for target_id: String in ["", enemy, "p9", "p2"]:
		assert_eq(_play(rules, state, BRO_HUG_ID, target_id)["reject"], "bad_target", "target %s" % target_id)


## Co-op shape (2 Dudes in state, no networking): p1's Bro Hug on p2 guards p2 only.
func test_coop_bro_hug_guards_the_teammate() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# result: p1's Bro Hug on p2.
	var result: Dictionary = _play(rules, _fight(rules, 2), BRO_HUG_ID, "p2")
	assert_eq(result["reject"], "")
	assert_eq(_guard_events(result), [Event.make("guard_changed", {"target_id": "p2", "delta": BRO_HUG_GUARD, "guard": BRO_HUG_GUARD})])
	assert_eq(result["state"]["dudes"][0]["guard"], 0, "the player who hugs gains nothing")


## G62: the giver's Chill applies (as Swole is the attacker's), not the receiver's; the receiver's
## Hungover reduces it (Hungover is "gains 25% less Guard from cards").
func test_giver_chill_and_receiver_hungover() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: p1 with 2 Chill, p2 with 5 Chill.
	var state: Dictionary = _fight(rules, 2)
	state["dudes"][0]["chill"] = 2
	state["dudes"][1]["chill"] = 5
	assert_eq(_guard_events(_play(rules, state.duplicate(true), BRO_HUG_ID, "p2"))[0]["delta"], BRO_HUG_GUARD + 2,
		"p1's Chill, not p2's")
	# hungover: the same, p2 Hungover; p1 is not.
	var hungover: Dictionary = state.duplicate(true)
	hungover["dudes"][1]["statuses"]["hungover"] = 1
	assert_eq(_guard_events(_play(rules, hungover, BRO_HUG_ID, "p2"))[0]["delta"],
		Ratio.floor_times(BRO_HUG_GUARD + 2, Ratio.from_constant(rules["constants"]["HUNGOVER_MULT"])), "p2's Hungover")
	# p1_hungover: only the giver Hungover; the receiver's Guard is not reduced.
	var p1_hungover: Dictionary = state.duplicate(true)
	p1_hungover["dudes"][0]["statuses"]["hungover"] = 1
	assert_eq(_guard_events(_play(rules, p1_hungover, BRO_HUG_ID, "p2"))[0]["delta"], BRO_HUG_GUARD + 2, "giver's Hungover ignored")


## A guard effect on any other card still lands on the player, whatever its target: an enemy-target
## card with guard (Stare Down's shape) guards the player, not the enemy.
func test_guard_on_other_cards_still_lands_on_the_actor() -> void:
	# extra: this file's cards plus an enemy-target Skill that gains Guard.
	var extra: Dictionary = CARDS.duplicate()
	extra["neutral_test_stare"] = {"id": "neutral_test_stare", "name": "Stare", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 1, "target": "enemy", "effects": [{"op": "guard", "amount": 5}],
		"keywords": [], "crunch": null, "upgrade": {}}
	# rules: the ruleset with extra.
	var rules: Dictionary = TomFixtures.ruleset(extra)
	# state: a solo fight.
	var state: Dictionary = _fight(rules, 1)
	# result: Stare at the Turtle.
	var result: Dictionary = _play(rules, state, "neutral_test_stare", state["combat"]["enemies"][0]["uid"])
	assert_eq(result["reject"], "")
	assert_eq(_guard_events(result), [Event.make("guard_changed", {"target_id": "p1", "delta": 5, "guard": 5})])
