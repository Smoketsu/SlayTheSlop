## Tom's card upgrades as data (task 032): the upgrade tables in docs/proposals/tom-slice-cards.md for
## all 30 of Tom's cards, and Q1 (Chest Bump has no upgrade), accepted by both people (decision log
## row "Task 012: upgrades, Q1 and Q2", #103). Lane: tools (Agent B).
## Each card's "upgrade" is checked against the accepted table and the proposal, applied with
## core/combat/upgrades.gd upgraded() and checked against the card schema; the upgraded text is checked
## against the upgraded numbers; and a fixed-seed run on the real data Lifts a card at a Tailgate and
## plays it in the next fight.
## GDD "Example card definition", "Card definition fields" (upgrade), "The Tailgate"; G15.
extends "res://tests/framework/test_case.gd"

const Check := preload("res://tests/data/content_check.gd")
const CardDef := preload("res://core/schema/card_def.gd")
const Upgrades := preload("res://core/combat/upgrades.gd")
const Core := preload("res://core/core.gd")
const RunHelpers := preload("res://tests/run/fixtures/run_helpers.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")

## The accepted upgrades, copied from tom-slice-cards.md "Upgrades" (both tables): card id ->
## {"upgrade": the card file's exact "upgrade" field, "from": each upgraded path's value before the
## upgrade (the proposal's "Reads" column, left of the arrow)}. Every upgrade that changes a number in
## the card's text also sets "text" to the base text with only that number changed (Agent A's note on
## #103: an upgraded copy otherwise keeps the old text). Cost-only upgrades set no "text": the card
## text never states the cost, and screens show the cost apart from it. Changed only when a person
## changes an upgrade in the proposal or the decision log.
const ACCEPTED_UPGRADES := {
	# GDD cards.
	# Punch: 6 -> 9 damage.
	"tom_punch": {"upgrade": {"effects[0].amount": 9, "text": "Deal 9 damage"},
		"from": {"effects[0].amount": 6}},
	# Flex: 5 -> 8 Guard.
	"tom_flex": {"upgrade": {"effects[0].amount": 8, "text": "Gain 8 Guard"},
		"from": {"effects[0].amount": 5}},
	# Arm Bar: 8 -> 11 damage (the GDD's example card; the path was already in the file).
	"tom_arm_bar": {"upgrade": {"effects[0].amount": 11, "text": "Deal 11 damage. Break 1 arm"},
		"from": {"effects[0].amount": 8}},
	# Well, Actually: 2 -> 3 Ick.
	"tom_well_actually": {"upgrade": {"effects[0].stacks": 3, "text": "Apply 3 Ick"},
		"from": {"effects[0].stacks": 2}},
	# Wrist Lock: 5 -> 8 damage.
	"tom_wrist_lock": {"upgrade": {"effects[0].amount": 8,
		"text": "Deal 8 damage. If the target has a Broken Arm, draw 1 card"},
		"from": {"effects[0].amount": 5}},
	# Chrome Dome: 7 -> 10 Guard (the 3 glare damage is unchanged).
	"tom_chrome_dome": {"upgrade": {"effects[0].amount": 10,
		"text": "Gain 10 Guard. This turn, enemies that hit Tom take 3 damage from the glare"},
		"from": {"effects[0].amount": 7}},
	# Skull Bash: 10 -> 14 damage (Tom still takes 2).
	"tom_skull_bash": {"upgrade": {"effects[0].amount": 14, "text": "Deal 14 damage. Tom takes 2 damage"},
		"from": {"effects[0].amount": 10}},
	# Unsolicited Advice: 3 -> 5 Ick (Noodle Arms unchanged).
	"tom_unsolicited_advice": {"upgrade": {"effects[0].stacks": 5, "text": "Apply 5 Ick and 1 Noodle Arms"},
		"from": {"effects[0].stacks": 3}},
	# Cast Party: 4 -> 6 Guard per Broken Arm.
	"tom_cast_party": {"upgrade": {"effects[0].amount": 6,
		"text": "Gain 6 Guard for every Broken Arm on all enemies"},
		"from": {"effects[0].amount": 4}},
	# Snap City: 14 -> 18 damage.
	"tom_snap_city": {"upgrade": {"effects[0].amount": 18,
		"text": "Deal 18 damage. Break 1 arm. If the target is now Armless, gain 1 Hype"},
		"from": {"effects[0].amount": 14}},
	# Pickup Line: 4 -> 6 Ick to all (Tom still takes 3).
	"tom_pickup_line": {"upgrade": {"effects[0].stacks": 6,
		"text": "Apply 6 Ick to all enemies. Tom takes 3 damage from the response"},
		"from": {"effects[0].stacks": 4}},
	# Reply Guy: the Power's trigger applies 2 -> 3 Ick.
	"tom_reply_guy": {"upgrade": {"power_triggers[0].effects[0].stacks": 3,
		"text": "Whenever an enemy gains a buff, apply 3 Ick to it"},
		"from": {"power_triggers[0].effects[0].stacks": 2}},
	# Double Arm Day: 9 -> 12 per hit (both damage effects).
	"tom_double_arm_day": {"upgrade": {"effects[0].amount": 12, "effects[2].amount": 12,
		"text": "Deal 12 damage twice. Each hit breaks 1 arm"},
		"from": {"effects[0].amount": 9, "effects[2].amount": 9}},
	# Friend Zone: cost 2 -> 1 (no text change).
	"tom_friend_zone": {"upgrade": {"cost": 1}, "from": {"cost": 2}},
	# New cards.
	# Noogie: 4 -> 6 damage, 1 -> 2 Ick.
	"tom_noogie": {"upgrade": {"effects[0].amount": 6, "effects[1].stacks": 2, "text": "Deal 6 damage. Apply 2 Ick"},
		"from": {"effects[0].amount": 4, "effects[1].stacks": 1}},
	# Headlock: 7 -> 10 damage.
	"tom_headlock": {"upgrade": {"effects[0].amount": 10,
		"text": "Deal 10 damage. If the target has a Broken Arm, apply 1 Noodle Arms"},
		"from": {"effects[0].amount": 7}},
	# Hot Take: 3 -> 5 Ick.
	"tom_hot_take": {"upgrade": {"effects[0].stacks": 5, "text": "Apply 5 Ick. Draw 1 card"},
		"from": {"effects[0].stacks": 3}},
	# Stare Down: 5 -> 8 Guard.
	"tom_stare_down": {"upgrade": {"effects[0].amount": 8, "text": "Gain 8 Guard. Apply 2 Ick"},
		"from": {"effects[0].amount": 5}},
	# Noggin Knock: 5 -> 7 per hit.
	"tom_noggin_knock": {"upgrade": {"effects[0].amount": 7, "text": "Deal 7 damage twice. Tom takes 2 damage"},
		"from": {"effects[0].amount": 5}},
	# Bro Hug: 7 -> 10 Guard.
	"tom_bro_hug": {"upgrade": {"effects[0].amount": 10, "text": "Target Dude gains 10 Guard"},
		"from": {"effects[0].amount": 7}},
	# Dislocate: cost 1 -> 0 (no text change).
	"tom_dislocate": {"upgrade": {"cost": 0}, "from": {"cost": 1}},
	# Compound Fracture: first hit 6 -> 9 (the two bonus hits stay 6).
	"tom_compound_fracture": {"upgrade": {"effects[0].amount": 9,
		"text": "Deal 9 damage. If the target has a Broken Arm, deal 6 more. If it is Armless, deal 6 more"},
		"from": {"effects[0].amount": 6}},
	# Story Time: 7 -> 10 Ick.
	"tom_story_time": {"upgrade": {"effects[0].stacks": 10, "text": "Apply 10 Ick"},
		"from": {"effects[0].stacks": 7}},
	# Gym Selfie: 2 -> 3 Swole.
	"tom_gym_selfie": {"upgrade": {"effects[0].amount": 3,
		"text": "Gain 3 Swole for this fight. Apply 1 Ick to all enemies. Tapped"},
		"from": {"effects[0].amount": 2}},
	# Headbutt: 18 -> 23 damage.
	"tom_headbutt": {"upgrade": {"effects[0].amount": 23, "text": "Deal 23 damage. Tom takes 4 damage"},
		"from": {"effects[0].amount": 18}},
	# Tough Skull: the Power's trigger gives 3 -> 5 Guard.
	"tom_tough_skull": {"upgrade": {"power_triggers[0].effects[0].amount": 5,
		"text": "Whenever Tom takes damage from his own card, gain 5 Guard"},
		"from": {"power_triggers[0].effects[0].amount": 3}},
	# Full Nelson: 10 -> 15 damage.
	"tom_full_nelson": {"upgrade": {"effects[0].amount": 15, "text": "Deal 15 damage. Break 2 arms"},
		"from": {"effects[0].amount": 10}},
	# Three-Hour Podcast: cost 2 -> 1 (no text change).
	"tom_three_hour_podcast": {"upgrade": {"cost": 1}, "from": {"cost": 2}},
	# Nothing to Lose: cost 2 -> 1 (no text change).
	"tom_nothing_to_lose": {"upgrade": {"cost": 1}, "from": {"cost": 2}},
	# Main Character Energy: cost 2 -> 1 (no text change).
	"tom_main_character_energy": {"upgrade": {"cost": 1}, "from": {"cost": 2}},
}

