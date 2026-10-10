## Tests for core/combat/upgrades.gd: applying a card's "upgrade" paths (task 025, G15). Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Upgrades := preload("res://core/combat/upgrades.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")

## A card definition with nested values to upgrade, shaped as core/schema/card_def.gd.
const CARD := {"id": "neutral_test_combo", "name": "Combo", "owner": "neutral", "type": "attack", "rarity": "common",
	"cost": 2, "target": "enemy", "effects": [{"op": "damage", "amount": 8, "hits": 1},
		{"op": "apply_status", "status": "broken_arm", "stacks": 1}],
	"keywords": [], "crunch": null, "upgrade": {}}


## Returns CARD with this upgrade map.
## upgrade: path -> new value.
func _with(upgrade: Dictionary) -> Dictionary:
	# card: a writable copy.
	var card: Dictionary = CARD.duplicate(true)
	card["upgrade"] = upgrade
	return card


## Paths set numbers in lists and top-level fields; the original is not changed.
func test_paths_apply() -> void:
	# card: Arm Bar's GDD upgrade plus a cost change.
	var card: Dictionary = _with({"effects[0].amount": 11, "cost": 1, "effects[1].stacks": 2})
	# result: the upgraded definition.
	var result: Dictionary = Upgrades.upgraded(card)
	assert_true(result["ok"], result["error"])
	assert_eq(result["definition"]["effects"][0]["amount"], 11)
	assert_eq(result["definition"]["effects"][1]["stacks"], 2)
	assert_eq(result["definition"]["cost"], 1)
	assert_eq(card["effects"][0]["amount"], 8, "the definition itself is unchanged")
	assert_true(Upgrades.can_upgrade(card))


## G15: an empty upgrade, a missing step, an index out of range, a type change, a bad path or a
## result the schema refuses cannot be upgraded.
func test_bad_upgrades() -> void:
	for upgrade: Dictionary in [{}, {"effects[2].amount": 9}, {"effects[0].power": 9}, {"effects[0].amount": "nine"},
			{"effects[x].amount": 9}, {"effects[0]amount": 9}, {"effects[-1].amount": 9}, {"cost": -5}, {"": 1}]:
		assert_false(Upgrades.can_upgrade(_with(upgrade)), "refused: %s" % str(upgrade))


## definition_of() reads the copy's instance: upgraded copies get the upgraded definition, one that
## cannot be upgraded gets {}, an unknown copy gets {}.
func test_definition_of() -> void:
	# rules: the combat fixtures (neutral_test_lifted: 6 -> 9 damage; neutral_test_bad_lift: broken).
	var rules: Dictionary = Fixtures.ruleset()
	# dude: a Dude owning three copies.
	var dude: Dictionary = {"cards": {"c1": {"def_id": "neutral_test_lifted", "upgraded": false},
		"c2": {"def_id": "neutral_test_lifted", "upgraded": true}, "c3": {"def_id": "neutral_test_bad_lift", "upgraded": true}}}
	assert_eq(Upgrades.definition_of(rules, dude, "c1")["effects"][0]["amount"], 6)
	assert_eq(Upgrades.definition_of(rules, dude, "c2")["effects"][0]["amount"], 9)
	assert_eq(Upgrades.definition_of(rules, dude, "c3"), {})
	assert_eq(Upgrades.definition_of(rules, dude, "c4"), {})
