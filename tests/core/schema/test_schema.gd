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


## grossed_out_skips (task 009) starts at 0 in blank(), must be an int and may not be negative.
func test_grossed_out_skips_is_checked() -> void:
	# enemy: a blank enemy, changed below.
	var enemy: Dictionary = EnemyState.blank("e1", "goblin_pledge")
	assert_eq(enemy["grossed_out_skips"], 0, "blank value")
	enemy["grossed_out_skips"] = 2
	assert_no_errors(EnemyState.check(enemy), "two pending skips")
	enemy["grossed_out_skips"] = -1
	assert_eq(EnemyState.check(enemy).size(), 1, "negative")
	enemy["grossed_out_skips"] = 1.0
	assert_eq(EnemyState.check(enemy).size(), 1, "float")
	enemy.erase("grossed_out_skips")
	assert_eq(EnemyState.check(enemy).size(), 1, "missing")


## Task 013: powers and thorns start empty and 0; a Power uid must be a card and in no pile; thorns
## may not be negative; both are required.
func test_powers_and_thorns_are_checked() -> void:
	# state: the sample, changed below.
	var state: Dictionary = _sample_state()
	# dude: its Dude.
	var dude: Dictionary = state["dudes"][0]
	assert_eq([dude["powers"], dude["thorns"]], [[], 0], "blank values")
	dude["cards"]["c4"] = {"def_id": "tom_reply_guy", "upgraded": false}
	dude["powers"] = ["c4"]
	dude["thorns"] = 3
	assert_no_errors(RunState.check(state), "an active Power and 3 thorns")
	dude["powers"] = ["c4", "c99"]
	assert_eq(RunState.check(state).size(), 1, "Power uid not in cards")
	dude["powers"] = ["c2"]
	assert_eq(RunState.check(state).size(), 1, "Power uid also in the hand")
	dude["powers"] = ["c4"]
	dude["thorns"] = -1
	assert_eq(RunState.check(state).size(), 1, "negative thorns")
	dude["thorns"] = 0
	dude.erase("powers")
	assert_eq(RunState.check(state).size(), 1, "powers is required")


## Task 013: power_triggers on a Power card are checked: when, target, subject only where there is
## one, effects with an op, and only on type "power".
func test_power_triggers_are_checked() -> void:
	# reply_guy: Reply Guy from the GDD, as task 013's ops express it.
	var reply_guy: Dictionary = {"id": "tom_reply_guy", "name": "Reply Guy", "owner": "tom", "type": "power",
		"rarity": "uncommon", "cost": 1, "target": "none", "effects": [], "keywords": [], "crunch": null,
		"upgrade": {}, "power_triggers": [{"when": "enemy_buffed", "target": "subject",
			"effects": [{"op": "apply_status", "status": "ick", "stacks": 2}]}]}
	assert_no_errors(CardDef.check(reply_guy), "Reply Guy")
	# bad: copies of reply_guy, each broken one way.
	var bad: Dictionary = reply_guy.duplicate(true)
	bad["type"] = "skill"
	assert_eq(CardDef.check(bad).size(), 1, "not a Power")
	bad = reply_guy.duplicate(true)
	bad["power_triggers"][0]["when"] = "sometimes"
	assert_eq(CardDef.check(bad).size(), 1, "unknown when")
	bad = reply_guy.duplicate(true)
	bad["power_triggers"][0]["target"] = "everyone"
	assert_eq(CardDef.check(bad).size(), 1, "unknown target")
	bad = reply_guy.duplicate(true)
	bad["power_triggers"][0]["when"] = "turn_start"
	assert_eq(CardDef.check(bad).size(), 1, "turn_start has no subject")
	bad = reply_guy.duplicate(true)
	bad["power_triggers"][0]["effects"] = [{"amount": 2}]
	assert_eq(CardDef.check(bad).size(), 1, "effect without op")
	bad = reply_guy.duplicate(true)
	bad["power_triggers"][0].erase("target")
	assert_eq(CardDef.check(bad).size(), 1, "missing target")
	bad = reply_guy.duplicate(true)
	bad["power_triggers"] = [{"when": "turn_start", "target": "all_enemies", "effects": [], "extra": 1}]
	assert_eq(CardDef.check(bad).size(), 1, "unknown trigger field")


