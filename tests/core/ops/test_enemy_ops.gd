## Tests for the task 017 ops' field checks and edge cases: summon_enemy, steal_dolla_bills, flee,
## gain_swole. Their use by real enemies is in tests/core/enemies/. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Ops := preload("res://core/ops/ops.gd")
const Event := preload("res://core/schema/event.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const EnemyFixtures := preload("res://tests/core/enemies/enemy_fixtures.gd")

## Fixed seed for the fights in this file.
const SEED: int = 17017


## Valid effects pass Ops.check; each bad one is reported once.
func test_field_checks() -> void:
	for effect: Dictionary in [
		{"op": "summon_enemy", "enemy_id": "goblin_pledge"}, {"op": "summon_enemy", "enemy_id": "goblin_pledge", "count": 2},
		{"op": "steal_dolla_bills", "amount": 5}, {"op": "flee"},
		{"op": "gain_swole", "amount": 2}, {"op": "gain_swole", "amount": 2, "tag": "goblin"},
	]:
		assert_no_errors(Ops.check(effect), str(effect))
	for effect: Dictionary in [
		{"op": "summon_enemy"}, {"op": "summon_enemy", "enemy_id": ""}, {"op": "summon_enemy", "enemy_id": "x", "count": 0},
		{"op": "summon_enemy", "enemy_id": "x", "where": "left"},
		{"op": "steal_dolla_bills", "amount": 0}, {"op": "steal_dolla_bills", "amount": 5.0}, {"op": "steal_dolla_bills"},
		{"op": "flee", "amount": 1},
		{"op": "gain_swole", "amount": 0}, {"op": "gain_swole", "amount": 2, "tag": ""}, {"op": "gain_swole", "amount": 2, "who": "all"},
	]:
		assert_eq(Ops.check(effect).size(), 1, str(effect))


## Only enemy moves aimed at Dudes need targets: steal_dolla_bills does; the others do not.
func test_needs_target() -> void:
	assert_true(Ops.needs_target([{"op": "steal_dolla_bills", "amount": 5}]))
	for op: Dictionary in [{"op": "summon_enemy", "enemy_id": "x"}, {"op": "flee"}, {"op": "gain_swole", "amount": 1}]:
		assert_false(Ops.needs_target([op]), str(op))


## Edge cases: summoning an unknown enemy or without a ruleset does nothing; a Dude cannot steal or
## flee; a Dude's own gain_swole raises their Swole; stealing from a Dude with no Dolla Bills emits nothing.
func test_edge_cases() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: a Dude against a rat, with no Dolla Bills.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["dorm_rat"])
	# rat: the rat's uid.
	var rat: String = state["combat"]["enemies"][0]["uid"]
	# before: a copy to compare against.
	var before: Dictionary = state.duplicate(true)
	# events: events of the no-op effects.
	var events: Array = []
	Ops.run(state, {"op": "summon_enemy", "enemy_id": "nobody"}, Ops.make_context(rules, rat, [], true, false), events)
	# no_ruleset: a context without the ruleset.
	var no_ruleset: Dictionary = Ops.make_context(rules, rat, [], true, false)
	no_ruleset.erase("ruleset")
	Ops.run(state, {"op": "summon_enemy", "enemy_id": "goblin_pledge"}, no_ruleset, events)
	Ops.run(state, {"op": "steal_dolla_bills", "amount": 5}, Ops.make_context(rules, rat, ["p1"], true, false), events)
	Ops.run(state, {"op": "steal_dolla_bills", "amount": 5}, Ops.make_context(rules, "p1", [rat], true, true), events)
	Ops.run(state, {"op": "flee"}, Ops.make_context(rules, "p1", [], false, true), events)
	assert_eq(events, [])
	assert_eq(state, before, "nothing changed")
	Ops.run(state, {"op": "gain_swole", "amount": 3}, Ops.make_context(rules, "p1", [], false, true), events)
	assert_eq(events, [Event.make("stat_changed", {"target_id": "p1", "stat": "swole", "delta": 3, "value": 3})])
	assert_eq(state["dudes"][0]["swole"], 3)
