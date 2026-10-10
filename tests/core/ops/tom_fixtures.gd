## Tom-like test content for task 013's tests. Lane: core (Agent A).
##
## Not a test file (no test_ prefix). Task 006 (Tom's real data files) has not merged, so these are
## in-memory copies of the GDD's 14 Tom cards and his Bro Move ("Tom, the Enforcer" and "Bro Meter"),
## with the GDD's numbers and wording, written with task 013's ops exactly as core/ops/README.md
## tells task 006 to write them. Ids are tom_test_<name> so they can never collide with task 006's
## real tom_<name> ids. Chest Bump's rarity is "rare" here only because the schema has no Bro Move
## rarity yet (G17). Once task 006 merges, the per-card tests should also run on the real files.
##
## The ruleset is built with the real core/ruleset/ruleset.gd build() and the real
## data/constants.json, plus every card, enemy and Dude from tests/core/combat/fixtures.gd.
extends RefCounted

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")

## Tom's GDD cards plus his Bro Move and two keyword test cards, by id. Shapes follow
## core/schema/card_def.gd; numbers and text are the GDD's.
const CARDS := {
	"tom_test_punch": {"id": "tom_test_punch", "name": "Punch", "owner": "tom", "type": "attack", "rarity": "starter",
		"cost": 1, "target": "enemy", "effects": [{"op": "damage", "amount": 6}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 6 damage"},
	"tom_test_flex": {"id": "tom_test_flex", "name": "Flex", "owner": "tom", "type": "skill", "rarity": "starter",
		"cost": 1, "target": "self", "effects": [{"op": "guard", "amount": 5}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Gain 5 Guard"},
	"tom_test_arm_bar": {"id": "tom_test_arm_bar", "name": "Arm Bar", "owner": "tom", "type": "attack", "rarity": "starter",
		"cost": 2, "target": "enemy",
		"effects": [{"op": "damage", "amount": 8, "hits": 1}, {"op": "apply_status", "status": "broken_arm", "stacks": 1}],
		"keywords": [], "crunch": null, "upgrade": {"effects[0].amount": 11}, "text": "Deal 8 damage. Break 1 arm"},
	"tom_test_well_actually": {"id": "tom_test_well_actually", "name": "Well, Actually", "owner": "tom", "type": "skill",
		"rarity": "starter", "cost": 0, "target": "enemy", "effects": [{"op": "apply_status", "status": "ick", "stacks": 2}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Apply 2 Ick"},
	"tom_test_wrist_lock": {"id": "tom_test_wrist_lock", "name": "Wrist Lock", "owner": "tom", "type": "attack",
		"rarity": "common", "cost": 1, "target": "enemy",
		"effects": [{"op": "damage", "amount": 5}, {"op": "draw", "amount": 1, "if": "target_has_broken_arm"}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 5 damage. If the target has a Broken Arm, draw 1 card"},
	"tom_test_chrome_dome": {"id": "tom_test_chrome_dome", "name": "Chrome Dome", "owner": "tom", "type": "skill",
		"rarity": "common", "cost": 1, "target": "self",
		"effects": [{"op": "guard", "amount": 7}, {"op": "thorns", "amount": 3}],
		"keywords": [], "crunch": null, "upgrade": {},
		"text": "Gain 7 Guard. This turn, enemies that hit Tom take 3 damage from the glare"},
	"tom_test_skull_bash": {"id": "tom_test_skull_bash", "name": "Skull Bash", "owner": "tom", "type": "attack",
		"rarity": "common", "cost": 1, "target": "enemy",
		"effects": [{"op": "damage", "amount": 10}, {"op": "self_damage", "amount": 2}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 10 damage. Tom takes 2 damage"},
	"tom_test_unsolicited_advice": {"id": "tom_test_unsolicited_advice", "name": "Unsolicited Advice", "owner": "tom",
		"type": "skill", "rarity": "common", "cost": 1, "target": "enemy",
		"effects": [{"op": "apply_status", "status": "ick", "stacks": 3}, {"op": "apply_status", "status": "noodle_arms", "stacks": 1}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Apply 3 Ick and 1 Noodle Arms"},
	"tom_test_cast_party": {"id": "tom_test_cast_party", "name": "Cast Party", "owner": "tom", "type": "skill",
		"rarity": "uncommon", "cost": 1, "target": "self", "effects": [{"op": "guard_per_broken_arm", "amount": 4}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Gain 4 Guard for every Broken Arm on all enemies"},
	"tom_test_snap_city": {"id": "tom_test_snap_city", "name": "Snap City", "owner": "tom", "type": "attack",
		"rarity": "uncommon", "cost": 2, "target": "enemy",
		"effects": [{"op": "damage", "amount": 14}, {"op": "apply_status", "status": "broken_arm", "stacks": 1},
			{"op": "gain_hype", "amount": 1, "if": "target_now_armless"}],
		"keywords": [], "crunch": null, "upgrade": {},
		"text": "Deal 14 damage. Break 1 arm. If the target is now Armless, gain 1 Hype"},
	"tom_test_pickup_line": {"id": "tom_test_pickup_line", "name": "Pickup Line", "owner": "tom", "type": "skill",
		"rarity": "uncommon", "cost": 1, "target": "all_enemies",
		"effects": [{"op": "apply_status", "status": "ick", "stacks": 4}, {"op": "self_damage", "amount": 3}],
		"keywords": [], "crunch": null, "upgrade": {},
		"text": "Apply 4 Ick to all enemies. Tom takes 3 damage from the response"},
	"tom_test_reply_guy": {"id": "tom_test_reply_guy", "name": "Reply Guy", "owner": "tom", "type": "power",
		"rarity": "uncommon", "cost": 1, "target": "none", "effects": [],
		"power_triggers": [{"when": "enemy_buffed", "target": "subject",
			"effects": [{"op": "apply_status", "status": "ick", "stacks": 2}]}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Whenever an enemy gains a buff, apply 2 Ick to it"},
	"tom_test_double_arm_day": {"id": "tom_test_double_arm_day", "name": "Double Arm Day", "owner": "tom", "type": "attack",
		"rarity": "rare", "cost": 3, "target": "enemy",
		"effects": [{"op": "damage", "amount": 9}, {"op": "apply_status", "status": "broken_arm", "stacks": 1},
			{"op": "damage", "amount": 9}, {"op": "apply_status", "status": "broken_arm", "stacks": 1}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 9 damage twice. Each hit breaks 1 arm"},
	"tom_test_friend_zone": {"id": "tom_test_friend_zone", "name": "Friend Zone", "owner": "tom", "type": "power",
		"rarity": "rare", "cost": 2, "target": "none", "effects": [],
		"power_triggers": [
			{"when": "turn_start", "target": "all_enemies", "effects": [{"op": "apply_status", "status": "ick", "stacks": 1}]},
			{"when": "enemy_grossed_out", "target": "subject", "effects": [{"op": "apply_status", "status": "exposed", "stacks": 2}]}],
		"keywords": [], "crunch": null, "upgrade": {},
		"text": "At the start of each turn, apply 1 Ick to all enemies. Grossed Out enemies also become Exposed for 2 turns"},
	"tom_test_chest_bump": {"id": "tom_test_chest_bump", "name": "Chest Bump", "owner": "tom", "type": "attack",
		"rarity": "rare", "cost": 0, "target": "enemy",
		"effects": [{"op": "damage", "amount": 20}, {"op": "apply_status", "status": "broken_arm", "stacks": 1, "target": "all_enemies"}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 20 damage. Break 1 arm on every enemy"},
	# Keyword test cards (not Tom's).
	"neutral_test_pocket_lint": {"id": "neutral_test_pocket_lint", "name": "Pocket Lint", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 1, "target": "self", "effects": [{"op": "guard", "amount": 1}],
		"keywords": ["pocketed"], "crunch": null, "upgrade": {}},
	"neutral_test_bad_power": {"id": "neutral_test_bad_power", "name": "Bad Power", "owner": "neutral", "type": "power",
		"rarity": "common", "cost": 0, "target": "none", "effects": [],
		"power_triggers": [{"when": "turn_start", "target": "self", "effects": [{"op": "summon_kegs"}]}],
		"keywords": [], "crunch": null, "upgrade": {}},
}

## The 14 GDD Tom cards above, in the GDD's table order (Chest Bump and the keyword cards excluded).
const TOM_CARD_IDS: Array[String] = ["tom_test_punch", "tom_test_flex", "tom_test_arm_bar", "tom_test_well_actually",
	"tom_test_wrist_lock", "tom_test_chrome_dome", "tom_test_skull_bash", "tom_test_unsolicited_advice",
	"tom_test_cast_party", "tom_test_snap_city", "tom_test_pickup_line", "tom_test_reply_guy",
	"tom_test_double_arm_day", "tom_test_friend_zone"]

## Tom-like Dudes, by id. "test_tom" is Tom's GDD attribute table (80 HP, 4 Punch, 4 Flex, Arm Bar,
## Well, Actually; Bro Move Chest Bump). "test_tom_all" holds one of each of his 14 cards, for the
## fixed-seed fight.
const DUDES := {
	"test_tom": {"id": "test_tom", "name": "Tom", "title": "the Enforcer", "max_hp": 80,
		"starter_deck": ["tom_test_punch", "tom_test_punch", "tom_test_punch", "tom_test_punch",
			"tom_test_flex", "tom_test_flex", "tom_test_flex", "tom_test_flex",
			"tom_test_arm_bar", "tom_test_well_actually"],
		"starting_gear": [], "bro_move": "tom_test_chest_bump"},
	"test_tom_all": {"id": "test_tom_all", "name": "Tom", "title": "the Whole Table", "max_hp": 80,
		"starter_deck": TOM_CARD_IDS, "starting_gear": [], "bro_move": "tom_test_chest_bump"},
}


## Returns the ruleset with Tom's test cards and Dudes added to tests/core/combat/fixtures.gd's (GEAR included, task 021)
## content. Empty if the build fails (the calling test's assertions then fail).
## extra_cards: task 031, more card definitions by id for one test file's own cards (for example a
## Power that feeds itself); empty (the default) adds none. Ids must not repeat CARDS' ids.
static func ruleset(extra_cards: Dictionary = {}) -> Dictionary:
	# files: repo path -> JSON text, as a content reader would give them.
	var files: Dictionary = {"data/constants.json": FileAccess.get_file_as_string(Fixtures.CONSTANTS_FILE)}
	for kind: Array in [["cards", Fixtures.CARDS], ["cards", CARDS], ["cards", extra_cards], ["enemies", Fixtures.ENEMIES],
			["dudes", Fixtures.DUDES], ["dudes", DUDES], ["gear", Fixtures.GEAR]]:
		for id: String in kind[1]:
			files["data/%s/%s.json" % [kind[0], id]] = JSON.stringify(kind[1][id])
	# built: build()'s result.
	var built: Dictionary = Ruleset.build(files)
	return built["ruleset"]
