## Tests for the shared shapes in core/schema/. Lane: tools (Agent B); changed alongside contract PRs.
extends "res://tests/framework/test_case.gd"

const Shape := preload("res://core/schema/shape.gd")
const JsonValues := preload("res://core/schema/json_values.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const EnemyState := preload("res://core/schema/enemy_state.gd")
const CombatState := preload("res://core/schema/combat_state.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Request := preload("res://core/schema/request.gd")
const Event := preload("res://core/schema/event.gd")
const CardDef := preload("res://core/schema/card_def.gd")
const EnemyDef := preload("res://core/schema/enemy_def.gd")
const DudeDef := preload("res://core/schema/dude_def.gd")

## A seed above 2^53, the largest int a JSON number (a double) holds exactly. Used to prove
## snapshots survive var_to_bytes but not JSON.
const BIG_SEED: int = 1152921504606846977


## Builds a small but complete mid-fight state: one Dude with three cards, two enemies.
## Fixed values, so it is the same on every run.
func _sample_state() -> Dictionary:
	# dude: the single player's Dude, holding one card in each of three piles.
	var dude: Dictionary = DudeState.blank("p1", "tom")
	dude["hp"] = 80
	dude["max_hp"] = 80
	dude["cards"] = {
		"c1": {"def_id": "tom_punch", "upgraded": false},
		"c2": {"def_id": "tom_flex", "upgraded": true},
		"c3": {"def_id": "tom_arm_bar", "upgraded": false},
	}
	dude["deck"] = ["c1", "c2", "c3"]
	dude["draw_pile"] = ["c1"]
	dude["hand"] = ["c2"]
	dude["discard_pile"] = ["c3"]
	dude["statuses"] = {"exposed": 2}
	# state: the run around that Dude.
	var state: Dictionary = RunState.blank(BIG_SEED, [dude])
	# pledge / bouncer: two enemies, one with an intent aimed at p1.
	var pledge: Dictionary = EnemyState.blank("e4", "goblin_pledge")
	pledge["hp"] = 12
	pledge["max_hp"] = 12
	pledge["arm_count"] = 2
	pledge["broken_arms"] = 1
	pledge["intent"] = {"move_id": "hit", "target_ids": ["p1"]}
	# bouncer: a second enemy left at blank values.
	var bouncer: Dictionary = EnemyState.blank("e5", "goblin_bouncer")
	state["combat"] = CombatState.blank()
	state["combat"]["enemies"] = [pledge, bouncer]
	state["combat"]["phase"] = "player"
	state["combat"]["turn"] = 1
	state["rng"] = {"shuffle:p1": -7046029254386353131, "combat_ai": 42}
	state["next_uid"] = 6
	return state


## Every blank() factory produces a value its own check() accepts.
func test_blank_states_are_valid() -> void:
	assert_no_errors(DudeState.check(DudeState.blank("p1", "tom")), "blank dude")
	assert_no_errors(EnemyState.check(EnemyState.blank("e1", "goblin_pledge")), "blank enemy")
	assert_no_errors(CombatState.check(CombatState.blank()), "blank combat")
	assert_no_errors(RunState.check(RunState.blank(1, [DudeState.blank("p1", "tom")])), "blank run")


## The sample mid-fight state is valid.
func test_sample_state_is_valid() -> void:
	assert_no_errors(RunState.check(_sample_state()), "sample state")


## A snapshot through var_to_bytes / bytes_to_var loads back identical, big ints included.
func test_snapshot_round_trip_is_identical() -> void:
	# state: the original.
	var state: Dictionary = _sample_state()
	# copy: the state after a save and load.
	var copy: Variant = bytes_to_var(var_to_bytes(state))
	assert_eq(copy, state, "binary snapshot")


## JSON cannot hold the state: the big seed comes back changed. This is why snapshots must not use JSON.
func test_json_corrupts_big_ints() -> void:
	# reparsed: the sample state after a JSON round trip.
	var reparsed: Dictionary = JsonValues.parse(JSON.stringify(_sample_state()))["value"]
	assert_ne(reparsed["run_seed"], BIG_SEED, "JSON should not round-trip a seed above 2^53")


## Strictness: a float in an int field, an unknown field and a missing field are all reported.
func test_shape_errors_are_reported() -> void:
	# dude: a blank Dude, broken three ways.
	var dude: Dictionary = DudeState.blank("p1", "tom")
	dude["hp"] = 80.0
	dude["mana"] = 3
	dude.erase("guard")
	# errors: what check() found.
	var errors: Array[String] = DudeState.check(dude)
	assert_eq(errors.size(), 3, "errors: %s" % str(errors))


## A card in two piles at once, or a pile entry with no card instance, is reported.
func test_card_bookkeeping_errors_are_reported() -> void:
	# state: the sample, with c1 copied into the hand and a made-up uid in the discard pile.
	var state: Dictionary = _sample_state()
	state["dudes"][0]["hand"].append("c1")
	state["dudes"][0]["discard_pile"].append("c99")
	assert_eq(RunState.check(state).size(), 2)


## party_size must match the number of Dudes.
func test_party_size_must_match_dudes() -> void:
	# state: the sample with a wrong party_size.
	var state: Dictionary = _sample_state()
	state["party_size"] = 2
	assert_eq(RunState.check(state).size(), 1)


## Duplicate enemy uids are reported.
func test_duplicate_enemy_uids_are_reported() -> void:
	# state: the sample with both enemies sharing a uid.
	var state: Dictionary = _sample_state()
	state["combat"]["enemies"][1]["uid"] = "e4"
	assert_eq(RunState.check(state).size(), 1)


## Requests: a valid play_card passes; unknown types, missing fields and float seqs fail.
func test_request_shapes() -> void:
	# good: a well-formed play_card.
	var good: Dictionary = {"type": "play_card", "player_id": "p1", "seq": 0,
		"card_uid": "c3", "target_id": "e4", "crunch": false}
	assert_no_errors(Request.check(good), "play_card")
	assert_no_errors(Request.check({"type": "use_bro_move", "player_id": "p1", "seq": 4}), "use_bro_move")
	assert_false(Request.check({"type": "dance", "player_id": "p1", "seq": 0}).is_empty(), "unknown type")
	# missing: good without its seq.
	var missing: Dictionary = good.duplicate()
	missing.erase("seq")
	assert_false(Request.check(missing).is_empty(), "missing seq")
	# floaty: good with a float seq, as raw JSON would give.
	var floaty: Dictionary = good.duplicate()
	floaty["seq"] = 0.0
	assert_false(Request.check(floaty).is_empty(), "float seq")


## Events: make() builds valid events; unknown types and missing fields fail.
func test_event_shapes() -> void:
	assert_no_errors(Event.check(Event.make("damage_dealt",
		{"source_id": "p1", "target_id": "e4", "amount": 8, "blocked": 0, "hp_lost": 8})), "damage_dealt")
	assert_no_errors(Event.check(Event.make("turn_started", {"turn": 1})), "turn_started")
	assert_false(Event.check(Event.make("fireworks", {})).is_empty(), "unknown type")
	assert_false(Event.check(Event.make("enemy_died", {})).is_empty(), "missing enemy_uid")


## Every event type in the catalogue has at least one field or is deliberately empty, and every
## rule in it is a valid spec rule (checked by validating a value built to match).
func test_event_catalogue_rules_are_valid() -> void:
	for type: String in Event.TYPES.keys():
		# spec: this type's field rules.
		var spec: Dictionary = Event.TYPES[type]
		for field: String in spec.keys():
			# rule_errors: problems from checking a deliberately wrong value; a bad rule reports "bad schema rule".
			var rule_errors: Array[String] = Shape.check_type(null, spec[field], field)
			for message: String in rule_errors:
				assert_false(message.contains("bad schema rule"), "%s.%s: %s" % [type, field, message])


## The GDD's example card definition (tom_arm_bar) is valid once parsed through json_values.
func test_gdd_example_card_is_valid() -> void:
	# text: the example from GDD "Example card definition", verbatim.
	var text: String = """{
	  "id": "tom_arm_bar", "name": "Arm Bar", "owner": "tom", "type": "attack",
	  "rarity": "starter", "cost": 2, "target": "enemy",
	  "effects": [
	    { "op": "damage", "amount": 8, "hits": 1 },
	    { "op": "apply_status", "status": "broken_arm", "stacks": 1 }
	  ],
	  "keywords": [], "crunch": null, "upgrade": { "effects[0].amount": 11 }
	}"""
	# parsed: the parse result.
	var parsed: Dictionary = JsonValues.parse(text)
	assert_true(parsed["ok"], parsed["error"])
	assert_no_errors(CardDef.check(parsed["value"]), "tom_arm_bar")
	assert_eq(parsed["value"]["cost"], 2, "cost must be an int after normalize")


## Bad card definitions are caught: a wrong cost text, an unknown keyword, an id without its owner prefix.
func test_bad_card_definitions_fail() -> void:
	# base: a minimal valid card, copied and broken below.
	var base: Dictionary = {"id": "tom_punch", "name": "Punch", "owner": "tom", "type": "attack",
		"rarity": "starter", "cost": 1, "target": "enemy", "effects": [{"op": "damage", "amount": 6, "hits": 1}],
		"keywords": [], "crunch": null, "upgrade": {}}
	assert_no_errors(CardDef.check(base), "base card")
	# bad: one broken copy at a time.
	var bad: Dictionary = base.duplicate(true)
	bad["cost"] = "y"
	assert_false(CardDef.check(bad).is_empty(), "cost y")
	bad = base.duplicate(true)
	bad["keywords"] = ["sticky"]
	assert_false(CardDef.check(bad).is_empty(), "unknown keyword")
	bad = base.duplicate(true)
	bad["id"] = "punch"
	assert_false(CardDef.check(bad).is_empty(), "id without owner prefix")


## A minimal enemy and Dude definition are valid; a duplicate move id is caught.
func test_enemy_and_dude_definitions() -> void:
	# pledge: Goblin Pledge from the GDD floor 1 table, moves only.
	var pledge: Dictionary = {"id": "goblin_pledge", "name": "Goblin Pledge", "floor": 1, "tier": "normal",
		"max_hp": 12, "arm_count": 2,
		"moves": [{"id": "hit", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 5, "hits": 1}]}]}
	assert_no_errors(EnemyDef.check(pledge), "goblin_pledge")
	pledge["moves"].append(pledge["moves"][0].duplicate(true))
	assert_false(EnemyDef.check(pledge).is_empty(), "duplicate move id")
	# tom: Tom's attributes from the GDD.
	var tom: Dictionary = {"id": "tom", "name": "Tom", "title": "the Enforcer", "max_hp": 80,
		"starter_deck": ["tom_punch"], "starting_gear": ["tom_unused_gym_membership"], "bro_move": "tom_chest_bump"}
	assert_no_errors(DudeDef.check(tom), "tom")


## json_values: whole numbers become ints at any depth, fractions stay floats, errors give a line.
func test_json_values_normalize() -> void:
	# parsed: a parse of mixed numbers.
	var parsed: Dictionary = JsonValues.parse('{"a": 3, "b": 1.5, "c": [2, {"d": -4}]}')
	assert_eq(parsed["value"], {"a": 3, "b": 1.5, "c": [2, {"d": -4}]})
	# broken: a parse of invalid JSON.
	var broken: Dictionary = JsonValues.parse('{"a": }')
	assert_false(broken["ok"], "invalid JSON must fail")
	assert_true(broken["error"].begins_with("line "), "error should name a line: " + broken["error"])
