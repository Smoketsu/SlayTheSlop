## Tests for the GDD damage order (core/ops/damage.gd, core/ops/ratio.gd; task 009): every
## combination of Noodle Arms, Broken Arm k of 2 and Exposed, with Swole and Guard, exact integers,
## rounding once, and G3 (only attack damage is multiplied). Lane: core (Agent A).
##
## The expected numbers are worked out by hand from the tuned constants (SLICE_VALUES: GDD 0.5, except
## BROKEN_ARM_MAX_REDUCTION 0.3, set by Smoketsu on 2026-10-12). Each test first checks that
## data/constants.json still holds those values, so a tuning change fails with a
## clear message ("update the table") instead of a puzzling number.
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Damage := preload("res://core/ops/damage.gd")
const Ratio := preload("res://core/ops/ratio.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const Event := preload("res://core/schema/event.gd")
const RunState := preload("res://core/schema/run_state.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 909

## The constant values the hand-worked tables below assume (GDD 0.5 "Tuning constants", with
## BROKEN_ARM_MAX_REDUCTION retuned from 0.4 to 0.3 on 2026-10-12).
const SLICE_VALUES := {"NOODLE_MULT": 0.75, "EXPOSED_MULT": 1.5, "BROKEN_ARM_MAX_REDUCTION": 0.3}

## Enemy attacker table: Hitter (10 damage, 2 arms) with 2 Swole -> 12 before multipliers, hitting
## a Dude with 3 Guard. Rows: [Noodle Arms on the enemy, arms broken k of 2, Dude Exposed,
## expected damage after rounding, damage if each step were rounded down separately].
## Factors: Noodle 3/4; Broken Arm 1, 17/20, 7/10 for k = 0, 1, 2; Exposed 3/2.
const ENEMY_TABLE: Array = [
	[false, 0, false, 12, 12],
	[false, 0, true, 18, 18],
	[false, 1, false, 10, 10],
	[false, 1, true, 15, 15],
	[false, 2, false, 8, 8],
	[false, 2, true, 12, 12],
	[true, 0, false, 9, 9],
	[true, 0, true, 13, 13],
	[true, 1, false, 7, 7],
	[true, 1, true, 11, 10],
	[true, 2, false, 6, 6],
	[true, 2, true, 9, 9],
]

## Dude attacker table: Jab (6) with 1 Swole -> 7, at a Dummy with 2 broken arms (which must not
## matter: Broken Arm reduces enemy attackers only). Rows: [Noodle Arms on the Dude, Dummy Exposed,
## expected damage].
const DUDE_TABLE: Array = [
	[false, false, 7],
	[false, true, 10],
	[true, false, 5],
	[true, true, 7],
]

## Guard the Dude has before the enemy hits in ENEMY_TABLE.
const DUDE_GUARD: int = 3


## Records a failure and returns false when the constants are not the values the tables assume.
## rules: the test ruleset.
func _constants_match(rules: Dictionary) -> bool:
	for name: String in SLICE_VALUES:
		if not is_equal_approx(float(rules["constants"][name]), SLICE_VALUES[name]):
			fail("%s is %s, not %s: update this file's tables for the new tuning" % [name, rules["constants"][name], SLICE_VALUES[name]])
			return false
	return true


## Returns the events of one type, in order.
## events: an event list. type: the event type wanted.
func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event["type"] == type)


## Every row of ENEMY_TABLE, played as a real enemy attack through Core.apply (set_ready): exact
## amount, Guard absorbs and is used up, the rest comes off HP.
func test_enemy_attack_table() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	if not _constants_match(rules):
		return
	for row: Array in ENEMY_TABLE:
		# state: a solo fight against the Hitter, set up for this row.
		var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_hitter"])
		# enemy: the Hitter.
		var enemy: Dictionary = state["combat"]["enemies"][0]
		enemy["swole"] = 2
		enemy["broken_arms"] = row[1]
		# With both arms broken it is Armless; mark its one skip as used so this attack lands (G7).
		enemy["armless_used"] = row[1] == enemy["arm_count"]
		if row[0]:
			enemy["statuses"]["noodle_arms"] = 1
		if row[2]:
			# 2 stacks: the Dude loses 1 at End of turn (G1), before the enemy phase.
			state["dudes"][0]["statuses"]["exposed"] = 2
		state["dudes"][0]["guard"] = DUDE_GUARD
		# result: after Ready; the Hitter punches.
		var result: Dictionary = Core.apply(rules, state, Fixtures.set_ready("p1", 0))
		assert_eq(result["reject"], "")
		# blocked: what the Guard absorbs.
		var blocked: int = mini(DUDE_GUARD, row[3])
		assert_eq(_of_type(result["events"], "damage_dealt"), [Event.make("damage_dealt", {"source_id": "e11",
			"target_id": "p1", "amount": row[3], "blocked": blocked, "hp_lost": row[3] - blocked})], "row %s" % str(row))
		assert_eq(result["state"]["dudes"][0]["hp"], 30 - (row[3] - blocked), "HP for row %s" % str(row))
		assert_no_errors(RunState.check(result["state"]), "state for row %s" % str(row))


## The same table through hit_amount() directly, plus proof that rounding happens once: in one row
## (Noodle, 1 arm broken, Exposed: 12 x 3/4 x 17/20 x 3/2 = 11.475) rounding after every step would
## give a smaller number (9, then 7, then 10).
func test_rounding_happens_once() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	if not _constants_match(rules):
		return
	# differing: rows where rounding at each step would differ from rounding once.
	var differing: int = 0
	for row: Array in ENEMY_TABLE:
		# attacker: a hand-made enemy state with only the fields the damage order reads.
		var attacker: Dictionary = {"swole": 2, "statuses": {"noodle_arms": 1} if row[0] else {}, "arm_count": 2, "broken_arms": row[1]}
		# target: a hand-made Dude state.
		var target: Dictionary = {"statuses": {"exposed": 1} if row[2] else {}}
		assert_eq(Damage.hit_amount(rules["constants"], attacker, target, 10, true), row[3], "row %s" % str(row))
		if row[3] != row[4]:
			differing += 1
	assert_eq(differing, 1, "the table includes a case that catches per-step rounding")
	# Poke (5) from a Noodle Dude at an Exposed enemy: 5 x 3/4 x 3/2 = 5.625 -> 5. Per step: 3, then 4.
	assert_eq(Damage.hit_amount(rules["constants"], {"swole": 0, "statuses": {"noodle_arms": 1}},
		{"statuses": {"exposed": 1}}, 5, true), 5)


## Every row of DUDE_TABLE through Core.apply: Noodle Arms and Exposed apply to a Dude's attack;
## the Dummy's broken arms do not (it is the target, not the attacker).
func test_dude_attack_table() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	if not _constants_match(rules):
		return
	for row: Array in DUDE_TABLE:
		# state: a solo fight against the Dummy.
		var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_dummy"])
		state["dudes"][0]["swole"] = 1
		state["combat"]["enemies"][0]["broken_arms"] = 2
		if row[0]:
			state["dudes"][0]["statuses"]["noodle_arms"] = 1
		if row[1]:
			state["combat"]["enemies"][0]["statuses"]["exposed"] = 1
		# result: after a Jab.
		var result: Dictionary = Core.apply(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, "neutral_test_jab"), "e11"))
		assert_eq(result["reject"], "")
		assert_eq(_of_type(result["events"], "damage_dealt")[0]["amount"], row[2], "row %s" % str(row))


