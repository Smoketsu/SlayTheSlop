## One test per GDD Tom card (task 013), using the Tom-like fixture cards in tom_fixtures.gd (task
## 006's real data has not merged). Each assertion carries the GDD's number. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Ops := preload("res://core/ops/ops.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const TomFixtures := preload("res://tests/core/ops/tom_fixtures.gd")
const Event := preload("res://core/schema/event.gd")
const RunState := preload("res://core/schema/run_state.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 1313

## Hype given to Tom before the plays in these tests, so cost never gets in the way.
const PLENTY_OF_HYPE: int = 99

## Tom's max HP in the GDD attribute table.
const TOM_HP: int = 80


## Returns a solo fight of test_tom against these enemies, in turn 1's player phase, with
## PLENTY_OF_HYPE Hype. Tom's 10 starter cards take c1..c10, so the enemies are e11, e12, ...
## rules: the ruleset. enemy_ids: enemy ids, left to right.
func _fight(rules: Dictionary, enemy_ids: Array) -> Dictionary:
	# state: the fight.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_tom"], enemy_ids)
	state["dudes"][0]["hype"] = PLENTY_OF_HYPE
	return state


## Applies a request, asserting it is accepted and that every event and the new state are valid.
## Returns apply()'s result.
## rules: the ruleset. state: the state. request: the request.
func _ok(rules: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
	# result: what apply() returned.
	var result: Dictionary = Core.apply(rules, state, request)
	assert_eq(result["reject"], "", "request %s should apply" % var_to_str(request))
	for event: Variant in result["events"]:
		assert_no_errors(Event.check(event), "event %s" % var_to_str(event))
	assert_no_errors(RunState.check(result["state"]), "state")
	return result


## Gives p1 a fresh copy of def_id and plays it at target_id with the next seq. Returns apply()'s result.
## rules: the ruleset. state: the state, changed only by the added card. def_id: the card.
## target_id: the target to send.
func _play(rules: Dictionary, state: Dictionary, def_id: String, target_id: String) -> Dictionary:
	# uid: the added copy.
	var uid: String = Fixtures.give(state, 0, def_id)
	return _ok(rules, state, Fixtures.play("p1", state["dudes"][0]["last_seq"] + 1, uid, target_id))


## Presses Ready for p1 with the next seq; returns apply()'s result.
## rules: the ruleset. state: the state.
func _ready(rules: Dictionary, state: Dictionary) -> Dictionary:
	return _ok(rules, state, Fixtures.set_ready("p1", state["dudes"][0]["last_seq"] + 1))


## Returns the events of one type, in order.
## events: an event list. type: the event type wanted.
func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(event: Dictionary) -> bool: return event["type"] == type)


## Returns the enemy with this uid in state, or {}.
## state: a run state. uid: the enemy uid.
func _enemy(state: Dictionary, uid: String) -> Dictionary:
	for enemy: Dictionary in state["combat"]["enemies"]:
		if enemy["uid"] == uid:
			return enemy
	return {}


## The 14 fixture cards pass the core's op check, so task 006 can write them exactly this way.
func test_every_tom_card_uses_known_ops() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	assert_false(rules.is_empty(), "the Tom fixture ruleset builds")
	assert_eq(TomFixtures.TOM_CARD_IDS.size(), 14, "the GDD lists 14 Tom cards")
	for id: String in TomFixtures.TOM_CARD_IDS + ["tom_test_chest_bump"]:
		assert_no_errors(_op_problems(rules["cards"][id]), id)


## Returns the op problems in a card's effects and Power triggers.
## card: a card definition.
func _op_problems(card: Dictionary) -> Array[String]:
	# errors: what Ops.check found.
	var errors: Array[String] = Ops.check_all(card["effects"])
	for trigger: Dictionary in card.get("power_triggers", []):
		errors.append_array(Ops.check_all(trigger["effects"]))
	return errors


## Punch: "Deal 6 damage".
func test_punch() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# result: Punch at the Hitter (60 HP).
	var result: Dictionary = _play(rules, _fight(rules, ["test_hitter"]), "tom_test_punch", "e11")
	assert_eq(_enemy(result["state"], "e11")["hp"], 60 - 6, "6 damage")


## Flex: "Gain 5 Guard".
func test_flex() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# result: Flex.
	var result: Dictionary = _play(rules, _fight(rules, ["test_hitter"]), "tom_test_flex", "")
	assert_eq(result["state"]["dudes"][0]["guard"], 5, "5 Guard")


## Arm Bar: "Deal 8 damage. Break 1 arm".
func test_arm_bar() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# result: Arm Bar at the Hitter.
	var result: Dictionary = _play(rules, _fight(rules, ["test_hitter"]), "tom_test_arm_bar", "e11")
	assert_eq(_enemy(result["state"], "e11")["hp"], 60 - 8, "8 damage")
	assert_eq(_enemy(result["state"], "e11")["broken_arms"], 1, "1 arm broken")


## Well, Actually: "Apply 2 Ick" (+ Clout once, G5).
func test_well_actually() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# result: Well, Actually at the Hitter.
	var result: Dictionary = _play(rules, _fight(rules, ["test_hitter"]), "tom_test_well_actually", "e11")
	assert_eq(_enemy(result["state"], "e11")["ick"], 2, "2 Ick")
	# clouty: the same fight with 1 Clout.
	var clouty: Dictionary = _fight(rules, ["test_hitter"])
	clouty["dudes"][0]["clout"] = 1
	result = _play(rules, clouty, "tom_test_well_actually", "e11")
	assert_eq(_enemy(result["state"], "e11")["ick"], 2 + 1, "2 Ick + 1 Clout")


## Wrist Lock: "Deal 5 damage. If the target has a Broken Arm, draw 1 card".
func test_wrist_lock() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: a fight; hand size counted before the play (the Wrist Lock itself is added by _play).
	var state: Dictionary = _fight(rules, ["test_hitter"])
	# hand: cards in hand before the play.
	var hand: int = state["dudes"][0]["hand"].size()
	# result: Wrist Lock at a Hitter with no Broken Arm: 5 damage, no draw.
	var result: Dictionary = _play(rules, state, "tom_test_wrist_lock", "e11")
	assert_eq(_enemy(result["state"], "e11")["hp"], 60 - 5, "5 damage")
	assert_eq(result["state"]["dudes"][0]["hand"].size(), hand, "no Broken Arm: no draw")
	# broken: a fight where the Hitter already has a Broken Arm.
	var broken: Dictionary = _fight(rules, ["test_hitter"])
	broken["combat"]["enemies"][0]["broken_arms"] = 1
	result = _play(rules, broken, "tom_test_wrist_lock", "e11")
	assert_eq(result["state"]["dudes"][0]["hand"].size(), hand + 1, "Broken Arm: draw 1 card")
	assert_eq(_of_type(result["events"], "card_moved").filter(
		func(event: Dictionary) -> bool: return event["to"] == "hand").size(), 1, "one card_moved into the hand")
	# killed: the target dies to the 5 damage, so it no longer "has" a Broken Arm.
	var killed: Dictionary = _fight(rules, ["test_hitter", "test_dummy"])
	killed["combat"]["enemies"][0]["broken_arms"] = 1
	killed["combat"]["enemies"][0]["hp"] = 5
	result = _play(rules, killed, "tom_test_wrist_lock", "e11")
	assert_eq(result["state"]["dudes"][0]["hand"].size(), hand, "a dead target has no Broken Arm")


## Chrome Dome: "Gain 7 Guard. This turn, enemies that hit Tom take 3 damage" - per hit (G9), not
## attack damage (G3), even when Guard absorbs the hit, and gone at the next Refresh.
func test_chrome_dome() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# result: Chrome Dome against Flurry (30 HP; 2 damage x 3 hits, then 3 Guard).
	var result: Dictionary = _play(rules, _fight(rules, ["test_flurry"]), "tom_test_chrome_dome", "")
	assert_eq(result["state"]["dudes"][0]["guard"], 7, "7 Guard")
	assert_eq(result["state"]["dudes"][0]["thorns"], 3, "3 thorns")
	assert_true(result["events"].has(Event.make("thorns_changed", {"target_id": "p1", "delta": 3, "thorns": 3})))
	# turn: Ready; Flurry hits 3 times into Tom's Guard and takes 3 per hit.
	var turn: Dictionary = _ready(rules, result["state"])
	# glare: the damage Flurry took back.
	var glare: Array = _of_type(turn["events"], "damage_dealt").filter(
		func(event: Dictionary) -> bool: return event["source_id"] == "p1")
	assert_eq(glare.size(), 3, "one glare per hit (G9)")
	assert_eq(glare.map(func(event: Dictionary) -> int: return event["amount"]), [3, 3, 3])
	assert_eq(_enemy(turn["state"], "e11")["hp"], 30 - 9, "3 hits take 9 (G9)")
	assert_eq(turn["state"]["dudes"][0]["hp"], TOM_HP, "Tom's 7 Guard absorbed all 6")
	assert_eq(turn["state"]["dudes"][0]["thorns"], 0, "thorns end at the next Refresh")
	assert_true(turn["events"].has(Event.make("thorns_changed", {"target_id": "p1", "delta": -3, "thorns": 0})))
	# frail: Flurry at 3 HP dies to the first glare, so its other two hits never land.
	var frail: Dictionary = _play(rules, _fight(rules, ["test_flurry"]), "tom_test_chrome_dome", "")["state"]
	frail["combat"]["enemies"][0]["hp"] = 3
	turn = _ready(rules, frail)
	assert_eq(_of_type(turn["events"], "damage_dealt").filter(
		func(event: Dictionary) -> bool: return event["source_id"] == "e11").size(), 1, "dead after one hit")
	assert_eq(turn["state"]["combat"]["result"], "won")


## Skull Bash: "Deal 10 damage. Tom takes 2 damage" - the self-damage ignores Exposed and Noodle
## Arms (G3) and goes through Guard first.
func test_skull_bash() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# result: Skull Bash at the Hitter.
	var result: Dictionary = _play(rules, _fight(rules, ["test_hitter"]), "tom_test_skull_bash", "e11")
	assert_eq(_enemy(result["state"], "e11")["hp"], 60 - 10, "10 damage")
	assert_eq(result["state"]["dudes"][0]["hp"], TOM_HP - 2, "Tom takes 2")
	assert_true(result["events"].has(Event.make("damage_dealt",
		{"source_id": "", "target_id": "p1", "amount": 2, "blocked": 0, "hp_lost": 2})))
	# messy: Tom is Exposed, has Noodle Arms and 1 Guard.
	var messy: Dictionary = _fight(rules, ["test_hitter"])
	messy["dudes"][0]["statuses"] = {"exposed": 1, "noodle_arms": 1}
	messy["dudes"][0]["guard"] = 1
	result = _play(rules, messy, "tom_test_skull_bash", "e11")
	assert_eq(_enemy(result["state"], "e11")["hp"], 60 - 7, "the attack is Noodled: 10 x 0.75 = 7")
	assert_true(result["events"].has(Event.make("damage_dealt",
		{"source_id": "", "target_id": "p1", "amount": 2, "blocked": 1, "hp_lost": 1})), "self-damage stays 2, Guard first")


## Unsolicited Advice: "Apply 3 Ick and 1 Noodle Arms".
func test_unsolicited_advice() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# result: Unsolicited Advice at the Hitter.
	var result: Dictionary = _play(rules, _fight(rules, ["test_hitter"]), "tom_test_unsolicited_advice", "e11")
	assert_eq(_enemy(result["state"], "e11")["ick"], 3, "3 Ick")
	assert_eq(_enemy(result["state"], "e11")["statuses"], {"noodle_arms": 1}, "1 Noodle Arms")


## Cast Party: "Gain 4 Guard for every Broken Arm on all enemies".
func test_cast_party() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: two enemies with 1 and 2 Broken Arms.
	var state: Dictionary = _fight(rules, ["test_hitter", "test_dummy"])
	state["combat"]["enemies"][0]["broken_arms"] = 1
	state["combat"]["enemies"][1]["broken_arms"] = 2
	# result: Cast Party.
	var result: Dictionary = _play(rules, state, "tom_test_cast_party", "")
	assert_eq(result["state"]["dudes"][0]["guard"], 4 * 3, "4 Guard for each of 3 Broken Arms")
	result = _play(rules, _fight(rules, ["test_hitter"]), "tom_test_cast_party", "")
	assert_eq(result["state"]["dudes"][0]["guard"], 0, "no Broken Arms, no Guard")
	assert_eq(_of_type(result["events"], "guard_changed"), [], "and no event")


## Snap City: "Deal 14 damage. Break 1 arm. If the target is now Armless, gain 1 Hype".
func test_snap_city() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: a Hitter (2 arms) with 1 already broken, so Snap City makes it Armless.
	var state: Dictionary = _fight(rules, ["test_hitter"])
	state["combat"]["enemies"][0]["broken_arms"] = 1
	# result: Snap City.
	var result: Dictionary = _play(rules, state, "tom_test_snap_city", "e11")
	assert_eq(_enemy(result["state"], "e11")["hp"], 60 - 14, "14 damage")
	assert_eq(_enemy(result["state"], "e11")["broken_arms"], 2, "1 arm broken")
	assert_eq(result["state"]["dudes"][0]["hype"], PLENTY_OF_HYPE - 2 + 1, "now Armless: gain 1 Hype")
	assert_true(result["events"].has(Event.make("hype_changed", {"player_id": "p1", "delta": 1, "hype": PLENTY_OF_HYPE - 1})))
	result = _play(rules, _fight(rules, ["test_hitter"]), "tom_test_snap_city", "e11")
	assert_eq(result["state"]["dudes"][0]["hype"], PLENTY_OF_HYPE - 2, "1 of 2 arms broken: not Armless, no Hype")
	result = _play(rules, _fight(rules, ["test_slime"]), "tom_test_snap_city", "e11")
	assert_eq(result["state"]["dudes"][0]["hype"], PLENTY_OF_HYPE - 2, "a 0-arm Slime is never Armless")


## Pickup Line: "Apply 4 Ick to all enemies. Tom takes 3 damage from the response" (Clout once per
## enemy, G5).
func test_pickup_line() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# result: Pickup Line at two enemies.
	var result: Dictionary = _play(rules, _fight(rules, ["test_hitter", "test_dummy"]), "tom_test_pickup_line", "")
	assert_eq([_enemy(result["state"], "e11")["ick"], _enemy(result["state"], "e12")["ick"]], [4, 4], "4 Ick on each")
	assert_eq(result["state"]["dudes"][0]["hp"], TOM_HP - 3, "Tom takes 3")
	# clouty: with 1 Clout every enemy gets 4 + 1.
	var clouty: Dictionary = _fight(rules, ["test_hitter", "test_rival"])
	clouty["dudes"][0]["clout"] = 1
	result = _play(rules, clouty, "tom_test_pickup_line", "")
	assert_eq(_of_type(result["events"], "status_changed").filter(
		func(event: Dictionary) -> bool: return event["status"] == "ick" and event["delta"] > 0).map(
		func(event: Dictionary) -> int: return event["delta"]), [5, 5], "4 + 1 Clout each")


## Reply Guy: "Whenever an enemy gains a buff, apply 2 Ick to it" - a Power that stays for the
## fight; Guard an enemy gains is a buff (G10).
func test_reply_guy() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: against the Turtle, which gains 4 Guard every turn.
	var state: Dictionary = _fight(rules, ["test_turtle"])
	# uid: the Reply Guy copy.
	var uid: String = Fixtures.give(state, 0, "tom_test_reply_guy")
	# result: Reply Guy played.
	var result: Dictionary = _ok(rules, state, Fixtures.play("p1", 0, uid, ""))
	assert_eq(result["state"]["dudes"][0]["powers"], [uid], "active")
	assert_false(result["state"]["dudes"][0]["discard_pile"].has(uid), "not discarded")
	assert_true(result["events"].has(Event.make("card_moved", {"player_id": "p1", "card_uid": uid, "from": "hand", "to": "powers"})))
	# flex: Tom's own Guard is not an enemy buff.
	var flex: Dictionary = _play(rules, result["state"], "tom_test_flex", "")
	assert_eq(_of_type(flex["events"], "power_triggered"), [], "Tom's Guard does not trigger it")
	# turn: Ready; the Turtle's Shell gives it 4 Guard and Reply Guy answers with 2 Ick.
	var turn: Dictionary = _ready(rules, flex["state"])
	assert_eq(_of_type(turn["events"], "power_triggered"), [Event.make("power_triggered",
		{"player_id": "p1", "card_uid": uid, "when": "enemy_buffed", "subject_id": "e11"})])
	assert_eq(_enemy(turn["state"], "e11")["ick"], 2, "2 Ick on the buffed enemy")
	# second: another turn; the Power is still there and fires again.
	var second: Dictionary = _ready(rules, turn["state"])
	assert_eq(_enemy(second["state"], "e11")["ick"], 4, "fires every time")
	assert_eq(second["state"]["dudes"][0]["powers"], [uid], "lasts the fight")


## Double Arm Day: "Deal 9 damage twice. Each hit breaks 1 arm" - damage, break, damage, break.
func test_double_arm_day() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# result: Double Arm Day at the Hitter.
	var result: Dictionary = _play(rules, _fight(rules, ["test_hitter"]), "tom_test_double_arm_day", "e11")
	assert_eq(_enemy(result["state"], "e11")["hp"], 60 - 9 - 9, "9 damage twice")
	assert_eq(_enemy(result["state"], "e11")["broken_arms"], 2, "each hit breaks 1 arm")
	# order: damage and arm events in order.
	var order: Array = result["events"].filter(func(event: Dictionary) -> bool:
		return event["type"] == "damage_dealt" or event["type"] == "status_changed").map(
		func(event: Dictionary) -> String: return event["type"] if event["type"] == "damage_dealt" else "arm %d" % event["stacks"])
	assert_eq(order, ["damage_dealt", "arm 1", "damage_dealt", "arm 2"], "each hit, then its break")
	# weak: a Hitter with 9 HP dies to the first hit; nothing more happens.
	var weak: Dictionary = _fight(rules, ["test_hitter"])
	weak["combat"]["enemies"][0]["hp"] = 9
	result = _play(rules, weak, "tom_test_double_arm_day", "e11")
	assert_eq(_of_type(result["events"], "damage_dealt").size(), 1)
	assert_eq(result["state"]["combat"]["result"], "won")


## Friend Zone: "At the start of each turn, apply 1 Ick to all enemies. Grossed Out enemies also
## become Exposed for 2 turns".
func test_friend_zone() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: against the Hitter (Ick 4 of 5, so the next Ick Grosses it Out) and the Dummy.
	var state: Dictionary = _fight(rules, ["test_hitter", "test_dummy"])
	state["combat"]["enemies"][0]["ick"] = 4
	# result: Friend Zone played; nothing fires this turn.
	var result: Dictionary = _play(rules, state, "tom_test_friend_zone", "")
	assert_eq(_of_type(result["events"], "power_triggered"), [], "it waits for the start of a turn")
	assert_eq(_enemy(result["state"], "e12")["ick"], 0)
	# turn: Ready; at the start of turn 2 every enemy gets 1 Ick, and the Grossed Out Hitter gets Exposed 2.
	var turn: Dictionary = _ready(rules, result["state"])
	assert_eq(turn["state"]["combat"]["phase"], "player")
	assert_eq(_enemy(turn["state"], "e12")["ick"], 1, "1 Ick on the Dummy")
	assert_eq(_enemy(turn["state"], "e11")["grossed_out_skips"], 1, "the Hitter is Grossed Out")
	assert_eq(_enemy(turn["state"], "e11")["statuses"], {"exposed": 2}, "and Exposed for 2 turns")
	assert_eq(_of_type(turn["events"], "power_triggered").map(func(event: Dictionary) -> String: return event["when"]),
		["turn_start", "enemy_grossed_out"])
	# later: a Pickup Line (4 Ick) Grosses Out the Dummy (1 Ick, threshold 5) while Friend Zone is active.
	var later: Dictionary = _play(rules, turn["state"], "tom_test_pickup_line", "")
	assert_eq(_enemy(later["state"], "e12")["statuses"], {"exposed": 2}, "Grossed Out by a card: Exposed 2 as well")


## A played Power's trigger effects must be ops the core has, or the card is unplayable.
func test_power_with_unknown_op_is_unplayable() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: a fight with Bad Power in hand.
	var state: Dictionary = _fight(rules, ["test_hitter"])
	# uid: the Bad Power copy.
	var uid: String = Fixtures.give(state, 0, "neutral_test_bad_power")
	assert_eq(Core.apply(rules, state, Fixtures.play("p1", 0, uid, ""))["reject"], "unplayable")


## Pocketed: "The card is not discarded at end of turn". Tapped still goes to the tapped pile.
func test_pocketed_and_tapped() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: a fight with Pocket Lint and a Sweep (tapped) in hand.
	var state: Dictionary = _fight(rules, ["test_hitter", "test_dummy"])
	# lint: the pocketed card.
	var lint: String = Fixtures.give(state, 0, "neutral_test_pocket_lint")
	# sweep: the tapped card, played now.
	var sweep: String = Fixtures.give(state, 0, "neutral_test_sweep")
	# result: Sweep played, then Ready.
	var result: Dictionary = _ok(rules, state, Fixtures.play("p1", 0, sweep, ""))
	assert_eq(result["state"]["dudes"][0]["tapped_pile"], [sweep], "tapped")
	result = _ready(rules, result["state"])
	assert_true(result["state"]["dudes"][0]["hand"].has(lint), "pocketed card kept in hand")
	assert_eq(result["state"]["dudes"][0]["hand"][0], lint, "kept first, ahead of the new draw")
	assert_false(result["state"]["dudes"][0]["discard_pile"].has(lint))
	assert_eq(_of_type(result["events"], "card_moved").filter(
		func(event: Dictionary) -> bool: return event["card_uid"] == lint), [], "it never moved")
	assert_false(result["state"]["dudes"][0]["hand"].has(sweep), "a tapped card does not come back")


## Powers and thorns are cleared when the next fight starts.
func test_powers_and_thorns_clear_at_next_fight() -> void:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset()
	# state: Reply Guy and Chrome Dome played, then the fight marked over.
	var state: Dictionary = _play(rules, _fight(rules, ["test_hitter"]), "tom_test_reply_guy", "")["state"]
	state = _play(rules, state, "tom_test_chrome_dome", "")["state"]
	assert_eq([state["dudes"][0]["powers"].size(), state["dudes"][0]["thorns"]], [1, 3])
	state["combat"]["phase"] = "over"
	# next: the next fight.
	var next: Dictionary = preload("res://core/combat/fight.gd").start_fight(rules, state, ["test_dummy"])
	assert_eq(next["error"], "")
	assert_eq([next["state"]["dudes"][0]["powers"], next["state"]["dudes"][0]["thorns"]], [[], 0])
	assert_no_errors(RunState.check(next["state"]), "next fight")
