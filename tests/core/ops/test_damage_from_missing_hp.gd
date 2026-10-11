## Tests for task 039: the "damage_from_missing_hp" op (Nothing to Lose). The hit's base damage is the
## actor's max_hp - hp when the effect runs, capped at "cap", then the normal damage order.
## Rules: core/ops/damage_from_missing_hp.gd. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Ops := preload("res://core/ops/ops.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const TomFixtures := preload("res://tests/core/ops/tom_fixtures.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 3939

## Hype given to Tom before each play, so cost never gets in the way.
const PLENTY_OF_HYPE: int = 99

## The cap on this file's cards, as on Nothing to Lose.
const CAP: int = 30

## Id of the Nothing to Lose test card: an Attack whose only effect is the op.
const NOTHING_ID: String = "neutral_test_nothing_to_lose"

## Id of a Skill with the same effect, to show a non-attack gets no Swole (G3).
const SKILL_ID: String = "neutral_test_missing_hp_skill"

## Id of an Attack that hurts Tom first, then hits with the op, to show the base is read when the
## effect runs.
const HURT_FIRST_ID: String = "neutral_test_hurt_then_hit"

## Self-damage the HURT_FIRST_ID card deals before its hit.
const HURT_FIRST_SELF_DAMAGE: int = 5

## Id of a plain 10-damage Attack, the yardstick for the damage order test.
const PLAIN_TEN_ID: String = "neutral_test_plain_ten"

## This file's own test cards, by id, added to the Tom fixture ruleset. Shapes follow
## core/schema/card_def.gd. Cost 0 so Hype never matters.
const CARDS := {
	NOTHING_ID: {"id": NOTHING_ID, "name": "Nothing to Lose", "owner": "neutral", "type": "attack", "rarity": "common",
		"cost": 0, "target": "enemy", "effects": [{"op": "damage_from_missing_hp", "cap": CAP}],
		"keywords": [], "crunch": null, "upgrade": {}},
	SKILL_ID: {"id": SKILL_ID, "name": "Missing HP Skill", "owner": "neutral", "type": "skill", "rarity": "common",
		"cost": 0, "target": "enemy", "effects": [{"op": "damage_from_missing_hp", "cap": CAP}],
		"keywords": [], "crunch": null, "upgrade": {}},
	HURT_FIRST_ID: {"id": HURT_FIRST_ID, "name": "Hurt Then Hit", "owner": "neutral", "type": "attack", "rarity": "common",
		"cost": 0, "target": "enemy",
		"effects": [{"op": "self_damage", "amount": HURT_FIRST_SELF_DAMAGE}, {"op": "damage_from_missing_hp", "cap": CAP}],
		"keywords": [], "crunch": null, "upgrade": {}},
	PLAIN_TEN_ID: {"id": PLAIN_TEN_ID, "name": "Plain Ten", "owner": "neutral", "type": "attack", "rarity": "common",
		"cost": 0, "target": "enemy", "effects": [{"op": "damage", "amount": 10}],
		"keywords": [], "crunch": null, "upgrade": {}},
}


## Returns the Tom fixture ruleset with this file's cards added; asserts it built.
func _rules() -> Dictionary:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset(CARDS)
	assert_false(rules.is_empty(), "the test ruleset builds")
	return rules


## Returns a solo fight of test_tom (80 max HP) against the Hitter (e11), in turn 1's player phase,
## with Tom at the given HP. rules: the ruleset. hp: Tom's HP, 1..max_hp.
func _fight(rules: Dictionary, hp: int) -> Dictionary:
	# state: the fight.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_tom"], ["test_hitter"])
	assert_false(state.is_empty(), "the fight starts")
	state["dudes"][0]["hp"] = hp
	state["dudes"][0]["hype"] = PLENTY_OF_HYPE
	return state


