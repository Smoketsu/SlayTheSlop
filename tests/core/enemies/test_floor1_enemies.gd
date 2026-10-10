## Floor 1 enemies other than the goblins (task 017): Keg Slime, Dorm Rats, Skeleton Intern,
## Boo-zer, Mimic Cooler, Kobold RA, Hall Monitor Golem and Sewer Gator. Lane: core (Agent A).
## Enemies are the fixtures in tests/core/enemies/enemy_fixtures.gd (task 010's data has not merged).
## Skeleton Intern's Paperwork and Hall Monitor Golem's Detention cards need task 015's add_card op;
## their tests here cover everything else, and the card checks wait in task 017's log.
extends "res://tests/core/enemies/enemy_test_case.gd"

const EnemyBehaviors := preload("res://core/combat/enemy_behaviors.gd")
const Ops := preload("res://core/ops/ops.gd")

## Fixed seed for every fight in this file.
const SEED: int = 17017


## Keg Slime (24 HP): above half HP nothing happens; the hit that leaves it at 12 or less splits it,
## after the card, into two 10-HP Foam Slimes at its position that pick intents at once and act in
## the coming enemy phase.
func test_keg_slime_splits_at_half_hp() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: a Keg Slime between two Pledges, so the split's position shows.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["test_turtle", "keg_slime", "test_turtle"], 100)
	# slime: the Keg Slime's uid.
	var slime: String = state["combat"]["enemies"][1]["uid"]
	# result: the fight as it goes.
	var result: Dictionary = play(rules, state, 0, "neutral_test_poke", slime)
	result = play(rules, result["state"], 1, "neutral_test_poke", slime)
	assert_eq(enemy_by_uid(result["state"], slime)["hp"], 14, "above half: no split")
	assert_eq(of_type(result["events"], "enemy_split"), [])
	result = play(rules, result["state"], 2, "neutral_test_poke", slime)
	# The third card of the turn also fills the solo Bro Meter (task 013), before the split is settled.
	assert_eq(types(result["events"]), ["card_played", "damage_dealt", "card_moved", "bro_meter_changed",
		"enemy_split", "enemy_spawned", "intent_set", "enemy_spawned", "intent_set"])
	assert_eq(of_type(result["events"], "enemy_split"), [Event.make("enemy_split", {"enemy_uid": slime})])
	assert_eq(of_type(result["events"], "enemy_spawned").map(func(e: Dictionary) -> int: return e["index"]), [1, 2])
	assert_eq(lineup(result["state"]), ["test_turtle", "foam_slime", "foam_slime", "test_turtle"])
	for i: int in [1, 2]:
		# foam: one Foam Slime.
		var foam: Dictionary = result["state"]["combat"]["enemies"][i]
		assert_eq([foam["hp"], foam["max_hp"], foam["statuses"], foam["intent"]],
			[10, 10, {}, {"move_id": "fizz", "target_ids": ["p1"]}], "fresh 10-HP Foam Slime")
	assert_true(enemy_by_uid(result["state"], slime).is_empty(), "the Keg Slime is gone")
	result = ready(rules, result["state"], 3)
	assert_eq(of_type(result["events"], "enemy_acted").map(func(e: Dictionary) -> String: return e["move_id"]),
		["shell", "fizz", "fizz", "shell"], "both halves act this turn")
	assert_eq(result["state"]["dudes"][0]["hp"], 94)