## Tom cards with no upgrade: Chest Bump, the Bro Move (Q1: it is never in the deck, so never
## Lifted). Changed only when a person answers differently.
const NO_UPGRADE: Array[String] = ["tom_chest_bump"]
## How many Tom cards have an upgrade: his 14 GDD cards and 16 new ones (G14, G15).
const UPGRADED_COUNT: int = 30
## The upgrade path that changes the card's display text. Part of the upgrade path grammar.
const TEXT_PATH: String = "text"
## The upgrade path that changes the card's Hype cost. Part of the upgrade path grammar.
const COST_PATH: String = "cost"

## The proposal whose "Upgrades" section holds both upgrade tables, one "| Name | `{...}` | Reads |"
## row per card. Read-only here; people change it.
const PROPOSAL_PATH: String = "res://docs/proposals/tom-slice-cards.md"

## Run seed of the fixed-seed Lift.
const SEED: int = 20261011
## The Lifted copy in the fixed-seed run: the first Punch of the starter deck (c1 to c4 are Punch).
const LIFT_UID: String = "c1"
## Recorded on Godot 4.7.2-stable with the data as merged in task 032: what the fixed-seed run shows,
## as [the Lift option's card_uids at the Tailgate, Goblin King Chad's fight's opening hand (card
## uids), the damage the Lifted Punch deals to the first enemy]. All 10 starter cards can be Lifted
## now (only Arm Bar, c9, before task 032), and the Lifted Punch deals its upgraded 9, not 6. If a
## data or rules change alters this on purpose, re-record it and say why in the PR.
const RECORDED: Array = [["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9", "c10"],
	["c1", "c9", "c5", "c8", "c4"], 9]


