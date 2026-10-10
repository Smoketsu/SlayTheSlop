## Tests for the Gear and Brew definition shapes, core/schema/gear_def.gd and brew_def.gd (task 021).
## Lane: core (Agent A); changed alongside contract PRs.
extends "res://tests/framework/test_case.gd"

const GearDef := preload("res://core/schema/gear_def.gd")
const BrewDef := preload("res://core/schema/brew_def.gd")
const JsonValues := preload("res://core/schema/json_values.gd")


## Returns a valid Gear definition using every part of the shape: a stat, two triggers, a modifier.
## Values are test values shaped like the GDD's Gear, not content.
func _gear() -> Dictionary:
	return {
		"id": "tom_test_gear", "name": "Test Gear", "owner": "tom", "rarity": "uncommon",
		"text": "+1 Swole. Heal 6 HP after every fight.",
		"stats": {"swole": 1, "chill": -1},
		"triggers": [
			{"when": "fight_end", "target": "self", "effects": [{"op": "heal", "amount": 6}], "hp_below_percent": 50},
			{"when": "ick_applied", "target": "trigger_target", "effects": [{"op": "damage", "amount": 2}],
				"amount_per_stack": true},
			{"when": "card_played", "target": "trigger_target", "effects": [], "card_type": "attack", "min_cost": 2},
		],
		"modifiers": [{"kind": "card_damage", "amount": 4, "card_type": "attack", "min_cost": 2},
			{"kind": "shop_price_percent", "amount": 80}],
	}


## Returns a valid Brew definition with a solo variant.
func _brew() -> Dictionary:
	return {
		"id": "test_salts", "name": "Test Salts", "rarity": "rare", "text": "Wake a teammate. Solo: hold on.",
		"target": "ally", "effects": [],
		"solo": {"target": "self", "effects": [{"op": "prevent_pass_out", "hp": 1}]},
	}


## Records a failure unless some error contains fragment.
## errors: a check() result. fragment: text one error must contain.
func _assert_error(errors: Array[String], fragment: String) -> void:
	for message: String in errors:
		if message.contains(fragment):
			return
	fail("no error containing \"%s\" in %s" % [fragment, str(errors)])


## A full Gear definition passes, and so does the GDD's starting Gear written as the header shows,
## parsed from JSON text so numbers are ints.
func test_valid_gear() -> void:
	assert_no_errors(GearDef.check(_gear()), "full gear")
	# text: Unused Gym Membership as the header example writes it.
	var text: String = JSON.stringify({"id": "tom_unused_gym_membership", "name": "Unused Gym Membership",
		"owner": "tom", "rarity": "starter", "text": "Heal 6 HP after every fight.", "stats": {},
		"triggers": [{"when": "fight_end", "target": "self", "effects": [{"op": "heal", "amount": 6}]}],
		"modifiers": []})
	assert_no_errors(GearDef.check(JsonValues.parse(text)["value"]), "starting gear from JSON")
	# boss: a Boss Gear with general id.
	var boss: Dictionary = {"id": "beer_helmet", "name": "Beer Helmet", "owner": "boss", "rarity": "boss",
		"text": "+1 Hype per turn. Start each fight with a Hangover card in your draw pile.",
		"stats": {"hype_per_turn": 1}, "triggers": [], "modifiers": []}
	assert_no_errors(GearDef.check(boss), "boss gear")


