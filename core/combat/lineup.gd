## Building enemy states from their definitions and putting them into a fight (task 017; the
## per-enemy setup moved here from core/combat/fight.gd, task 007). Lane: core (Agent A).
##
## Every enemy that joins a fight goes through new_enemy(): the starting lineup (fight.gd
## start_fight_in_place), enemies called in by the summon_enemy op (core/ops/summon_enemy.gd) and
## the enemies a splitting enemy becomes (core/combat/enemy_behaviors.gd). So every one of them gets:
##   - uid "e" + next_uid (core/schema/README.md "Ids"), and next_uid rises by 1;
##   - max_hp = hp = the definition's solo max_hp times the party's HP multiplier, rounded down;
##   - arm_count from the definition;
##   - ick_threshold = ICK_BASE_<tier> times the HP multiplier, rounded up (GDD "Difficulty scaling");
##   - drops_brews from the definition (task 017, Mimic Cooler), 0 when absent;
##   - every other field as EnemyState.blank().
## Escorts (enemy_def.gd "arrives_with", task 017) are added to the starting lineup by expand(): each
## listed enemy is followed by its escorts, one level deep.
##
## Pure: no file, clock, network or random access. Functions ending in _in_place change the working
## copy they are given (see core/combat/bodies.gd).
extends RefCounted

const EnemyState := preload("res://core/schema/enemy_state.gd")
const Event := preload("res://core/schema/event.gd")
const Scaling := preload("res://core/combat/party_scaling.gd")

## Enemy tier (core/schema/enemy_def.gd TIERS) -> name of the constant with its solo starting Ick
## threshold (GDD "Statuses"). Changes only with the GDD's tiers.
const ICK_BASE_BY_TIER := {"normal": "ICK_BASE_NORMAL", "rival": "ICK_BASE_RIVAL", "boss": "ICK_BASE_BOSS"}

## Prefix of an enemy uid; the number after it comes from run_state.next_uid (core/schema/README.md "Ids").
const ENEMY_UID_PREFIX: String = "e"


## Returns the starting lineup for these enemies: each id, followed right away by the ids in its
## definition's arrives_with, in order. An escort's own arrives_with is ignored. Ids the ruleset does
## not have are kept as they are, so the caller's check reports them.
## ruleset: the read-only content. def_ids: enemy definition ids, left to right.
static func expand(ruleset: Dictionary, def_ids: Array) -> Array:
	# lineup: the result.
	var lineup: Array = []
	for def_id: Variant in def_ids:
		lineup.append(def_id)
		if typeof(def_id) == TYPE_STRING and ruleset["enemies"].has(def_id):
			lineup.append_array(ruleset["enemies"][def_id].get("arrives_with", []))
	return lineup


## Returns a new enemy state for this definition, set up as the file header says, and raises
## state.next_uid by 1. Does not put it in the fight. The definition must exist and its tier's
## ICK_BASE_* constant must be an int (Fight.check_start and EnemyBehaviors.check_start check that).
## ruleset: the read-only content. state: the working copy; only next_uid changes.
## def_id: the enemy definition id.
static func new_enemy(ruleset: Dictionary, state: Dictionary, def_id: String) -> Dictionary:
	# definition: the enemy's fixed values.
	var definition: Dictionary = ruleset["enemies"][def_id]
	# uid: this enemy's id in the fight.
	var uid: String = ENEMY_UID_PREFIX + str(state["next_uid"])
	state["next_uid"] += 1
	# enemy: the new enemy state.
	var enemy: Dictionary = EnemyState.blank(uid, def_id)
	enemy["max_hp"] = Scaling.scale_down(definition["max_hp"], ruleset["constants"], state["party_size"])
	enemy["hp"] = enemy["max_hp"]
	enemy["arm_count"] = definition["arm_count"]
	enemy["ick_threshold"] = Scaling.scale_up(ruleset["constants"][ICK_BASE_BY_TIER[definition["tier"]]],
		ruleset["constants"], state["party_size"])
	enemy["drops_brews"] = definition.get("drops_brews", 0)
	return enemy


## Adds a new enemy of this definition to the running fight at position index (clamped to 0..the
## number of enemies; that number puts it at the right end) and emits enemy_spawned with the
## position it got. It has no intent until one is chosen for it. Returns the new enemy state, or {}
## when the ruleset has no such definition (nothing changes then).
## ruleset: the read-only content. state: the working copy, in a fight. def_id: the enemy definition
## id. index: where in the left-to-right order it goes. events: the event list, appended to.
static func spawn_in_place(ruleset: Dictionary, state: Dictionary, def_id: String, index: int, events: Array) -> Dictionary:
	if not ruleset["enemies"].has(def_id) or not ICK_BASE_BY_TIER.has(ruleset["enemies"][def_id]["tier"]):
		return {}
	# enemies: the fight's enemy list, inside state.
	var enemies: Array = state["combat"]["enemies"]
	# at: the clamped position.
	var at: int = clampi(index, 0, enemies.size())
	# enemy: the new enemy.
	var enemy: Dictionary = new_enemy(ruleset, state, def_id)
	enemies.insert(at, enemy)
	events.append(Event.make("enemy_spawned", {"enemy_uid": enemy["uid"], "def_id": def_id, "index": at}))
	return enemy
