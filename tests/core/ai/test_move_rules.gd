## Tests for enemy move rules (core/ai/move_rules.gd, task 017): each condition kind, rule order,
## and that rules beat the pattern and the random choice without drawing. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const MoveRules := preload("res://core/ai/move_rules.gd")
const EnemyFixtures := preload("res://tests/core/enemies/enemy_fixtures.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")

## Fixed seed for the fights in this file.
const SEED: int = 17017


## Returns a fight against a Shot-Caller and its 2 Pledges (plus a Keg Slime) at the given turn.
## rules: the enemy test ruleset. turn: the turn number to set, 1 or more.
func _fight_at(rules: Dictionary, turn: int) -> Dictionary:
	# state: the fight.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["goblin_shot_caller", "keg_slime"])
	state["combat"]["turn"] = turn
	return state


## Each condition kind holds exactly when the file header says.
func test_each_condition() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: Shot-Caller, Pledge, Pledge, Keg Slime at turn 4.
	var state: Dictionary = _fight_at(rules, 4)
	# caller: the Shot-Caller.
	var caller: Dictionary = state["combat"]["enemies"][0]
	# pledge: its first Pledge.
	var pledge: Dictionary = state["combat"]["enemies"][1]
	# slime: the Keg Slime.
	var slime: Dictionary = state["combat"]["enemies"][3]
	assert_false(MoveRules.holds(rules, state, pledge, {"if": "last_of_tag", "tag": "goblin"}), "two other goblins")
	assert_true(MoveRules.holds(rules, state, slime, {"if": "last_of_tag", "tag": "slime"}), "no other slime")
	assert_true(MoveRules.holds(rules, state, caller, {"if": "turn_at_least", "turn": 4}))
	assert_false(MoveRules.holds(rules, state, caller, {"if": "turn_at_least", "turn": 5}))
	# cycle: turn -> does every 3 from turn 3 hold.
	var cycle: Dictionary = {1: false, 2: false, 3: true, 4: false, 5: false, 6: true, 9: true}
	for turn: int in cycle.keys():
		state["combat"]["turn"] = turn
		assert_eq(MoveRules.holds(rules, state, caller, {"if": "turn_cycle", "every": 3, "first_turn": 3}), cycle[turn], "turn %d" % turn)
	assert_false(MoveRules.holds(rules, state, caller, {"if": "count_below", "def_id": "goblin_pledge", "count": 2}))
	assert_true(MoveRules.holds(rules, state, caller, {"if": "count_at_least", "def_id": "goblin_pledge", "count": 2}))
	assert_true(MoveRules.holds(rules, state, pledge, {"if": "count_below", "def_id": "goblin_pledge", "count": 2}),
		"a Pledge counts only the other one")
	caller["hp"] = 30
	assert_false(MoveRules.holds(rules, state, caller, {"if": "hp_below_percent", "percent": 50}), "30 of 60 is not below half")
	caller["hp"] = 29
	assert_true(MoveRules.holds(rules, state, caller, {"if": "hp_below_percent", "percent": 50}))
	assert_false(MoveRules.holds(rules, state, caller, {"if": "full_moon"}), "unknown kinds never hold")


## Rules are tried in order and the first match wins; with none matching the answer is "", and the
## caller then uses the pattern or random choice. Rules draw nothing from combat_ai.
func test_rule_order_and_no_draw() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: turn 2, both Pledges standing.
	var state: Dictionary = _fight_at(rules, 2)
	# before: the random streams before.
	var before: Dictionary = state["rng"].duplicate()
	assert_eq(MoveRules.ruled_move(rules, state, state["combat"]["enemies"][0]), "pregame", "second rule")
	state["combat"]["enemies"].remove_at(1)
	assert_eq(MoveRules.ruled_move(rules, state, state["combat"]["enemies"][0]), "next_pledge", "first rule wins")
	state["combat"]["turn"] = 3
	assert_eq(MoveRules.ruled_move(rules, state, state["combat"]["enemies"][0]), "", "no rule on turn 3")
	assert_eq(MoveRules.ruled_move(rules, state, state["combat"]["enemies"][2]), "", "no rules at all")
	assert_eq(state["rng"], before)
