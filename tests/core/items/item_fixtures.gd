## Gear and Brew fixtures for task 021's tests. Lane: core (Agent A).
##
## Not a test file (no test_ prefix). Agent B's real data (task 014) has not merged, so GEAR and
## BREWS hold the slice's 13 Gear and 8 Brews written the way task 014 must write them: GDD ids,
## names, rarities, text and numbers, in core/schema/gear_def.gd and brew_def.gd format, using only
## ops the core has or the op names pinned for tasks 013 and 015. When task 014 merges, these tests
## should switch to the real files (task 021 log).
##
## Pending ops (not built by task 021, so those items' effects are skipped or refused today):
##   draw (task 013): backwards_cap, energy_drink.
##   gain_hype (task 013) and add_card (task 015): special_brownie; add_card: beer_helmet's downside.
## Their fields follow core/ops/README.md on the 013/015 branches (draw and gain_hype: amount;
## add_card: card_id, to, shuffle_in), so these items work once those ops merge.
##
## TEST_GEAR and TEST_BREWS are test-only items that exercise rules no slice item uses.
extends RefCounted

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const Party := preload("res://core/combat/party.gd")
const Fight := preload("res://core/combat/fight.gd")
const GearTriggers := preload("res://core/combat/gear_triggers.gd")

## The slice's Gear (G16 plus the three Boss Gear), by id, as task 014 must write them.
const GEAR := {
	"tom_unused_gym_membership": {"id": "tom_unused_gym_membership", "name": "Unused Gym Membership",
		"owner": "tom", "rarity": "starter", "text": "Heal 6 HP after every fight.", "stats": {},
		"triggers": [{"when": "fight_end", "target": "self", "effects": [{"op": "heal", "amount": 6}]}],
		"modifiers": []},
	"tom_arm_wrestling_table": {"id": "tom_arm_wrestling_table", "name": "Arm Wrestling Table",
		"owner": "tom", "rarity": "uncommon", "text": "Every enemy starts the fight with 1 Broken Arm.", "stats": {},
		"triggers": [{"when": "fight_start", "target": "all_enemies",
			"effects": [{"op": "apply_status", "status": "broken_arm", "stacks": 1}]}],
		"modifiers": []},
	"tom_whole_can_of_body_spray": {"id": "tom_whole_can_of_body_spray", "name": "Whole Can of Body Spray",
		"owner": "tom", "rarity": "rare", "text": "When Tom applies Ick, the target takes 2 damage per stack applied.",
		"stats": {},
		"triggers": [{"when": "ick_applied", "target": "trigger_target", "amount_per_stack": true,
			"effects": [{"op": "damage", "amount": 2}]}],
		"modifiers": []},
	"lifting_belt": {"id": "lifting_belt", "name": "Lifting Belt", "owner": "general", "rarity": "common",
		"text": "+1 Swole", "stats": {"swole": 1}, "triggers": [], "modifiers": []},
	"lucky_lighter": {"id": "lucky_lighter", "name": "Lucky Lighter", "owner": "general", "rarity": "common",
		"text": "+1 Chill", "stats": {"chill": 1}, "triggers": [], "modifiers": []},
	"gallon_jug": {"id": "gallon_jug", "name": "Gallon Jug", "owner": "general", "rarity": "common",
		"text": "+8 Max HP", "stats": {"max_hp": 8}, "triggers": [], "modifiers": []},
	# Pending task 013's draw op.
	"backwards_cap": {"id": "backwards_cap", "name": "Backwards Cap", "owner": "general", "rarity": "common",
		"text": "Draw 2 extra cards on the first turn of each fight.", "stats": {},
		"triggers": [{"when": "first_turn", "target": "self", "effects": [{"op": "draw", "amount": 2}]}],
		"modifiers": []},
	"participation_trophy": {"id": "participation_trophy", "name": "Participation Trophy", "owner": "general",
		"rarity": "uncommon", "text": "If you end a fight below 50% HP, heal 8.", "stats": {},
		"triggers": [{"when": "fight_end", "target": "self", "hp_below_percent": 50,
			"effects": [{"op": "heal", "amount": 8}]}],
		"modifiers": []},
	"championship_ring": {"id": "championship_ring", "name": "Championship Ring", "owner": "general",
		"rarity": "rare", "text": "Attacks that cost 2 or more Hype deal 4 more damage.", "stats": {}, "triggers": [],
		"modifiers": [{"kind": "card_damage", "amount": 4, "card_type": "attack", "min_cost": 2}]},
	"medical_card": {"id": "medical_card", "name": "Medical Card", "owner": "general", "rarity": "uncommon",
		"text": "Prices at Baileys are 20% lower.", "stats": {}, "triggers": [],
		"modifiers": [{"kind": "shop_price_percent", "amount": 80}]},
	# I7 (accepted) wants its Hangover to last this fight only, with task 033's add_card "lasts":
	# "fight". This entry matches data/gear/beer_helmet.json on main (tests/data compares them), so it
	# gains "lasts" together with that file; test_fight_only_helmet in TEST_GEAR has it now.
	"beer_helmet": {"id": "beer_helmet", "name": "Beer Helmet", "owner": "boss", "rarity": "boss",
		"text": "+1 Hype per turn. Start each fight with a Hangover card in your draw pile.",
		"stats": {"hype_per_turn": 1},
		"triggers": [{"when": "fight_start", "target": "self",
			"effects": [{"op": "add_card", "card_id": "junk_hangover", "to": "draw_pile", "shuffle_in": true}]}],
		"modifiers": []},
	"dads_platinum_card": {"id": "dads_platinum_card", "name": "Dad's Platinum Card", "owner": "boss",
		"rarity": "boss", "text": "+1 Hype per turn. You no longer earn Dolla Bills from fights.",
		"stats": {"hype_per_turn": 1}, "triggers": [],
		"modifiers": [{"kind": "fight_dolla_bills_percent", "amount": 0}]},
	"cursed_intramural_trophy": {"id": "cursed_intramural_trophy", "name": "Cursed Intramural Trophy",
		"owner": "boss", "rarity": "boss", "text": "+1 Draw per turn. Every enemy starts each fight with 1 Swole.",
		"stats": {"draw_per_turn": 1},
		"triggers": [{"when": "fight_start", "target": "all_enemies",
			"effects": [{"op": "gain_stat", "stat": "swole", "amount": 1}]}],
		"modifiers": []},
}

