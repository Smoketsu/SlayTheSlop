## Tests for the run tests' fight bot (tests/run/fixtures/run_helpers.gd bot_request), which
## tests/run/fixtures/run_bot.gd also uses. Task 035 follow-up: the bot plays Assist cards (target
## "ally") on its own Dude instead of skipping them. Lane: run (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const TomFixtures := preload("res://tests/core/ops/tom_fixtures.gd")
const Helpers := preload("res://tests/run/fixtures/run_helpers.gd")

## Seed for the fight. Any value works; fixed so every run is the same.
const SEED: int = 3535

## The ally test card in tests/core/combat/fixtures.gd: target "ally", 4 Guard.
const SPOT_ID: String = "neutral_test_spot"


## With only an ally card in hand, the bot plays it on its own Dude, and the core accepts it.
func test_bot_plays_an_ally_card_on_itself() -> void:
	# rules: the fixture ruleset (it holds neutral_test_spot).
	var rules: Dictionary = TomFixtures.ruleset()
	assert_false(rules.is_empty(), "the test ruleset builds")
	# state: a solo fight, p1 at full HP (no Brew), Bro Meter not full, only Spot in hand.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_turtle"])
	assert_false(state.is_empty(), "the fight starts")
	state["dudes"][0]["hand"] = []
	# spot: the ally card, the only card in hand.
	var spot: String = Fixtures.give(state, 0, SPOT_ID)
	# sent: the bot's request.
	var sent: Dictionary = Helpers.bot_request(rules, state, 0, Helpers.next_seq(state))
	assert_eq([sent["type"], sent.get("card_uid", ""), sent.get("target_id", "")], ["play_card", spot, "p1"])
	assert_eq(Core.validate(rules, state, sent), "", "the core accepts it")
