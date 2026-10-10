## Fixed-seed fight with Gear and Brews (task 021): a simple bot drinks every Brew on turn 1, then
## plays every legal card each turn, with five Gear owned. The same seed always gives the same
## fight and the recorded outcome. Lane: core (Agent A).
##
## If a rules change alters this fight on purpose, re-record RECORDED (the failure message prints
## the new values) and say why in the PR. An unexplained change means determinism broke.
extends "res://tests/framework/test_case.gd"

const Core := preload("res://core/core.gd")
const Event := preload("res://core/schema/event.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const ItemFixtures := preload("res://tests/core/items/item_fixtures.gd")

## The run seed of the fight.
const SEED: int = 20211010

## p1's Gear, in the order gained (after the Dude's starting Gear).
const GEAR: Array = ["tom_unused_gym_membership", "tom_arm_wrestling_table", "tom_whole_can_of_body_spray",
	"lifting_belt", "championship_ring"]

## p1's Brews, slot order. All three are drunk on turn 1.
const BREWS: Array = ["light_beer", "protein_shake", "shot_of_courage"]

## The enemies, left to right.
const ENEMIES: Array = ["test_hitter", "test_pledge"]

## Most requests the bot sends before the test gives up (a stuck fight is a failure).
const MAX_REQUESTS: int = 300

## Recorded outcome on Godot 4.7.2-stable: [result, final turn, p1's final HP, brews_drunk,
## applied requests, Body Spray triggers].
const RECORDED: Array = ["won", 3, 80, 3, 15, 3]


## Plays the whole fight with the bot. Returns {"state": the final state, "events": every event,
## "applied": how many requests were applied}.
func _replay() -> Dictionary:
	# rules: the item ruleset.
	var rules: Dictionary = ItemFixtures.ruleset()
	# started: the fight, turn 1.
	var started: Dictionary = ItemFixtures.fight(rules, SEED, GEAR, BREWS, ENEMIES, ["test_breaker"])
	# state: the fight as it goes.
	var state: Dictionary = started["state"]
	# events: every event, fight start included.
	var events: Array = started["events"].duplicate()
	# seq: p1's next seq.
	var seq: int = 0
	# applied: requests applied so far.
	var applied: int = 0
	while state["combat"]["phase"] != "over" and seq < MAX_REQUESTS:
		# request: the bot's next request.
		var request: Dictionary = _next_request(rules, state, seq)
		# result: what apply() returned.
		var result: Dictionary = Core.apply(rules, state, request)
		assert_eq(result["reject"], "", "bot request %s" % var_to_str(request))
		if result["reject"] != "":
			break
		state = result["state"]
		events.append_array(result["events"])
		applied += 1
		seq += 1
	assert_no_errors(RunState.check(state), "final state")
	return {"state": state, "events": events, "applied": applied}


## The bot: on turn 1 it drinks slot 0 while it holds a Brew; otherwise it plays the first card in
## hand that is legal on the leftmost enemy or with no target; with none, it presses Ready.
## rules: the ruleset. state: the current state, in the player phase. seq: the seq to use.
func _next_request(rules: Dictionary, state: Dictionary, seq: int) -> Dictionary:
	# dude: p1.
	var dude: Dictionary = state["dudes"][0]
	if state["combat"]["turn"] == 1 and not dude["brews"].is_empty():
		return ItemFixtures.drink("p1", seq, 0)
	# target: the leftmost enemy.
	var target: String = state["combat"]["enemies"][0]["uid"]
	for uid: String in dude["hand"]:
		for target_id: String in [target, ""]:
			# play: a candidate request.
			var play: Dictionary = Fixtures.play("p1", seq, uid, target_id)
			if Core.validate(rules, state, play) == "":
				return play
	return Fixtures.set_ready("p1", seq)


## The fight ends as recorded, and Gear and Brews visibly took part.
func test_items_fight_ends_as_recorded() -> void:
	# run: the replayed fight.
	var run: Dictionary = _replay()
	# state: the final state.
	var state: Dictionary = run["state"]
	# sprays: Body Spray triggers in the fight.
	var sprays: int = run["events"].filter(func(e: Dictionary) -> bool:
		return e["type"] == "gear_triggered" and e["gear_id"] == "tom_whole_can_of_body_spray").size()
	# outcome: what happened, in RECORDED's order.
	var outcome: Array = [state["combat"]["result"], state["combat"]["turn"], state["dudes"][0]["hp"],
		state["brews_drunk"], run["applied"], sprays]
	assert_eq(outcome, RECORDED, "outcome %s (re-record only for an intended rules change)" % str(outcome))
	assert_eq(state["brews_drunk"], BREWS.size(), "every Brew drunk")
	assert_eq(state["dudes"][0]["swole"], 1, "Protein Shake's +3 taken back; the belt's +1 stays")
	assert_true(sprays > 0, "Body Spray fired")


## Two replays give byte-identical final states and identical events.
func test_items_fight_is_deterministic() -> void:
	# a: the first replay.
	var a: Dictionary = _replay()
	# b: the second replay.
	var b: Dictionary = _replay()
	assert_eq(var_to_bytes(a["state"]), var_to_bytes(b["state"]), "identical final bytes")
	assert_eq(a["events"], b["events"], "identical events")