## Gives Tom a copy of a card, plays it at e11 and returns the damage of the first damage_dealt event
## on e11 (before Guard), or -1 if there is none. Asserts the play is accepted.
## rules: the ruleset. state: a fight from _fight(). card_id: the card to play.
func _hit_on_enemy(rules: Dictionary, state: Dictionary, card_id: String) -> int:
	# uid: the copy put in hand.
	var uid: String = Fixtures.give(state, 0, card_id)
	# result: apply()'s result.
	var result: Dictionary = Core.apply(rules, state, Fixtures.play("p1", state["dudes"][0]["last_seq"] + 1, uid, "e11"))
	assert_eq(result["reject"], "", "%s is accepted" % card_id)
	for event: Dictionary in result["events"]:
		if event["type"] == "damage_dealt" and event["target_id"] == "e11":
			return event["amount"]
	return -1


## Ops.check accepts a cap of 0 or more and refuses a missing, negative or non-int cap and unknown fields.
func test_check_fields() -> void:
	for cap: int in [0, CAP]:
		assert_eq(Ops.check({"op": "damage_from_missing_hp", "cap": cap}), [] as Array[String], "cap %d" % cap)
	for bad: Dictionary in [{}, {"cap": -1}, {"cap": "30"}, {"cap": 30.5}, {"cap": CAP, "amount": 5}]:
		# effect: the bad effect.
		var effect: Dictionary = bad.duplicate()
		effect["op"] = "damage_from_missing_hp"
		assert_eq(Ops.check(effect).size(), 1, "refused: %s" % str(bad))


## The base is Tom's missing HP, capped at cap: full HP 0, 10 missing 10, exactly cap missing cap,
## more than cap missing cap. Tom has no Swole and the Hitter no statuses, so base = damage dealt.
func test_base_is_missing_hp_capped() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# rows: [Tom's HP out of 80, damage expected].
	var rows: Array = [[80, 0], [70, 10], [80 - CAP, CAP], [20, CAP]]
	for row: Array in rows:
		assert_eq(_hit_on_enemy(rules, _fight(rules, row[0]), NOTHING_ID), row[1], "Tom at %d/80" % row[0])


## The base is read when the effect runs: self-damage earlier on the same card counts.
func test_base_is_read_after_earlier_effects() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# start_hp: Tom's HP before the card; he is missing 5, then 5 more after the self-damage.
	var start_hp: int = 75
	assert_eq(_hit_on_enemy(rules, _fight(rules, start_hp), HURT_FIRST_ID), 80 - start_hp + HURT_FIRST_SELF_DAMAGE)


## On an Attack card it is attack damage (G3): with Swole on Tom and Exposed on the enemy, a base of 10
## deals exactly what a plain 10-damage Attack deals in the same state, and more than 10.
func test_follows_the_damage_order() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# dealt: [the op's hit, the plain Attack's hit], each in a fresh fight with the same set-up.
	var dealt: Array = []
	for card_id: String in [NOTHING_ID, PLAIN_TEN_ID]:
		# state: Tom missing 10 HP, with 2 Swole; the Hitter Exposed.
		var state: Dictionary = _fight(rules, 70)
		state["dudes"][0]["swole"] = 2
		state["combat"]["enemies"][0]["statuses"]["exposed"] = 1
		dealt.append(_hit_on_enemy(rules, state, card_id))
	assert_eq(dealt[0], dealt[1], "same as damage 10 under Swole and Exposed")
	assert_true(dealt[0] > 10, "Swole and Exposed applied")


## On a Skill it is not attack damage (G3): Swole does not apply, so it deals exactly the base.
func test_skill_card_is_not_attack_damage() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: Tom missing 10 HP, with 2 Swole.
	var state: Dictionary = _fight(rules, 70)
	state["dudes"][0]["swole"] = 2
	assert_eq(_hit_on_enemy(rules, state, SKILL_ID), 10)


## At full HP the base is 0, but it is still a hit: Swole raises it, as for any damage effect.
func test_full_hp_still_adds_swole() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: Tom at full HP with 3 Swole.
	var state: Dictionary = _fight(rules, 80)
	state["dudes"][0]["swole"] = 3
	assert_eq(_hit_on_enemy(rules, state, NOTHING_ID), 3)
