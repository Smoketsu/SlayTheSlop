## Small in-memory content for the bot and simulation tests (task 022). Lane: tools (Agent B).
##
## Not a test file (no test_ prefix). The definitions are test-only and generic, so the recorded
## report in sim_expected_report.txt does not change when real cards, enemies or Dudes are tuned. They
## go through the real core/ruleset/ruleset.gd build() with the real data/constants.json. Numbers here
## are fixture values chosen for the tests, not game balance.
extends RefCounted

const Ruleset := preload("res://core/ruleset/ruleset.gd")

## The real constants file (tests may read files; the core may not).
const CONSTANTS_FILE := "res://data/constants.json"

## Test card definitions, by id. Shapes follow core/schema/card_def.gd. One of each target kind the
## bots handle: one enemy, all enemies, self, an ally (Assist), and a Bro Move aimed at an enemy.
const CARDS := {
	"neutral_sim_jab": {"id": "neutral_sim_jab", "name": "Sim Jab", "owner": "neutral", "type": "attack",
		"rarity": "starter", "cost": 1, "target": "enemy", "effects": [{"op": "damage", "amount": 6}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_sim_brace": {"id": "neutral_sim_brace", "name": "Sim Brace", "owner": "neutral", "type": "skill",
		"rarity": "starter", "cost": 1, "target": "self", "effects": [{"op": "guard", "amount": 5}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_sim_sweep": {"id": "neutral_sim_sweep", "name": "Sim Sweep", "owner": "neutral", "type": "attack",
		"rarity": "starter", "cost": 1, "target": "all_enemies", "effects": [{"op": "damage", "amount": 3}],
		"keywords": [], "crunch": null, "upgrade": {}},
	"neutral_sim_spot": {"id": "neutral_sim_spot", "name": "Sim Spot", "owner": "neutral", "type": "skill",
		"rarity": "starter", "cost": 0, "target": "ally", "effects": [{"op": "guard", "amount": 3}],
		"keywords": ["assist"], "crunch": null, "upgrade": {}},
	"neutral_sim_bro": {"id": "neutral_sim_bro", "name": "Sim Bro", "owner": "neutral", "type": "attack",
		"rarity": "starter", "cost": 0, "target": "enemy", "effects": [{"op": "damage", "amount": 10}],
		"keywords": [], "crunch": null, "upgrade": {}},
}

## Test enemy definitions, by id. Shapes follow core/schema/enemy_def.gd.
## sim_grunt: weak, mixes attacks and Guard. sim_brute: hits hard. sim_wall: cannot be beaten in a few
## turns and never attacks, for the "stalled" outcome.
const ENEMIES := {
	"sim_grunt": {"id": "sim_grunt", "name": "Sim Grunt", "floor": 1, "tier": "normal", "max_hp": 20, "arm_count": 2,
		"moves": [{"id": "poke", "weight": 2, "intent": "attack", "effects": [{"op": "damage", "amount": 6}]},
			{"id": "hunker", "weight": 1, "intent": "defend", "effects": [{"op": "guard", "amount": 4}]}]},
	"sim_brute": {"id": "sim_brute", "name": "Sim Brute", "floor": 1, "tier": "normal", "max_hp": 45, "arm_count": 2,
		"moves": [{"id": "smash", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 11}]}]},
	"sim_wall": {"id": "sim_wall", "name": "Sim Wall", "floor": 1, "tier": "normal", "max_hp": 500, "arm_count": 0,
		"moves": [{"id": "stand", "weight": 1, "intent": "defend", "effects": [{"op": "guard", "amount": 1}]}]},
}

## Test Dude definitions, by id. Shapes follow core/schema/dude_def.gd.
const DUDES := {
	"sim_dude": {"id": "sim_dude", "name": "Sim Dude", "title": "the Fixture", "max_hp": 40,
		"starter_deck": ["neutral_sim_jab", "neutral_sim_jab", "neutral_sim_jab", "neutral_sim_jab",
			"neutral_sim_brace", "neutral_sim_brace", "neutral_sim_brace",
			"neutral_sim_sweep", "neutral_sim_sweep", "neutral_sim_spot"],
		"starting_gear": [], "bro_move": "neutral_sim_bro"},
}

## Test encounter definitions, by id. Shapes follow core/schema/encounter_def.gd.
const ENCOUNTERS := {
	"sim_grunts": {"id": "sim_grunts", "floor": 1, "node": "brawl", "enemies": ["sim_grunt", "sim_grunt"]},
}


## Returns the test ruleset, built with the real build() and the real constants file, or {} when the
## build fails (the calling test's assertions then fail).
static func ruleset() -> Dictionary:
	# files: repo path -> JSON text, as tools/data_files.gd would give them.
	var files: Dictionary = {"data/constants.json": FileAccess.get_file_as_string(CONSTANTS_FILE)}
	for kind: Array in [["cards", CARDS], ["enemies", ENEMIES], ["dudes", DUDES], ["encounters", ENCOUNTERS]]:
		for id: String in kind[1]:
			files["data/%s/%s.json" % [kind[0], id]] = JSON.stringify(kind[1][id])
	# built: build()'s result.
	var built: Dictionary = Ruleset.build(files)
	if not built["ok"]:
		push_warning("sim_fixtures: %s" % str(built["errors"]))
	return built["ruleset"]
