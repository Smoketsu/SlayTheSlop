## Test content and helpers for the Junk card tests (task 015). Lane: core (Agent A).
##
## Not a test file (no test_ prefix). Adds to the shared fixtures (tests/core/combat/fixtures.gd)
## without editing them, so task 013 can change that file at the same time.
##
## JUNK holds the six GDD Junk cards ("Junk cards" table) written with task 015's fields, with the
## ids task 008 is asked to use (junk_hangover ...). They are this task's reading of the GDD, kept
## here so the rules are tested before task 008's data files merge; when they do, a test may load
## the real files instead. The other cards and enemies are test-only; their numbers are fixture
## values, not game balance.
extends RefCounted

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")

## The six Junk cards, by id, as GDD "Junk cards" reads (shapes: core/schema/card_def.gd).
const JUNK := {
	# Unplayable. When drawn, lose 1 Hype. Lasts the run.
	"junk_hangover": {"id": "junk_hangover", "name": "Hangover", "owner": "junk", "type": "junk",
		"rarity": "special", "cost": -1, "target": "none", "effects": [], "keywords": [], "crunch": null,
		"upgrade": {}, "on_draw": [{"op": "lose_hype", "amount": 1}], "lasts": "run"},
	# Unplayable. Cannot be removed at Baileys. Lasts the run.
	"junk_regret": {"id": "junk_regret", "name": "Regret", "owner": "junk", "type": "junk",
		"rarity": "special", "cost": -1, "target": "none", "effects": [], "keywords": [], "crunch": null,
		"upgrade": {}, "removable": false, "lasts": "run"},
	# Unplayable. When drawn, take 1 damage. Lasts the run.
	"junk_bedbugs": {"id": "junk_bedbugs", "name": "Bedbugs", "owner": "junk", "type": "junk",
		"rarity": "special", "cost": -1, "target": "none", "effects": [], "keywords": [], "crunch": null,
		"upgrade": {}, "on_draw": [{"op": "self_damage", "amount": 1}], "lasts": "run"},
	# Costs 1 Hype. Does nothing. Tapped. Lasts the fight.
	"junk_paperwork": {"id": "junk_paperwork", "name": "Paperwork", "owner": "junk", "type": "junk",
		"rarity": "special", "cost": 1, "target": "none", "effects": [], "keywords": ["tapped"], "crunch": null,
		"upgrade": {}, "lasts": "fight"},
	# Unplayable. While it is in your hand, you can play at most 4 cards this turn. Lasts the fight.
	"junk_detention": {"id": "junk_detention", "name": "Detention", "owner": "junk", "type": "junk",
		"rarity": "special", "cost": -1, "target": "none", "effects": [], "keywords": [], "crunch": null,
		"upgrade": {}, "play_limit_in_hand": 4, "lasts": "fight"},
	# Unplayable. If it is in your hand at end of turn, take 2 damage. Lasts the fight.
	"junk_burn": {"id": "junk_burn", "name": "Burn", "owner": "junk", "type": "junk",
		"rarity": "special", "cost": -1, "target": "none", "effects": [], "keywords": [], "crunch": null,
		"upgrade": {}, "on_end_of_turn_in_hand": [{"op": "self_damage", "amount": 2}], "lasts": "fight"},
}

## Test-only cards that use the task 015 ops, by id.
const CARDS := {
	# Like Special Brownie's second half: a Hangover into your own discard pile.
	"neutral_test_brownie": {"id": "neutral_test_brownie", "name": "Brownie", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 0, "target": "self",
		"effects": [{"op": "add_card", "card_id": "junk_hangover", "to": "discard_pile"}],
		"keywords": [], "crunch": null, "upgrade": {}},
	# An attack aimed at an enemy whose add_card still lands on the player: 2 Paperwork to hand.
	"neutral_test_red_tape": {"id": "neutral_test_red_tape", "name": "Red Tape", "owner": "neutral", "type": "attack",
		"rarity": "common", "cost": 0, "target": "enemy",
		"effects": [{"op": "damage", "amount": 1}, {"op": "add_card", "card_id": "junk_paperwork", "to": "hand", "count": 2}],
		"keywords": [], "crunch": null, "upgrade": {}},
	# A Regret on top of your own draw pile.
	"neutral_test_tattoo": {"id": "neutral_test_tattoo", "name": "Tattoo", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 0, "target": "none",
		"effects": [{"op": "add_card", "card_id": "junk_regret", "to": "draw_pile"}],
		"keywords": [], "crunch": null, "upgrade": {}},
	# lose_hype and self_damage on a playable card.
	"neutral_test_bad_idea": {"id": "neutral_test_bad_idea", "name": "Bad Idea", "owner": "neutral", "type": "skill",
		"rarity": "common", "cost": 0, "target": "enemy",
		"effects": [{"op": "lose_hype", "amount": 2}, {"op": "self_damage", "amount": 4}],
		"keywords": [], "crunch": null, "upgrade": {}},
}

