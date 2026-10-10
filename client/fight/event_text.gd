## One player-facing line per event, for the fight screen's placeholder animations (task 024).
## Lane: client (Agent B).
##
## Every event type in core/schema/event.gd has a template in TEMPLATES; tests/client fails when a
## new type is added without one. Templates name things in the GDD's themed terms (Hype, Guard,
## Dolla Bills, Bro Meter, Brew). "{name}" fields are filled with display names looked up by id, so
## no Dude, card or enemy is named in client code. Writers may change any template.
extends RefCounted

const Messages := preload("res://client/fight/messages.gd")

## Event type -> template. {field} is replaced with the event's value; {field@} with the display
## name of the id in that field (a Dude, an enemy, a card copy, a map node or a Side Quest), or, for
## a code field (status, node_type, kind, won), its word from messages.gd field_word(). Changed only
## by the client lane.
const TEMPLATES := {
	"fight_started": "A fight breaks out!",
	"turn_started": "Turn {turn}.",
	"intent_set": "{enemy_uid@} gets ready: {move_id}.",
	"deck_shuffled": "{player_id@} shuffles the discard pile back in.",
	"card_moved": "{card_uid@}: {from} → {to}.",
	"card_created": "{player_id@} gets a {def_id@} ({to}).",
	"card_removed": "{card_uid@} is gone for good.",
	"card_played": "{player_id@} plays {card_uid@}.",
	"hype_changed": "{player_id@}: Hype {delta:+} (now {hype}).",
	"guard_changed": "{target_id@}: Guard {delta:+} (now {guard}).",
	"damage_dealt": "{target_id@} takes {hp_lost} damage ({blocked} blocked).",
	"healed": "{target_id@} heals {amount} (HP {hp}).",
	"status_changed": "{target_id@}: {status@} {delta:+} (now {stacks}).",
	"grossed_out": "{enemy_uid@} is Grossed Out!",
	"armless": "{enemy_uid@} is Armless and loses its attack.",
	"enemy_acted": "{enemy_uid@} uses {move_id}.",
	"enemy_skipped": "{enemy_uid@} skips its turn ({reason}).",
	"enemy_spawned": "{def_id@} joins the fight.",
	"enemy_died": "{enemy_uid@} is down.",
	"dude_passed_out": "{player_id@} Passes Out.",
	"bro_meter_changed": "Bro Meter {delta:+} (now {bro_meter}).",
	"dolla_bills_changed": "{player_id@}: Dolla Bills {delta:+} (now {dolla_bills}).",
	"ready_changed": "{player_id@} is ready.",
	"fight_ended": "The fight is over: {result}.",
	"bro_move_used": "{player_id@} pulls off {def_id@}!",
	"thorns_changed": "{target_id@}: thorns {delta:+} (now {thorns}).",
	"power_triggered": "{card_uid@} kicks in.",
	"gear_gained": "{player_id@} gets {gear_id@}.",
	"gear_triggered": "{gear_id@} kicks in.",
	"brew_used": "{player_id@} drinks {brew_id@}.",
	"stat_changed": "{target_id@}: {stat} {delta:+} (now {value}).",
	"pass_out_prevented": "{player_id@} refuses to Pass Out (HP {hp}).",
	"enemy_fled": "{enemy_uid@} runs off.",
	"enemy_split": "{enemy_uid@} splits in two!",
	"dolla_bills_stolen": "{enemy_uid@} steals {amount} Dolla Bills from {player_id@}.",
	"dolla_bills_returned": "{player_id@} gets {amount} Dolla Bills back.",
	"brew_dropped": "{enemy_uid@} drops {count} Brew(s).",
	"enemy_triggered": "{enemy_uid@} reacts.",
	"charge_started": "{enemy_uid@} starts charging!",
	"enemy_fell": "{enemy_uid@} falls over!",
	# Task 025, the run flow. item_bought and brew_gained never say "Brew": either may come from
	# Baileys, where every Brew is a Shake, so they name only the Brew itself.
	"floor_started": "Floor {floor} begins.",
	"vote_cast": "{player_id@} votes for {node_id@}.",
	"node_entered": "The party heads into {node_type@}.",
	"offer_opened": "{player_id@} has a choice: {kind@}.",
	"offer_closed": "{player_id@} is done choosing.",
	"item_bought": "{player_id@} pays {price} Dolla Bills at Baileys.",
	"card_upgraded": "{card_uid@} is upgraded.",
	"brew_gained": "{player_id@} stashes {brew_id@} for later.",
	"brew_not_kept": "{player_id@} has no room for {brew_id@}.",
	"side_quest_rolled": "{side_quest_id@}: {percent}% chance... {won@}",
	"pending_status_added": "{player_id@} will start the next fight with {stacks} {status@}.",
	"dude_revived": "{player_id@} wakes up with {hp} HP.",
	"floor_ended": "Floor {floor} cleared!",
	"run_ended": "The run is over: {result}.",
}


## Returns the line for one event, with ids replaced by display names.
## event: one event Dictionary. names: id -> display name, from names_for().
static func line(event: Dictionary, names: Dictionary) -> String:
	# text: the template being filled.
	var text: String = TEMPLATES.get(event["type"], event["type"])
	# keys: the event's fields, sorted so the result never depends on dictionary order.
	var keys: Array = event.keys()
	keys.sort()
	for key: String in keys:
		# value: this field's value.
		var value: Variant = event[key]
		text = text.replace("{%s@}" % key, names.get(str(value), Messages.field_word(key, str(value))))
		text = text.replace("{%s:+}" % key, ("+%d" % value) if typeof(value) == TYPE_INT and value >= 0 else str(value))
		text = text.replace("{%s}" % key, str(value))
	return text


## Returns id -> display name for every Dude, enemy, card copy and map node in the given states, and
## every card, enemy, Gear, Brew and Side Quest definition in the ruleset. A map node is named by its
## type (messages.gd NODE_TYPES). Pass the states from before and after a request so enemies that
## died or fled still have names.
## ruleset: read-only content. states: run states to read, oldest first.
static func names_for(ruleset: Dictionary, states: Array) -> Dictionary:
	# names: the result.
	var names: Dictionary = {}
	for kind: String in ["cards", "enemies", "gear", "brews", "side_quests", "dudes"]:
		for id: String in ruleset.get(kind, {}):
			names[id] = ruleset[kind][id].get("name", id)
	for state: Dictionary in states:
		for dude: Dictionary in state.get("dudes", []):
			names[dude["player_id"]] = ruleset["dudes"].get(dude["dude_id"], {}).get("name", dude["player_id"])
			for uid: String in dude["cards"]:
				names[uid] = ruleset["cards"].get(dude["cards"][uid]["def_id"], {}).get("name", uid)
		# node: one map node of this state's floor (run_state.gd "map"; none while map is {}).
		for node: Dictionary in state.get("map", {}).get("nodes", []):
			names[node["id"]] = Messages.field_word("node_type", node["type"])
		if state.get("combat") != null:
			for enemy: Dictionary in state["combat"]["enemies"]:
				names[enemy["uid"]] = ruleset["enemies"].get(enemy["def_id"], {}).get("name", enemy["uid"])
	return names
