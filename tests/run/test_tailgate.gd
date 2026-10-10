## Tests for core/run/tailgate.gd: Nap or Lift (task 025, G15, G22) and what a Lifted card does.
## Lane: run (Agent A).
extends "res://tests/framework/test_case.gd"

const RunFixtures := preload("res://tests/run/fixtures/run_fixtures.gd")
const Helpers := preload("res://tests/run/fixtures/run_helpers.gd")
const Core := preload("res://core/core.gd")
const Fight := preload("res://core/combat/fight.gd")

## Seed used by these tests.
const SEED: int = 1525


## Returns a solo run that has just entered a Tailgate, with Tom at the given HP (test setup).
## rules: the ruleset. hp: Tom's HP. max_hp: Tom's max HP.
func _at_tailgate(rules: Dictionary, hp: int, max_hp: int = 80) -> Dictionary:
	# state: a run on a one-Tailgate map.
	var state: Dictionary = Helpers.use_small_map(Helpers.start(rules, SEED), ["tailgate"])
	state["dudes"][0]["hp"] = hp
	state["dudes"][0]["max_hp"] = max_hp
	# result: the vote's result.
	var result: Dictionary = Core.apply(rules, state, Helpers.vote("p1", 0, "r1c0"))
	assert_eq(result["reject"], "")
	assert_eq(Helpers.contract_problems(result), [] as Array[String])
	return result["state"]


## The offer: Nap (heal amount shown) and Lift (only Arm Bar can be upgraded, G15), no skip.
func test_tailgate_offer() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: at the Tailgate with Tom at 40 / 80.
	var state: Dictionary = _at_tailgate(rules, 40)
	# offer: Tom's Tailgate offer.
	var offer: Dictionary = state["dudes"][0]["offers"][0]
	assert_eq(offer["kind"], "tailgate")
	assert_false(offer["skippable"])
	assert_eq(offer["options"][0], {"kind": "nap", "available": true, "amount": 24}, "30% of 80")
	assert_eq(offer["options"][1], {"kind": "lift", "available": true, "card_uids": ["c9"]}, "only Arm Bar has an upgrade")
	assert_eq(Core.apply(rules, state, Helpers.choose("p1", 1, offer["id"], -1))["reject"], "bad_target")


## Nap heals TAILGATE_NAP_HEAL of max HP, rounded down, never above max HP.
func test_nap() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: at the Tailgate with Tom at 40 / 88 (30% is 26.4).
	var state: Dictionary = _at_tailgate(rules, 40, 88)
	# result: the Nap.
	var result: Dictionary = Core.apply(rules, state, Helpers.choose("p1", 1, state["dudes"][0]["offers"][0]["id"], 0))
	assert_eq(result["reject"], "")
	assert_eq(result["state"]["dudes"][0]["hp"], 66, "26 restored, rounded down")
	assert_eq(result["state"]["run_phase"], "map")
	# nearly_full: at 79 / 80 the Nap restores 1.
	var nearly_full: Dictionary = _at_tailgate(rules, 79)
	assert_eq(nearly_full["dudes"][0]["offers"][0]["options"][0]["amount"], 1)
	assert_eq(Core.apply(rules, nearly_full, Helpers.choose("p1", 1, nearly_full["dudes"][0]["offers"][0]["id"], 0))["state"]["dudes"][0]["hp"], 80)


## Lift upgrades the named card (card_upgraded); a card that cannot be upgraded, or no card_uid, is refused.
func test_lift() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: at the Tailgate.
	var state: Dictionary = _at_tailgate(rules, 80)
	# offer_id: the Tailgate offer.
	var offer_id: String = state["dudes"][0]["offers"][0]["id"]
	assert_eq(Core.apply(rules, state, Helpers.choose("p1", 1, offer_id, 1))["reject"], "bad_target", "no card_uid")
	assert_eq(Core.apply(rules, state, Helpers.choose("p1", 1, offer_id, 1, "c1"))["reject"], "bad_target", "Punch has no upgrade")
	assert_eq(Core.apply(rules, state, Helpers.choose("p1", 1, offer_id, 0, "c9"))["reject"], "bad_target", "Nap takes no card")
	# result: Lift Arm Bar.
	var result: Dictionary = Core.apply(rules, state, Helpers.choose("p1", 1, offer_id, 1, "c9"))
	assert_eq(result["reject"], "")
	assert_eq(Helpers.contract_problems(result), [] as Array[String])
	assert_true(result["state"]["dudes"][0]["cards"]["c9"]["upgraded"])
	assert_eq(Helpers.of_type(result["events"], "card_upgraded"), [{"type": "card_upgraded", "player_id": "p1", "card_uid": "c9"}])
	# again: a second Tailgate offers no Lift (Arm Bar is upgraded already).
	var again: Dictionary = Helpers.use_small_map(result["state"].duplicate(true), ["tailgate"])
	again = Core.apply(rules, again, Helpers.vote("p1", 2, "r1c0"))["state"]
	assert_eq(again["dudes"][0]["offers"][0]["options"][1], {"kind": "lift", "available": false, "card_uids": []})


## A Lifted Arm Bar deals its upgraded damage, 11 instead of 8 (GDD "Example card definition").
func test_lifted_card_plays_upgraded() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: a run with Arm Bar upgraded (test setup), then a fight against a training dummy-like Pledge.
	var state: Dictionary = Helpers.start(rules, SEED)
	state["dudes"][0]["cards"]["c9"]["upgraded"] = true
	state = Fight.start_fight(rules, state, ["goblin_bouncer"])["state"]
	# tom: p1.
	var tom: Dictionary = state["dudes"][0]
	# found: whether Arm Bar is in the opening hand; if not, it is moved there (test setup).
	if not tom["hand"].has("c9"):
		tom["draw_pile"].erase("c9")
		tom["discard_pile"].erase("c9")
		tom["hand"].append("c9")
	# enemy: the Bouncer.
	var enemy: String = state["combat"]["enemies"][0]["uid"]
	# result: playing the Lifted Arm Bar.
	var result: Dictionary = Core.apply(rules, state, Helpers.request("play_card", "p1", 0,
		{"card_uid": "c9", "target_id": enemy, "crunch": false}))
	assert_eq(result["reject"], "")
	assert_eq(Helpers.of_type(result["events"], "damage_dealt")[0]["amount"], 11)