## An enemy with no arms never gets the Broken Arm factor; Exposed still applies.
func test_armless_by_nature_enemy() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	if not _constants_match(rules):
		return
	# slime: a hand-made 0-arm enemy (7 damage).
	var slime: Dictionary = {"swole": 0, "statuses": {}, "arm_count": 0, "broken_arms": 0}
	assert_eq(Damage.hit_amount(rules["constants"], slime, {"statuses": {}}, 7, true), 7)
	assert_eq(Damage.hit_amount(rules["constants"], slime, {"statuses": {"exposed": 3}}, 7, true), 10, "7 x 1.5 = 10.5")


## G3: damage on a card that is not an Attack ignores Swole, Noodle Arms and Exposed.
func test_non_attack_damage_is_not_multiplied() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	# state: a fight where p1 has Swole and Noodle Arms and the Dummy is Exposed.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude"], ["test_dummy"])
	state["dudes"][0]["swole"] = 3
	state["dudes"][0]["statuses"]["noodle_arms"] = 1
	state["combat"]["enemies"][0]["statuses"]["exposed"] = 1
	# result: after Skill Hit (a Skill with damage 6).
	var result: Dictionary = Core.apply(rules, state, Fixtures.play("p1", 0, Fixtures.give(state, 0, "neutral_test_skill_hit"), "e11"))
	assert_eq(result["reject"], "")
	assert_eq(_of_type(result["events"], "damage_dealt")[0]["amount"], 6)
	assert_eq(Damage.hit_amount(rules["constants"], {"swole": 3, "statuses": {"noodle_arms": 1}}, {"statuses": {"exposed": 1}}, 6, false), 6)