## Keg Slime: a hit that kills it outright leaves nothing to split, and in a party of 2 the split
## point and the Foam Slimes' HP scale with the HP multiplier (43 HP splits at 21; halves have 18).
func test_keg_slime_kill_and_party_scaling() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: a solo Keg Slime, with 4 Hype for the 99-damage Big.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["keg_slime"])
	state["dudes"][0]["hype"] = 4
	# result: the kill.
	var result: Dictionary = play(rules, state, 0, "neutral_test_big", state["combat"]["enemies"][0]["uid"])
	assert_eq(of_type(result["events"], "enemy_split"), [], "killed outright")
	assert_eq(result["state"]["combat"]["result"], "won")
	# duo: a party of 2 against a Keg Slime.
	var duo: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["keg_slime"])
	# slime: the Keg Slime's state.
	var slime: Dictionary = duo["combat"]["enemies"][0]
	assert_eq(slime["max_hp"], 43)
	slime["hp"] = 22
	assert_false(EnemyBehaviors.should_split(slime, rules["enemies"]["keg_slime"]["split"]), "22 of 43 is above half")
	slime["hp"] = 21
	assert_true(EnemyBehaviors.should_split(slime, rules["enemies"]["keg_slime"]["split"]), "21 of 43 is at or below half")
	# events: the split's events.
	var events: Array = []
	EnemyBehaviors.settle_in_place(rules, duo, events)
	assert_eq(duo["combat"]["enemies"].map(func(e: Dictionary) -> int: return e["max_hp"]), [18, 18])
	assert_valid(duo, events)


## A split in the enemy phase (as thorns could cause) gives the halves no intent until the next turn.
func test_split_in_enemy_phase_waits_for_intents() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: a solo Keg Slime, set to half HP in the enemy phase by hand.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["keg_slime"])
	state["combat"]["phase"] = "enemy"
	state["combat"]["enemies"][0]["hp"] = 12
	# events: the split's events.
	var events: Array = []
	EnemyBehaviors.settle_in_place(rules, state, events)
	assert_eq(types(events), ["enemy_split", "enemy_spawned", "enemy_spawned"])
	assert_eq(state["combat"]["enemies"].map(func(e: Dictionary) -> Variant: return e["intent"]), [null, null])


## Dorm Rats (3 x 8 HP): each bite deals 3 and steals 5 Dolla Bills, never more than the Dude holds.
## Killing a rat returns its haul; the others flee on turn 4 (intent shown on turn 4, gone in that
## enemy phase) with what they stole, and the fight ends with no enemies left.
func test_dorm_rats_steal_return_and_flee() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: a pack of 3 against a Dude holding 12 Dolla Bills.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["dorm_rat", "dorm_rat", "dorm_rat"], 30, 12)
	# rats: the three rats' uids.
	var rats: Array = state["combat"]["enemies"].map(func(e: Dictionary) -> String: return e["uid"])
	# result: the fight as it goes.
	var result: Dictionary = ready(rules, state, 0)
	assert_eq(of_type(result["events"], "dolla_bills_stolen").map(func(e: Dictionary) -> int: return e["amount"]),
		[5, 5, 2], "5, 5, then the last 2")
	assert_eq(result["state"]["dudes"][0]["dolla_bills"], 0)
	assert_eq(result["state"]["dudes"][0]["hp"], 21, "3 bites of 3")
	assert_eq(result["state"]["combat"]["enemies"].map(func(e: Dictionary) -> Dictionary: return e["haul"]),
		[{"p1": 5}, {"p1": 5}, {"p1": 2}])
	# Turn 2: kill the first rat; its 5 come back.
	result = play(rules, result["state"], 1, "neutral_test_poke", rats[0])
	result = play(rules, result["state"], 2, "neutral_test_poke", rats[0])
	assert_eq(result["events"].slice(result["events"].find(Event.make("enemy_died", {"enemy_uid": rats[0]}))).slice(0, 3), [
		Event.make("enemy_died", {"enemy_uid": rats[0]}),
		Event.make("dolla_bills_changed", {"player_id": "p1", "delta": 5, "dolla_bills": 5}),
		Event.make("dolla_bills_returned", {"enemy_uid": rats[0], "player_id": "p1", "amount": 5}),
	])
	result = ready(rules, result["state"], 3)
	assert_eq(result["state"]["dudes"][0]["dolla_bills"], 0, "the 5 are stolen again")
	assert_eq(result["state"]["combat"]["enemies"].map(func(e: Dictionary) -> Dictionary: return e["haul"]),
		[{"p1": 10}, {"p1": 2}])
	result = ready(rules, result["state"], 4)
	assert_eq(result["state"]["combat"]["turn"], 4)
	assert_eq(result["state"]["combat"]["enemies"].map(func(e: Dictionary) -> Dictionary: return e["intent"]),
		[{"move_id": "scurry_off", "target_ids": []}, {"move_id": "scurry_off", "target_ids": []}], "turn 4: flee")
	result = ready(rules, result["state"], 5)
	assert_eq(of_type(result["events"], "enemy_fled"), [Event.make("enemy_fled", {"enemy_uid": rats[1]}),
		Event.make("enemy_fled", {"enemy_uid": rats[2]})])
	assert_eq(of_type(result["events"], "dolla_bills_returned"), [], "fled rats keep their haul")
	assert_eq(of_type(result["events"], "enemy_died"), [])
	assert_eq(result["state"]["dudes"][0]["dolla_bills"], 0)
	assert_eq([result["state"]["combat"]["phase"], result["state"]["combat"]["result"]], ["over", "won"])


