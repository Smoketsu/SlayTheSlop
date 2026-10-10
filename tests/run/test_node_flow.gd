## Tests for core/run/node_flow.gd: votes, moving, fights started by the run, their rewards, Loot and
## the floor's end (task 025). Lane: run (Agent A).
extends "res://tests/framework/test_case.gd"

const RunFixtures := preload("res://tests/run/fixtures/run_fixtures.gd")
const Helpers := preload("res://tests/run/fixtures/run_helpers.gd")
const Core := preload("res://core/core.gd")
const Encounters := preload("res://core/run/encounters.gd")
const Pools := preload("res://core/run/pools.gd")
const Rewards := preload("res://core/run/rewards.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")
const CombatState := preload("res://core/schema/combat_state.gd")

## Seed used by most tests. Fixed so every run checks the same states.
const SEED: int = 7025

## Tom's max HP for tests that must win long fights with a simple bot. A fixture value, not balance.
const STURDY_HP: int = 400


## Applies a request, asserts it was applied and followed the contract, and returns the result.
## rules: the ruleset. state: the state. sent: the request.
func _apply(rules: Dictionary, state: Dictionary, sent: Dictionary) -> Dictionary:
	# result: apply()'s result.
	var result: Dictionary = Core.apply(rules, state, sent)
	assert_eq(result["reject"], "", "request %s applied" % str(sent))
	assert_eq(Helpers.contract_problems(result), [] as Array[String], "contract after %s" % str(sent))
	return result


## Asserts a request is refused with this reason and the state is returned unchanged.
## rules: the ruleset. state: the state. sent: the request. reason: the expected reject code.
func _assert_rejected(rules: Dictionary, state: Dictionary, sent: Dictionary, reason: String) -> void:
	# result: apply()'s result.
	var result: Dictionary = Core.apply(rules, state, sent)
	assert_eq(result["reject"], reason, "reject for %s" % str(sent))
	assert_true(is_same(result["state"], state), "a refused request returns the same state")
	assert_eq(result["events"], [])


## Returns a run on a small map with one row-1 node of each type, after voting for row 1's column
## (the result of that vote, already checked).
## rules: the ruleset. types: the row-1 types. column: which one to vote for.
## dude_ids: Dude ids by seat (each votes for the same column).
func _enter(rules: Dictionary, types: Array, column: int = 0, dude_ids: Array = ["tom"]) -> Dictionary:
	# state: a new run on the small map.
	var state: Dictionary = Helpers.use_small_map(Helpers.start(rules, SEED, dude_ids), types)
	# result: the last vote's result.
	var result: Dictionary = {}
	for i: int in dude_ids.size():
		result = _apply(rules, state, Helpers.vote("p%d" % (i + 1), Helpers.next_seq(state, i), "r1c%d" % column))
		state = result["state"]
	return result


## Refusals on the map: a node that is not a link, an unknown node, choose_reward with no node, a
## fight request outside a fight, and pick_dude (no lobby yet).
func test_map_rejects() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: a new run on a small map.
	var state: Dictionary = Helpers.use_small_map(Helpers.start(rules, SEED), ["brawl", "tailgate"])
	_assert_rejected(rules, state, Helpers.vote("p1", 0, "r2c0"), "bad_target")
	_assert_rejected(rules, state, Helpers.vote("p1", 0, "r9c9"), "bad_target")
	_assert_rejected(rules, state, Helpers.choose("p1", 0, "o1", 0), "wrong_phase")
	_assert_rejected(rules, state, Helpers.request("set_ready", "p1", 0, {"ready": true}), "wrong_phase")
	_assert_rejected(rules, state, Helpers.request("pick_dude", "p1", 0, {"dude_id": "tom"}), "wrong_phase")
	_assert_rejected(rules, state, Helpers.vote("p2", 0, "r1c0"), "unknown_player")