## The eight GDD Brews, by id, as task 014 must write them.
const BREWS := {
	"light_beer": {"id": "light_beer", "name": "Light Beer", "rarity": "common", "text": "Heal 10 HP.",
		"target": "self", "effects": [{"op": "heal", "amount": 10}]},
	# Pending task 013's draw op.
	"energy_drink": {"id": "energy_drink", "name": "Energy Drink", "rarity": "common", "text": "Draw 3 cards.",
		"target": "self", "effects": [{"op": "draw", "amount": 3}]},
	"protein_shake": {"id": "protein_shake", "name": "Protein Shake", "rarity": "common",
		"text": "Gain 3 Swole for this fight.", "target": "self",
		"effects": [{"op": "gain_stat", "stat": "swole", "amount": 3, "duration": "fight"}]},
	"shot_of_courage": {"id": "shot_of_courage", "name": "Shot of Courage", "rarity": "common",
		"text": "Apply 3 Exposed to all enemies.", "target": "all_enemies",
		"effects": [{"op": "apply_status", "status": "exposed", "stacks": 3}]},
	# Pending task 013's gain_hype and task 015's add_card.
	"special_brownie": {"id": "special_brownie", "name": "Special Brownie", "rarity": "uncommon",
		"text": "Gain 2 Hype. Add a Hangover card to your discard pile.", "target": "self",
		"effects": [{"op": "gain_hype", "amount": 2}, {"op": "add_card", "card_id": "junk_hangover", "to": "discard_pile"}]},
	"hair_of_the_dog": {"id": "hair_of_the_dog", "name": "Hair of the Dog", "rarity": "uncommon",
		"text": "Remove all your debuffs and Tap every Junk card in your hand.", "target": "self",
		"effects": [{"op": "remove_debuffs"}, {"op": "tap_cards", "card_type": "junk"}]},
	"party_bowl": {"id": "party_bowl", "name": "Party Bowl", "rarity": "uncommon", "text": "Every player heals 8 HP.",
		"target": "all_dudes", "effects": [{"op": "heal", "amount": 8}]},
	# Co-op waking is not built (effects [] until an op exists); the solo rule is.
	"smelling_salts": {"id": "smelling_salts", "name": "Smelling Salts", "rarity": "rare",
		"text": "Wake a Passed Out teammate at 25% HP. Solo: the next time you would pass out this fight, stay at 1 HP instead.",
		"target": "ally", "effects": [],
		"solo": {"target": "self", "effects": [{"op": "prevent_pass_out", "hp": 1}]}},
}

