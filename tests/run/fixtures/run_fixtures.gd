## The slice's content as fixtures, for the run flow tests (task 025). Lane: run (Agent A).
##
## Not a test file (no test_ prefix). Written before Agent B's data merged: tasks 006, 008, 010 and 014
## are on main now (#60), but Side Quests (task 016) and encounters are not, so this still builds a
## ruleset from in-memory copies written exactly in the merged formats, with the ids the data uses.
## Switching the run tests to data/ once 016 and the encounter data merge is a follow-up:
##   - Tom's 14 GDD cards and Chest Bump (TOM_CARDS, ids "tom_<name>"), "tom" (DUDES), from the GDD's
##     "Tom, the Enforcer" table. Only Arm Bar has an upgrade (G15).
##   - The six Junk cards from tests/core/combat/junk_fixtures.gd (task 015's reading of the GDD).
##   - The slice's 13 Gear and 8 Brews from tests/core/items/item_fixtures.gd (task 021's reading).
##   - Floor 1's enemies and Goblin King Chad from tests/core/enemies/enemy_fixtures.gd (tasks 017, 019).
##   - The five GDD Side Quests (SIDE_QUESTS) in core/schema/side_quest_def.gd format: what task 016
##     must write. Only the safe option's label is from the GDD; the dumb labels and prompts are
##     placeholders for the content lane.
##   - Floor 1's encounters from G19 (ENCOUNTERS) in core/schema/encounter_def.gd format.
## Everything goes through the real core/ruleset/ruleset.gd build() with the real data/constants.json,
## so it passes the shared schemas. When B's data merges, the tests should switch to it (task file).
extends RefCounted

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const JsonValues := preload("res://core/schema/json_values.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")
const JunkFixtures := preload("res://tests/core/combat/junk_fixtures.gd")
const ItemFixtures := preload("res://tests/core/items/item_fixtures.gd")
const EnemyFixtures := preload("res://tests/core/enemies/enemy_fixtures.gd")

