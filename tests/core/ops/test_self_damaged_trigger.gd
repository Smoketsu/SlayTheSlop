## Tests for task 037: the Power trigger "self_damaged" (Tough Skull). It fires each time the Power's
## own Dude takes damage from a self_damage effect of a card they played, and never from enemies,
## Junk (Burn), or another Dude's card. Rules: core/combat/powers.gd, core/ops/ops.gd
## PLAYED_CARD_KEY, core/combat/play.gd. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Event := preload("res://core/schema/event.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const TomFixtures := preload("res://tests/core/ops/tom_fixtures.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 3737

## Hype given to every Dude before the plays, so cost never gets in the way.
const PLENTY_OF_HYPE: int = 99

## Id of the Tough Skull test Power, shaped as task 012's proposal writes tom_tough_skull.
const TOUGH_SKULL_ID: String = "neutral_test_tough_skull"

## Guard Tough Skull gives each time it fires (its proposed amount).
const SKULL_GUARD: int = 3

## Id of Skull Bash in the Tom fixtures: 10 damage, then Tom takes SKULL_BASH_SELF_DAMAGE.
const SKULL_BASH_ID: String = "tom_test_skull_bash"

## Self-damage Skull Bash deals to Tom (the GDD's 2).
const SKULL_BASH_SELF_DAMAGE: int = 2

## Id of a test Attack whose self_damage is 0, which must fire nothing.
const ZERO_ID: String = "neutral_test_zero_self_damage"

## Id of a Burn-shaped test Junk card (unplayable, cost -1 as Junk is): at End of turn in hand, its
## owner takes 2 damage.
const BURN_ID: String = "junk_test_burn"

## This file's own test cards, by id, added to the Tom fixture ruleset.
const CARDS := {
	TOUGH_SKULL_ID: {"id": TOUGH_SKULL_ID, "name": "Tough Skull", "owner": "neutral", "type": "power", "rarity": "uncommon",
		"cost": 0, "target": "none", "effects": [],
		"power_triggers": [{"when": "self_damaged", "target": "self", "effects": [{"op": "guard", "amount": SKULL_GUARD}]}],
		"keywords": [], "crunch": null, "upgrade": {}},
	ZERO_ID: {"id": ZERO_ID, "name": "Zero", "owner": "neutral", "type": "attack", "rarity": "common",
		"cost": 0, "target": "enemy", "effects": [{"op": "damage", "amount": 1}, {"op": "self_damage", "amount": 0}],
		"keywords": [], "crunch": null, "upgrade": {}},
	BURN_ID: {"id": BURN_ID, "name": "Burn", "owner": "junk", "type": "junk", "rarity": "special",
		"cost": -1, "target": "none", "effects": [], "keywords": [], "crunch": null, "upgrade": {},
		"on_end_of_turn_in_hand": [{"op": "self_damage", "amount": 2}], "lasts": "fight"},
}


## Returns the Tom fixture ruleset with this file's cards added; asserts it built.
func _rules() -> Dictionary:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset(CARDS)
	assert_false(rules.is_empty(), "the test ruleset builds")
	return rules


## Returns a fight of test_tom players (p1, p2 ...) against the Hitter, in turn 1's player phase,
## every Dude with PLENTY_OF_HYPE Hype and no Guard.
## rules: the ruleset. party_size: how many Dudes, 1 or more.
func _fight(rules: Dictionary, party_size: int) -> Dictionary:
	# dude_ids: one test_tom per seat.
	var dude_ids: Array = []
	for seat: int in party_size:
		dude_ids.append("test_tom")
	# state: the fight.
	var state: Dictionary = Fixtures.fight(rules, SEED, dude_ids, ["test_hitter"])
	assert_false(state.is_empty(), "the fight starts")
	for dude: Dictionary in state["dudes"]:
		dude["hype"] = PLENTY_OF_HYPE
		dude["guard"] = 0
	return state


## Gives a Dude a copy of a card and plays it; asserts it is accepted. Returns apply()'s result.
## rules: the ruleset. state: a fight. seat: the player's seat, 0-based. card_id: the card.
## target_id: the request's target_id.
func _play(rules: Dictionary, state: Dictionary, seat: int, card_id: String, target_id: String) -> Dictionary:
	# dude: the player.
	var dude: Dictionary = state["dudes"][seat]
	# uid: the copy put in hand.
	var uid: String = Fixtures.give(state, seat, card_id)
	# result: apply()'s result.
	var result: Dictionary = Core.apply(rules, state, Fixtures.play(dude["player_id"], dude["last_seq"] + 1, uid, target_id))
	assert_eq(result["reject"], "", "%s is accepted" % card_id)
	return result


## Returns the power_triggered events with when "self_damaged" in an event list.
## events: an event list.
func _skull_fires(events: Array) -> Array:
	return events.filter(func(event: Dictionary) -> bool:
		return event["type"] == "power_triggered" and event["when"] == "self_damaged")