## Items whose tests wait on ops from tasks 013 and 015 (listed in the task 021 log instead).
const PENDING: Array[String] = ["backwards_cap", "energy_drink", "special_brownie"]

## Test-only Gear for rules no slice Gear uses: a card_played trigger, and a trigger with an op the
## core lacks (skipped whole).
const TEST_GEAR := {
	"test_card_counter": {"id": "test_card_counter", "name": "Card Counter", "owner": "general", "rarity": "rare",
		"text": "After you play an Attack that costs 2 or more, apply 1 Exposed to its target.", "stats": {},
		"triggers": [{"when": "card_played", "target": "trigger_target", "card_type": "attack", "min_cost": 2,
			"effects": [{"op": "apply_status", "status": "exposed", "stacks": 1}]}],
		"modifiers": []},
	"test_broken_trigger": {"id": "test_broken_trigger", "name": "Broken Trigger", "owner": "general",
		"rarity": "common", "text": "Heal 5, then summon kegs, at the start of each fight.", "stats": {},
		"triggers": [{"when": "fight_start", "target": "self",
			"effects": [{"op": "heal", "amount": 5}, {"op": "summon_kegs", "amount": 1}]}],
		"modifiers": []},
	# Task 033: Beer Helmet as I7's accepted answer has it, with its Hangover lasting this fight only.
	"test_fight_only_helmet": {"id": "test_fight_only_helmet", "name": "Fight-Only Helmet", "owner": "boss",
		"rarity": "boss", "text": "+1 Hype per turn. Start each fight with a Hangover card in your draw pile.",
		"stats": {"hype_per_turn": 1},
		"triggers": [{"when": "fight_start", "target": "self",
			"effects": [{"op": "add_card", "card_id": "junk_hangover", "to": "draw_pile", "shuffle_in": true, "lasts": "fight"}]}],
		"modifiers": []},
}

## Test-only Brews: one with an op the core lacks, and three aimed at an enemy (a debuff, Ick, damage).
const TEST_BREWS := {
	"test_mystery_brew": {"id": "test_mystery_brew", "name": "Mystery Brew", "rarity": "common", "text": "Kegs.",
		"target": "self", "effects": [{"op": "summon_kegs", "amount": 1}]},
	"test_dart": {"id": "test_dart", "name": "Dart", "rarity": "common", "text": "Apply 1 Noodle Arms to an enemy.",
		"target": "enemy", "effects": [{"op": "apply_status", "status": "noodle_arms", "stacks": 1}]},
	"test_stink": {"id": "test_stink", "name": "Stink", "rarity": "common", "text": "Apply 2 Ick to an enemy.",
		"target": "enemy", "effects": [{"op": "apply_status", "status": "ick", "stacks": 2}]},
	"test_bomb": {"id": "test_bomb", "name": "Bomb", "rarity": "common", "text": "Deal 5 damage to an enemy.",
		"target": "enemy", "effects": [{"op": "damage", "amount": 5}]},
}

