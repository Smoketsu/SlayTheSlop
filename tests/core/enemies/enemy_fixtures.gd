## Floor 1 enemy definitions and helpers for the enemy behavior tests (task 017). Lane: core (Agent A).
##
## Not a test file (no test_ prefix). Agent B's real enemy data (task 010) has not merged, so these
## are FIXTURES shaped exactly as core/schema/enemy_def.gd says, with the ids the GDD's names give
## (goblin_pledge, keg_slime ...) and the GDD's HP, arms and numbers, so the content lane can copy
## the fields and ops. Where the GDD does not give a number or a move (Foam Slime's attack, Goblin
## Shot-Caller's ordinary turn, which turn a cycle starts on), the value here is a placeholder for the
## tests, marked "placeholder", and not a design decision. docs/tasks/017-floor1-enemy-behaviors.md
## lists what task 010's data must match.
##
## The definitions go through the real core/ruleset/ruleset.gd build() with the real
## data/constants.json, together with task 007's test cards and Dudes (tests/core/combat/fixtures.gd).
extends RefCounted

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")

## Floor 1 enemies (GDD "Floor 1: The Basement"), by id, plus Foam Slime. Shapes follow core/schema/enemy_def.gd.
const ENEMIES := {
	# "Hits for 5. If it is the last goblin standing, calls one more Goblin Pledge."
	"goblin_pledge": {"id": "goblin_pledge", "name": "Goblin Pledge", "floor": 1, "tier": "normal",
		"max_hp": 12, "arm_count": 2, "tags": ["goblin"],
		"move_rules": [{"move_id": "call_for_help", "when": [{"if": "last_of_tag", "tag": "goblin"}]}],
		"moves": [{"id": "hit", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 5}]},
			{"id": "call_for_help", "weight": 0, "intent": "summon",
				"effects": [{"op": "summon_enemy", "enemy_id": "goblin_pledge", "count": 1}]}]},
	# "Alternates 8 Guard with a 9-damage hit. Checks ID: applies 1 Noodle Arms." Checks ID is read
	# here as the hit (placeholder reading; the content lane decides).
	"goblin_bouncer": {"id": "goblin_bouncer", "name": "Goblin Bouncer", "floor": 1, "tier": "normal",
		"max_hp": 28, "arm_count": 2, "tags": ["goblin"], "pattern": ["bounce", "checks_id"],
		"moves": [{"id": "bounce", "weight": 0, "intent": "defend", "target": "none", "effects": [{"op": "guard", "amount": 8}]},
			{"id": "checks_id", "weight": 0, "intent": "attack", "target": "dude",
				"effects": [{"op": "damage", "amount": 9}, {"op": "apply_status", "status": "noodle_arms", "stacks": 1}]}]},
	# "Hits for 7. At half HP, splits into two Foam Slimes with 10 HP each."
	"keg_slime": {"id": "keg_slime", "name": "Keg Slime", "floor": 1, "tier": "normal", "max_hp": 24, "arm_count": 0,
		"split": {"into": "foam_slime", "count": 2, "at_hp_percent": 50},
		"moves": [{"id": "slosh", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 7}]}]},
	# Keg Slime's halves: 10 HP (GDD). The GDD gives no attack: 3 damage is a placeholder.
	"foam_slime": {"id": "foam_slime", "name": "Foam Slime", "floor": 1, "tier": "normal", "max_hp": 10, "arm_count": 0,
		"moves": [{"id": "fizz", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 3}]}]},
	# One rat of the pack of 3: "Each bite deals 3 and steals 5 Dolla Bills. They flee on turn 4;
	# kill them to get the Dolla Bills back."
	"dorm_rat": {"id": "dorm_rat", "name": "Dorm Rat", "floor": 1, "tier": "normal", "max_hp": 8, "arm_count": 2,
		"move_rules": [{"move_id": "scurry_off", "when": [{"if": "turn_at_least", "turn": 4}]}],
		"moves": [{"id": "bite", "weight": 1, "intent": "attack",
				"effects": [{"op": "damage", "amount": 3}, {"op": "steal_dolla_bills", "amount": 5}]},
			{"id": "scurry_off", "weight": 0, "intent": "flee", "effects": [{"op": "flee"}]}]},
	# "Hits for 6. Every other turn, shuffles Paperwork into the target's deck." The Paperwork move
	# uses task 015's add_card op; until 015 merges that effect is skipped (an unknown op).
	"skeleton_intern": {"id": "skeleton_intern", "name": "Skeleton Intern", "floor": 1, "tier": "normal",
		"max_hp": 18, "arm_count": 2, "pattern": ["hit", "file_paperwork"],
		"moves": [{"id": "hit", "weight": 0, "intent": "attack", "effects": [{"op": "damage", "amount": 6}]},
			{"id": "file_paperwork", "weight": 0, "intent": "attack", "target": "dude",
				"effects": [{"op": "damage", "amount": 6},
					{"op": "add_card", "card_id": "junk_paperwork", "to": "draw_pile", "shuffle_in": true}]}]},
	# "A ghost. Every other turn it is Faded and takes at most 1 damage per hit. Hits for 8."
	# Faded on turns 1, 3, 5 ... (which turn starts the cycle is a placeholder).
	"boo_zer": {"id": "boo_zer", "name": "Boo-zer", "floor": 1, "tier": "normal", "max_hp": 16, "arm_count": 0,
		"periodic_statuses": [{"status": "faded", "every": 2, "first_turn": 1}],
		"moves": [{"id": "boo", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 8}]}]},
	# "Disguised as a Loot node. Bites for 12. Always drops a Brew."
	"mimic_cooler": {"id": "mimic_cooler", "name": "Mimic Cooler", "floor": 1, "tier": "normal", "max_hp": 30,
		"arm_count": 0, "drops_brews": 1,
		"moves": [{"id": "chomp", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 12}]}]},
	# "Noise Complaint: a player who plays 5 or more cards in a turn takes 5 damage. Hits for 6."
	"kobold_ra": {"id": "kobold_ra", "name": "Kobold RA", "floor": 1, "tier": "normal", "max_hp": 22, "arm_count": 2,
		"triggers": [{"id": "noise_complaint", "on": "cards_played", "cards": 5, "repeat": false,
			"effects": [{"op": "damage", "amount": 5}]}],
		"moves": [{"id": "write_up", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 6}]}]},
	# Rival. "Arrives with 2 Goblin Pledges. Every other turn gives all goblins 2 Swole or replaces a
	# dead Pledge." The GDD gives no ordinary move: the 10-damage "whip" is a placeholder. Read here:
	# on turns 2, 4, 6 ... it replaces a dead Pledge if fewer than 2 are standing, otherwise gives Swole.
	"goblin_shot_caller": {"id": "goblin_shot_caller", "name": "Goblin Shot-Caller", "floor": 1, "tier": "rival",
		"max_hp": 60, "arm_count": 2, "tags": ["goblin"], "arrives_with": ["goblin_pledge", "goblin_pledge"],
		"move_rules": [
			{"move_id": "next_pledge", "when": [{"if": "turn_cycle", "every": 2, "first_turn": 2},
				{"if": "count_below", "def_id": "goblin_pledge", "count": 2}]},
			{"move_id": "pregame", "when": [{"if": "turn_cycle", "every": 2, "first_turn": 2}]}],
		"moves": [{"id": "whip", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 10}]},
			{"id": "next_pledge", "weight": 0, "intent": "summon",
				"effects": [{"op": "summon_enemy", "enemy_id": "goblin_pledge", "count": 1}]},
			{"id": "pregame", "weight": 0, "intent": "buff", "effects": [{"op": "gain_swole", "amount": 2, "tag": "goblin"}]}]},
	# Rival. "Every third card a player plays in a turn adds Detention to their discard pile. Hits for
	# 14." Detention uses task 015's add_card op; until 015 merges that effect is skipped.
	"hall_monitor_golem": {"id": "hall_monitor_golem", "name": "Hall Monitor Golem", "floor": 1, "tier": "rival",
		"max_hp": 75, "arm_count": 2,
		"triggers": [{"id": "detention", "on": "cards_played", "cards": 3, "repeat": true,
			"effects": [{"op": "add_card", "card_id": "junk_detention", "to": "discard_pile"}]}],
		"moves": [{"id": "stomp", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 14}]}]},
	# Rival. "Death Roll: 5 damage 3 times. Gains 2 Swole whenever it deals unblocked damage."
	"sewer_gator": {"id": "sewer_gator", "name": "Sewer Gator in a Letterman Jacket", "floor": 1, "tier": "rival",
		"max_hp": 68, "arm_count": 2,
		"triggers": [{"id": "letterman_swagger", "on": "unblocked_damage", "effects": [{"op": "gain_swole", "amount": 2}]}],
		"moves": [{"id": "death_roll", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 5, "hits": 3}]}]},
}