## Test-only enemies that add Junk, by id. Scripted (pattern) so no random move choice is involved.
const ENEMIES := {
	# Like Skeleton Intern: hits, then shuffles a Paperwork into the target's draw pile.
	"test_intern": {"id": "test_intern", "name": "Intern", "floor": 1, "tier": "normal", "max_hp": 18, "arm_count": 2,
		"pattern": ["file"],
		"moves": [{"id": "file", "weight": 1, "intent": "debuff", "effects": [{"op": "damage", "amount": 6},
			{"op": "add_card", "card_id": "junk_paperwork", "to": "draw_pile", "shuffle_in": true}]}]},
	# Like Hall Monitor Golem's Detention: a Detention into the target's discard pile, no damage.
	"test_monitor": {"id": "test_monitor", "name": "Monitor", "floor": 1, "tier": "rival", "max_hp": 75, "arm_count": 2,
		"pattern": ["write_up"],
		"moves": [{"id": "write_up", "weight": 1, "intent": "debuff",
			"effects": [{"op": "add_card", "card_id": "junk_detention", "to": "discard_pile"}]}]},
	# Like Boag Imp: two Burns into the target's hand.
	"test_imp": {"id": "test_imp", "name": "Imp", "floor": 1, "tier": "normal", "max_hp": 22, "arm_count": 2,
		"pattern": ["flick"],
		"moves": [{"id": "flick", "weight": 1, "intent": "debuff",
			"effects": [{"op": "add_card", "card_id": "junk_burn", "to": "hand", "count": 2}]}]},
}


## Returns the shared fixture ruleset (with its GEAR, task 021) plus JUNK, CARDS and ENEMIES, built with the real build() and
## the real constants file. Empty if the build fails.
static func ruleset() -> Dictionary:
	return build_result()["ruleset"]


## Returns build()'s whole result for the same content, so a test can read its errors.
## extra: more repo path -> JSON text entries to add (for example a broken card). Optional.
static func build_result(extra: Dictionary = {}) -> Dictionary:
	# files: repo path -> JSON text, as a content reader would give them.
	var files: Dictionary = {"data/constants.json": FileAccess.get_file_as_string(Fixtures.CONSTANTS_FILE)}
	for kind: Array in [["cards", Fixtures.CARDS], ["enemies", Fixtures.ENEMIES], ["dudes", Fixtures.DUDES],
			["gear", Fixtures.GEAR], ["cards", JUNK], ["cards", CARDS], ["enemies", ENEMIES]]:
		for id: String in kind[1]:
			files["data/%s/%s.json" % [kind[0], id]] = JSON.stringify(kind[1][id])
	files.merge(extra, true)
	return Ruleset.build(files)


## Gives a Dude a new copy of a card in a pile (test setup only; the core does this through
## add_card): on top (front) of the draw pile, or at the end of any other pile. The copy joins the
## run deck too unless it is one of JUNK that lasts the fight. Returns its card_uid.
## state: a run state, changed here. player_index: the Dude's seat, 0-based. def_id: a card id.
## pile: "draw_pile", "hand", "discard_pile" or "tapped_pile".
static func own(state: Dictionary, player_index: int, def_id: String, pile: String) -> String:
	# uid: the new copy's card_uid, given into the hand first.
	var uid: String = Fixtures.give(state, player_index, def_id)
	# dude: the Dude, inside state.
	var dude: Dictionary = state["dudes"][player_index]
	dude["hand"].erase(uid)
	if pile == "draw_pile":
		dude["draw_pile"].insert(0, uid)
	else:
		dude[pile].append(uid)
	# Task 033: give() already put the copy in the run deck; a fight-only copy leaves it, as add_card does.
	if JUNK.get(def_id, {}).get("lasts", "run") != "run":
		dude["deck"].erase(uid)
	return uid