## Voting for a Brawl moves the party onto it and starts its fight in the same request; the first
## Brawl of a floor uses an "early" encounter (G19); choose_reward is wrong_phase during the fight.
func test_vote_enters_a_brawl() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# result: the vote's result.
	var result: Dictionary = _enter(rules, ["brawl", "tailgate"])
	# state: after the vote.
	var state: Dictionary = result["state"]
	assert_eq(state["state_version"], 1)
	assert_eq(state["run_phase"], "node")
	assert_eq(state["node_index"], 1)
	assert_eq(state["path"], ["r1c0"])
	assert_eq(state["votes"], {})
	assert_true(RunFixtures.ENCOUNTERS[state["encounter_id"]].get("early", false), "first Brawl is early: %s" % state["encounter_id"])
	assert_eq(state["combat"]["phase"], "player")
	assert_eq(result["events"][0], {"type": "vote_cast", "player_id": "p1", "node_id": "r1c0"})
	assert_eq(result["events"][1], {"type": "node_entered", "node_id": "r1c0", "node_type": "brawl"})
	assert_eq(result["events"][2]["type"], "fight_started")
	_assert_rejected(rules, state, Helpers.choose("p1", 1, "o1", 0), "wrong_phase")
	_assert_rejected(rules, state, Helpers.vote("p1", 1, "r2c0"), "wrong_phase")


## G19: the first EARLY_BRAWL_COUNT Brawls draw only early encounters; later ones draw from all.
func test_early_brawls() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: a run whose path holds brawl nodes (test setup).
	var state: Dictionary = Helpers.use_small_map(Helpers.start(rules, SEED), ["brawl", "brawl", "brawl"])
	# early: the early encounter ids.
	var early: Array = []
	# all: every brawl encounter id.
	var all: Array = []
	for id: String in RunFixtures.ENCOUNTERS:
		if RunFixtures.ENCOUNTERS[id]["node"] == "brawl":
			all.append(id)
			if RunFixtures.ENCOUNTERS[id].get("early", false):
				early.append(id)
	early.sort()
	all.sort()
	state["path"] = ["r1c0"]
	assert_eq(Encounters.candidates(rules, state, "brawl"), early, "first Brawl")
	state["path"] = ["r1c0", "r1c1"]
	assert_eq(Encounters.candidates(rules, state, "brawl"), early, "second Brawl")
	state["path"] = ["r1c0", "r1c1", "r1c2"]
	assert_eq(Encounters.candidates(rules, state, "brawl"), all, "third Brawl")
	assert_eq(Encounters.candidates(rules, state, "rival").size(), 3, "three floor 1 Rivals")
	assert_eq(Encounters.candidates(rules, state, "boss"), ["basement_goblin_king_chad"])
	# Before moving (a vote is checked before the party moves): path does not hold the voted node yet,
	# so every entry is an earlier Brawl. After two Brawls the vote check sees the full list, as the
	# draw on entering will (found by Agent B in the review of #66).
	state["path"] = ["r1c0", "r1c1"]
	assert_eq(Encounters.brawls_before(state, false), 2, "two Brawls behind, none entered yet")
	assert_eq(Encounters.candidates(rules, state, "brawl", false), all, "vote check for the third Brawl")
	assert_eq(Encounters.brawls_before(state), 1, "on the second Brawl: one before it")