## data/cards holds exactly the 30 upgraded Tom cards plus Chest Bump, and each file's "upgrade" is
## the accepted one; Chest Bump's is {} (Q1).
func test_every_tom_card_has_its_accepted_upgrade() -> void:
	# found: every Tom card id in data/cards, sorted. expected: the ids this file knows, sorted.
	var found: Array = Check.ids_in("data/cards").filter(func(id: String) -> bool: return id.begins_with("tom_"))
	found.sort()
	var expected: Array = ACCEPTED_UPGRADES.keys() + NO_UPGRADE
	expected.sort()
	assert_eq(found, expected, "every Tom card is in ACCEPTED_UPGRADES or NO_UPGRADE")
	assert_eq(ACCEPTED_UPGRADES.size(), UPGRADED_COUNT, "30 Tom cards have an upgrade")
	for id: String in ACCEPTED_UPGRADES:
		# card: the data file.
		var card: Dictionary = Check.load_file("data/cards/%s.json" % id)
		assert_false(card.get("upgrade", {}).is_empty(), "%s has an upgrade" % id)
		assert_eq(card.get("upgrade"), Check.as_data(ACCEPTED_UPGRADES[id]["upgrade"]), "%s upgrade" % id)
	for id: String in NO_UPGRADE:
		assert_eq(Check.load_file("data/cards/%s.json" % id).get("upgrade"), {}, "%s has no upgrade (Q1)" % id)


