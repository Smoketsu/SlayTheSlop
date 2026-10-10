## Tests for the state and event additions of task 021: combat_state fight_stat_changes and
## pass_out_saves, and the Gear and Brew event types. Lane: core (Agent A); changed alongside
## contract PRs.
extends "res://tests/framework/test_case.gd"

const CombatState := preload("res://core/schema/combat_state.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Event := preload("res://core/schema/event.gd")


## A blank fight has both new maps empty and is valid; filled-in values are valid too.
func test_new_combat_fields_are_valid() -> void:
	# combat: a blank fight.
	var combat: Dictionary = CombatState.blank()
	assert_eq(combat["fight_stat_changes"], {})
	assert_eq(combat["pass_out_saves"], {})
	assert_no_errors(CombatState.check(combat), "blank fight")
	combat["fight_stat_changes"] = {"p1": {"swole": 3}, "p2": {"chill": -1, "swole": 1}}
	combat["pass_out_saves"] = {"p1": 1}
	assert_no_errors(CombatState.check(combat), "filled fight")


## Bad values in the new fields are reported with their path.
func test_bad_combat_fields_fail() -> void:
	# cases: [field, bad value, fragment of the expected message].
	var cases: Array = [
		["fight_stat_changes", {"p1": {"swole": 1.5}}, "fight_stat_changes.p1.swole: expected int"],
		["fight_stat_changes", {"p1": 3}, "fight_stat_changes.p1: expected Dictionary"],
		["pass_out_saves", {"p1": 0}, "pass_out_saves.p1: HP must be 1 or more"],
		["pass_out_saves", {"p1": "1"}, "pass_out_saves.p1: expected int"],
	]
	for entry: Array in cases:
		# combat: a blank fight with one bad field.
		var combat: Dictionary = CombatState.blank()
		combat[entry[0]] = entry[1]
		# errors: what check() found.
		var errors: Array[String] = CombatState.check(combat)
		assert_true(errors.any(func(e: String) -> bool: return e.contains(entry[2])),
			"expected \"%s\" in %s" % [entry[2], str(errors)])
	# old: a fight in the version 4 shape (before task 021), without the new fields.
	var old: Dictionary = {"turn": 0, "phase": "intents", "enemies": [], "result": ""}
	assert_false(CombatState.check(old).is_empty(), "a fight without the new fields is refused")


## SCHEMA_VERSION is at least 5, the shape with the task 021 fields (later shapes raise it), and
## blank() stamps it.
func test_schema_version() -> void:
	assert_true(RunState.SCHEMA_VERSION >= 5, "version %d" % RunState.SCHEMA_VERSION)
	assert_eq(RunState.blank(1, [])["schema_version"], RunState.SCHEMA_VERSION)


## Each new event type builds a valid event, and a missing field fails.
func test_new_events() -> void:
	# made: one valid event per new type.
	var made: Array = [
		Event.make("gear_gained", {"player_id": "p1", "gear_id": "lifting_belt"}),
		Event.make("gear_triggered", {"player_id": "p1", "gear_id": "tom_unused_gym_membership", "when": "fight_end"}),
		Event.make("brew_used", {"player_id": "p1", "slot": 0, "brew_id": "light_beer", "target_id": ""}),
		Event.make("stat_changed", {"target_id": "e3", "stat": "swole", "delta": 1, "value": 1}),
		Event.make("pass_out_prevented", {"player_id": "p1", "hp": 1}),
	]
	for event: Dictionary in made:
		assert_no_errors(Event.check(event), event["type"])
	assert_false(Event.check(Event.make("brew_used", {"player_id": "p1", "slot": 0})).is_empty(), "missing fields")
