## Picks the art of the map screen (task 061): the floor's backdrop, one icon per node type, and the
## floor boss's portrait. Lane: client (taken over by Agent A from Agent B, 2026-10-13, at Smoketsu's
## request).
##
## Art lives in res://assets/placeholder/map/ (assets/placeholder/README.md "Map"; how it is made:
## assets/STYLE_GUIDE.md): "<backdrop>.webp" per floor and "node_<type>.png" per node type. A floor or
## node type with no file returns null, and the map screen then draws a plain colour or the node's
## name as text: never a crash. Pure lookup: reads the ruleset and files, never changes game state.
extends RefCounted

## Folder the map art is read from. Changed only by the client lane, together with
## assets/placeholder/README.md.
const MAP_DIR: String = "res://assets/placeholder/map"
## Floor number (run_state.floor, 1..4) -> its backdrop's file name, without ".webp". Only floor 1
## exists in the solo slice. Changed only by the client lane.
const FLOOR_BACKDROPS := {
	1: "basement",
}
## Map node type (core/schema/run_state.gd map node "type") -> its icon's file name in MAP_DIR,
## without ".png". A type with no entry is drawn as its name. Changed only by the client lane.
const NODE_ICONS := {
	"start": "node_start",
	"brawl": "node_brawl",
	"rival": "node_rival",
	"side_quest": "node_side_quest",
	"tailgate": "node_tailgate",
	"baileys": "node_baileys",
	"loot": "node_loot",
	"boss": "node_boss",
}
## [added, task 067] Backdrop -> the open area of its picture where the map's nodes go, as fractions of
## the picture's width and height (x, y, width, height; 0..1), so nodes never sit on the drawn rooms.
## Measured on the picture with a pixel grid:
##   basement (1536 x 1024): the big open room between the walls, x 625..1015, y 275..915.
## A backdrop with no entry lets the nodes use the whole screen below the header. Changed only by the
## client lane, after measuring a new or replaced picture.
const PLAY_AREAS := {
	"basement": Rect2(625.0 / 1536.0, 275.0 / 1024.0, 390.0 / 1536.0, 640.0 / 1024.0),
}
## Colour drawn behind the map when its floor has no backdrop. Changed only by the client lane.
const FALLBACK_COLOR := Color(0.14, 0.12, 0.11)


## Returns a floor's backdrop texture, or null when it has none.
## floor_number: run_state.floor, 1 or more.
static func backdrop_for(floor_number: int) -> Texture2D:
	return _load(str(FLOOR_BACKDROPS.get(floor_number, "")), ".webp")


## [added, task 067] Returns a floor's open area for nodes (PLAY_AREAS, fractions of its backdrop), or
## an empty Rect2 when the floor has no backdrop or no measured area.
## floor_number: run_state.floor, 1 or more.
static func play_area(floor_number: int) -> Rect2:
	return PLAY_AREAS.get(str(FLOOR_BACKDROPS.get(floor_number, "")), Rect2())


## Returns a node type's icon texture, or null when it has none (the screen then shows its name).
## node_type: a map node "type", such as "brawl".
static func icon_for(node_type: String) -> Texture2D:
	return _load(str(NODE_ICONS.get(node_type, "")), ".png")


## Returns the enemy id whose portrait the Boss node shows: the one boss-tier enemy of the floor's
## boss encounters, or "" when there is none or more than one to choose from (the floor "rolls one of
## two", and the map must not give away which before the fight). Reads the ruleset only.
## ruleset: the read-only content. floor_number: run_state.floor.
static func boss_portrait_id(ruleset: Dictionary, floor_number: int) -> String:
	# found: boss enemy ids of this floor's boss encounters, as keys.
	var found: Dictionary = {}
	for encounter: Dictionary in ruleset.get("encounters", {}).values():
		if int(encounter.get("floor", 0)) != floor_number or encounter.get("node", "") != "boss":
			continue
		for enemy_id: String in encounter.get("enemies", []):
			if ruleset.get("enemies", {}).get(enemy_id, {}).get("tier", "") == "boss":
				found[enemy_id] = true
	return found.keys()[0] if found.size() == 1 else ""


## Loads MAP_DIR/<file_name><extension>, or returns null when the name is empty, not a plain
## snake_case id, or has no file.
## file_name: the file's name without extension. extension: ".webp" or ".png".
static func _load(file_name: String, extension: String) -> Texture2D:
	if file_name.is_empty() or not file_name.is_valid_ascii_identifier() or file_name.to_lower() != file_name:
		return null
	# path: where the file would be.
	var path: String = MAP_DIR.path_join(file_name + extension)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