## Each row of the proposal's two upgrade tables names a card and its upgrade, and that upgrade
## (without the "text" this task adds) is the one in ACCEPTED_UPGRADES, so the table here is the
## proposal's.
func test_accepted_upgrades_are_the_proposal_tables() -> void:
	# text: the proposal. start: where its "Upgrades" section starts.
	var text: String = FileAccess.get_file_as_string(PROPOSAL_PATH)
	assert_ne(text, "", "the proposal is readable")
	var start: int = text.find("\n## Upgrades")
	assert_ne(start, -1, "the proposal has an Upgrades section")
	if start == -1:
		return
	# end: where the next level-2 heading starts, or -1. section: the section's text.
	var end: int = text.find("\n## ", start + 1)
	var section: String = text.substr(start, end - start if end != -1 else -1)
	# by_name: card display name -> card id, for every Tom card with an upgrade.
	var by_name: Dictionary = {}
	for id: String in ACCEPTED_UPGRADES:
		by_name[Check.load_file("data/cards/%s.json" % id).get("name", "")] = id
	# row: matches "| Name | `{...}` |". seen: the card ids found in the tables.
	var row: RegEx = RegEx.create_from_string("(?m)^\\| ([^|]+?) \\| `(\\{[^`]*\\})` \\|")
	var seen: Array = []
	for m: RegExMatch in row.search_all(section):
		# id: the row's card id. proposed: the row's upgrade, parsed. accepted: ours without "text".
		var id: String = by_name.get(m.get_string(1), "")
		assert_ne(id, "", "%s is a Tom card with an upgrade" % m.get_string(1))
		if id == "":
			continue
		seen.append(id)
		var proposed: Variant = Check.as_data(JSON.parse_string(m.get_string(2)))
		var accepted: Dictionary = Check.as_data(ACCEPTED_UPGRADES[id]["upgrade"])
		accepted.erase(TEXT_PATH)
		assert_eq(proposed, accepted, "%s matches the proposal" % id)
	seen.sort()
	# all_ids: every id in ACCEPTED_UPGRADES, sorted.
	var all_ids: Array = ACCEPTED_UPGRADES.keys()
	all_ids.sort()
	assert_eq(seen, all_ids, "the proposal has one row per upgraded card")


## Every upgrade applies with upgraded(): each path held its "from" value, now holds the accepted value,
## the upgraded card passes card_def.gd check(), nothing else changes, and Lift can offer it
## (can_upgrade). Chest Bump cannot be upgraded.
func test_upgrades_apply_and_pass_the_schema() -> void:
	for id: String in ACCEPTED_UPGRADES:
		# card: the data file. entry: the accepted upgrade. lifted: upgraded()'s result.
		var card: Dictionary = Check.load_file("data/cards/%s.json" % id)
		var entry: Dictionary = Check.as_data(ACCEPTED_UPGRADES[id])
		var lifted: Dictionary = Upgrades.upgraded(card)
		assert_true(lifted["ok"], "%s upgrades: %s" % [id, lifted["error"]])
		if not lifted["ok"]:
			continue
		# up: the upgraded definition.
		var up: Dictionary = lifted["definition"]
		assert_no_errors(CardDef.check(up, id + " upgraded"), "%s upgraded schema" % id)
		assert_true(Upgrades.can_upgrade(card), "%s can be Lifted" % id)
		for path: String in entry["from"]:
			assert_eq(_value_at(card, path), entry["from"][path], "%s %s before" % [id, path])
			assert_eq(_value_at(up, path), entry["upgrade"][path], "%s %s after" % [id, path])
		# back: the upgraded card with each upgraded path set back, which must be the base card.
		var back: Dictionary = up.duplicate(true)
		for path: String in entry["from"]:
			_set_at(back, path, entry["from"][path])
		back["text"] = card["text"]
		assert_eq(back, card, "%s: the upgrade changes nothing else" % id)
	for id: String in NO_UPGRADE:
		# bump: the data file.
		var bump: Dictionary = Check.load_file("data/cards/%s.json" % id)
		assert_false(Upgrades.can_upgrade(bump), "%s cannot be Lifted (Q1)" % id)
		assert_false(Upgrades.upgraded(bump)["ok"], "%s has no upgraded form" % id)


## The upgraded text of every card whose upgrade changes a number in its text differs from the base
## text, holds each upgraded number as a whole word, and is exactly the base text with each upgraded
## number swapped in for the old one (first match), so nothing else in the wording changed. A cost-only
## upgrade keeps the base text.
func test_upgraded_text_shows_the_upgraded_numbers() -> void:
	for id: String in ACCEPTED_UPGRADES:
		# card: the data file. entry: the accepted upgrade. lifted: upgraded()'s result.
		var card: Dictionary = Check.load_file("data/cards/%s.json" % id)
		var entry: Dictionary = Check.as_data(ACCEPTED_UPGRADES[id])
		var lifted: Dictionary = Upgrades.upgraded(card)
		if not lifted["ok"]:
			fail("%s does not upgrade" % id)
			continue
		# up_text: the upgraded card's text.
		var up_text: String = lifted["definition"]["text"]
		if entry["from"].keys() == [COST_PATH]:
			assert_false(entry["upgrade"].has(TEXT_PATH), "%s: a cost-only upgrade sets no text" % id)
			assert_eq(up_text, card["text"], "%s keeps its text" % id)
			continue
		assert_true(entry["upgrade"].has(TEXT_PATH), "%s sets the upgraded text" % id)
		assert_ne(up_text, card["text"], "%s: the upgraded text differs" % id)
		# swapped: the base text with each old number replaced by its new one. pairs: [old, new] done.
		var swapped: String = card["text"]
		var pairs: Array = []
		for path: String in entry["from"]:
			# pair: this path's [old, new] numbers.
			var pair: Array = [entry["from"][path], entry["upgrade"][path]]
			assert_true(_has_word(up_text, pair[1]), "%s text holds %d" % [id, pair[1]])
			if pairs.has(pair):
				continue
			pairs.append(pair)
			assert_true(_has_word(swapped, pair[0]), "%s base text holds %d" % [id, pair[0]])
			swapped = _swap_first(swapped, pair[0], pair[1])
		assert_eq(up_text, swapped, "%s: only the upgraded numbers change" % id)