## Tom's 14 GDD cards and his Bro Move, by id, with the GDD's numbers and text (core/ops/README.md
## "Tom's cards, written with these ops"). Chest Bump's rarity is "special" (G17).
const TOM_CARDS := {
	"tom_punch": {"id": "tom_punch", "name": "Punch", "owner": "tom", "type": "attack", "rarity": "starter",
		"cost": 1, "target": "enemy", "effects": [{"op": "damage", "amount": 6}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 6 damage"},
	"tom_flex": {"id": "tom_flex", "name": "Flex", "owner": "tom", "type": "skill", "rarity": "starter",
		"cost": 1, "target": "self", "effects": [{"op": "guard", "amount": 5}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Gain 5 Guard"},
	"tom_arm_bar": {"id": "tom_arm_bar", "name": "Arm Bar", "owner": "tom", "type": "attack", "rarity": "starter",
		"cost": 2, "target": "enemy",
		"effects": [{"op": "damage", "amount": 8, "hits": 1}, {"op": "apply_status", "status": "broken_arm", "stacks": 1}],
		"keywords": [], "crunch": null, "upgrade": {"effects[0].amount": 11}, "text": "Deal 8 damage. Break 1 arm"},
	"tom_well_actually": {"id": "tom_well_actually", "name": "Well, Actually", "owner": "tom", "type": "skill",
		"rarity": "starter", "cost": 0, "target": "enemy", "effects": [{"op": "apply_status", "status": "ick", "stacks": 2}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Apply 2 Ick"},
	"tom_wrist_lock": {"id": "tom_wrist_lock", "name": "Wrist Lock", "owner": "tom", "type": "attack",
		"rarity": "common", "cost": 1, "target": "enemy",
		"effects": [{"op": "damage", "amount": 5}, {"op": "draw", "amount": 1, "if": "target_has_broken_arm"}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 5 damage. If the target has a Broken Arm, draw 1 card"},
	"tom_chrome_dome": {"id": "tom_chrome_dome", "name": "Chrome Dome", "owner": "tom", "type": "skill",
		"rarity": "common", "cost": 1, "target": "self",
		"effects": [{"op": "guard", "amount": 7}, {"op": "thorns", "amount": 3}],
		"keywords": [], "crunch": null, "upgrade": {},
		"text": "Gain 7 Guard. This turn, enemies that hit Tom take 3 damage from the glare"},
	"tom_skull_bash": {"id": "tom_skull_bash", "name": "Skull Bash", "owner": "tom", "type": "attack",
		"rarity": "common", "cost": 1, "target": "enemy",
		"effects": [{"op": "damage", "amount": 10}, {"op": "self_damage", "amount": 2}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 10 damage. Tom takes 2 damage"},
	"tom_unsolicited_advice": {"id": "tom_unsolicited_advice", "name": "Unsolicited Advice", "owner": "tom",
		"type": "skill", "rarity": "common", "cost": 1, "target": "enemy",
		"effects": [{"op": "apply_status", "status": "ick", "stacks": 3}, {"op": "apply_status", "status": "noodle_arms", "stacks": 1}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Apply 3 Ick and 1 Noodle Arms"},
	"tom_cast_party": {"id": "tom_cast_party", "name": "Cast Party", "owner": "tom", "type": "skill",
		"rarity": "uncommon", "cost": 1, "target": "self", "effects": [{"op": "guard_per_broken_arm", "amount": 4}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Gain 4 Guard for every Broken Arm on all enemies"},
	"tom_snap_city": {"id": "tom_snap_city", "name": "Snap City", "owner": "tom", "type": "attack",
		"rarity": "uncommon", "cost": 2, "target": "enemy",
		"effects": [{"op": "damage", "amount": 14}, {"op": "apply_status", "status": "broken_arm", "stacks": 1},
			{"op": "gain_hype", "amount": 1, "if": "target_now_armless"}],
		"keywords": [], "crunch": null, "upgrade": {},
		"text": "Deal 14 damage. Break 1 arm. If the target is now Armless, gain 1 Hype"},
	"tom_pickup_line": {"id": "tom_pickup_line", "name": "Pickup Line", "owner": "tom", "type": "skill",
		"rarity": "uncommon", "cost": 1, "target": "all_enemies",
		"effects": [{"op": "apply_status", "status": "ick", "stacks": 4}, {"op": "self_damage", "amount": 3}],
		"keywords": [], "crunch": null, "upgrade": {},
		"text": "Apply 4 Ick to all enemies. Tom takes 3 damage from the response"},
	"tom_reply_guy": {"id": "tom_reply_guy", "name": "Reply Guy", "owner": "tom", "type": "power",
		"rarity": "uncommon", "cost": 1, "target": "none", "effects": [],
		"power_triggers": [{"when": "enemy_buffed", "target": "subject",
			"effects": [{"op": "apply_status", "status": "ick", "stacks": 2}]}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Whenever an enemy gains a buff, apply 2 Ick to it"},
	"tom_double_arm_day": {"id": "tom_double_arm_day", "name": "Double Arm Day", "owner": "tom", "type": "attack",
		"rarity": "rare", "cost": 3, "target": "enemy",
		"effects": [{"op": "damage", "amount": 9}, {"op": "apply_status", "status": "broken_arm", "stacks": 1},
			{"op": "damage", "amount": 9}, {"op": "apply_status", "status": "broken_arm", "stacks": 1}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 9 damage twice. Each hit breaks 1 arm"},
	"tom_friend_zone": {"id": "tom_friend_zone", "name": "Friend Zone", "owner": "tom", "type": "power",
		"rarity": "rare", "cost": 2, "target": "none", "effects": [],
		"power_triggers": [
			{"when": "turn_start", "target": "all_enemies", "effects": [{"op": "apply_status", "status": "ick", "stacks": 1}]},
			{"when": "enemy_grossed_out", "target": "subject", "effects": [{"op": "apply_status", "status": "exposed", "stacks": 2}]}],
		"keywords": [], "crunch": null, "upgrade": {},
		"text": "At the start of each turn, apply 1 Ick to all enemies. Grossed Out enemies also become Exposed for 2 turns"},
	"tom_chest_bump": {"id": "tom_chest_bump", "name": "Chest Bump", "owner": "tom", "type": "attack",
		"rarity": "special", "cost": 0, "target": "enemy",
		"effects": [{"op": "damage", "amount": 20}, {"op": "apply_status", "status": "broken_arm", "stacks": 1, "target": "all_enemies"}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 20 damage. Break 1 arm on every enemy"},
}

## Tom (GDD "Tom, the Enforcer"): 80 HP; 4 Punch, 4 Flex, 1 Arm Bar, 1 Well, Actually; starting Gear
## Unused Gym Membership; Bro Move Chest Bump.
const DUDES := {
	"tom": {"id": "tom", "name": "Tom", "title": "the Enforcer", "max_hp": 80,
		"starter_deck": ["tom_punch", "tom_punch", "tom_punch", "tom_punch", "tom_flex", "tom_flex", "tom_flex",
			"tom_flex", "tom_arm_bar", "tom_well_actually"],
		"starting_gear": ["tom_unused_gym_membership"], "bro_move": "tom_chest_bump"},
}

## The five GDD Side Quests ("Example Side Quests"), by id, as task 016 must write them. Numbers and the
## safe labels are the GDD's; prompts and dumb labels are placeholders. G23: the bet needs 50 Dolla
## Bills. "Hungover for 3 turns" is 3 stacks (G1: 1 stack wears off per turn).
const SIDE_QUESTS := {
	"beer_pong_table": {"id": "beer_pong_table", "name": "The Beer Pong Table",
		"text": "A beer pong table, a stranger, and a bet nobody asked for.",
		"safe": {"label": "Walk away", "text": "Nothing happens.", "effects": []},
		"dumb": {"label": "Bet 50 Dolla Bills", "min_dolla_bills": 50,
			"text": "50% to double them, 50% to lose them and gain a Hangover card.",
			"effects": [{"op": "chance", "percent": 50, "then": [{"op": "dolla_bills", "amount": 50}],
				"else": [{"op": "dolla_bills", "amount": -50}, {"op": "add_card", "card_id": "junk_hangover"}]}]}},
	"gas_station_sushi": {"id": "gas_station_sushi", "name": "Gas-Station Sushi",
		"text": "It has been in the case since Tuesday. Of which year, unclear.",
		"safe": {"label": "Skip it", "text": "Nothing happens.", "effects": []},
		"dumb": {"label": "Eat it", "text": "Heal 25 HP; 35% chance to start the next fight with Hungover for 3 turns.",
			"effects": [{"op": "heal", "amount": 25},
				{"op": "chance", "percent": 35, "then": [{"op": "next_fight_status", "status": "hungover", "stacks": 3}]}]}},
	"three_am_tattoo": {"id": "three_am_tattoo", "name": "3 a.m. Tattoo",
		"text": "The parlor is open. The artist is awake. Mostly.",
		"safe": {"label": "Go to bed", "text": "Nothing happens.", "effects": []},
		"dumb": {"label": "Get the tattoo", "text": "Gain a random Gear and a permanent Regret card.",
			"effects": [{"op": "random_gear"}, {"op": "add_card", "card_id": "junk_regret"}]}},
	"free_couch_on_the_curb": {"id": "free_couch_on_the_curb", "name": "Free Couch on the Curb",
		"text": "A couch on the curb with a FREE sign. It looks comfortable. It looks back.",
		"safe": {"label": "Leave it", "text": "Nothing happens.", "effects": []},
		"dumb": {"label": "Take a nap on it", "text": "Full heal; 30% chance to add Bedbugs, a junk card that deals 1 damage when drawn.",
			"effects": [{"op": "full_heal"}, {"op": "chance", "percent": 30, "then": [{"op": "add_card", "card_id": "junk_bedbugs"}]}]}},
	"unlabeled_brownie": {"id": "unlabeled_brownie", "name": "The Unlabeled Brownie",
		"text": "A brownie on a paper plate. No label. No owner. No questions.",
		"safe": {"label": "Politely decline", "text": "Nothing happens.", "effects": []},
		"dumb": {"label": "Eat it", "text": "Upgrade 2 random cards, and start the next fight with 2 Foggy.",
			"effects": [{"op": "upgrade_random_cards", "count": 2}, {"op": "next_fight_status", "status": "foggy", "stacks": 2}]}},
}

## Floor 1's encounters (G19), by id. "early" marks the groups made only of Pledges, a Bouncer or an
## Intern, which the first EARLY_BRAWL_COUNT Brawls draw from (Pledge + Intern is read as early too, gap G61;
## the content lane confirms).
const ENCOUNTERS := {
	"basement_goblin_pledges": {"id": "basement_goblin_pledges", "floor": 1, "node": "brawl", "early": true,
		"enemies": ["goblin_pledge", "goblin_pledge"]},
	"basement_goblin_bouncer": {"id": "basement_goblin_bouncer", "floor": 1, "node": "brawl", "early": true,
		"enemies": ["goblin_bouncer"]},
	"basement_keg_slime": {"id": "basement_keg_slime", "floor": 1, "node": "brawl", "enemies": ["keg_slime"]},
	"basement_dorm_rats": {"id": "basement_dorm_rats", "floor": 1, "node": "brawl",
		"enemies": ["dorm_rat", "dorm_rat", "dorm_rat"]},
	"basement_skeleton_intern": {"id": "basement_skeleton_intern", "floor": 1, "node": "brawl", "early": true,
		"enemies": ["skeleton_intern"]},
	"basement_boo_zer": {"id": "basement_boo_zer", "floor": 1, "node": "brawl", "enemies": ["boo_zer"]},
	"basement_kobold_ra": {"id": "basement_kobold_ra", "floor": 1, "node": "brawl", "enemies": ["kobold_ra"]},
	"basement_pledge_and_intern": {"id": "basement_pledge_and_intern", "floor": 1, "node": "brawl", "early": true,
		"enemies": ["goblin_pledge", "skeleton_intern"]},
	"basement_goblin_shot_caller": {"id": "basement_goblin_shot_caller", "floor": 1, "node": "rival",
		"enemies": ["goblin_shot_caller"]},
	"basement_hall_monitor_golem": {"id": "basement_hall_monitor_golem", "floor": 1, "node": "rival",
		"enemies": ["hall_monitor_golem"]},
	"basement_sewer_gator": {"id": "basement_sewer_gator", "floor": 1, "node": "rival", "enemies": ["sewer_gator"]},
	"basement_goblin_king_chad": {"id": "basement_goblin_king_chad", "floor": 1, "node": "boss",
		"enemies": ["goblin_king_chad"]},
	"basement_mimic_cooler": {"id": "basement_mimic_cooler", "floor": 1, "node": "loot", "enemies": ["mimic_cooler"]},
}


## Returns the content files (repo path -> JSON text) of the slice fixtures, with optional changes.
## constants: constant name -> value to put in data/constants.json instead of its own (or added).
## dude_changes: Tom's definition fields to change (for example {"max_hp": 400}).
## extra: more repo path -> definition Dictionary entries, added or replacing (null removes a file).
static func files(constants: Dictionary = {}, dude_changes: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	# parsed: the real constants file, parsed.
	var parsed: Dictionary = JsonValues.parse(FileAccess.get_file_as_string(Fixtures.CONSTANTS_FILE))["value"]
	for name: String in constants:
		parsed[name] = {"value": constants[name], "unit": "test", "meaning": "test override"}
	# result: repo path -> text.
	var result: Dictionary = {"data/constants.json": JSON.stringify(parsed)}
	# dudes: Tom with the changes.
	var dudes: Dictionary = DUDES.duplicate(true)
	dudes["tom"].merge(dude_changes, true)
	# cards: Tom's cards, the Junk cards and the enemy fixtures' helper cards.
	var cards: Dictionary = TOM_CARDS.duplicate(true)
	cards.merge(JunkFixtures.JUNK)
	for kind: Array in [["cards", cards], ["dudes", dudes], ["enemies", EnemyFixtures.ENEMIES],
			["gear", ItemFixtures.GEAR], ["brews", ItemFixtures.BREWS], ["side_quests", SIDE_QUESTS],
			["encounters", ENCOUNTERS]]:
		for id: String in kind[1]:
			result["data/%s/%s.json" % [kind[0], id]] = JSON.stringify(kind[1][id])
	for path: String in extra:
		if extra[path] == null:
			result.erase(path)
		else:
			result[path] = JSON.stringify(extra[path])
	return result


## Returns the slice fixture ruleset (see files() for the arguments). Empty if the build fails.
## constants: constant overrides. dude_changes: Tom's field changes. extra: more or replaced files.
static func ruleset(constants: Dictionary = {}, dude_changes: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	return Ruleset.build(files(constants, dude_changes, extra))["ruleset"]