## Test-only cards: a 2-cost Skill that deals damage, for Championship Ring's "Attacks" filter, and a
## stand-in junk_hangover (no effects) for the add_card items, until task 008's real card merges.
const CARDS := {
	"junk_hangover": {"id": "junk_hangover", "name": "Hangover", "owner": "junk", "type": "junk",
		"rarity": "special", "cost": -1, "target": "none", "effects": [], "keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_heavy_skill": {"id": "neutral_test_heavy_skill", "name": "Heavy Skill", "owner": "neutral",
		"type": "skill", "rarity": "common", "cost": 2, "target": "enemy", "effects": [{"op": "damage", "amount": 6}],
		"keywords": [], "crunch": null, "upgrade": {}},
}


## Returns the item test ruleset: task 007's fixture content plus every Gear, Brew and card above,
## built with the real build() and the real constants file. Empty if the build fails.
static func ruleset() -> Dictionary:
	# files: repo path -> JSON text.
	var files: Dictionary = {"data/constants.json": FileAccess.get_file_as_string(Fixtures.CONSTANTS_FILE)}
	# gear: every Gear, by id.
	var gear: Dictionary = GEAR.duplicate(true)
	gear.merge(TEST_GEAR)
	gear.merge(Fixtures.GEAR)
	# brews: every Brew, by id.
	var brews: Dictionary = BREWS.duplicate(true)
	brews.merge(TEST_BREWS)
	# cards: every card, by id.
	var cards: Dictionary = Fixtures.CARDS.duplicate(true)
	cards.merge(CARDS)
	for kind: Array in [["cards", cards], ["enemies", Fixtures.ENEMIES], ["dudes", Fixtures.DUDES], ["gear", gear],
			["brews", brews]]:
		for id: String in kind[1]:
			files["data/%s/%s.json" % [kind[0], id]] = JSON.stringify(kind[1][id])
	return Ruleset.build(files)["ruleset"]


## Builds a run for these Dudes, gives p1 the Gear (in order, after the starting Gear) and fills
## p1's Brew slots, then starts a fight. Returns {"state": in turn 1's player phase, "events": the
## fight start's events}, or {"state": {}, "events": []} if a step fails.
## rules: the item ruleset. run_seed: the seed. gear_ids: Gear for p1. brew_ids: Brews for p1, slot
## order. enemy_ids: enemies, left to right. dude_ids: Dude ids by seat (default one test_dude).
static func fight(rules: Dictionary, run_seed: int, gear_ids: Array, brew_ids: Array, enemy_ids: Array,
		dude_ids: Array = ["test_dude"]) -> Dictionary:
	# party: build_run_state()'s result.
	var party: Dictionary = Party.build_run_state(rules, run_seed, dude_ids)
	if party["error"] != "":
		return {"state": {}, "events": []}
	# state: the run before the fight.
	var state: Dictionary = party["state"]
	for gear_id: String in gear_ids:
		GearTriggers.gain_in_place(rules, state["dudes"][0], gear_id, [])
	state["dudes"][0]["brew_slots"] = maxi(state["dudes"][0]["brew_slots"], brew_ids.size())
	state["dudes"][0]["brews"] = brew_ids.duplicate()
	# started: start_fight()'s result.
	var started: Dictionary = Fight.start_fight(rules, state, enemy_ids)
	if started["error"] != "":
		return {"state": {}, "events": []}
	return {"state": started["state"], "events": started["events"]}


## Returns a use_brew request.
## player_id: the sender. seq: its seq. slot: the Brew slot. target_id: the target or "".
static func drink(player_id: String, seq: int, slot: int, target_id: String = "") -> Dictionary:
	return Fixtures.request("use_brew", player_id, seq, {"slot": slot, "target_id": target_id})


## Returns the events of one type, in order.
## events: an event list. type: the event type wanted.
static func of_type(events: Array, type: String) -> Array:
	# found: the matching events.
	var found: Array = []
	for event: Dictionary in events:
		if event["type"] == type:
			found.append(event)
	return found