## Ratios are exact: constants become reduced fractions, products stay reduced, and a value that
## float math gets wrong (0.29 x 100 = 28.999...) comes out right.
func test_ratios_are_exact() -> void:
	assert_eq(Ratio.from_constant(0.75), [3, 4])
	assert_eq(Ratio.from_constant(1.5), [3, 2])
	assert_eq(Ratio.from_constant(0.4), [2, 5])
	assert_eq(Ratio.from_constant(2), [2, 1])
	assert_eq(Ratio.times([3, 4], [3, 2]), [9, 8])
	assert_eq(Ratio.times([2, 3], [3, 2]), [1, 1], "cross-reduced")
	assert_eq(int(0.29 * 100), 28, "float math drifts")
	assert_eq(Ratio.floor_times(100, Ratio.from_constant(0.29)), 29, "ratio math does not")
	assert_eq(Ratio.gcd(0, 0), 0)
	assert_eq(Ratio.reduced(0, 10), [0, 1])


## Every product of the slice constants rounds exactly right for every base 0..200: the core's
## answer equals the hand-written integer formula base x num / den for each combination.
func test_every_product_rounds_exactly() -> void:
	# rules: the test ruleset.
	var rules: Dictionary = Fixtures.ruleset()
	if not _constants_match(rules):
		return
	# combos: [Noodle, k of 2, Exposed, numerator, denominator] for all 12 combinations.
	var combos: Array = []
	for noodle: bool in [false, true]:
		for k: int in [0, 1, 2]:
			for exposed: bool in [false, true]:
				# num: the product's numerator: Noodle 3/4, Broken Arm (20 - 3k)/20, Exposed 3/2.
				var num: int = (3 if noodle else 1) * (20 - 3 * k) * (3 if exposed else 1)
				# den: the product's denominator.
				var den: int = (4 if noodle else 1) * 20 * (2 if exposed else 1)
				combos.append([noodle, k, exposed, num, den])
	for combo: Array in combos:
		# attacker: a hand-made enemy state.
		var attacker: Dictionary = {"swole": 0, "statuses": {"noodle_arms": 1} if combo[0] else {}, "arm_count": 2, "broken_arms": combo[1]}
		# target: a hand-made target state.
		var target: Dictionary = {"statuses": {"exposed": 1} if combo[2] else {}}
		for base: int in 201:
			assert_eq(Damage.hit_amount(rules["constants"], attacker, target, base, true), base * combo[3] / combo[4],
				"base %d, combo %s" % [base, str(combo)])