## Each Gear rule rejects a bad value with a message naming the field.
func test_bad_gear_fails() -> void:
	assert_eq(GearDef.check("lifting_belt").size(), 1, "not a Dictionary")
	# cases: [field change as a callable on a fresh definition, expected fragment].
	var cases: Array = [
		[func(g: Dictionary) -> void: g.erase("text"), "text: missing"],
		[func(g: Dictionary) -> void: g["owner"] = "dylan", "owner"],
		[func(g: Dictionary) -> void: g["rarity"] = "legendary", "rarity"],
		[func(g: Dictionary) -> void: g["rarity"] = "boss", "must be \"boss\" exactly when owner is \"boss\""],
		[func(g: Dictionary) -> void: g["id"] = "test_gear", "must start with its owner \"tom_\""],
		[func(g: Dictionary) -> void: g["stats"] = {"speed": 1}, "stats"],
		[func(g: Dictionary) -> void: g["stats"] = {"swole": 0}, "stats.swole: must not be 0"],
		[func(g: Dictionary) -> void: g["stats"] = {"swole": 1.5}, "expected int"],
		[func(g: Dictionary) -> void: g["triggers"][0]["when"] = "on_nap", "triggers[0].when"],
		[func(g: Dictionary) -> void: g["triggers"][0]["target"] = "everyone", "triggers[0].target"],
		[func(g: Dictionary) -> void: g["triggers"][0]["target"] = "trigger_target", "trigger_target only works"],
		[func(g: Dictionary) -> void: g["triggers"][0]["card_type"] = "attack", "card_type and min_cost only work"],
		[func(g: Dictionary) -> void: g["triggers"][0]["amount_per_stack"] = true, "amount_per_stack: only works"],
		[func(g: Dictionary) -> void: g["triggers"][0]["hp_below_percent"] = 0, "hp_below_percent: must be 1..100"],
		[func(g: Dictionary) -> void: g["triggers"][0]["hp_below_percent"] = 101, "hp_below_percent: must be 1..100"],
		[func(g: Dictionary) -> void: g["triggers"][0]["effects"] = [{"amount": 6}], "effects[0]: missing String \"op\""],
		[func(g: Dictionary) -> void: g["triggers"][0]["sometimes"] = true, "unknown field"],
		[func(g: Dictionary) -> void: g["triggers"][2]["card_type"] = "trap", "card_type"],
		[func(g: Dictionary) -> void: g["triggers"][2]["min_cost"] = -1, "min_cost: must be 0 or more"],
		[func(g: Dictionary) -> void: g["modifiers"][0]["kind"] = "luck", "modifiers[0].kind"],
		[func(g: Dictionary) -> void: g["modifiers"][0]["amount"] = -4, "amount: must be 0 or more"],
		[func(g: Dictionary) -> void: g["modifiers"][1]["min_cost"] = 1, "card_type and min_cost only work with kind"],
		[func(g: Dictionary) -> void: g["modifiers"][1].erase("amount"), "amount: missing"],
	]
	for i: int in cases.size():
		# gear: a fresh valid definition, broken once.
		var gear: Dictionary = _gear()
		cases[i][0].call(gear)
		_assert_error(GearDef.check(gear), cases[i][1])


## A Brew with and without a solo variant passes, including the header example from JSON text.
func test_valid_brew() -> void:
	assert_no_errors(BrewDef.check(_brew()), "brew with solo")
	# text: Light Beer as the header example writes it.
	var text: String = JSON.stringify({"id": "light_beer", "name": "Light Beer", "rarity": "common",
		"text": "Heal 10 HP.", "target": "self", "effects": [{"op": "heal", "amount": 10}]})
	assert_no_errors(BrewDef.check(JsonValues.parse(text)["value"]), "light beer from JSON")


## Each Brew rule rejects a bad value with a message naming the field.
func test_bad_brew_fails() -> void:
	assert_eq(BrewDef.check(null).size(), 1, "not a Dictionary")
	# cases: [change as a callable on a fresh definition, expected fragment].
	var cases: Array = [
		[func(b: Dictionary) -> void: b["rarity"] = "starter", "rarity"],
		[func(b: Dictionary) -> void: b["target"] = "puppet", "test_salts.target"],
		[func(b: Dictionary) -> void: b["effects"] = [{"amount": 1}], "effects[0]: missing String \"op\""],
		[func(b: Dictionary) -> void: b["owner"] = "general", "owner: unknown field"],
		[func(b: Dictionary) -> void: b.erase("text"), "text: missing"],
		[func(b: Dictionary) -> void: b["solo"] = {"target": "self"}, "solo.effects: missing"],
		[func(b: Dictionary) -> void: b["solo"]["target"] = "nobody", "solo.target"],
		[func(b: Dictionary) -> void: b["solo"]["effects"] = [{}], "solo.effects[0]: missing String \"op\""],
		[func(b: Dictionary) -> void: b["solo"] = [], "solo: expected"],
	]
	for i: int in cases.size():
		# brew: a fresh valid definition, broken once.
		var brew: Dictionary = _brew()
		brew["id"] = "test_salts"
		cases[i][0].call(brew)
		_assert_error(BrewDef.check(brew, "test_salts"), cases[i][1])