## Skull Bash with Tough Skull in play: after Tom's 2 self-damage, Tough Skull fires once and Tom
## gains 3 Guard, in that order.
func test_skull_bash_fires_tough_skull() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: Tough Skull in play.
	var state: Dictionary = _play(rules, _fight(rules, 1), 0, TOUGH_SKULL_ID, "")["state"]
	# result: Skull Bash at the Hitter.
	var result: Dictionary = _play(rules, state, 0, SKULL_BASH_ID, state["combat"]["enemies"][0]["uid"])
	# types: the event types after the card's own damage to the enemy, in order.
	var types: Array = result["events"].map(func(event: Dictionary) -> String: return event["type"])
	# self_hit: index of Tom's self-damage event.
	var self_hit: int = -1
	for i: int in result["events"].size():
		if result["events"][i]["type"] == "damage_dealt" and result["events"][i]["target_id"] == "p1":
			self_hit = i
	assert_true(self_hit != -1, "Tom took his self-damage")
	assert_eq(types.slice(self_hit, self_hit + 3), ["damage_dealt", "power_triggered", "guard_changed"])
	assert_eq(_skull_fires(result["events"]).size(), 1)
	assert_eq(result["state"]["dudes"][0]["guard"], SKULL_GUARD)


## It fires even when Guard takes all of the self-damage (like thorns, G49), and two copies both fire.
func test_fires_through_guard_and_per_copy() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: two Tough Skulls in play, Tom with 5 Guard.
	var state: Dictionary = _play(rules, _fight(rules, 1), 0, TOUGH_SKULL_ID, "")["state"]
	state = _play(rules, state, 0, TOUGH_SKULL_ID, "")["state"]
	state["dudes"][0]["guard"] = 5
	# result: Skull Bash.
	var result: Dictionary = _play(rules, state, 0, SKULL_BASH_ID, state["combat"]["enemies"][0]["uid"])
	assert_eq(_skull_fires(result["events"]).size(), 2, "one per copy")
	assert_eq(result["state"]["dudes"][0]["guard"], 5 - SKULL_BASH_SELF_DAMAGE + 2 * SKULL_GUARD)


## A self_damage of 0 deals nothing, so nothing fires.
func test_zero_self_damage_fires_nothing() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: Tough Skull in play.
	var state: Dictionary = _play(rules, _fight(rules, 1), 0, TOUGH_SKULL_ID, "")["state"]
	assert_eq(_skull_fires(_play(rules, state, 0, ZERO_ID, state["combat"]["enemies"][0]["uid"])["events"]), [])


## Burn's self-damage at End of turn and the Hitter's attack in the enemy phase fire nothing: neither is
## a card Tom played.
func test_junk_and_enemies_do_not_fire_it() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: Tough Skull in play and a Burn in Tom's hand.
	var state: Dictionary = _play(rules, _fight(rules, 1), 0, TOUGH_SKULL_ID, "")["state"]
	Fixtures.give(state, 0, BURN_ID)
	# result: Tom readies, so the turn ends (Burn hurts him) and the Hitter attacks.
	var result: Dictionary = Core.apply(rules, state, Fixtures.set_ready("p1", state["dudes"][0]["last_seq"] + 1))
	assert_eq(result["reject"], "")
	# hurt: damage events on Tom with no source (Burn) and from the Hitter.
	var hurt: Array = result["events"].filter(func(event: Dictionary) -> bool:
		return event["type"] == "damage_dealt" and event["target_id"] == "p1")
	assert_true(hurt.size() >= 2, "Burn and the Hitter both hit Tom (got %d)" % hurt.size())
	assert_eq(_skull_fires(result["events"]), [])


## When the self-damage Passes Out the Dude, nothing fires (a Passed Out Dude's Powers do not fire, G34).
func test_passed_out_by_it_fires_nothing() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: Tough Skull in play, Tom at 2 HP with no Guard, so Skull Bash's 2 Passes him Out.
	var state: Dictionary = _play(rules, _fight(rules, 1), 0, TOUGH_SKULL_ID, "")["state"]
	state["dudes"][0]["hp"] = SKULL_BASH_SELF_DAMAGE
	# result: Skull Bash.
	var result: Dictionary = _play(rules, state, 0, SKULL_BASH_ID, state["combat"]["enemies"][0]["uid"])
	assert_true(result["state"]["dudes"][0]["passed_out"], "Tom Passed Out")
	assert_eq(_skull_fires(result["events"]), [])


## Co-op shape: only the hurt Dude's own Powers fire. p2's Tough Skull ignores p1's Skull Bash, and
## p1's Skull Bash fires only p1's.
func test_only_the_hurt_dudes_powers_fire() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: two Dudes, p2 with Tough Skull in play.
	var state: Dictionary = _play(rules, _fight(rules, 2), 1, TOUGH_SKULL_ID, "")["state"]
	# result: p1 plays Skull Bash.
	var result: Dictionary = _play(rules, state, 0, SKULL_BASH_ID, state["combat"]["enemies"][0]["uid"])
	assert_eq(_skull_fires(result["events"]), [], "p2's Power ignores p1's self-damage")
	assert_eq(result["state"]["dudes"][1]["guard"], 0)