## A won Brawl: Unused Gym Membership heals, then BRAWL_DOLLA Dolla Bills and a card offer of
## CARD_REWARD_CHOICES different cards from Tom's pool (no starter or special card); picking one adds it
## to the run deck and the party is back on the map; the fight is cleared.
func test_brawl_reward() -> void:
	# rules: the slice fixtures, Tom sturdy so the bot wins.
	var rules: Dictionary = RunFixtures.ruleset({}, {"max_hp": STURDY_HP})
	# fought: the bot's fight after entering the Brawl.
	var fought: Dictionary = Helpers.bot_fight(rules, _enter(rules, ["brawl"])["state"])
	assert_eq(fought["problems"], [] as Array[String])
	# state: after the fight.
	var state: Dictionary = fought["state"]
	# tom: p1.
	var tom: Dictionary = state["dudes"][0]
	assert_eq(state["combat"], null, "the won fight is cleared")
	assert_eq(state["run_phase"], "node", "the card choice keeps the party on the node")
	assert_eq(Helpers.of_type(fought["events"], "fight_ended"), [{"type": "fight_ended", "result": "won"}])
	assert_eq(Helpers.of_type(fought["events"], "gear_triggered")[0]["gear_id"], "tom_unused_gym_membership")
	# gained: the Dolla Bills the fight gave (the rats may steal, so only the reward event is read).
	var gained: Array = Helpers.of_type(fought["events"], "dolla_bills_changed")
	assert_true(gained.back()["delta"] >= 10 and gained.back()["delta"] <= 20, "Brawl Dolla Bills %d" % gained.back()["delta"])
	assert_eq(tom["offers"].size(), 1)
	# offer: the card reward.
	var offer: Dictionary = tom["offers"][0]
	assert_eq(offer["kind"], "card")
	assert_true(offer["skippable"])
	assert_eq(offer["options"].size(), rules["constants"]["CARD_REWARD_CHOICES"])
	# offered: the card ids, to check they differ.
	var offered: Dictionary = {}
	for option: Dictionary in offer["options"]:
		assert_eq(option["kind"], "card")
		# card: the offered card.
		var card: Dictionary = rules["cards"][option["card_id"]]
		assert_eq(card["owner"], "tom")
		assert_true(Pools.OFFERED_RARITIES.has(card["rarity"]), "%s is %s" % [card["id"], card["rarity"]])
		offered[option["card_id"]] = true
	assert_eq(offered.size(), offer["options"].size(), "no card twice in one offer")
	# deck_size: the deck before picking.
	var deck_size: int = tom["deck"].size()
	# picked: the choice's result.
	var picked: Dictionary = _apply(rules, state, Helpers.choose("p1", Helpers.next_seq(state), offer["id"], 1))
	assert_eq(picked["state"]["dudes"][0]["deck"].size(), deck_size + 1)
	assert_eq(Helpers.deck_ids(picked["state"]).back(), offer["options"][1]["card_id"])
	assert_eq(picked["state"]["run_phase"], "map")
	assert_eq(picked["state"]["encounter_id"], "")
	assert_eq(Helpers.of_type(picked["events"], "offer_closed"), [{"type": "offer_closed", "player_id": "p1",
		"reward_id": offer["id"], "choice_index": 1}])
	assert_eq(Helpers.of_type(picked["events"], "card_created")[0]["to"], "deck")


## Skipping a card reward (-1) adds nothing; a bad index or a card_uid is refused.
func test_skip_card_reward() -> void:
	# rules: the slice fixtures, Tom sturdy.
	var rules: Dictionary = RunFixtures.ruleset({}, {"max_hp": STURDY_HP})
	# state: after a won Brawl.
	var state: Dictionary = Helpers.bot_fight(rules, _enter(rules, ["brawl"])["state"])["state"]
	# offer_id: the card reward.
	var offer_id: String = state["dudes"][0]["offers"][0]["id"]
	# seq: the next seq.
	var seq: int = Helpers.next_seq(state)
	_assert_rejected(rules, state, Helpers.choose("p1", seq, offer_id, 3), "bad_target")
	_assert_rejected(rules, state, Helpers.choose("p1", seq, offer_id, -2), "bad_target")
	_assert_rejected(rules, state, Helpers.choose("p1", seq, offer_id, 0, "c1"), "bad_target")
	_assert_rejected(rules, state, Helpers.choose("p1", seq, "o999", 0), "wrong_phase")
	# skipped: the skip's result.
	var skipped: Dictionary = _apply(rules, state, Helpers.choose("p1", seq, offer_id, -1))
	assert_eq(skipped["state"]["dudes"][0]["deck"], state["dudes"][0]["deck"])
	assert_eq(skipped["state"]["run_phase"], "map")


## A lost fight ends the run: run_phase "lost", run_ended, the fight kept, every request refused.
func test_lost_fight_ends_the_run() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: in a Brawl, Tom at 1 HP (test setup).
	var state: Dictionary = _enter(rules, ["brawl"])["state"]
	state["dudes"][0]["hp"] = 1
	# events: every event until the fight ends.
	var events: Array = []
	while state["combat"]["phase"] == "player":
		# result: Ready, again and again, so the enemies hit.
		var result: Dictionary = _apply(rules, state, Helpers.request("set_ready", "p1", Helpers.next_seq(state), {"ready": true}))
		events.append_array(result["events"])
		state = result["state"]
	assert_eq(state["run_phase"], "lost")
	assert_eq(state["combat"]["result"], "lost")
	assert_eq(Helpers.of_type(events, "run_ended"), [{"type": "run_ended", "result": "lost"}])
	_assert_rejected(rules, state, Helpers.vote("p1", Helpers.next_seq(state), "r2c0"), "wrong_phase")
	_assert_rejected(rules, state, Helpers.request("set_ready", "p1", Helpers.next_seq(state), {"ready": true}), "wrong_phase")