## Task 013: use_bro_move may carry a String target_id, and the new events are well-formed.
func test_bro_move_request_and_task_013_events() -> void:
	assert_no_errors(Request.check({"type": "use_bro_move", "player_id": "p1", "seq": 4, "target_id": "e3"}), "with target")
	assert_eq(Request.check({"type": "use_bro_move", "player_id": "p1", "seq": 4, "target_id": 3}).size(), 1, "int target")
	assert_eq(Request.check({"type": "set_ready", "player_id": "p1", "seq": 4, "ready": true, "target_id": ""}).size(), 1,
		"target_id is optional only on use_bro_move")
	assert_no_errors(Event.check(Event.make("bro_move_used", {"player_id": "p1", "def_id": "tom_chest_bump", "target_id": "e3"})), "bro_move_used")
	assert_no_errors(Event.check(Event.make("thorns_changed", {"target_id": "p1", "delta": 3, "thorns": 3})), "thorns_changed")
	assert_no_errors(Event.check(Event.make("power_triggered", {"player_id": "p1", "card_uid": "c4",
		"when": "turn_start", "subject_id": ""})), "power_triggered")


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


## Task 015: the Junk fields. Rarity "special" (G17), the trigger lists, play_limit_in_hand, lasts
## and removable are accepted when well formed, and each malformed value is caught.
func test_junk_card_fields() -> void:
	# junk: a Detention-like card using every new field once.
	var junk: Dictionary = {"id": "junk_detention", "name": "Detention", "owner": "junk", "type": "junk",
		"rarity": "special", "cost": -1, "target": "none", "effects": [], "keywords": [], "crunch": null,
		"upgrade": {}, "on_draw": [{"op": "lose_hype", "amount": 1}],
		"on_end_of_turn_in_hand": [{"op": "self_damage", "amount": 2}], "play_limit_in_hand": 4,
		"lasts": "fight", "removable": false}
	assert_no_errors(CardDef.check(junk), "junk card with every new field")
	assert_true(CardDef.RARITIES.has("special"), "G17 rarity")
	# cases: [field, bad value, label]; each makes the card invalid on its own.
	var cases: Array = [["rarity", "junky", "unknown rarity"], ["lasts", "forever", "unknown lasts"],
		["lasts", 1, "lasts not text"], ["play_limit_in_hand", -1, "negative limit"],
		["play_limit_in_hand", 4.0, "float limit"], ["removable", "no", "removable not bool"],
		["on_draw", [{"amount": 1}], "on_draw entry without op"], ["on_draw", {"op": "lose_hype"}, "on_draw not a list"],
		["on_end_of_turn_in_hand", [{"op": 3}], "end-of-turn op not text"]]
	for case: Array in cases:
		# bad: the card with one field broken.
		var bad: Dictionary = junk.duplicate(true)
		bad[case[0]] = case[1]
		assert_false(CardDef.check(bad).is_empty(), case[2])


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


## Task 011's optional enemy fields: a scripted pattern of its own move ids and a per-move target
## are valid; an empty pattern, an unknown move in it, an unknown target and a negative weight are not.
func test_enemy_pattern_and_move_target() -> void:
	# bouncer: a Bouncer-style enemy that alternates Guard and a hit, as a pattern.
	var bouncer: Dictionary = {"id": "goblin_bouncer", "name": "Goblin Bouncer", "floor": 1, "tier": "normal",
		"max_hp": 28, "arm_count": 2, "pattern": ["guard_up", "hit"],
		"moves": [{"id": "guard_up", "weight": 0, "intent": "defend", "target": "none", "effects": [{"op": "guard", "amount": 8}]},
			{"id": "hit", "weight": 0, "intent": "attack", "target": "dude", "effects": [{"op": "damage", "amount": 9}]},
			{"id": "slam", "weight": 1, "intent": "attack", "target": "all_dudes", "effects": [{"op": "damage", "amount": 1}]}]}
	assert_no_errors(EnemyDef.check(bouncer), "pattern and targets")
	# bad: copies of bouncer, each broken one way.
	var bad: Dictionary = bouncer.duplicate(true)
	bad["pattern"] = []
	assert_eq(EnemyDef.check(bad).size(), 1, "empty pattern")
	bad = bouncer.duplicate(true)
	bad["pattern"] = ["guard_up", "kick"]
	assert_eq(EnemyDef.check(bad).size(), 1, "pattern names an unknown move")
	bad = bouncer.duplicate(true)
	bad["pattern"] = "guard_up"
	assert_eq(EnemyDef.check(bad).size(), 1, "pattern is not a list")
	bad = bouncer.duplicate(true)
	bad["moves"][1]["target"] = "enemy"
	assert_eq(EnemyDef.check(bad).size(), 1, "unknown move target")
	bad = bouncer.duplicate(true)
	bad["moves"][2]["weight"] = -1
	assert_eq(EnemyDef.check(bad).size(), 1, "negative weight")
	bad = bouncer.duplicate(true)
	bad["moves"][2]["aim"] = "dude"
	assert_eq(EnemyDef.check(bad).size(), 1, "unknown move field")


