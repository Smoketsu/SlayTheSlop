## Test content and helpers for the combat and ops tests (task 007). Lane: core (Agent A).
##
## Not a test file (no test_ prefix). The content is test-only and generic, so the tests do not
## depend on which real cards, enemies or Dudes have merged; it goes through the real
## core/ruleset/ruleset.gd build() with the real data/constants.json, so it passes the shared schemas.
## Numbers here are fixture values chosen for the tests, not game balance.
extends RefCounted

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const Party := preload("res://core/combat/party.gd")
const Fight := preload("res://core/combat/fight.gd")

## The real constants file, read by tests (tests may read files; the core may not).
const CONSTANTS_FILE := "res://data/constants.json"

## Test card definitions, by id. Shapes follow core/schema/card_def.gd.
const CARDS := {
	"neutral_test_jab": {"id": "neutral_test_jab", "name": "Jab", "owner": "neutral", "type": "attack",
		"rarity": "starter", "cost": 1, "target": "enemy", "effects": [{"op": "damage", "amount": 6, "hits": 1}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_brace": {"id": "neutral_test_brace", "name": "Brace", "owner": "neutral", "type": "skill",
		"rarity": "starter", "cost": 1, "target": "self", "effects": [{"op": "guard", "amount": 5}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_double": {"id": "neutral_test_double", "name": "Double", "owner": "neutral", "type": "attack",
		"rarity": "common", "cost": 2, "target": "enemy", "effects": [{"op": "damage", "amount": 4, "hits": 2}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_sweep": {"id": "neutral_test_sweep", "name": "Sweep", "owner": "neutral", "type": "attack",
		"rarity": "common", "cost": 1, "target": "all_enemies", "effects": [{"op": "damage", "amount": 3}],
		"keywords": ["tapped"], "crunch": null, "upgrade": {}},
	"neutral_test_freebie": {"id": "neutral_test_freebie", "name": "Freebie", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 0, "target": "none", "effects": [{"op": "guard", "amount": 2}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_bash": {"id": "neutral_test_bash", "name": "Bash", "owner": "neutral", "type": "attack",
		"rarity": "common", "cost": 1, "target": "enemy",
		"effects": [{"op": "damage", "amount": 3}, {"op": "guard", "amount": 3}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_big": {"id": "neutral_test_big", "name": "Big", "owner": "neutral", "type": "attack",
		"rarity": "rare", "cost": 4, "target": "enemy", "effects": [{"op": "damage", "amount": 99}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_x": {"id": "neutral_test_x", "name": "X", "owner": "neutral", "type": "attack",
		"rarity": "rare", "cost": "x", "target": "enemy", "effects": [{"op": "damage", "amount": 5}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_mystery": {"id": "neutral_test_mystery", "name": "Mystery", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 1, "target": "enemy", "effects": [{"op": "summon_kegs", "amount": 1}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_typo": {"id": "neutral_test_typo", "name": "Typo", "owner": "neutral", "type": "attack",
		"rarity": "common", "cost": 1, "target": "enemy", "effects": [{"op": "damage", "amout": 6}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_spot": {"id": "neutral_test_spot", "name": "Spot", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 1, "target": "ally", "effects": [{"op": "guard", "amount": 4}],
		"keywords": ["assist"], "crunch": null, "upgrade": {}},
	"neutral_test_lifted": {"id": "neutral_test_lifted", "name": "Lifted", "owner": "neutral", "type": "attack",
		"rarity": "common", "cost": 1, "target": "enemy", "effects": [{"op": "damage", "amount": 6}],
		"keywords": [], "crunch": null, "upgrade": {"effects[0].amount": 9}},
	"neutral_test_bro": {"id": "neutral_test_bro", "name": "Bro", "owner": "neutral", "type": "skill",
		"rarity": "starter", "cost": 0, "target": "self", "effects": [{"op": "guard", "amount": 1}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"junk_test_dud": {"id": "junk_test_dud", "name": "Dud", "owner": "junk", "type": "junk",
		"rarity": "starter", "cost": -1, "target": "none", "effects": [],
		"keywords": [], "crunch": null, "upgrade": {}},
	# Task 009 status cards (shaped like Tom's GDD cards, but test-only).
	"neutral_test_arm_bar": {"id": "neutral_test_arm_bar", "name": "Arm Bar", "owner": "neutral", "type": "attack",
		"rarity": "starter", "cost": 2, "target": "enemy",
		"effects": [{"op": "damage", "amount": 8, "hits": 1}, {"op": "apply_status", "status": "broken_arm", "stacks": 1}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_well_actually": {"id": "neutral_test_well_actually", "name": "Well, Actually", "owner": "neutral",
		"type": "skill", "rarity": "starter", "cost": 0, "target": "enemy",
		"effects": [{"op": "apply_status", "status": "ick", "stacks": 2}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_pickup": {"id": "neutral_test_pickup", "name": "Pickup", "owner": "neutral", "type": "skill",
		"rarity": "uncommon", "cost": 1, "target": "all_enemies",
		"effects": [{"op": "apply_status", "status": "ick", "stacks": 4}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_expose": {"id": "neutral_test_expose", "name": "Expose", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 1, "target": "enemy",
		"effects": [{"op": "apply_status", "status": "exposed", "stacks": 2}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_advice": {"id": "neutral_test_advice", "name": "Advice", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 1, "target": "enemy",
		"effects": [{"op": "apply_status", "status": "ick", "stacks": 3}, {"op": "apply_status", "status": "noodle_arms", "stacks": 1}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_snap_all": {"id": "neutral_test_snap_all", "name": "Snap All", "owner": "neutral", "type": "attack",
		"rarity": "rare", "cost": 0, "target": "enemy",
		"effects": [{"op": "apply_status", "status": "broken_arm", "stacks": 5}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_self_mess": {"id": "neutral_test_self_mess", "name": "Self Mess", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 0, "target": "self",
		"effects": [{"op": "apply_status", "status": "hungover", "stacks": 1}, {"op": "apply_status", "status": "foggy", "stacks": 1},
			{"op": "apply_status", "status": "ick", "stacks": 2}, {"op": "apply_status", "status": "broken_arm", "stacks": 1}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_skill_hit": {"id": "neutral_test_skill_hit", "name": "Skill Hit", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 1, "target": "enemy", "effects": [{"op": "damage", "amount": 6}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_test_poke": {"id": "neutral_test_poke", "name": "Poke", "owner": "neutral", "type": "attack",
		"rarity": "common", "cost": 0, "target": "enemy", "effects": [{"op": "damage", "amount": 5}],
		"keywords": [], "crunch": null, "upgrade": {}},
}

## Test enemy definitions, by id. Shapes follow core/schema/enemy_def.gd.
const ENEMIES := {
	"test_dummy": {"id": "test_dummy", "name": "Dummy", "floor": 1, "tier": "normal", "max_hp": 20, "arm_count": 2,
		"moves": [{"id": "swing", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 5, "hits": 1}]},
			{"id": "unused", "weight": 0, "intent": "defend", "effects": [{"op": "guard", "amount": 1}]}]},
	"test_turtle": {"id": "test_turtle", "name": "Turtle", "floor": 1, "tier": "normal", "max_hp": 14, "arm_count": 0,
		"moves": [{"id": "shell", "weight": 1, "intent": "defend", "effects": [{"op": "guard", "amount": 4}]}]},
	"test_pledge": {"id": "test_pledge", "name": "Pledge", "floor": 1, "tier": "normal", "max_hp": 12, "arm_count": 2,
		"moves": [{"id": "hit", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 5}]}]},
	"test_rival": {"id": "test_rival", "name": "Rival", "floor": 1, "tier": "rival", "max_hp": 60, "arm_count": 2,
		"moves": [{"id": "slam", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 12}]}]},
	"test_boss": {"id": "test_boss", "name": "Boss", "floor": 1, "tier": "boss", "max_hp": 100, "arm_count": 2,
		"moves": [{"id": "stomp", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 1}]}]},
	"test_brute": {"id": "test_brute", "name": "Brute", "floor": 1, "tier": "normal", "max_hp": 40, "arm_count": 2,
		"moves": [{"id": "smash", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 50}]}]},
	"test_flurry": {"id": "test_flurry", "name": "Flurry", "floor": 1, "tier": "normal", "max_hp": 30, "arm_count": 2,
		"moves": [{"id": "flurry", "weight": 1, "intent": "attack",
			"effects": [{"op": "damage", "amount": 2, "hits": 3}, {"op": "guard", "amount": 3}, {"op": "warp", "amount": 1}]}]},
	# Task 009 enemies.
	# Scripted to punch every turn (task 011 "pattern"), so task 009's tests do not depend on random
	# move choice; "pose" stays available for tests that set the intent by hand.
	"test_hitter": {"id": "test_hitter", "name": "Hitter", "floor": 1, "tier": "normal", "max_hp": 60, "arm_count": 2,
		"pattern": ["punch"],
		"moves": [{"id": "punch", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 10}]},
			{"id": "pose", "weight": 1, "intent": "defend", "effects": [{"op": "guard", "amount": 2}]}]},
	"test_hexer": {"id": "test_hexer", "name": "Hexer", "floor": 1, "tier": "normal", "max_hp": 20, "arm_count": 2,
		"moves": [{"id": "hex", "weight": 1, "intent": "debuff", "effects": [
			{"op": "apply_status", "status": "exposed", "stacks": 2}, {"op": "apply_status", "status": "foggy", "stacks": 1},
			{"op": "apply_status", "status": "hungover", "stacks": 1}, {"op": "apply_status", "status": "noodle_arms", "stacks": 1},
			{"op": "apply_status", "status": "broken_arm", "stacks": 1}, {"op": "apply_status", "status": "ick", "stacks": 1},
			{"op": "damage", "amount": 4}]}]},
	"test_slime": {"id": "test_slime", "name": "Slime", "floor": 1, "tier": "normal", "max_hp": 24, "arm_count": 0,
		"moves": [{"id": "slosh", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 7}]}]},
}

## Test Dude definitions, by id. Shapes follow core/schema/dude_def.gd.
const DUDES := {
	"test_dude": {"id": "test_dude", "name": "Tester", "title": "the Fixture", "max_hp": 30,
		"starter_deck": ["neutral_test_jab", "neutral_test_jab", "neutral_test_jab", "neutral_test_jab",
			"neutral_test_brace", "neutral_test_brace", "neutral_test_brace",
			"neutral_test_double", "neutral_test_sweep", "neutral_test_freebie"],
		"starting_gear": ["test_gear"], "bro_move": "neutral_test_bro"},
	"test_tiny": {"id": "test_tiny", "name": "Tiny", "title": "the Small Deck", "max_hp": 10,
		"starter_deck": ["neutral_test_jab", "neutral_test_brace", "neutral_test_jab"],
		"starting_gear": [], "bro_move": "neutral_test_bro"},
	# Task 009: a Tom-like deck of status cards for the fixed-seed status fight.
	"test_breaker": {"id": "test_breaker", "name": "Breaker", "title": "the Status Fixture", "max_hp": 80,
		"starter_deck": ["neutral_test_arm_bar", "neutral_test_arm_bar", "neutral_test_well_actually",
			"neutral_test_well_actually", "neutral_test_jab", "neutral_test_jab", "neutral_test_jab",
			"neutral_test_brace", "neutral_test_brace", "neutral_test_advice"],
		"starting_gear": [], "bro_move": "neutral_test_bro"},
}


## Test Gear definitions, by id (task 021). Shapes follow core/schema/gear_def.gd. test_gear is
## test_dude's starting Gear and does nothing, so the fights here are not changed by Gear.
const GEAR := {
	"test_gear": {"id": "test_gear", "name": "Test Gear", "owner": "general", "rarity": "starter",
		"text": "Does nothing.", "stats": {}, "triggers": [], "modifiers": []},
}


## Returns the test ruleset, built with the real build() and the real constants file. Empty if the
## build fails (the calling test's assertions then fail).
static func ruleset() -> Dictionary:
	# files: repo path -> JSON text, as a content reader would give them.
	var files: Dictionary = {"data/constants.json": FileAccess.get_file_as_string(CONSTANTS_FILE)}
	for kind: Array in [["cards", CARDS], ["enemies", ENEMIES], ["dudes", DUDES], ["gear", GEAR]]:
		for id: String in kind[1]:
			files["data/%s/%s.json" % [kind[0], id]] = JSON.stringify(kind[1][id])
	# built: build()'s result.
	var built: Dictionary = Ruleset.build(files)
	return built["ruleset"]


## Returns a run state for these Dudes with a fight against these enemies, in turn 1's player
## phase, or {} if either step reports an error.
## rules: the ruleset. run_seed: the run seed. dude_ids: Dude ids by seat. enemy_ids: enemy ids, left to right.
static func fight(rules: Dictionary, run_seed: int, dude_ids: Array, enemy_ids: Array) -> Dictionary:
	# party: build_run_state()'s result.
	var party: Dictionary = Party.build_run_state(rules, run_seed, dude_ids)
	if party["error"] != "":
		return {}
	# started: start_fight()'s result.
	var started: Dictionary = Fight.start_fight(rules, party["state"], enemy_ids)
	return started["state"] if started["error"] == "" else {}


## Puts a new copy of a card into a Dude's hand (test setup only; the core never does this) and
## returns its card_uid. Uses and raises next_uid.
## state: a run state, changed here. player_index: the Dude's seat, 0-based. def_id: a card id.
static func give(state: Dictionary, player_index: int, def_id: String) -> String:
	# uid: the new copy's card_uid.
	var uid: String = "c%d" % state["next_uid"]
	state["next_uid"] += 1
	state["dudes"][player_index]["cards"][uid] = {"def_id": def_id, "upgraded": false}
	state["dudes"][player_index]["hand"].append(uid)
	return uid


## Returns a request Dictionary with the common fields filled in.
## type: the request type. player_id: the sender. seq: its seq. fields: the type's own fields.
static func request(type: String, player_id: String, seq: int, fields: Dictionary = {}) -> Dictionary:
	# out: the result.
	var out: Dictionary = fields.duplicate()
	out["type"] = type
	out["player_id"] = player_id
	out["seq"] = seq
	return out


## Returns a play_card request.
## player_id: the sender. seq: its seq. card_uid: the card in hand. target_id: the target or "".
static func play(player_id: String, seq: int, card_uid: String, target_id: String) -> Dictionary:
	return request("play_card", player_id, seq, {"card_uid": card_uid, "target_id": target_id, "crunch": false})


## Returns a set_ready request.
## player_id: the sender. seq: its seq. ready: the flag.
static func set_ready(player_id: String, seq: int, ready: bool = true) -> Dictionary:
	return request("set_ready", player_id, seq, {"ready": ready})