## Co-op votes: the party moves only when every Dude has voted; a tie goes to the Designated Driver.
func test_votes_wait_for_everyone_and_ties_go_to_the_driver() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: two Toms on a map with a Tailgate and Baileys.
	var state: Dictionary = Helpers.use_small_map(Helpers.start(rules, SEED, ["tom", "tom"]), ["tailgate", "baileys"])
	# first: p1's vote.
	var first: Dictionary = _apply(rules, state, Helpers.vote("p1", 0, "r1c0"))
	assert_eq(first["state"]["run_phase"], "map", "waits for p2")
	assert_eq(first["state"]["votes"], {"p1": "r1c0"})
	# changed: p1 changes their vote.
	var changed: Dictionary = _apply(rules, first["state"], Helpers.vote("p1", 1, "r1c1"))
	assert_eq(changed["state"]["votes"], {"p1": "r1c1"})
	# tied: p2 votes the other node; p1 is the Designated Driver.
	var tied: Dictionary = _apply(rules, changed["state"], Helpers.vote("p2", 0, "r1c0"))
	assert_eq(tied["state"]["path"], ["r1c1"], "the Driver's vote wins the tie")
	assert_eq(tied["state"]["dudes"][0]["offers"][0]["kind"], "baileys")
	assert_eq(tied["state"]["dudes"][1]["offers"][0]["kind"], "baileys", "each player gets their own offer")
	# driven: the same votes with p2 as Designated Driver (test setup).
	var driven: Dictionary = changed["state"].duplicate(true)
	driven["designated_driver"] = "p2"
	assert_eq(_apply(rules, driven, Helpers.vote("p2", 0, "r1c0"))["state"]["path"], ["r1c0"])


## A node the ruleset has nothing for is refused at the vote: a fight node with no encounter, a
## Side Quest node with no Side Quest. A Loot node with no loot encounter is plain Loot.
func test_nodes_without_content_are_refused() -> void:
	# extra: every encounter and Side Quest file removed.
	var extra: Dictionary = {}
	for id: String in RunFixtures.ENCOUNTERS:
		extra["data/encounters/%s.json" % id] = null
	for id: String in RunFixtures.SIDE_QUESTS:
		extra["data/side_quests/%s.json" % id] = null
	# rules: the fixtures without them.
	var rules: Dictionary = RunFixtures.ruleset({"LOOT_MIMIC_CHANCE": 1}, {}, extra)
	assert_false(rules.is_empty())
	# state: a run with every node type in row 1.
	var state: Dictionary = Helpers.use_small_map(Helpers.start(rules, SEED), ["brawl", "rival", "side_quest", "loot", "tailgate"])
	_assert_rejected(rules, state, Helpers.vote("p1", 0, "r1c0"), "bad_target")
	_assert_rejected(rules, state, Helpers.vote("p1", 0, "r1c1"), "bad_target")
	_assert_rejected(rules, state, Helpers.vote("p1", 0, "r1c2"), "bad_target")
	# looted: the Loot node, a Mimic roll with no Mimic encounter.
	var looted: Dictionary = _apply(rules, state, Helpers.vote("p1", 0, "r1c3"))
	assert_eq(looted["state"]["combat"], null)
	assert_eq(looted["state"]["dudes"][0]["gear"].size(), 2, "plain Loot gave a Gear")