## steal_dolla_bills in co-op: one rat robs two Dudes in one bite (an area bite); each gets their own
## part back when it dies, in player order.
func test_haul_is_per_player() -> void:
	# rules: the enemy test ruleset, with the rat's bite turned into an area bite.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: two Dudes with 3 and 20 Dolla Bills, one rat.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_dude", "test_dude"], ["dorm_rat"])
	state["dudes"][0]["dolla_bills"] = 3
	state["dudes"][1]["dolla_bills"] = 20
	# rat: the rat's uid.
	var rat: String = state["combat"]["enemies"][0]["uid"]
	# events: the effect's events.
	var events: Array = []
	Ops.run(state, {"op": "steal_dolla_bills", "amount": 5}, Ops.make_context(rules, rat, ["p1", "p2"], true, false), events)
	assert_eq(state["combat"]["enemies"][0]["haul"], {"p1": 3, "p2": 5})
	assert_eq([state["dudes"][0]["dolla_bills"], state["dudes"][1]["dolla_bills"]], [0, 15])
	state["combat"]["enemies"][0]["hp"] = 1
	events = []
	Ops.run(state, {"op": "damage", "amount": 1}, Ops.make_context(rules, "p1", [rat], true, true), events)
	assert_eq(of_type(events, "dolla_bills_returned").map(func(e: Dictionary) -> String: return e["player_id"]), ["p1", "p2"])
	assert_eq([state["dudes"][0]["dolla_bills"], state["dudes"][1]["dolla_bills"]], [3, 20])
	assert_valid(state, events)


## Skeleton Intern: hits for 6 every turn and on every other turn uses its Paperwork move, aimed at
## the Dude it hits. (That the Paperwork lands in the target's draw pile is checked once task 015's
## add_card op has merged; see task 017's log.)
func test_skeleton_intern_alternates() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: one Skeleton Intern.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["skeleton_intern"])
	# result: the fight as it goes.
	var result: Dictionary = ready(rules, state, 0)
	assert_eq(result["state"]["dudes"][0]["hp"], 24, "hit for 6")
	assert_eq(result["state"]["combat"]["enemies"][0]["intent"], {"move_id": "file_paperwork", "target_ids": ["p1"]})
	result = ready(rules, result["state"], 1)
	assert_eq(result["state"]["dudes"][0]["hp"], 18, "the Paperwork turn hits for 6 too")
	result = ready(rules, result["state"], 2)
	assert_eq(result["state"]["combat"]["enemies"][0]["move_history"], ["hit", "file_paperwork", "hit", "file_paperwork"])


