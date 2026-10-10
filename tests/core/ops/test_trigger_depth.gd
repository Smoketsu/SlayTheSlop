## Tests for task 031: the Power trigger depth cap (core/ops/ops.gd "trigger_depth" and the constant
## MAX_TRIGGER_DEPTH). A Power that feeds itself stops after MAX_TRIGGER_DEPTH nested firings instead
## of hanging the fight, and the legitimate chain Reply Guy -> Gross Out -> Friend Zone still works.
## The rule is gap G53 (docs/proposals/solo-slice-rule-gaps.md), built as suggested. Lane: core (Agent A).
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Ops := preload("res://core/ops/ops.gd")
const Fight := preload("res://core/combat/fight.gd")
const Party := preload("res://core/combat/party.gd")
const Powers := preload("res://core/combat/powers.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const TomFixtures := preload("res://tests/core/ops/tom_fixtures.gd")
const Event := preload("res://core/schema/event.gd")

## Seed for every fight in this file. Any value works; fixed so every run is the same.
const SEED: int = 3131

## Hype given to Tom before the plays in these tests, so cost never gets in the way.
const PLENTY_OF_HYPE: int = 99

## Id of the self-feeding test Power: whenever an enemy gains a buff, that enemy gains 1 Swole,
## which is another buff (G10). Without the cap it fires forever.
const ECHO_ID: String = "neutral_test_echo_chamber"

## Id of the test Power that draws 1 card whenever an enemy gains a buff.
const DOOMSCROLL_ID: String = "neutral_test_doomscroll"

## Id of the test card whose on_draw gives every enemy 1 Swole, so a draw inside a Power trigger
## buffs an enemy from inside an op (core/combat/card_triggers.gd, via the draw op).
const HYPE_POST_ID: String = "neutral_test_hype_post"

## This file's own test cards, by id, added to the Tom fixture ruleset. Shapes follow
## core/schema/card_def.gd. Not real content; no GDD card does this.
const CARDS := {
	ECHO_ID: {"id": ECHO_ID, "name": "Echo Chamber", "owner": "neutral", "type": "power", "rarity": "common",
		"cost": 0, "target": "none", "effects": [],
		"power_triggers": [{"when": "enemy_buffed", "target": "subject",
			"effects": [{"op": "gain_stat", "stat": "swole", "amount": 1}]}],
		"keywords": [], "crunch": null, "upgrade": {}},
	DOOMSCROLL_ID: {"id": DOOMSCROLL_ID, "name": "Doomscroll", "owner": "neutral", "type": "power", "rarity": "common",
		"cost": 0, "target": "none", "effects": [],
		"power_triggers": [{"when": "enemy_buffed", "target": "self", "effects": [{"op": "draw", "amount": 1}]}],
		"keywords": [], "crunch": null, "upgrade": {}},
	HYPE_POST_ID: {"id": HYPE_POST_ID, "name": "Hype Post", "owner": "neutral", "type": "skill", "rarity": "common",
		"cost": 1, "target": "none", "effects": [],
		"on_draw": [{"op": "gain_stat", "stat": "swole", "amount": 1, "target": "all_enemies"}],
		"keywords": [], "crunch": null, "upgrade": {}},
}

## The buff that starts each chain here: 1 Swole for the targets (an enemy), from Tom.
const SWOLE_UP := {"op": "gain_stat", "stat": "swole", "amount": 1}

## Copies of Hype Post put in the draw pile for the draw test; more than any cap the test uses, so
## the cap, not an empty pile, is what stops the chain.
const HYPE_POST_COPIES: int = 20


## Returns the Tom fixture ruleset with this file's cards added; asserts it built.
func _rules() -> Dictionary:
	# rules: the ruleset.
	var rules: Dictionary = TomFixtures.ruleset(CARDS)
	assert_false(rules.is_empty(), "the test ruleset builds")
	return rules


## Returns a writable copy of the ruleset whose MAX_TRIGGER_DEPTH is cap; the rest is shared.
## rules: the ruleset. cap: the depth cap wanted (any value, for the refusal test too).
func _with_cap(rules: Dictionary, cap: Variant) -> Dictionary:
	# capped: the copy.
	var capped: Dictionary = rules.duplicate()
	capped["constants"] = rules["constants"].duplicate()
	capped["constants"][Ops.MAX_DEPTH_CONSTANT] = cap
	return capped


## Returns a solo fight of test_tom against these enemies, in turn 1's player phase, with
## PLENTY_OF_HYPE Hype. Tom's 10 starter cards take c1..c10, so the enemies are e11, e12, ...
## rules: the ruleset. enemy_ids: enemy ids, left to right.
func _fight(rules: Dictionary, enemy_ids: Array) -> Dictionary:
	# state: the fight.
	var state: Dictionary = Fixtures.fight(rules, SEED, ["test_tom"], enemy_ids)
	assert_false(state.is_empty(), "the fight starts")
	state["dudes"][0]["hype"] = PLENTY_OF_HYPE
	return state


## Makes a Power active for Tom without playing it (test setup only) and returns its card_uid.
## state: a fight, changed here. def_id: the Power's card id.
func _activate(state: Dictionary, def_id: String) -> String:
	# uid: the new copy, moved from the hand to the powers list.
	var uid: String = Fixtures.give(state, 0, def_id)
	state["dudes"][0]["hand"].erase(uid)
	state["dudes"][0]["powers"].append(uid)
	return uid


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


## The constant exists and is usable, and the suggested value is above 1 so chains of 2 work.
func test_constant_is_usable() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	assert_eq(Ops.check_constants(rules["constants"]), "")
	assert_true(rules["constants"][Ops.MAX_DEPTH_CONSTANT] >= 2, "Reply Guy -> Friend Zone needs depth 2")


## A self-feeding Power terminates: one buff from Tom sets off exactly MAX_TRIGGER_DEPTH nested
## firings, each giving 1 more Swole, and then the chain stops.
func test_self_feeding_power_stops_at_the_cap() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# cap: MAX_TRIGGER_DEPTH from the real constants file.
	var cap: int = rules["constants"][Ops.MAX_DEPTH_CONSTANT]
	# state: Echo Chamber active against the Hitter (e11).
	var state: Dictionary = _fight(rules, ["test_hitter"])
	# uid: the Echo Chamber copy.
	var uid: String = _activate(state, ECHO_ID)
	# before: the Hitter's Swole before the chain.
	var before: int = _enemy(state, "e11")["swole"]
	# events: what the chain emitted.
	var events: Array = []
	Ops.run(state, SWOLE_UP, Ops.make_context(rules, "p1", ["e11"], false, true), events)
	assert_eq(_of_type(events, "power_triggered").size(), cap, "fires exactly MAX_TRIGGER_DEPTH times")
	assert_eq(_of_type(events, "power_triggered")[0], Event.make("power_triggered",
		{"player_id": "p1", "card_uid": uid, "when": "enemy_buffed", "subject_id": "e11"}))
	assert_eq(_of_type(events, "stat_changed").size(), cap + 1, "Tom's buff, then one per firing")
	assert_eq(_enemy(state, "e11")["swole"], before + 1 + cap, "1 from Tom, 1 per firing")


## The cap is read from the constants: with MAX_TRIGGER_DEPTH 1 and 3 the same chain fires 1 and 3 times.
func test_cap_comes_from_the_constants() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	for cap: int in [1, 3]:
		# capped: the ruleset with this cap.
		var capped: Dictionary = _with_cap(rules, cap)
		# state: Echo Chamber active against the Hitter (e11).
		var state: Dictionary = _fight(capped, ["test_hitter"])
		_activate(state, ECHO_ID)
		# events: what the chain emitted.
		var events: Array = []
		Ops.run(state, SWOLE_UP, Ops.make_context(capped, "p1", ["e11"], false, true), events)
		assert_eq(_of_type(events, "power_triggered").size(), cap, "cap %d" % cap)


## Depth counts nesting: triggers set off from depth MAX_TRIGGER_DEPTH - 1 fire once (their effects
## run at the cap, so set off nothing more); from depth MAX_TRIGGER_DEPTH none fire. With no depth
## given (turn start), the whole chain runs.
func test_depth_rises_one_per_trigger() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# cap: MAX_TRIGGER_DEPTH.
	var cap: int = rules["constants"][Ops.MAX_DEPTH_CONSTANT]
	for case: Array in [[cap - 1, 1], [cap, 0], [0, cap]]:
		# state: Echo Chamber active against the Hitter (e11).
		var state: Dictionary = _fight(rules, ["test_hitter"])
		_activate(state, ECHO_ID)
		# events: what firing emitted.
		var events: Array = []
		Ops.fire_power_triggers_in_place(rules, state, Powers.matching(rules, state, Powers.WHEN_ENEMY_BUFFED, "e11"),
			events, case[0])
		assert_eq(_of_type(events, "power_triggered").size(), case[1], "from depth %d" % case[0])


## make_context() starts at depth 0 from a ruleset and keeps the depth of an op context passed in its
## place (card_triggers.gd does that for on_draw effects run by a draw op).
func test_make_context_carries_the_depth() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# outer: a context from the ruleset.
	var outer: Dictionary = Ops.make_context(rules, "p1", [], false, true)
	assert_eq(outer[Ops.DEPTH_KEY], 0, "a ruleset starts a chain")
	outer[Ops.DEPTH_KEY] = 5
	assert_eq(Ops.make_context(outer, "p1", ["p1"], false, true)[Ops.DEPTH_KEY], 5, "an op context keeps its depth")


## A chain through a draw keeps counting: Doomscroll draws on every enemy buff, and each Hype Post
## drawn buffs every enemy from its on_draw. Without carrying the depth through the draw, every
## on_draw would start again at 0 and the chain would only stop when the draw pile ran out.
func test_chain_through_a_draw_is_capped() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# cap: MAX_TRIGGER_DEPTH.
	var cap: int = rules["constants"][Ops.MAX_DEPTH_CONSTANT]
	# state: Doomscroll active against the Hitter (e11); the draw pile is only Hype Posts.
	var state: Dictionary = _fight(rules, ["test_hitter"])
	_activate(state, DOOMSCROLL_ID)
	# dude: Tom, inside state.
	var dude: Dictionary = state["dudes"][0]
	dude["draw_pile"].clear()
	dude["discard_pile"].clear()
	for i: int in HYPE_POST_COPIES:
		# post: one Hype Post copy, moved from the hand to the draw pile.
		var post: String = Fixtures.give(state, 0, HYPE_POST_ID)
		dude["hand"].erase(post)
		dude["draw_pile"].append(post)
	# events: what the chain emitted.
	var events: Array = []
	Ops.run(state, SWOLE_UP, Ops.make_context(rules, "p1", ["e11"], false, true), events)
	assert_eq(_of_type(events, "power_triggered").size(), cap, "fires exactly MAX_TRIGGER_DEPTH times")
	assert_eq(dude["draw_pile"].size(), HYPE_POST_COPIES - cap, "one card drawn per firing")


## A draw's nested on_draw effects set off each Power trigger once, not twice: the on_draw's
## run() fires Reply Guy for the Swole, and the draw op's own run() does not react to those events
## again (Ops.NESTING_OPS). Before task 031 Reply Guy fired twice here.
func test_draw_does_not_fire_triggers_twice() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: Reply Guy active against the Hitter (e11); a Hype Post on top of the draw pile.
	var state: Dictionary = _fight(rules, ["test_hitter"])
	# reply: the Reply Guy copy.
	var reply: String = _activate(state, "tom_test_reply_guy")
	# post: the Hype Post copy, moved from the hand to the top of the draw pile.
	var post: String = Fixtures.give(state, 0, HYPE_POST_ID)
	state["dudes"][0]["hand"].erase(post)
	state["dudes"][0]["draw_pile"].push_front(post)
	# ick: the Hitter's Ick before the draw.
	var ick: int = _enemy(state, "e11")["ick"]
	# events: what the draw emitted.
	var events: Array = []
	Ops.run(state, {"op": "draw", "amount": 1}, Ops.make_context(rules, "p1", [], false, true), events)
	assert_eq(state["dudes"][0]["hand"].back(), post, "the Hype Post was drawn")
	assert_eq(_of_type(events, "power_triggered"), [Event.make("power_triggered",
		{"player_id": "p1", "card_uid": reply, "when": "enemy_buffed", "subject_id": "e11"})], "Reply Guy fires once")
	assert_eq(_enemy(state, "e11")["ick"], ick + 2, "2 Ick, once")


## Reply Guy then Friend Zone, directly: an enemy at Ick threshold - 2 gains Guard, Reply Guy (depth 1)
## applies 2 Ick, which Grosses it Out, and Friend Zone's enemy_grossed_out trigger (depth 2) makes
## it Exposed 2. Also true at MAX_TRIGGER_DEPTH 2; at 1 the second link is cut, which is why the cap
## cannot be 1.
func test_reply_guy_then_friend_zone_still_chains() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	for cap: int in [rules["constants"][Ops.MAX_DEPTH_CONSTANT], 2, 1]:
		# capped: the ruleset with this cap.
		var capped: Dictionary = _with_cap(rules, cap)
		# state: Reply Guy and Friend Zone active against the Hitter (e11), 2 Ick short of Grossed Out.
		var state: Dictionary = _fight(capped, ["test_hitter"])
		# reply: the Reply Guy copy.
		var reply: String = _activate(state, "tom_test_reply_guy")
		# zone: the Friend Zone copy.
		var zone: String = _activate(state, "tom_test_friend_zone")
		# hitter: e11, inside state.
		var hitter: Dictionary = _enemy(state, "e11")
		hitter["ick"] = hitter["ick_threshold"] - 2
		# events: what the chain emitted, starting with the Hitter's own Guard.
		var events: Array = []
		Ops.run(state, {"op": "guard", "amount": 2}, Ops.make_context(capped, "e11", [], false, false), events)
		# fired: [card_uid, when] of each power_triggered, in order.
		var fired: Array = _of_type(events, "power_triggered").map(
			func(event: Dictionary) -> Array: return [event["card_uid"], event["when"]])
		assert_eq(_of_type(events, "grossed_out").size(), 1, "cap %d: Reply Guy's Ick Grosses it Out" % cap)
		if cap >= 2:
			assert_eq(fired, [[reply, "enemy_buffed"], [zone, "enemy_grossed_out"]], "cap %d: both links fire" % cap)
			assert_eq(hitter["statuses"].get("exposed", 0), 2, "cap %d: Friend Zone's Exposed 2" % cap)
		else:
			assert_eq(fired, [[reply, "enemy_buffed"]], "cap 1: Friend Zone is cut off")
			assert_eq(hitter["statuses"].get("exposed", 0), 0, "cap 1: no Exposed")


## The same chain in a real turn with the real constants: both Powers played as cards, then Ready;
## the Turtle's Shell (4 Guard) sets off Reply Guy, whose Ick Grosses it Out, which fires Friend Zone.
func test_reply_guy_then_friend_zone_in_a_turn() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# state: against the Turtle, which gains 4 Guard every turn.
	var state: Dictionary = _fight(rules, ["test_turtle"])
	for def_id: String in ["tom_test_reply_guy", "tom_test_friend_zone"]:
		# uid: the Power copy, played from the hand.
		var uid: String = Fixtures.give(state, 0, def_id)
		# played: apply()'s result.
		var played: Dictionary = Core.apply(rules, state, Fixtures.play("p1", state["dudes"][0]["last_seq"] + 1, uid, ""))
		assert_eq(played["reject"], "", "%s is played" % def_id)
		state = played["state"]
	_enemy(state, "e11")["ick"] = _enemy(state, "e11")["ick_threshold"] - 2
	# turn: Ready; the enemy phase, then the start of turn 2.
	var turn: Dictionary = Core.apply(rules, state, Fixtures.set_ready("p1", state["dudes"][0]["last_seq"] + 1))
	assert_eq(turn["reject"], "")
	# whens: the "when" of each power_triggered, in order.
	var whens: Array = _of_type(turn["events"], "power_triggered").map(func(event: Dictionary) -> String: return event["when"])
	assert_eq(whens.slice(0, 2), ["enemy_buffed", "enemy_grossed_out"], "Shell -> Reply Guy -> Gross Out -> Friend Zone")
	assert_eq(_enemy(turn["state"], "e11")["grossed_out_skips"], 1, "the Turtle is Grossed Out")


## A fight refuses to start when MAX_TRIGGER_DEPTH is missing, not an int, or below 1.
func test_fight_refuses_an_unusable_cap() -> void:
	# rules: the ruleset.
	var rules: Dictionary = _rules()
	# party: a run state for Tom, before any fight.
	var party: Dictionary = Party.build_run_state(rules, SEED, ["test_tom"])
	assert_eq(party["error"], "")
	for cap: Variant in [0, -1, 2.5, "8"]:
		# error: why the fight cannot start.
		var error: String = Fight.check_start(_with_cap(rules, cap), party["state"], ["test_hitter"])
		assert_true(error.contains(Ops.MAX_DEPTH_CONSTANT), "cap %s: %s" % [var_to_str(cap), error])
	# missing: the constants without MAX_TRIGGER_DEPTH.
	var missing: Dictionary = _with_cap(rules, 0)
	missing["constants"].erase(Ops.MAX_DEPTH_CONSTANT)
	assert_true(Fight.check_start(missing, party["state"], ["test_hitter"]).contains(Ops.MAX_DEPTH_CONSTANT), "missing")
	assert_eq(Fight.check_start(rules, party["state"], ["test_hitter"]), "", "the real constant is fine")
