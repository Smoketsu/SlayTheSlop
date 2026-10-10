## Picks the room drawn behind a fight (task 028). Lane: client (Agent B).
##
## Rooms live in res://assets/placeholder/backgrounds/<room>.webp (assets/placeholder/README.md
## "Backgrounds"). A boss room is named by the boss's content id, so when an enemy on the field has a
## file named by its def_id, that room is used; otherwise the floor's default room from FLOOR_ROOMS.
## A room with no file is drawn as FALLBACK_COLOR by the screen: never a crash. Pure lookup: reads
## the state, never changes it.
extends RefCounted

## Folder the room backgrounds are read from, one "<room>.webp" each. Changed only by the client
## lane, together with assets/placeholder/README.md.
const BG_DIR: String = "res://assets/placeholder/backgrounds"
## File extension of a room background, with the dot. Changed only by the client lane.
const BG_EXTENSION: String = ".webp"
## The room used when a floor has no FLOOR_ROOMS entry: floor 1's Basement. Changed only by the
## client lane.
const DEFAULT_ROOM: String = "basement"
## Floor number (run_state.floor, 1..4) -> the room its ordinary fights (Brawls, Rivals) use. Only
## floor 1 exists in the solo slice. Changed only by the client lane.
const FLOOR_ROOMS := {
	1: "basement",
}
## Colour drawn instead of a room whose file is missing. Changed only by the client lane.
const FALLBACK_COLOR := Color(0.12, 0.11, 0.13)


## Returns the room for a state's fight: the def_id of the first enemy, left to right, that has a
## background file (a boss room); otherwise the floor's FLOOR_ROOMS entry, or DEFAULT_ROOM.
## state: a run state; combat may be null and floor missing.
static func room_for(state: Dictionary) -> String:
	# combat: the fight, or null outside one.
	var combat: Variant = state.get("combat")
	if typeof(combat) == TYPE_DICTIONARY:
		for enemy: Dictionary in combat.get("enemies", []):
			if texture_for_room(enemy.get("def_id", "")) != null:
				return enemy["def_id"]
	return FLOOR_ROOMS.get(int(state.get("floor", 1)), DEFAULT_ROOM)


## Returns a room's background texture, or null when it has no file (the screen then draws
## FALLBACK_COLOR).
## room: a room name, such as "basement" or a boss's def_id.
static func texture_for_room(room: String) -> Texture2D:
	# path: where its file would be.
	var path: String = room_path(room)
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Returns the path a room's file would have, or "" when the name is not a plain snake_case id (so
## no data value can reach a path outside BG_DIR).
## room: a room name.
static func room_path(room: String) -> String:
	if room.is_empty() or not room.is_valid_ascii_identifier() or room.to_lower() != room:
		return ""
	return BG_DIR.path_join(room + BG_EXTENSION)
