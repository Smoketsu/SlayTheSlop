## Tom's new cards as data (task 030): the 13 of the 16 cards accepted in
## docs/proposals/tom-slice-cards.md (decision log row "Task 012: Tom's 16 new cards", #91) whose ops
## the core already has. Lane: tools (Agent B).
## Each file is checked against the accepted proposal, the schema, the op catalogue, the real ruleset
## and Tom's card pool; a few cards are played through Core.apply on the real data, and a fixed-seed
## fight plays a deck holding all 13.
extends "res://tests/framework/test_case.gd"

const Check := preload("res://tests/data/content_check.gd")
const CardDef := preload("res://core/schema/card_def.gd")
const Ops := preload("res://core/ops/ops.gd")
const Pools := preload("res://core/run/pools.gd")
const Core := preload("res://core/core.gd")
const Party := preload("res://core/combat/party.gd")
const Fight := preload("res://core/combat/fight.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const RunState := preload("res://core/schema/run_state.gd")

## The 13 new cards exactly as accepted in tom-slice-cards.md ("New cards"), card id -> definition.
## Numbers, text, rarity, target and keywords are the proposal's. "upgrade" is {} because the
## proposal's upgrade tables are not accepted yet (only the 16 cards are). Changed only when a person
## changes a card in the proposal or the decision log.
const ACCEPTED := {
	# Common, Repellent: Deal 4 damage. Apply 1 Ick.
	"tom_noogie": {"id": "tom_noogie", "name": "Noogie", "owner": "tom", "type": "attack", "rarity": "common",
		"cost": 0, "target": "enemy",
		"effects": [{"op": "damage", "amount": 4}, {"op": "apply_status", "status": "ick", "stacks": 1}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 4 damage. Apply 1 Ick"},
	# Common, Orthopedic Surgeon: Deal 7 damage; 1 Noodle Arms if the target has a Broken Arm.
	"tom_headlock": {"id": "tom_headlock", "name": "Headlock", "owner": "tom", "type": "attack", "rarity": "common",
		"cost": 1, "target": "enemy",
		"effects": [{"op": "damage", "amount": 7},
			{"op": "apply_status", "status": "noodle_arms", "stacks": 1, "if": "target_has_broken_arm"}],
		"keywords": [], "crunch": null, "upgrade": {},
		"text": "Deal 7 damage. If the target has a Broken Arm, apply 1 Noodle Arms"},
	# Common, Repellent: Apply 3 Ick. Draw 1 card.
	"tom_hot_take": {"id": "tom_hot_take", "name": "Hot Take", "owner": "tom", "type": "skill", "rarity": "common",
		"cost": 1, "target": "enemy",
		"effects": [{"op": "apply_status", "status": "ick", "stacks": 3}, {"op": "draw", "amount": 1}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Apply 3 Ick. Draw 1 card"},
	# Common, Repellent: Gain 5 Guard (on Tom, the actor). Apply 2 Ick.
	"tom_stare_down": {"id": "tom_stare_down", "name": "Stare Down", "owner": "tom", "type": "skill", "rarity": "common",
		"cost": 1, "target": "enemy",
		"effects": [{"op": "guard", "amount": 5}, {"op": "apply_status", "status": "ick", "stacks": 2}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Gain 5 Guard. Apply 2 Ick"},
	# Common, Head First: Deal 5 damage twice. Tom takes 2 damage.
	"tom_noggin_knock": {"id": "tom_noggin_knock", "name": "Noggin Knock", "owner": "tom", "type": "attack", "rarity": "common",
		"cost": 1, "target": "enemy",
		"effects": [{"op": "damage", "amount": 5, "hits": 2}, {"op": "self_damage", "amount": 2}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 5 damage twice. Tom takes 2 damage"},
	# Uncommon, Orthopedic Surgeon: Break 1 arm. Apply 2 Exposed.
	"tom_dislocate": {"id": "tom_dislocate", "name": "Dislocate", "owner": "tom", "type": "skill", "rarity": "uncommon",
		"cost": 1, "target": "enemy",
		"effects": [{"op": "apply_status", "status": "broken_arm", "stacks": 1},
			{"op": "apply_status", "status": "exposed", "stacks": 2}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Break 1 arm. Apply 2 Exposed"},
	# Uncommon, Orthopedic Surgeon: 6 damage, 6 more on a Broken Arm, 6 more on an Armless target.
	"tom_compound_fracture": {"id": "tom_compound_fracture", "name": "Compound Fracture", "owner": "tom", "type": "attack",
		"rarity": "uncommon", "cost": 2, "target": "enemy",
		"effects": [{"op": "damage", "amount": 6}, {"op": "damage", "amount": 6, "if": "target_has_broken_arm"},
			{"op": "damage", "amount": 6, "if": "target_now_armless"}],
		"keywords": [], "crunch": null, "upgrade": {},
		"text": "Deal 6 damage. If the target has a Broken Arm, deal 6 more. If it is Armless, deal 6 more"},
	# Uncommon, Repellent: Apply 7 Ick.
	"tom_story_time": {"id": "tom_story_time", "name": "Story Time", "owner": "tom", "type": "skill", "rarity": "uncommon",
		"cost": 2, "target": "enemy", "effects": [{"op": "apply_status", "status": "ick", "stacks": 7}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Apply 7 Ick"},
	# Uncommon, General: 2 Swole for this fight, 1 Ick to every enemy, Tapped.
	"tom_gym_selfie": {"id": "tom_gym_selfie", "name": "Gym Selfie", "owner": "tom", "type": "skill", "rarity": "uncommon",
		"cost": 1, "target": "self",
		"effects": [{"op": "gain_stat", "stat": "swole", "amount": 2, "duration": "fight"},
			{"op": "apply_status", "status": "ick", "stacks": 1, "target": "all_enemies"}],
		"keywords": ["tapped"], "crunch": null, "upgrade": {},
		"text": "Gain 2 Swole for this fight. Apply 1 Ick to all enemies. Tapped"},
	# Uncommon, Head First: Deal 18 damage. Tom takes 4 damage.
	"tom_headbutt": {"id": "tom_headbutt", "name": "Headbutt", "owner": "tom", "type": "attack", "rarity": "uncommon",
		"cost": 2, "target": "enemy",
		"effects": [{"op": "damage", "amount": 18}, {"op": "self_damage", "amount": 4}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 18 damage. Tom takes 4 damage"},
	# Rare, Orthopedic Surgeon: Deal 10 damage. Break 2 arms (capped at the enemy's arm_count).
	"tom_full_nelson": {"id": "tom_full_nelson", "name": "Full Nelson", "owner": "tom", "type": "attack", "rarity": "rare",
		"cost": 3, "target": "enemy",
		"effects": [{"op": "damage", "amount": 10}, {"op": "apply_status", "status": "broken_arm", "stacks": 2}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 10 damage. Break 2 arms"},
	# Rare, Repellent: Apply 12 Ick. Tapped.
	"tom_three_hour_podcast": {"id": "tom_three_hour_podcast", "name": "Three-Hour Podcast", "owner": "tom", "type": "skill",
		"rarity": "rare", "cost": 2, "target": "enemy", "effects": [{"op": "apply_status", "status": "ick", "stacks": 12}],
		"keywords": ["tapped"], "crunch": null, "upgrade": {}, "text": "Apply 12 Ick. Tapped"},
	# Rare Power, Orthopedic Surgeon and Repellent: whenever an enemy is Grossed Out, break 1 of its arms.
	"tom_main_character_energy": {"id": "tom_main_character_energy", "name": "Main Character Energy", "owner": "tom",
		"type": "power", "rarity": "rare", "cost": 2, "target": "none", "effects": [],
		"power_triggers": [{"when": "enemy_grossed_out", "target": "subject",
			"effects": [{"op": "apply_status", "status": "broken_arm", "stacks": 1}]}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Whenever an enemy is Grossed Out, break 1 of its arms"},
}

## Accepted cards that wait for a rule from Agent A, so have no data file yet: card id -> the core
## task that builds the rule. When one of those tasks merges, the card's own content task removes it
## here and adds it to ACCEPTED.
const WAITING := {
	"tom_bro_hug": "035 (ally targets)",
	"tom_tough_skull": "037 (self_damaged Power trigger)",
	"tom_nothing_to_lose": "039 (op damage_from_missing_hp)",
}

## Tom's card pool (core/run/pools.gd card_pool) with the 13 new cards: rarity -> number of cards.
## GDD cards: 4 common, 4 uncommon, 2 rare. New: 5 common, 5 uncommon, 3 rare (the proposal's 6, 6
## and 4, minus Bro Hug, Tough Skull and Nothing to Lose).
const POOL_SIZES := {"common": 9, "uncommon": 9, "rare": 5}

## The enemy of the single-card checks: 28 HP, 2 arms (GDD floor 1 table).
const TEST_FOE: String = "goblin_bouncer"
## Run seed of the single-card checks and of the fixed-seed fight.
const SEED: int = 20261011
## Hype given to Tom before a single-card check, enough for any two of the new cards. Test-only.
const CHECK_HYPE: int = 5

## The enemies of the fixed-seed fight, left to right.
const FOES: Array[String] = ["goblin_pledge", "goblin_bouncer"]
## Most requests the policy may send before the fight test gives up (a safety stop, not a rule).
const MAX_REQUESTS: int = 300
## Recorded outcome of the fixed-seed fight on Godot 4.7.2-stable with the data as merged in task 030:
## [result, final turn, applied requests, Tom's final HP]. If a data or rules change alters this
## fight on purpose, re-record it and say why in the PR.
const RECORDED: Array = ["won", 6, 21, 71]
## Recorded: the new card ids the fixed-seed fight played at least once, sorted (11 of the 13; Full
## Nelson and Headbutt were not played before the fight was won). Same rule as RECORDED.
const RECORDED_PLAYED: Array = ["tom_compound_fracture", "tom_dislocate", "tom_gym_selfie", "tom_headlock",
	"tom_hot_take", "tom_main_character_energy", "tom_noggin_knock", "tom_noogie", "tom_stare_down",
	"tom_story_time", "tom_three_hour_podcast"]


## data/cards holds exactly the 13 accepted files whose ops exist, each equal to the proposal, and
## none of the three waiting cards.
func test_new_cards_match_the_proposal() -> void:
	# ids: every card file name.
	var ids: Array[String] = Check.ids_in("data/cards")
	for id: String in ACCEPTED:
		assert_true(ids.has(id), "%s has a file" % id)
		assert_eq(Check.load_file("data/cards/%s.json" % id), Check.as_data(ACCEPTED[id]), id)
	for id: String in WAITING:
		assert_false(ids.has(id), "%s waits for task %s" % [id, WAITING[id]])
	assert_eq(ACCEPTED.size(), 13, "13 of the 16 accepted cards")


## Every new card passes the card schema, the op catalogue (effects and Power trigger effects) and
## the real ruleset build.
func test_new_cards_pass_the_schema_and_ops() -> void:
	# rules: the real ruleset.
	var rules: Dictionary = Check.real_ruleset()
	assert_false(rules.is_empty(), "data/ builds")
	for id: String in ACCEPTED:
		# card: the data file.
		var card: Dictionary = Check.load_file("data/cards/%s.json" % id)
		assert_no_errors(CardDef.check(card, id), "%s schema" % id)
		assert_no_errors(Ops.check_all(card["effects"], id + ".effects"), "%s ops" % id)
		for i: int in card.get("power_triggers", []).size():
			assert_no_errors(Ops.check_all(card["power_triggers"][i]["effects"], "%s.power_triggers[%d]" % [id, i]), "%s trigger ops" % id)
		assert_true(rules.get("cards", {}).has(id), "%s is in the ruleset" % id)


## Every new card is in Tom's card pool under its rarity, so rewards and Baileys can offer it.
func test_new_cards_are_in_toms_pool() -> void:
	# rules: the real ruleset. pool: Tom's card pool by rarity.
	var rules: Dictionary = Check.real_ruleset()
	if rules.is_empty():
		fail("data/ does not build")
		return
	var pool: Dictionary = Pools.card_pool(rules, "tom")
	for id: String in ACCEPTED:
		assert_true(pool[ACCEPTED[id]["rarity"]].has(id), "%s is offered as %s" % [id, ACCEPTED[id]["rarity"]])
	for rarity: String in POOL_SIZES:
		assert_eq(pool[rarity].size(), POOL_SIZES[rarity], "%s cards in Tom's pool" % rarity)


## Full Nelson then Compound Fracture on a fresh Goblin Bouncer: 10 damage and both arms broken,
## then all three of Compound Fracture's hits (the target has a Broken Arm and is Armless).
func test_full_nelson_then_compound_fracture() -> void:
	# setup: a fight against TEST_FOE with the two cards in hand.
	var setup: Dictionary = _fight_with_hand(["tom_full_nelson", "tom_compound_fracture"])
	if setup.is_empty():
		return
	# foe: the enemy's uid. played: the result after both cards.
	var foe: String = setup["state"]["combat"]["enemies"][0]["uid"]
	var played: Dictionary = _play_all(setup, foe)
	if played.is_empty():
		return
	assert_eq(_damage_to(played["events"], foe), [10, 6, 6, 6], "Full Nelson's hit, then Compound Fracture's three")
	assert_true(played["events"].any(func(e: Dictionary) -> bool:
		return e["type"] == "status_changed" and e["target_id"] == foe and e["status"] == "broken_arm" and e["stacks"] == 2),
		"Full Nelson breaks both arms")


## Headlock adds Noodle Arms only when the target has a Broken Arm: not on a fresh enemy, yes after
## Dislocate.
func test_headlock_needs_a_broken_arm() -> void:
	# fresh, broken: the two setups.
	var fresh: Dictionary = _fight_with_hand(["tom_headlock"])
	var broken: Dictionary = _fight_with_hand(["tom_dislocate", "tom_headlock"])
	if fresh.is_empty() or broken.is_empty():
		return
	# fresh_foe, broken_foe: the enemy uids.
	var fresh_foe: String = fresh["state"]["combat"]["enemies"][0]["uid"]
	var broken_foe: String = broken["state"]["combat"]["enemies"][0]["uid"]
	# after_fresh, after_broken: the results.
	var after_fresh: Dictionary = _play_all(fresh, fresh_foe)
	var after_broken: Dictionary = _play_all(broken, broken_foe)
	if after_fresh.is_empty() or after_broken.is_empty():
		return
	assert_false(_got_status(after_fresh["events"], fresh_foe, "noodle_arms"), "no Noodle Arms without a Broken Arm")
	assert_true(_got_status(after_broken["events"], broken_foe, "noodle_arms"), "Noodle Arms after Dislocate")
	assert_true(_got_status(after_broken["events"], broken_foe, "exposed"), "Dislocate applies Exposed")


## Main Character Energy, then Three-Hour Podcast: 12 Ick Grosses Out the Goblin Bouncer, and the
## Power breaks 1 of its arms. The Podcast is Tapped.
func test_main_character_energy_breaks_an_arm_on_gross_out() -> void:
	# setup: a fight with the Power and the Podcast in hand.
	var setup: Dictionary = _fight_with_hand(["tom_main_character_energy", "tom_three_hour_podcast"])
	if setup.is_empty():
		return
	# foe: the enemy's uid. podcast: the Podcast's uid. played: the result after both cards.
	var foe: String = setup["state"]["combat"]["enemies"][0]["uid"]
	var podcast: String = setup["uids"][1]
	var played: Dictionary = _play_all(setup, foe)
	if played.is_empty():
		return
	# types: the event types after the Podcast was played, in order.
	var types: Array = []
	for e: Dictionary in played["events"]:
		types.append(e["type"])
	assert_true(types.has("grossed_out"), "12 Ick Grosses Out the Goblin Bouncer")
	assert_true(types.has("power_triggered"), "Main Character Energy fires")
	assert_eq(played["state"]["combat"]["enemies"][0]["broken_arms"], 1, "the Power breaks 1 arm")
	assert_true(played["state"]["dudes"][0]["tapped_pile"].has(podcast), "the Podcast is Tapped")


## Tom fights a Goblin Pledge and a Goblin Bouncer on the real data with his starter deck plus one
## of each new card, playing a new card whenever one is legal. Every state passes run_state.check(),
## the fight ends as RECORDED, it plays RECORDED_PLAYED, and a replay gives identical snapshot bytes.
func test_fixed_seed_fight_with_the_new_cards() -> void:
	# first, second: two replays of the same fight.
	var first: Dictionary = _replay()
	var second: Dictionary = _replay()
	if first.is_empty() or second.is_empty():
		return
	assert_ne(first["state"]["combat"]["result"], "", "the fight is decided within %d requests" % MAX_REQUESTS)
	assert_eq(Snapshot.to_bytes(second["state"]), Snapshot.to_bytes(first["state"]), "a replay is identical")
	# outcome: what this fight ended with.
	var outcome: Array = [first["state"]["combat"]["result"], first["state"]["combat"]["turn"], first["requests"], first["state"]["dudes"][0]["hp"]]
	assert_eq(outcome, RECORDED, "recorded outcome")
	assert_eq(first["played"], RECORDED_PLAYED, "recorded new cards played")
	assert_false(first["played"].is_empty(), "at least one new card is played")


## Starts a fight against TEST_FOE on the real data and puts one fight-only copy of each card in
## def_ids at the end of Tom's hand, with CHECK_HYPE Hype. Returns {"rules", "state", "uids"} (the
## copies' uids, in def_ids order), or {} after recording a failure.
## def_ids: card ids from ACCEPTED.
func _fight_with_hand(def_ids: Array) -> Dictionary:
	# rules: the real ruleset.
	var rules: Dictionary = Check.real_ruleset()
	assert_false(rules.is_empty(), "data/ builds")
	if rules.is_empty():
		return {}
	# party: the run state with Tom in seat 1. started: the fight.
	var party: Dictionary = Party.build_run_state(rules, SEED, ["tom"])
	var started: Dictionary = Fight.start_fight(rules, party["state"], [TEST_FOE])
	assert_eq(started["error"], "", "start_fight")
	if started["error"] != "":
		return {}
	# state: the fight's state, changed below. dude: Tom. uids: the copies made.
	var state: Dictionary = started["state"]
	var dude: Dictionary = state["dudes"][0]
	var uids: Array = []
	for def_id: String in def_ids:
		# uid: a fresh card uid from next_uid, as the core makes them.
		var uid: String = Party.CARD_UID_PREFIX + str(state["next_uid"])
		state["next_uid"] += 1
		dude["cards"][uid] = {"def_id": def_id, "upgraded": false}
		dude["hand"].append(uid)
		uids.append(uid)
	dude["hype"] = CHECK_HYPE
	assert_no_errors(RunState.check(state), "the changed state is valid")
	return {"rules": rules, "state": state, "uids": uids}


## Plays the setup's copies in order, each aimed at target_id (or no target for a card that takes
## none). Returns {"state", "events"} with every event of those plays, or {} after recording a failure.
## setup: from _fight_with_hand. target_id: the enemy uid.
func _play_all(setup: Dictionary, target_id: String) -> Dictionary:
	# state: the current state. events: collected events.
	var state: Dictionary = setup["state"]
	var events: Array = []
	for uid: String in setup["uids"]:
		# card: the copy's definition. seq: the next seq.
		var card: Dictionary = setup["rules"]["cards"][state["dudes"][0]["cards"][uid]["def_id"]]
		var seq: int = state["dudes"][0]["last_seq"] + 1
		# request: the play.
		var request: Dictionary = {"type": "play_card", "player_id": "p1", "seq": seq, "card_uid": uid,
			"target_id": target_id if card["target"] == "enemy" else "", "crunch": false}
		# result: the core's answer.
		var result: Dictionary = Core.apply(setup["rules"], state, request)
		assert_eq(result["reject"], "", "%s is played" % card["id"])
		if result["reject"] != "":
			return {}
		state = result["state"]
		events.append_array(result["events"])
	return {"state": state, "events": events}


## Returns the amount of each damage_dealt event on target_id, in order.
## events: core events. target_id: the enemy uid.
func _damage_to(events: Array, target_id: String) -> Array:
	# amounts: the result.
	var amounts: Array = []
	for e: Dictionary in events:
		if e["type"] == "damage_dealt" and e["target_id"] == target_id:
			amounts.append(e["amount"])
	return amounts


## Returns true when events raise status on target_id.
## events: core events. target_id: the enemy uid. status: a status id.
func _got_status(events: Array, target_id: String, status: String) -> bool:
	return events.any(func(e: Dictionary) -> bool:
		return e["type"] == "status_changed" and e["target_id"] == target_id and e["status"] == status and e["delta"] > 0)


## Plays the fixed-seed fight. Returns {"state", "requests", "played"} ("played": the new card ids
## played at least once, sorted), or {} after recording a failure.
func _replay() -> Dictionary:
	# rules: the real ruleset.
	var rules: Dictionary = Check.real_ruleset()
	assert_false(rules.is_empty(), "data/ builds")
	if rules.is_empty():
		return {}
	# party: the run state with Tom in seat 1; his run deck gets one copy of each new card below.
	var party: Dictionary = Party.build_run_state(rules, SEED, ["tom"])
	assert_eq(party["error"], "", "build_run_state")
	# run: the run state before the fight. dude: Tom.
	var run: Dictionary = party["state"]
	var dude: Dictionary = run["dudes"][0]
	# ids: the new card ids, sorted, so the deck order never depends on dictionary order.
	var ids: Array = ACCEPTED.keys()
	ids.sort()
	for def_id: String in ids:
		# uid: a fresh card uid from next_uid, as a reward would make it.
		var uid: String = Party.CARD_UID_PREFIX + str(run["next_uid"])
		run["next_uid"] += 1
		dude["deck"].append(uid)
		dude["cards"][uid] = {"def_id": def_id, "upgraded": false}
	assert_no_errors(RunState.check(run), "the run state with the new cards is valid")
	# started: the fight against FOES.
	var started: Dictionary = Fight.start_fight(rules, run, FOES)
	assert_eq(started["error"], "", "start_fight")
	if started["error"] != "":
		return {}
	# state: the current state; applied: requests the core accepted; played: new card ids played.
	var state: Dictionary = started["state"]
	var applied: int = 0
	var played: Array = []
	for i: int in MAX_REQUESTS:
		if state["combat"]["result"] != "":
			break
		# request: the policy's next request. result: the core's answer.
		var request: Dictionary = _next_request(rules, state)
		var result: Dictionary = Core.apply(rules, state, request)
		assert_eq(result["reject"], "", "the policy only sends legal requests")
		if result["reject"] != "":
			return {}
		if request["type"] == "play_card":
			# def_id: the played card's definition id.
			var def_id: String = state["dudes"][0]["cards"][request["card_uid"]]["def_id"]
			if ACCEPTED.has(def_id) and not played.has(def_id):
				played.append(def_id)
		state = result["state"]
		applied += 1
		assert_no_errors(RunState.check(state), "state after request %d" % applied)
	played.sort()
	return {"state": state, "requests": applied, "played": played}


## Returns the policy's next request: the Bro Move at the first enemy when legal, else the first new
## card in hand the core accepts, else the first other card it accepts (each aimed at the first
## enemy, or no target), else Ready.
## rules: the ruleset. state: the state, in the player phase.
func _next_request(rules: Dictionary, state: Dictionary) -> Dictionary:
	# seq: the next seq. first: the leftmost enemy's uid. dude: Tom.
	var seq: int = state["dudes"][0]["last_seq"] + 1
	var first: String = state["combat"]["enemies"][0]["uid"]
	var dude: Dictionary = state["dudes"][0]
	# bro: the Bro Move request (Chest Bump needs a target, G33).
	var bro: Dictionary = {"type": "use_bro_move", "player_id": "p1", "seq": seq, "target_id": first}
	if Core.validate(rules, state, bro) == "":
		return bro
	for new_first: bool in [true, false]:
		for uid: String in dude["hand"]:
			if ACCEPTED.has(dude["cards"][uid]["def_id"]) != new_first:
				continue
			for target_id: String in [first, ""]:
				# play: one candidate.
				var play: Dictionary = {"type": "play_card", "player_id": "p1", "seq": seq, "card_uid": uid, "target_id": target_id, "crunch": false}
				if Core.validate(rules, state, play) == "":
					return play
	return {"type": "set_ready", "player_id": "p1", "seq": seq, "ready": true}