## Boo-zer (16 HP, Faded on turns 1, 3 ...): while Faded every hit deals at most FADED_MAX_DAMAGE,
## attack or not, including each hit of a multi-hit card; on other turns hits land in full. Faded is
## a status the client sees (status_changed at the start of each turn).
func test_boo_zer_faded_every_other_turn() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# started: the fight's start, with its events.
	var started: Dictionary = Fight.start_fight(rules, Party.build_run_state(rules, SEED, ["test_dude"])["state"], ["boo_zer"])
	# ghost: the Boo-zer's uid.
	var ghost: String = started["state"]["combat"]["enemies"][0]["uid"]
	assert_true(started["events"].has(Event.make("status_changed", {"target_id": ghost, "status": "faded", "delta": 1, "stacks": 1})))
	assert_eq(started["state"]["combat"]["enemies"][0]["statuses"], {"faded": 1}, "turn 1: Faded")
	# result: the fight as it goes.
	var result: Dictionary = play(rules, started["state"], 0, "neutral_test_poke", ghost)
	assert_eq(of_type(result["events"], "damage_dealt")[0]["amount"], rules["constants"]["FADED_MAX_DAMAGE"])
	result = play(rules, result["state"], 1, "neutral_test_double", ghost)
	assert_eq(of_type(result["events"], "damage_dealt").map(func(e: Dictionary) -> int: return e["amount"]), [1, 1], "each hit capped")
	result = play(rules, result["state"], 2, "neutral_test_skill_hit", ghost)
	assert_eq(of_type(result["events"], "damage_dealt")[0]["amount"], 1, "non-attack damage capped too")
	assert_eq(result["state"]["combat"]["enemies"][0]["hp"], 12)
	result = ready(rules, result["state"], 3)
	assert_true(result["events"].has(Event.make("status_changed", {"target_id": ghost, "status": "faded", "delta": -1, "stacks": 0})))
	assert_eq(result["state"]["combat"]["enemies"][0]["statuses"], {}, "turn 2: not Faded")
	assert_eq(result["state"]["dudes"][0]["hp"], 22, "hits for 8")
	result = play(rules, result["state"], 4, "neutral_test_poke", ghost)
	assert_eq(of_type(result["events"], "damage_dealt")[0]["amount"], 5, "full damage")
	result = ready(rules, result["state"], 5)
	assert_eq(result["state"]["combat"]["enemies"][0]["statuses"], {"faded": 1}, "turn 3: Faded again")


## Mimic Cooler: bites for 12; when it dies it drops a Brew, reported (brew_dropped and
## combat.brews_dropped) for the run lane, and no Brew is granted here.
func test_mimic_cooler_reports_brew_drop() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: one Mimic Cooler.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["mimic_cooler"])
	assert_eq(state["combat"]["enemies"][0]["drops_brews"], 1)
	# mimic: its uid.
	var mimic: String = state["combat"]["enemies"][0]["uid"]
	# result: the fight as it goes.
	var result: Dictionary = ready(rules, state, 0)
	assert_eq(result["state"]["dudes"][0]["hp"], 18, "bites for 12")
	result["state"]["dudes"][0]["hype"] = 4
	result = play(rules, result["state"], 1, "neutral_test_big", mimic)
	assert_eq(types(result["events"]), ["card_played", "hype_changed", "damage_dealt", "enemy_died", "brew_dropped",
		"card_moved", "fight_ended"])
	assert_eq(of_type(result["events"], "brew_dropped"), [Event.make("brew_dropped", {"enemy_uid": mimic, "count": 1})])
	assert_eq(result["state"]["combat"]["brews_dropped"], 1)
	assert_eq(result["state"]["dudes"][0]["brews"], [], "reported, not granted")


## Kobold RA: Noise Complaint deals 5 to a player on their fifth card of a turn, once (not on the
## sixth), again on the fifth card of the next turn. It is not attack damage (G3): the Kobold's
## Swole and the Dude's Exposed do not change it, and Guard absorbs it.
func test_kobold_noise_complaint() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: one Kobold RA, with 3 Swole, against an Exposed Dude.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["kobold_ra"], 100)
	state["combat"]["enemies"][0]["swole"] = 3
	state["dudes"][0]["statuses"] = {"exposed": 3}
	# kobold: its uid.
	var kobold: String = state["combat"]["enemies"][0]["uid"]
	# result: the fight as it goes.
	var result: Dictionary = {"state": state}
	for seq: int in 4:
		result = play(rules, result["state"], seq, "neutral_test_shrug", "")
		assert_eq(of_type(result["events"], "enemy_triggered"), [], "card %d: quiet" % (seq + 1))
	result = play(rules, result["state"], 4, "neutral_test_shrug", "")
	assert_eq(types(result["events"]), ["card_played", "card_moved", "enemy_triggered", "damage_dealt"])
	assert_eq(result["events"].slice(2), [
		Event.make("enemy_triggered", {"enemy_uid": kobold, "trigger_id": "noise_complaint", "target_id": "p1"}),
		Event.make("damage_dealt", {"source_id": kobold, "target_id": "p1", "amount": 5, "blocked": 0, "hp_lost": 5}),
	])
	result = play(rules, result["state"], 5, "neutral_test_shrug", "")
	assert_eq(of_type(result["events"], "enemy_triggered"), [], "the sixth card: no second complaint")
	result = ready(rules, result["state"], 6)
	# Turn 2: Guard from a Brace absorbs the complaint.
	result = play(rules, result["state"], 7, "neutral_test_brace", "")
	for seq: int in [8, 9, 10]:
		result = play(rules, result["state"], seq, "neutral_test_shrug", "")
	result = play(rules, result["state"], 11, "neutral_test_shrug", "")
	assert_eq(of_type(result["events"], "damage_dealt"), [
		Event.make("damage_dealt", {"source_id": kobold, "target_id": "p1", "amount": 5, "blocked": 5, "hp_lost": 0})])