## Fixed seed, real data: a new run with a one-Tailgate map. The Tailgate's Lift offers every starter
## card; Lifting LIFT_UID (a Punch) upgrades it, and its definition then reads "Deal 9 damage". Voting
## for the boss node starts Goblin King Chad's fight through Core.apply, and the Lifted Punch played
## at the first enemy deals 9. Every step passes the contract checks, the run ends as RECORDED, and a
## replay gives identical snapshot bytes.
func test_fixed_seed_lift_at_a_tailgate() -> void:
	# first, second: two replays.
	var first: Dictionary = _lift_and_play()
	var second: Dictionary = _lift_and_play()
	if first.is_empty() or second.is_empty():
		return
	assert_eq(Snapshot.to_bytes(second["state"]), Snapshot.to_bytes(first["state"]), "a replay is identical")
	assert_eq(first["outcome"], RECORDED, "recorded outcome")
	assert_eq(first["outcome"][2], ACCEPTED_UPGRADES["tom_punch"]["upgrade"]["effects[0].amount"], "the Lifted Punch deals its upgraded damage")


## Plays the fixed-seed Lift run. Returns {"state": the state after the Punch, "outcome": in RECORDED's
## form}, or {} after recording a failure.
func _lift_and_play() -> Dictionary:
	# rules: the real ruleset.
	var rules: Dictionary = Check.real_ruleset()
	assert_false(rules.is_empty(), "data/ builds")
	if rules.is_empty():
		return {}
	# state: a new run on a one-Tailgate map.
	var state: Dictionary = RunHelpers.start(rules, SEED)
	assert_false(state.is_empty(), "the run starts")
	if state.is_empty():
		return {}
	state = RunHelpers.use_small_map(state, ["tailgate"])
	assert_eq(state["dudes"][0]["cards"][LIFT_UID]["def_id"], "tom_punch", "%s is a Punch" % LIFT_UID)
	# voted: entering the Tailgate.
	var voted: Dictionary = Core.apply(rules, state, RunHelpers.vote("p1", RunHelpers.next_seq(state), "r1c0"))
	assert_eq(voted["reject"], "", "the vote for the Tailgate")
	if voted["reject"] != "":
		return {}
	assert_no_errors(RunHelpers.contract_problems(voted), "after the vote")
	# offer: Tom's Tailgate offer. lift: the Lift option's index.
	var offer: Dictionary = voted["state"]["dudes"][0]["offers"][0]
	assert_eq(offer["kind"], "tailgate", "the offer is a Tailgate")
	var lift: int = -1
	for i: int in offer["options"].size():
		if offer["options"][i]["kind"] == "lift":
			lift = i
	assert_ne(lift, -1, "the Tailgate offers a Lift")
	if lift == -1:
		return {}
	# liftable: the Lift option's card uids.
	var liftable: Array = offer["options"][lift]["card_uids"]
	assert_eq(liftable.size(), voted["state"]["dudes"][0]["deck"].size(), "every starter card can be Lifted")
	# lifted: the Lift of LIFT_UID.
	var lifted: Dictionary = Core.apply(rules, voted["state"],
		RunHelpers.choose("p1", RunHelpers.next_seq(voted["state"]), offer["id"], lift, LIFT_UID))
	assert_eq(lifted["reject"], "", "the Lift")
	if lifted["reject"] != "":
		return {}
	assert_no_errors(RunHelpers.contract_problems(lifted), "after the Lift")
	assert_eq(RunHelpers.of_type(lifted["events"], "card_upgraded"),
		[{"type": "card_upgraded", "player_id": "p1", "card_uid": LIFT_UID}], "the Punch is upgraded")
	# tom: Tom after the Lift. definition: the Lifted copy's definition.
	var tom: Dictionary = lifted["state"]["dudes"][0]
	var definition: Dictionary = Upgrades.definition_of(rules, tom, LIFT_UID)
	assert_eq(definition.get("text"), "Deal 9 damage", "the Lifted Punch reads its upgraded text")
	# boss: entering Goblin King Chad's node.
	var boss: Dictionary = Core.apply(rules, lifted["state"], RunHelpers.vote("p1", RunHelpers.next_seq(lifted["state"]), "r2c0"))
	assert_eq(boss["reject"], "", "the vote for the boss")
	if boss["reject"] != "":
		return {}
	assert_no_errors(RunHelpers.contract_problems(boss), "after the boss vote")
	# hand: the opening hand.
	var hand: Array = boss["state"]["dudes"][0]["hand"].duplicate()
	if not hand.has(LIFT_UID):
		fail("%s is not in the opening hand %s" % [LIFT_UID, hand])
		return {}
	# foe: the first enemy. played: the Punch.
	var foe: String = boss["state"]["combat"]["enemies"][0]["uid"]
	var played: Dictionary = Core.apply(rules, boss["state"], RunHelpers.request("play_card", "p1",
		RunHelpers.next_seq(boss["state"]), {"card_uid": LIFT_UID, "target_id": foe, "crunch": false}))
	assert_eq(played["reject"], "", "the Lifted Punch is played")
	if played["reject"] != "":
		return {}
	assert_no_errors(RunHelpers.contract_problems(played), "after the Punch")
	# hits: the damage_dealt events on foe.
	var hits: Array = RunHelpers.of_type(played["events"], "damage_dealt").filter(func(e: Dictionary) -> bool:
		return e["target_id"] == foe)
	assert_eq(hits.size(), 1, "one hit")
	if hits.size() != 1:
		return {}
	return {"state": played["state"], "outcome": [liftable, hand, hits[0]["amount"]]}