## Extra test cards, by id. Shapes follow core/schema/card_def.gd.
##   neutral_test_shrug: costs 0 and does nothing, for counting cards played.
##   junk_paperwork / junk_detention: stand-ins for task 008's Junk cards, named as the GDD's, so the
##   add_card effects above name a card the ruleset has. Written with task 015's fields (rarity
##   special, lasts fight, Detention's play_limit_in_hand), as tests/core/combat/junk_fixtures.gd.
const CARDS := {
	"neutral_test_shrug": {"id": "neutral_test_shrug", "name": "Shrug", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 0, "target": "none", "effects": [], "keywords": [], "crunch": null, "upgrade": {}},
	"junk_paperwork": {"id": "junk_paperwork", "name": "Paperwork", "owner": "junk", "type": "junk",
		"rarity": "special", "cost": 1, "target": "none", "effects": [], "keywords": ["tapped"], "crunch": null, "upgrade": {},
		"lasts": "fight"},
	"junk_detention": {"id": "junk_detention", "name": "Detention", "owner": "junk", "type": "junk",
		"rarity": "special", "cost": -1, "target": "none", "effects": [], "keywords": [], "crunch": null, "upgrade": {},
		"play_limit_in_hand": 4, "lasts": "fight"},
}


## Returns the test ruleset: task 007's fixture content plus ENEMIES and CARDS, built with the real
## build() and the real constants file. Empty if the build fails (the calling test's assertions then fail).
static func ruleset() -> Dictionary:
	# files: repo path -> JSON text, as a content reader would give them.
	var files: Dictionary = {"data/constants.json": FileAccess.get_file_as_string(Fixtures.CONSTANTS_FILE)}
	# enemies: task 007's test enemies and this file's, by id.
	var enemies: Dictionary = Fixtures.ENEMIES.duplicate(true)
	enemies.merge(ENEMIES)
	# cards: task 007's test cards and this file's, by id.
	var cards: Dictionary = Fixtures.CARDS.duplicate(true)
	cards.merge(CARDS)
	for kind: Array in [["cards", cards], ["enemies", enemies], ["dudes", Fixtures.DUDES], ["gear", Fixtures.GEAR]]:
		for id: String in kind[1]:
			files["data/%s/%s.json" % [kind[0], id]] = JSON.stringify(kind[1][id])
	# built: build()'s result.
	var built: Dictionary = Ruleset.build(files)
	return built["ruleset"]


## Returns a solo fight against these enemies in turn 1's player phase, with the Dude's HP and max HP
## set to hp (so long fights do not end early) and dolla_bills set as given. {} if the fight cannot start.
## rules: the ruleset. run_seed: the seed. enemy_ids: enemy ids, left to right. hp: the Dude's HP, 1 or
## more. dolla_bills: the Dude's Dolla Bills, 0 or more.
static func solo_fight(rules: Dictionary, run_seed: int, enemy_ids: Array, hp: int = 30, dolla_bills: int = 0) -> Dictionary:
	# state: the fight from task 007's helper.
	var state: Dictionary = Fixtures.fight(rules, run_seed, ["test_dude"], enemy_ids)
	if state.is_empty():
		return state
	state["dudes"][0]["hp"] = hp
	state["dudes"][0]["max_hp"] = hp
	state["dudes"][0]["dolla_bills"] = dolla_bills
	return state
