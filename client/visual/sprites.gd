## Looks up the placeholder sprite of a Dude or enemy by its content id (task 028).
## Lane: client (Agent B).
##
## Art lives in res://assets/placeholder/characters/<def_id>.png (assets/placeholder/README.md), so a
## new enemy with art needs no client change. An id with no file of its own uses its FALLBACKS entry,
## and an id with neither gets a generic box, so missing art is visible on screen and never a crash.
## Pure lookup: reads files only through ResourceLoader, never touches game state.
extends RefCounted

## Folder the character sprites are read from, one "<def_id>.png" per Dude or enemy. Changed only
## by the client lane, together with assets/placeholder/README.md.
const ART_DIR: String = "res://assets/placeholder/characters"

## Ids with no art file of their own -> how to draw them instead. Only content ids appear here.
##   "art":   the id whose file to borrow (must have its own file in ART_DIR).
##   "scale": size relative to a normal sprite, 0.1..1.0.
##   "tint":  colour multiplied over the borrowed art, so the two read as different enemies.
## Remove an entry once its own art exists. Changed only by the client lane.
const FALLBACKS := {
	# The Keg Slime's split halves: its own art, smaller and paler (#81 has no foam_slime art).
	"foam_slime": {"art": "keg_slime", "scale": 0.65, "tint": Color(1.0, 1.0, 0.8)},
}

## Side of the generic fallback box, in pixels. Changed only by the client lane.
const GENERIC_SIZE: int = 96
## Fill colour of the generic fallback box: loud on purpose, so missing art is noticed. Changed
## only by the client lane.
const GENERIC_COLOR := Color(0.85, 0.2, 0.75)
## Kind of a look() result: the id's own art file.
const OWN := "own"
## Kind of a look() result: art borrowed through FALLBACKS.
const BORROWED := "borrowed"
## Kind of a look() result: the generic box, because the id has no art and no FALLBACKS entry.
const GENERIC := "generic"

## The generic fallback texture, built on first use and then shared. Never edited after that.
static var _generic: Texture2D = null


## Returns how to draw a content id: {"texture": Texture2D (never null), "scale": float (1.0 for
## own art), "tint": Color (white for own art), "kind": OWN, BORROWED or GENERIC}.
## def_id: a Dude id (dude_state.dude_id) or an enemy id (enemy_state.def_id).
static func look(def_id: String) -> Dictionary:
	# own: this id's own art, or null when it has none.
	var own: Texture2D = _load(def_id)
	if own != null:
		return {"texture": own, "scale": 1.0, "tint": Color.WHITE, "kind": OWN}
	if FALLBACKS.has(def_id):
		# fallback: the FALLBACKS entry. borrowed: the art it points at, or null if that is missing.
		var fallback: Dictionary = FALLBACKS[def_id]
		var borrowed: Texture2D = _load(fallback["art"])
		if borrowed != null:
			return {"texture": borrowed, "scale": fallback["scale"], "tint": fallback["tint"], "kind": BORROWED}
	return {"texture": generic_texture(), "scale": 1.0, "tint": Color.WHITE, "kind": GENERIC}


## Returns just the texture look() would draw for a content id; never null.
## def_id: a Dude or enemy id.
static func texture_for(def_id: String) -> Texture2D:
	return look(def_id)["texture"]


## Returns the path a content id's own art would have, or "" when the id is not a plain snake_case
## id (so no data value can reach a path outside ART_DIR).
## def_id: a Dude or enemy id.
static func art_path(def_id: String) -> String:
	if def_id.is_empty() or not def_id.is_valid_ascii_identifier() or def_id.to_lower() != def_id:
		return ""
	return ART_DIR.path_join(def_id + ".png")


## Returns the generic fallback texture: a GENERIC_COLOR square of GENERIC_SIZE pixels.
static func generic_texture() -> Texture2D:
	if _generic == null:
		# image: the square's pixels.
		var image := Image.create_empty(GENERIC_SIZE, GENERIC_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(GENERIC_COLOR)
		_generic = ImageTexture.create_from_image(image)
	return _generic


## Returns a content id's own art, or null when it has no file.
## def_id: a Dude or enemy id.
static func _load(def_id: String) -> Texture2D:
	# path: where its art would be.
	var path: String = art_path(def_id)
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