## Returns the value at an upgrade path in a card definition, or null when a step is missing.
## card: a card definition. path: an upgrade path such as "effects[0].amount" (grammar in
## core/combat/upgrades.gd).
func _value_at(card: Dictionary, path: String) -> Variant:
	# at: the container being walked.
	var at: Variant = card
	for step: Variant in _steps(path):
		if typeof(step) == TYPE_INT:
			if typeof(at) != TYPE_ARRAY or step >= at.size():
				return null
		elif typeof(at) != TYPE_DICTIONARY or not at.has(step):
			return null
		at = at[step]
	return at


## Sets the value at an upgrade path in a card definition, in place (every step must exist).
## card: a writable card definition. path: an upgrade path. value: the new value.
func _set_at(card: Dictionary, path: String, value: Variant) -> void:
	# steps: the path's steps. at: the container holding the last step.
	var steps: Array = _steps(path)
	var at: Variant = card
	for i: int in steps.size() - 1:
		at = at[steps[i]]
	at[steps[-1]] = value


## Splits an upgrade path into field names (String) and list indexes (int), for example
## "power_triggers[0].effects[0].stacks" -> ["power_triggers", 0, "effects", 0, "stacks"].
## path: an upgrade path from ACCEPTED_UPGRADES (well formed).
func _steps(path: String) -> Array:
	# steps: the result. part: one "."-separated piece.
	var steps: Array = []
	for part: String in path.split("."):
		# pieces: the field name, then each index's digits.
		var pieces: PackedStringArray = part.replace("]", "").split("[")
		steps.append(pieces[0])
		for i: int in range(1, pieces.size()):
			steps.append(pieces[i].to_int())
	return steps


## True when text holds number as a whole word (so 2 does not match inside 12).
## text: card text. number: the number looked for.
func _has_word(text: String, number: int) -> bool:
	return RegEx.create_from_string("\\b%d\\b" % number).search(text) != null


## Returns text with the first whole-word old_number replaced by new_number.
## text: card text. old_number: the number replaced. new_number: its replacement.
func _swap_first(text: String, old_number: int, new_number: int) -> String:
	# found: the first whole-word match, or null.
	var found: RegExMatch = RegEx.create_from_string("\\b%d\\b" % old_number).search(text)
	if found == null:
		return text
	return text.substr(0, found.get_start()) + str(new_number) + text.substr(found.get_end())