## Hall Monitor Golem: its Detention trigger fires on every third card a player plays in a turn
## (3rd, 6th ...), aimed at that player. (The Detention card it adds to the discard pile is checked
## once task 015's add_card op has merged; see task 017's log.)
func test_hall_monitor_golem_every_third_card() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: one Golem.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["hall_monitor_golem"], 100)
	# golem: its uid.
	var golem: String = state["combat"]["enemies"][0]["uid"]
	# fired_on: the card counts at which the trigger fired.
	var fired_on: Array = []
	# result: the fight as it goes.
	var result: Dictionary = {"state": state}
	for seq: int in 7:
		result = play(rules, result["state"], seq, "neutral_test_shrug", "")
		for event: Dictionary in of_type(result["events"], "enemy_triggered"):
			assert_eq(event, Event.make("enemy_triggered", {"enemy_uid": golem, "trigger_id": "detention", "target_id": "p1"}))
			fired_on.append(seq + 1)
	assert_eq(fired_on, [3, 6])
	result = ready(rules, result["state"], 7)
	assert_eq(result["state"]["dudes"][0]["hp"], 86, "hits for 14")


## Sewer Gator: Death Roll is 5 damage 3 times; each hit that takes HP gives it 2 Swole after the
## roll (3 hits: +6). Next turn its hits are 11; the one Guard fully blocks gives nothing, the
## others give 2 each.
func test_sewer_gator_death_roll_and_swole() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: one Gator against a sturdy Dude.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["sewer_gator"], 200)
	# gator: its uid.
	var gator: String = state["combat"]["enemies"][0]["uid"]
	# result: the fight as it goes.
	var result: Dictionary = ready(rules, state, 0)
	assert_eq(of_type(result["events"], "damage_dealt").map(func(e: Dictionary) -> int: return e["hp_lost"]), [5, 5, 5])
	assert_eq(of_type(result["events"], "stat_changed").map(func(e: Dictionary) -> int: return e["value"]), [2, 4, 6])
	assert_eq(of_type(result["events"], "enemy_triggered").size(), 3)
	assert_eq(result["state"]["combat"]["enemies"][0]["swole"], 6)
	# Turn 2: 15 Guard from three Braces.
	for seq: int in [1, 2, 3]:
		result = play(rules, result["state"], seq, "neutral_test_brace", "")
	assert_eq(result["state"]["dudes"][0]["guard"], 15)
	result = ready(rules, result["state"], 4)
	assert_eq(of_type(result["events"], "damage_dealt"), [
		Event.make("damage_dealt", {"source_id": gator, "target_id": "p1", "amount": 11, "blocked": 11, "hp_lost": 0}),
		Event.make("damage_dealt", {"source_id": gator, "target_id": "p1", "amount": 11, "blocked": 4, "hp_lost": 7}),
		Event.make("damage_dealt", {"source_id": gator, "target_id": "p1", "amount": 11, "blocked": 0, "hp_lost": 11}),
	])
	assert_eq(result["state"]["combat"]["enemies"][0]["swole"], 10, "two unblocked hits: +4")


