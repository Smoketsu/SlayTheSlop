## Test content and helpers for the enemy AI tests (task 011). Lane: core (Agent A).
##
## Not a test file (no test_ prefix). Adds test-only enemies to task 007's fixtures
## (tests/core/combat/fixtures.gd) and builds them with the real core/ruleset/ruleset.gd and the
## real data/constants.json, so every definition passes the shared schemas. Numbers here are
## fixture values chosen for the tests, not game balance.
extends RefCounted

const Ruleset := preload("res://core/ruleset/ruleset.gd")
const Rng := preload("res://core/rng/rng.gd")
const Fixtures := preload("res://tests/core/combat/fixtures.gd")

## Test enemy definitions for the AI, by id. Shapes follow core/schema/enemy_def.gd.
##   ai_duo:      two moves, equal weight: an attack and a Guard move.
##   ai_weighted: weights 1 / 2 / 5 and a weight-0 move that only a rule may choose.
##   ai_heavy:    one move ten times as likely as the other, so the no-three rule triggers often.
##   ai_bouncer:  Goblin Bouncer-style pattern: 8 Guard, then a 9-damage hit, alternating.
##   ai_triple:   a pattern that repeats a move three times (allowed: patterns are exempt, G11).
##   ai_lonely:   one weighted move and one weight-0 move (the no-three ban must be lifted).
##   ai_stuck:    no pattern and only weight-0 moves (a content error: no intent).
##   ai_area:     an area attack (target "all_dudes").
##   ai_quiet:    a damage move explicitly aimed at nobody (target "none").
const ENEMIES := {
	"ai_duo": {"id": "ai_duo", "name": "Duo", "floor": 1, "tier": "normal", "max_hp": 30, "arm_count": 2,
		"moves": [{"id": "poke", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 1}]},
			{"id": "brace", "weight": 1, "intent": "defend", "effects": [{"op": "guard", "amount": 1}]}]},
	"ai_weighted": {"id": "ai_weighted", "name": "Weighted", "floor": 1, "tier": "normal", "max_hp": 30, "arm_count": 2,
		"moves": [{"id": "light", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 1}]},
			{"id": "medium", "weight": 2, "intent": "attack", "effects": [{"op": "damage", "amount": 1}]},
			{"id": "heavy", "weight": 5, "intent": "defend", "effects": [{"op": "guard", "amount": 1}]},
			{"id": "special", "weight": 0, "intent": "buff", "effects": [{"op": "guard", "amount": 1}]}]},
	"ai_heavy": {"id": "ai_heavy", "name": "Heavy", "floor": 1, "tier": "normal", "max_hp": 30, "arm_count": 2,
		"moves": [{"id": "often", "weight": 10, "intent": "attack", "effects": [{"op": "damage", "amount": 1}]},
			{"id": "seldom", "weight": 1, "intent": "defend", "effects": [{"op": "guard", "amount": 1}]}]},
	"ai_bouncer": {"id": "ai_bouncer", "name": "Bouncer", "floor": 1, "tier": "normal", "max_hp": 28, "arm_count": 2,
		"pattern": ["guard_up", "hit"],
		"moves": [{"id": "guard_up", "weight": 0, "intent": "defend", "target": "none", "effects": [{"op": "guard", "amount": 8}]},
			{"id": "hit", "weight": 0, "intent": "attack", "target": "dude", "effects": [{"op": "damage", "amount": 9}]}]},
	"ai_triple": {"id": "ai_triple", "name": "Triple", "floor": 1, "tier": "normal", "max_hp": 30, "arm_count": 2,
		"pattern": ["stomp", "stomp", "stomp", "rest"],
		"moves": [{"id": "stomp", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 1}]},
			{"id": "rest", "weight": 1, "intent": "defend", "effects": [{"op": "guard", "amount": 1}]}]},
	"ai_lonely": {"id": "ai_lonely", "name": "Lonely", "floor": 1, "tier": "normal", "max_hp": 30, "arm_count": 2,
		"moves": [{"id": "only", "weight": 1, "intent": "attack", "effects": [{"op": "damage", "amount": 1}]},
			{"id": "never", "weight": 0, "intent": "defend", "effects": [{"op": "guard", "amount": 1}]}]},
	"ai_stuck": {"id": "ai_stuck", "name": "Stuck", "floor": 1, "tier": "normal", "max_hp": 30, "arm_count": 2,
		"moves": [{"id": "idle", "weight": 0, "intent": "unknown", "effects": [{"op": "guard", "amount": 1}]}]},
	"ai_area": {"id": "ai_area", "name": "Area", "floor": 1, "tier": "normal", "max_hp": 30, "arm_count": 2,
		"moves": [{"id": "roar", "weight": 1, "intent": "attack", "target": "all_dudes", "effects": [{"op": "damage", "amount": 2}]}]},
	"ai_quiet": {"id": "ai_quiet", "name": "Quiet", "floor": 1, "tier": "normal", "max_hp": 30, "arm_count": 2,
		"moves": [{"id": "mutter", "weight": 1, "intent": "unknown", "target": "none", "effects": [{"op": "damage", "amount": 3}]}]},
}


## Returns the test ruleset: task 007's fixture content plus ENEMIES, built with the real build()
## and the real constants file. Empty if the build fails (the calling test's assertions then fail).
static func ruleset() -> Dictionary:
	# files: repo path -> JSON text, as a content reader would give them.
	var files: Dictionary = {"data/constants.json": FileAccess.get_file_as_string(Fixtures.CONSTANTS_FILE)}
	# enemies: task 007's test enemies and this file's, by id.
	var enemies: Dictionary = Fixtures.ENEMIES.duplicate(true)
	enemies.merge(ENEMIES)
	# Task 021: Fixtures.GEAR holds test_dude's starting Gear, which the build now checks.
	for kind: Array in [["cards", Fixtures.CARDS], ["enemies", enemies], ["dudes", Fixtures.DUDES], ["gear", Fixtures.GEAR]]:
		for id: String in kind[1]:
			files["data/%s/%s.json" % [kind[0], id]] = JSON.stringify(kind[1][id])
	# built: build()'s result.
	var built: Dictionary = Ruleset.build(files)
	return built["ruleset"]


## Returns a minimal state for calling core/ai/ functions directly: party_size Dudes ("p1".."pN",
## none Passed Out) and every random stream for run_seed. Not a full run state.
## run_seed: the seed the streams come from. party_size: how many Dudes, 1..4.
static func ai_state(run_seed: int, party_size: int) -> Dictionary:
	# dudes: minimal Dude records, only what the AI reads.
	var dudes: Array = []
	# ids: the player ids, in seat order.
	var ids: Array = []
	for i: int in party_size:
		ids.append("p%d" % (i + 1))
		dudes.append({"player_id": ids[i], "passed_out": false})
	return {"party_size": party_size, "dudes": dudes, "rng": Rng.create_streams(run_seed, ids), "combat": null}


## Returns a fresh enemy state record for direct move-choice calls: only what the AI reads.
## def_id: the enemy definition id.
static func ai_enemy(def_id: String) -> Dictionary:
	return {"uid": "e1", "def_id": def_id, "guard": 0, "intent": null, "move_history": []}