## Task 011's enemy move_history: [] in blank(), a list of move ids; anything else is reported.
func test_enemy_move_history() -> void:
	# enemy: a blank enemy state.
	var enemy: Dictionary = EnemyState.blank("e1", "goblin_bouncer")
	assert_eq(enemy["move_history"], [], "blank history")
	enemy["move_history"] = ["guard_up", "hit", "guard_up"]
	assert_no_errors(EnemyState.check(enemy), "history of move ids")
	enemy["move_history"] = ["guard_up", 3]
	assert_eq(EnemyState.check(enemy).size(), 1, "non-String entry")
	enemy.erase("move_history")
	assert_eq(EnemyState.check(enemy).size(), 1, "move_history is required")


## json_values: whole numbers become ints at any depth, fractions stay floats, errors give a line.
func test_json_values_normalize() -> void:
	# parsed: a parse of mixed numbers.
	var parsed: Dictionary = JsonValues.parse('{"a": 3, "b": 1.5, "c": [2, {"d": -4}]}')
	assert_eq(parsed["value"], {"a": 3, "b": 1.5, "c": [2, {"d": -4}]})
	# broken: a parse of invalid JSON.
	var broken: Dictionary = JsonValues.parse('{"a": }')
	assert_false(broken["ok"], "invalid JSON must fail")
	assert_true(broken["error"].begins_with("line "), "error should name a line: " + broken["error"])


## Returns a valid enemy definition that uses every behavior field task 017 added, for the tests below.
func _behavior_enemy() -> Dictionary:
	return {"id": "goblin_shot_caller", "name": "Goblin Shot-Caller", "floor": 1, "tier": "rival",
		"max_hp": 60, "arm_count": 2, "tags": ["goblin"], "arrives_with": ["goblin_pledge", "goblin_pledge"],
		"move_rules": [{"move_id": "replace", "when": [{"if": "turn_cycle", "every": 2, "first_turn": 2},
			{"if": "count_below", "def_id": "goblin_pledge", "count": 2}]},
			{"move_id": "pump", "when": [{"if": "last_of_tag", "tag": "goblin"}, {"if": "turn_at_least", "turn": 4},
				{"if": "count_at_least", "def_id": "goblin_pledge", "count": 1}, {"if": "hp_below_percent", "percent": 50}]}],
		"triggers": [{"id": "noise_complaint", "on": "cards_played", "cards": 5, "repeat": false,
			"effects": [{"op": "damage", "amount": 5}]},
			{"id": "momentum", "on": "unblocked_damage", "effects": [{"op": "gain_swole", "amount": 2}]}],
		"split": {"into": "foam_slime", "count": 2, "at_hp_percent": 50},
		"periodic_statuses": [{"status": "faded", "every": 2, "first_turn": 1}],
		"drops_brews": 1,
		"moves": [{"id": "hit", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 10}]},
			{"id": "replace", "weight": 0, "intent": "summon", "effects": [{"op": "summon_enemy", "enemy_id": "goblin_pledge", "count": 1}]},
			{"id": "pump", "weight": 0, "intent": "buff", "effects": [{"op": "gain_swole", "amount": 2, "tag": "goblin"}]}]}