## A won Rival fight: RIVAL_DOLLA Dolla Bills, one Gear from the Loot pool, and a card offer.
func test_rival_reward() -> void:
	# rules: the slice fixtures, Tom sturdy.
	var rules: Dictionary = RunFixtures.ruleset({}, {"max_hp": STURDY_HP})
	# entered: the vote into the Rival.
	var entered: Dictionary = _enter(rules, ["rival"])
	assert_eq(RunFixtures.ENCOUNTERS[entered["state"]["encounter_id"]]["node"], "rival")
	# fought: the bot's fight.
	var fought: Dictionary = Helpers.bot_fight(rules, entered["state"])
	assert_eq(fought["problems"], [] as Array[String])
	# tom: p1 after the fight.
	var tom: Dictionary = fought["state"]["dudes"][0]
	# money: the reward's Dolla Bills event (the last one).
	var money: Dictionary = Helpers.of_type(fought["events"], "dolla_bills_changed").back()
	assert_true(money["delta"] >= 25 and money["delta"] <= 35, "Rival Dolla Bills %d" % money["delta"])
	assert_eq(tom["gear"].size(), 2, "a Gear")
	# gear: the new Gear.
	var gear: Dictionary = rules["gear"][tom["gear"][1]]
	assert_true(gear["owner"] == "general" or gear["owner"] == "tom")
	assert_true(Pools.OFFERED_RARITIES.has(gear["rarity"]))
	assert_eq(tom["offers"].size(), 1)
	assert_eq(tom["offers"][0]["kind"], "card")


## The boss: a full heal and 1 of BOSS_GEAR_CHOICES Boss Gear (no skip); picking it ends the floor.
func test_boss_reward_and_floor_end() -> void:
	# rules: the slice fixtures, Tom sturdy.
	var rules: Dictionary = RunFixtures.ruleset({}, {"max_hp": STURDY_HP})
	# entered: the vote into the boss node.
	var entered: Dictionary = _enter(rules, ["boss"])
	assert_eq(entered["state"]["encounter_id"], "basement_goblin_king_chad")
	# fought: the bot's fight against Goblin King Chad.
	var fought: Dictionary = Helpers.bot_fight(rules, entered["state"])
	assert_eq(fought["problems"], [] as Array[String])
	# state: after the fight.
	var state: Dictionary = fought["state"]
	# tom: p1.
	var tom: Dictionary = state["dudes"][0]
	assert_eq(tom["hp"], tom["max_hp"], "full heal")
	assert_eq(Helpers.of_type(fought["events"], "dolla_bills_changed").filter(
		func(e: Dictionary) -> bool: return e["delta"] > 0), [], "no Dolla Bills from a boss")
	# offer: the Boss Gear pick.
	var offer: Dictionary = tom["offers"][0]
	assert_eq(offer["kind"], "boss_gear")
	assert_false(offer["skippable"])
	# offered: the Boss Gear ids offered, sorted.
	var offered: Array = offer["options"].map(func(o: Dictionary) -> String: return o["gear_id"])
	offered.sort()
	assert_eq(offered, ["beer_helmet", "cursed_intramural_trophy", "dads_platinum_card"])
	_assert_rejected(rules, state, Helpers.choose("p1", Helpers.next_seq(state), offer["id"], -1), "bad_target")
	# picked: the pick's result.
	var picked: Dictionary = _apply(rules, state, Helpers.choose("p1", Helpers.next_seq(state), offer["id"], 0))
	assert_eq(picked["state"]["dudes"][0]["gear"].back(), offer["options"][0]["gear_id"])
	assert_eq(picked["state"]["run_phase"], "floor_end")
	assert_eq(Helpers.of_type(picked["events"], "floor_ended"), [{"type": "floor_ended", "floor": 1}])
	_assert_rejected(rules, picked["state"], Helpers.vote("p1", Helpers.next_seq(picked["state"]), "r2c0"), "wrong_phase")


## Loot (G19): with LOOT_MIMIC_CHANCE 0, free Gear from the Loot pool and straight back to the map.
func test_loot_gives_gear() -> void:
	# rules: the slice fixtures, never a Mimic.
	var rules: Dictionary = RunFixtures.ruleset({"LOOT_MIMIC_CHANCE": 0})
	# result: the vote into Loot.
	var result: Dictionary = _enter(rules, ["loot"])
	# tom: p1.
	var tom: Dictionary = result["state"]["dudes"][0]
	assert_eq(result["state"]["combat"], null)
	assert_eq(result["state"]["run_phase"], "map", "nothing to choose")
	assert_eq(tom["gear"].size(), 2)
	assert_true(Pools.loot_gear(rules, Helpers.start(rules, SEED)["dudes"][0]).has(tom["gear"][1]), "from the Loot pool")
	assert_eq(Helpers.of_type(result["events"], "gear_gained").size(), 1)


