## Placeholder content and a sample fight for developing the fight screen (task 018).
## Lane: client (Agent B).
##
## data/ has no cards, enemies or Dudes yet (tasks 006 and 010), so this builds a small ruleset in
## memory. It goes through the real core/ruleset/ruleset.gd build() with the real
## data/constants.json, so every definition here passes the shared schemas; nothing is invented
## outside them. The content is deliberately generic: no GDD Dude, card or enemy is copied here, so
## nothing in the client names a real Dude (CLAUDE.md "Build for co-op from the first commit").
## Delete this file's content once real data exists and the screen can load it.
extends RefCounted

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")
const RunState := preload("res://core/schema/run_state.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const CombatState := preload("res://core/schema/combat_state.gd")
const EnemyState := preload("res://core/schema/enemy_state.gd")

## Placeholder card definitions, by id. Shapes follow core/schema/card_def.gd. Changed only by the
## client lane, and only to exercise the screen.
const CARDS := {
	"neutral_dev_jab": {
		"id": "neutral_dev_jab", "name": "Jab", "owner": "neutral", "type": "attack", "rarity": "starter",
		"cost": 1, "target": "enemy", "effects": [{"op": "damage", "amount": 6, "hits": 1}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 6 damage",
	},
	"neutral_dev_brace": {
		"id": "neutral_dev_brace", "name": "Brace", "owner": "neutral", "type": "skill", "rarity": "starter",
		"cost": 1, "target": "self", "effects": [{"op": "guard", "amount": 5}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Gain 5 Guard",
	},
	"neutral_dev_haymaker": {
		"id": "neutral_dev_haymaker", "name": "Haymaker", "owner": "neutral", "type": "attack", "rarity": "common",
		"cost": 2, "target": "enemy", "effects": [{"op": "damage", "amount": 12, "hits": 1}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 12 damage",
	},
	"neutral_dev_sweep": {
		"id": "neutral_dev_sweep", "name": "Sweep", "owner": "neutral", "type": "attack", "rarity": "common",
		"cost": 1, "target": "all_enemies", "effects": [{"op": "damage", "amount": 3, "hits": 1}],
		"keywords": ["tapped"], "crunch": null, "upgrade": {}, "text": "Deal 3 damage to all enemies. Tapped",
	},
	"neutral_dev_spot_me": {
		"id": "neutral_dev_spot_me", "name": "Spot Me", "owner": "neutral", "type": "skill", "rarity": "common",
		"cost": 1, "target": "ally", "effects": [{"op": "guard", "amount": 4}],
		"keywords": ["assist"], "crunch": null, "upgrade": {}, "text": "Target Dude gains 4 Guard",
	},
	"neutral_dev_high_five": {
		"id": "neutral_dev_high_five", "name": "High Five", "owner": "neutral", "type": "attack", "rarity": "starter",
		"cost": 0, "target": "enemy", "effects": [{"op": "damage", "amount": 10, "hits": 1}],
		"keywords": [], "crunch": null, "upgrade": {}, "text": "Deal 10 damage",
	},
}

## Placeholder enemy definitions, by id. Shapes follow core/schema/enemy_def.gd.
const ENEMIES := {
	"dev_dummy": {
		"id": "dev_dummy", "name": "Training Dummy", "floor": 1, "tier": "normal", "max_hp": 20, "arm_count": 2,
		"moves": [{"id": "flail", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 5, "hits": 1}]}],
		"text": "Hits for 5",
	},
	"dev_blob": {
		"id": "dev_blob", "name": "Practice Blob", "floor": 1, "tier": "normal", "max_hp": 14, "arm_count": 0,
		"moves": [{"id": "wobble", "weight": 1, "intent": "defend", "effects": [{"op": "guard", "amount": 4}]}],
		"text": "Gains 4 Guard",
	},
}

## Placeholder Dude definitions, by id. Shapes follow core/schema/dude_def.gd.
const DUDES := {
	"dev_dude": {
		"id": "dev_dude", "name": "Test Dude", "title": "the Placeholder", "max_hp": 70,
		"starter_deck": ["neutral_dev_jab", "neutral_dev_jab", "neutral_dev_brace", "neutral_dev_haymaker",
			"neutral_dev_sweep", "neutral_dev_spot_me"],
		"starting_gear": [], "bro_move": "neutral_dev_high_five",
	},
}


## Builds the placeholder ruleset with the real build() and the real constants file.
## Returns build()'s result: {"ok", "ruleset", "errors"}.
static func ruleset() -> Dictionary:
	# files: repo path -> JSON text, as the real reader would give them.
	var files: Dictionary = {"data/constants.json": DataFiles.read_all().get("data/constants.json", "")}
	for kind: Array in [["cards", CARDS], ["enemies", ENEMIES], ["dudes", DUDES]]:
		for id: String in kind[1]:
			files["data/%s/%s.json" % [kind[0], id]] = JSON.stringify(kind[1][id])
	return Ruleset.build(files)


## Returns a solo run state in the player phase of turn 1, with the Dude's starter deck split
## between hand and draw pile, and one enemy of each placeholder kind. Passes RunState.check().
## Built by hand because the core cannot start fights yet (task 007).
static func sample_state() -> Dictionary:
	# dude: the one Dude, player p1.
	var dude: Dictionary = DudeState.blank("p1", "dev_dude")
	dude["max_hp"] = DUDES["dev_dude"]["max_hp"]
	dude["hp"] = 58
	dude["hype"] = 3
	dude["hype_per_turn"] = 3
	dude["draw_per_turn"] = 5
	dude["guard"] = 2
	dude["statuses"] = {"exposed": 1}
	dude["brew_slots"] = 3
	dude["dolla_bills"] = 99
	# uid_number: the next card_uid number to hand out.
	var uid_number: int = 1
	for def_id: String in DUDES["dev_dude"]["starter_deck"]:
		# uid: this copy's card_uid.
		var uid: String = "c%d" % uid_number
		uid_number += 1
		dude["deck"].append(uid)
		dude["cards"][uid] = {"def_id": def_id, "upgraded": false}
		(dude["hand"] if dude["hand"].size() < 5 else dude["draw_pile"]).append(uid)
	# combat: the fight, already in the player phase with intents set.
	var combat: Dictionary = CombatState.blank()
	combat["turn"] = 1
	combat["phase"] = "player"
	# dummy, blob: the two enemies, left to right.
	var dummy: Dictionary = EnemyState.blank("e%d" % uid_number, "dev_dummy")
	uid_number += 1
	dummy["max_hp"] = ENEMIES["dev_dummy"]["max_hp"]
	dummy["hp"] = 20
	dummy["arm_count"] = 2
	dummy["broken_arms"] = 1
	dummy["ick"] = 2
	dummy["ick_threshold"] = 5
	dummy["intent"] = {"move_id": "flail", "target_ids": ["p1"]}
	var blob: Dictionary = EnemyState.blank("e%d" % uid_number, "dev_blob")
	uid_number += 1
	blob["max_hp"] = ENEMIES["dev_blob"]["max_hp"]
	blob["hp"] = 14
	blob["statuses"] = {"noodle_arms": 2}
	blob["ick_threshold"] = 5
	blob["intent"] = {"move_id": "wobble", "target_ids": []}
	combat["enemies"] = [dummy, blob]
	# state: the run around the fight.
	var state: Dictionary = RunState.blank(424242, [dude])
	state["combat"] = combat
	state["bro_meter"] = 10
	state["next_uid"] = uid_number
	return state