## A fight refuses enemies whose escorts, split targets or summoned enemies the ruleset lacks, and a
## missing FADED_MAX_DAMAGE.
func test_start_checks_behavior_references() -> void:
	# rules: the enemy test ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	assert_eq(EnemyBehaviors.check_start(rules, ["goblin_shot_caller", "keg_slime"]), "")
	# broken: a writable copy of the ruleset, broken one way at a time.
	var broken: Dictionary = rules.duplicate(true)
	broken["enemies"].erase("foam_slime")
	assert_true(Fight.check_start(broken, Party.build_run_state(rules, SEED, ["test_dude"])["state"], ["keg_slime"]).contains("foam_slime"))
	broken = rules.duplicate(true)
	broken["enemies"]["goblin_shot_caller"]["arrives_with"] = ["goblin_pladge"]
	assert_true(EnemyBehaviors.check_start(broken, ["goblin_shot_caller"]).contains("goblin_pladge"))
	broken = rules.duplicate(true)
	broken["enemies"]["goblin_pledge"]["moves"][1]["effects"][0]["enemy_id"] = "goblin_plege"
	assert_true(EnemyBehaviors.check_start(broken, ["goblin_pledge"]).contains("goblin_plege"))
	broken = rules.duplicate(true)
	broken["constants"].erase("FADED_MAX_DAMAGE")
	assert_true(EnemyBehaviors.check_start(broken, ["test_dummy"]).contains("FADED_MAX_DAMAGE"))


## Skeleton Intern: on its Paperwork turn the target gets one Paperwork shuffled into the draw pile
## (task 015's add_card; written in task 017, added once 015 was in the stack).
func test_skeleton_intern_paperwork() -> void:
	# rules: the enemy fixture ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# state: p1 against one Skeleton Intern.
	var state: Dictionary = EnemyFixtures.solo_fight(rules, SEED, ["skeleton_intern"])
	# result: turn 1 ends; the Intern only hits.
	var result: Dictionary = ready(rules, state, 0)
	assert_eq(of_type(result["events"], "card_created"), [])
	# Turn 2 ends; the Intern hits and adds Paperwork.
	result = ready(rules, result["state"], 1)
	# created: the card_created events of turn 2's enemy phase.
	var created: Array = of_type(result["events"], "card_created")
	assert_eq(created.size(), 1)
	assert_eq([created[0]["player_id"], created[0]["def_id"], created[0]["to"]], ["p1", "junk_paperwork", "draw_pile"])
	# dude: p1 after turn 3's Refresh.
	var dude: Dictionary = result["state"]["dudes"][0]
	assert_eq(dude["cards"][created[0]["card_uid"]]["def_id"], "junk_paperwork")
	# It was shuffled into the draw pile before turn 3's Refresh drew, so it is in the draw pile or the hand.
	assert_true(dude["draw_pile"].has(created[0]["card_uid"]) or dude["hand"].has(created[0]["card_uid"]))
	assert_false(dude["deck"].has(created[0]["card_uid"]), "Paperwork lasts the fight, so it is not in the run deck")


## Hall Monitor Golem: the 3rd and 6th card of a turn each put one Detention on the discard pile
## (task 015's add_card; written in task 017, added once 015 was in the stack).
func test_hall_monitor_golem_adds_detention() -> void:
	# rules: the enemy fixture ruleset.
	var rules: Dictionary = EnemyFixtures.ruleset()
	# result: the latest apply() result; starts as p1 (100 HP) against one Hall Monitor Golem.
	var result: Dictionary = {"state": EnemyFixtures.solo_fight(rules, SEED, ["hall_monitor_golem"], 100)}
	# detentions: which card of the turn (1-based) each Detention came after.
	var detentions: Array = []
	for seq: int in 7:
		result = play(rules, result["state"], seq, "neutral_test_shrug", "")
		for event: Dictionary in of_type(result["events"], "card_created"):
			assert_eq([event["def_id"], event["to"]], ["junk_detention", "discard_pile"])
			detentions.append(seq + 1)
	assert_eq(detentions, [3, 6])
	# dude: p1 after the seven plays.
	var dude: Dictionary = result["state"]["dudes"][0]
	assert_eq(dude["discard_pile"].filter(
		func(uid: String) -> bool: return dude["cards"][uid]["def_id"] == "junk_detention").size(), 2)