## Loot as a Mimic Cooler (G19): with LOOT_MIMIC_CHANCE 1 the node is a fight against the Mimic; winning
## gives the Brew it drops and no Gear and no card offer.
func test_mimic_cooler() -> void:
	# rules: the slice fixtures, always a Mimic, Tom sturdy.
	var rules: Dictionary = RunFixtures.ruleset({"LOOT_MIMIC_CHANCE": 1}, {"max_hp": STURDY_HP})
	# entered: the vote into Loot.
	var entered: Dictionary = _enter(rules, ["loot"])
	assert_eq(entered["state"]["encounter_id"], "basement_mimic_cooler")
	# fought: the bot's fight.
	var fought: Dictionary = Helpers.bot_fight(rules, entered["state"])
	assert_eq(fought["problems"], [] as Array[String])
	# tom: p1 after it.
	var tom: Dictionary = fought["state"]["dudes"][0]
	assert_eq(Helpers.of_type(fought["events"], "brew_dropped").size(), 1)
	assert_eq(tom["brews"].size(), 1, "the dropped Brew")
	assert_eq(tom["gear"], ["tom_unused_gym_membership"], "no Loot Gear")
	assert_eq(tom["offers"], [])
	assert_eq(fought["state"]["run_phase"], "map")


## G19's 1 in 4: over many seeds about a quarter of Loot nodes are Mimics.
func test_mimic_odds() -> void:
	# rules: the slice fixtures with the real chance.
	var rules: Dictionary = RunFixtures.ruleset()
	# mimics: Loot nodes that were Mimics.
	var mimics: int = 0
	# tries: seeds tried.
	var tries: int = 400
	for run_seed: int in tries:
		# state: a run on a one-Loot map.
		var state: Dictionary = Helpers.use_small_map(Helpers.start(rules, run_seed), ["loot"])
		if Core.apply(rules, state, Helpers.vote("p1", 0, "r1c0"))["state"]["combat"] != null:
			mimics += 1
	assert_true(mimics > tries * 15 / 100 and mimics < tries * 35 / 100, "Mimics %d of %d" % [mimics, tries])


## G21: card offers draw common / uncommon / rare about 60 / 35 / 5 percent of the time.
func test_card_reward_rarity_odds() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# counts: rarity -> how often it came first in an offer.
	var counts: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}
	# tries: offers drawn.
	var tries: int = 2000
	# state: a run whose rewards stream is drawn on.
	var state: Dictionary = Helpers.start(rules, SEED)
	for i: int in tries:
		# card_id: the first card of one offer.
		var card_id: String = Pools.draw_cards_in_place(rules, state, "rewards:p1", "tom", 1)[0]
		counts[rules["cards"][card_id]["rarity"]] += 1
	assert_true(counts["common"] > 1080 and counts["common"] < 1320, "common %d" % counts["common"])
	assert_true(counts["uncommon"] > 580 and counts["uncommon"] < 820, "uncommon %d" % counts["uncommon"])
	assert_true(counts["rare"] > 50 and counts["rare"] < 160, "rare %d" % counts["rare"])


## G22: a Brawl gives a Brew about 40% of the time; with every slot full it is not kept.
func test_brawl_brew_chance() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# brews: Brawl rewards that included a Brew.
	var brews: int = 0
	# tries: rewards handed out.
	var tries: int = 500
	for run_seed: int in tries:
		# state: a run with a won fight (test setup) whose rewards are handed out.
		var state: Dictionary = Helpers.start(rules, run_seed)
		state["combat"] = CombatState.blank()
		# events: the reward's events.
		var events: Array = []
		Rewards.after_win_in_place(rules, state, "brawl", events)
		brews += Helpers.of_type(events, "brew_gained").size()
	assert_true(brews > tries * 30 / 100 and brews < tries * 50 / 100, "Brews %d of %d" % [brews, tries])
	# full: a Dude with no free slot.
	var full: Dictionary = Helpers.start(rules, SEED)
	full["dudes"][0]["brew_slots"] = 0
	# kept: the events of granting a Brew to them.
	var kept: Array = []
	Rewards.random_brew_in_place(rules, full, 0, "rewards:p1", kept)
	assert_eq(kept[0]["type"], "brew_not_kept")
	assert_eq(full["dudes"][0]["brews"], [])