## Task 017's optional enemy fields: a definition using all of them is valid, and each kind of
## mistake in them is reported exactly once.
func test_enemy_behavior_fields() -> void:
	assert_no_errors(EnemyDef.check(_behavior_enemy()), "every behavior field")
	# cases: label -> a function that breaks a copy of the valid definition one way.
	var cases: Dictionary = {
		"duplicate tag": func(e: Dictionary) -> void: e["tags"] = ["goblin", "goblin"],
		"arrives_with not a list": func(e: Dictionary) -> void: e["arrives_with"] = "goblin_pledge",
		"rule names an unknown move": func(e: Dictionary) -> void: e["move_rules"][0]["move_id"] = "kick",
		"rule without conditions": func(e: Dictionary) -> void: e["move_rules"][0]["when"] = [],
		"unknown condition": func(e: Dictionary) -> void: e["move_rules"][0]["when"][0] = {"if": "moon_is_full"},
		"condition missing a field": func(e: Dictionary) -> void: e["move_rules"][0]["when"][0].erase("every"),
		"condition with an extra field": func(e: Dictionary) -> void: e["move_rules"][0]["when"][1]["tag"] = "goblin",
		"condition turn 0": func(e: Dictionary) -> void: e["move_rules"][1]["when"][1]["turn"] = 0,
		"percent above 100": func(e: Dictionary) -> void: e["move_rules"][1]["when"][3]["percent"] = 101,
		"unknown trigger kind": func(e: Dictionary) -> void: e["triggers"][0]["on"] = "card_drawn",
		"trigger missing repeat": func(e: Dictionary) -> void: e["triggers"][0].erase("repeat"),
		"duplicate trigger id": func(e: Dictionary) -> void: e["triggers"][1]["id"] = "noise_complaint",
		"trigger cards 0": func(e: Dictionary) -> void: e["triggers"][0]["cards"] = 0,
		"split at 100 percent": func(e: Dictionary) -> void: e["split"]["at_hp_percent"] = 100,
		"split count 0": func(e: Dictionary) -> void: e["split"]["count"] = 0,
		"split missing into": func(e: Dictionary) -> void: e["split"].erase("into"),
		"periodic unknown status": func(e: Dictionary) -> void: e["periodic_statuses"][0]["status"] = "exposed",
		"periodic every 0": func(e: Dictionary) -> void: e["periodic_statuses"][0]["every"] = 0,
		"negative drops_brews": func(e: Dictionary) -> void: e["drops_brews"] = -1,
		"float drops_brews": func(e: Dictionary) -> void: e["drops_brews"] = 1.0,
	}
	for label: String in cases.keys():
		# bad: a fresh copy, broken by this case.
		var bad: Dictionary = _behavior_enemy()
		cases[label].call(bad)
		assert_eq(EnemyDef.check(bad).size(), 1, label + ": " + str(EnemyDef.check(bad)))


## Task 017's state fields: enemy haul and drops_brews, combat brews_dropped. Blank values are valid,
## filled values are valid, and bad ones are reported.
func test_haul_and_brew_fields() -> void:
	# enemy: a blank enemy state, changed below.
	var enemy: Dictionary = EnemyState.blank("e1", "dorm_rat")
	assert_eq(enemy["haul"], {}, "blank haul")
	assert_eq(enemy["drops_brews"], 0, "blank drops_brews")
	enemy["haul"] = {"p1": 5, "p2": 10}
	enemy["drops_brews"] = 1
	assert_no_errors(EnemyState.check(enemy), "filled")
	enemy["haul"] = {"p1": 0}
	assert_eq(EnemyState.check(enemy).size(), 1, "zero haul entry")
	enemy["haul"] = {"p1": 5.0}
	assert_eq(EnemyState.check(enemy).size(), 1, "float haul entry")
	enemy["haul"] = {}
	enemy["drops_brews"] = -1
	assert_eq(EnemyState.check(enemy).size(), 1, "negative drops_brews")
	# combat: a blank fight, changed below.
	var combat: Dictionary = CombatState.blank()
	assert_eq(combat["brews_dropped"], 0, "blank brews_dropped")
	combat["brews_dropped"] = -1
	assert_eq(CombatState.check(combat).size(), 1, "negative brews_dropped")
	combat.erase("brews_dropped")
	assert_eq(CombatState.check(combat).size(), 1, "brews_dropped is required")


## Task 017's event types have the documented shapes.
func test_task_017_events() -> void:
	# good: one valid event of each new type.
	var good: Array = [
		Event.make("enemy_fled", {"enemy_uid": "e3"}),
		Event.make("enemy_split", {"enemy_uid": "e3"}),
		Event.make("dolla_bills_stolen", {"enemy_uid": "e3", "player_id": "p1", "amount": 5}),
		Event.make("dolla_bills_returned", {"enemy_uid": "e3", "player_id": "p1", "amount": 5}),
		Event.make("brew_dropped", {"enemy_uid": "e3", "count": 1}),
		Event.make("enemy_triggered", {"enemy_uid": "e3", "trigger_id": "noise_complaint", "target_id": "p1"}),
	]
	for event: Dictionary in good:
		assert_no_errors(Event.check(event), event["type"])
	assert_eq(Event.check(Event.make("dolla_bills_stolen", {"enemy_uid": "e3", "player_id": "p1"})).size(), 1, "missing amount")