## GDD "Passing out": a Passed Out Dude wakes at REVIVE_HP_FRACTION of max HP (rounded down, G57)
## when the team wins, before the rewards, and gets their own reward.
func test_revive_after_a_won_fight() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: two Toms after a won fight with p2 Passed Out (test setup).
	var state: Dictionary = Helpers.start(rules, SEED, ["tom", "tom"])
	state["dudes"][1]["hp"] = 0
	state["dudes"][1]["passed_out"] = true
	state["combat"] = CombatState.blank()
	# events: the reward's events.
	var events: Array = []
	Rewards.after_win_in_place(rules, state, "brawl", events)
	assert_false(state["dudes"][1]["passed_out"])
	assert_eq(state["dudes"][1]["hp"], 24, "30% of 80")
	assert_eq(events[0], {"type": "dude_revived", "player_id": "p2", "hp": 24})
	assert_eq(state["dudes"][1]["offers"].size(), 1, "p2's own card offer")
	assert_ne(state["dudes"][0]["offers"][0]["id"], state["dudes"][1]["offers"][0]["id"])


## Dad's Platinum Card: "You no longer earn Dolla Bills from fights".
func test_dads_platinum_card_stops_fight_money() -> void:
	# rules: the slice fixtures.
	var rules: Dictionary = RunFixtures.ruleset()
	# state: a run with the card and a won fight (test setup).
	var state: Dictionary = Helpers.start(rules, SEED)
	GearTriggers.gain_in_place(rules, state["dudes"][0], "dads_platinum_card", [])
	state["combat"] = CombatState.blank()
	# events: the reward's events.
	var events: Array = []
	Rewards.after_win_in_place(rules, state, "rival", events)
	assert_eq(state["dudes"][0]["dolla_bills"], 99)
	assert_eq(Helpers.of_type(events, "dolla_bills_changed"), [])


## I7 (accepted; task 033): Beer Helmet's Hangover lasts one fight (add_card "lasts": "fight"), so
## after two fights the run deck holds no Hangover and the Dude owns none.
func test_beer_helmet_hangovers_do_not_pile_up() -> void:
	# rules: the slice fixtures, Tom sturdy.
	var rules: Dictionary = RunFixtures.ruleset({}, {"max_hp": STURDY_HP})
	# state: a run on a map of two Brawls in a row (test setup), with Beer Helmet.
	var state: Dictionary = Helpers.start(rules, SEED)
	state["map"] = {"floor": 1, "nodes": [
		{"id": "r0c0", "row": 0, "column": 0, "type": "start", "links": ["r1c0"]},
		{"id": "r1c0", "row": 1, "column": 0, "type": "brawl", "links": ["r2c0"]},
		{"id": "r2c0", "row": 2, "column": 0, "type": "brawl", "links": ["r3c0"]},
		{"id": "r3c0", "row": 3, "column": 0, "type": "boss", "links": []}]}
	GearTriggers.gain_in_place(rules, state["dudes"][0], "beer_helmet", [])
	for node_id: String in ["r1c0", "r2c0"]:
		state = _apply(rules, state, Helpers.vote("p1", Helpers.next_seq(state), node_id))["state"]
		state = Helpers.bot_fight(rules, state)["state"]
		state = _apply(rules, state, Helpers.choose("p1", Helpers.next_seq(state), state["dudes"][0]["offers"][0]["id"], -1))["state"]
	assert_eq(Helpers.deck_ids(state).count("junk_hangover"), 0, "each fight's Hangover left when the fight ended")
	assert_eq(state["dudes"][0]["cards"].values().filter(
		func(card: Dictionary) -> bool: return card["def_id"] == "junk_hangover").size(), 0, "none owned between fights")
