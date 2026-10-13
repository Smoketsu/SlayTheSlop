## Picks the splash picture shown behind an offer (task 063). Lane: client (taken over by Agent A
## from Agent B, 2026-10-13, at Smoketsu's request).
##
## Splashes live in res://assets/placeholder/splashes/<key>.webp (assets/placeholder/README.md
## "Splashes"; how they are made: assets/STYLE_GUIDE.md). A Side Quest is keyed by its content id
## (data/side_quests/<id>.json); The Tailgate and Baileys by their offer kind. SPLASH_KINDS lists the
## offer kinds that show a splash at all; a kind or Side Quest in that list with no file gets the
## visible fallback (FALLBACK_COLOR plus FALLBACK_TEXT), never a crash. Card rewards and the Boss Gear
## pick show no splash. Pure lookup: reads an offer, never changes it.
extends RefCounted

## Folder the splashes are read from, one "<key>.webp" each. Changed only by the client lane,
## together with assets/placeholder/README.md.
const SPLASH_DIR: String = "res://assets/placeholder/splashes"
## File extension of a splash, with the dot. Changed only by the client lane.
const SPLASH_EXTENSION: String = ".webp"
## Offer kinds (core/schema/dude_state.gd offers[].kind) that show a splash. A Side Quest's key is
## its def_id; the others' key is the kind itself. Changed only by the client lane.
const SPLASH_KINDS: Array[String] = ["side_quest", "tailgate", "baileys"]
## Colour drawn instead of a splash whose file is missing. Changed only by the client lane.
const FALLBACK_COLOR := Color(0.16, 0.13, 0.12)
## Words drawn on FALLBACK_COLOR so a missing picture is visible, not silent. Changed only by the
## client lane (writers may change the words).
const FALLBACK_TEXT: String = "(art coming soon)"
## Fraction of the screen's height, from the top, that a splash keeps clear of UI (0..1). The
## offer's title, text and choices sit below it, on SAFE_PANEL_COLOR. Matches the "safe area" in
## assets/STYLE_GUIDE.md. Changed only by the client lane, together with the guide.
const SAFE_TOP: float = 0.5
## Colour of the panel the choices sit on over a splash: dark and mostly opaque, so text stays
## readable on any picture. Changed only by the client lane.
const SAFE_PANEL_COLOR := Color(0.06, 0.05, 0.05, 0.86)


## Returns the splash key for an offer: its def_id for a Side Quest, its kind for The Tailgate and
## Baileys, or "" when the offer shows no splash (a card reward, the Boss Gear pick, or {}).
## offer: one entry of dude_state.offers, or {}.
static func key_for(offer: Dictionary) -> String:
	# kind: the offer's kind.
	var kind: String = str(offer.get("kind", ""))
	if not SPLASH_KINDS.has(kind):
		return ""
	if kind == "side_quest":
		return str(offer.get("def_id", ""))
	return kind


## Returns true when an offer shows a splash (its own picture or the fallback).
## offer: one entry of dude_state.offers, or {}.
static func shows_splash(offer: Dictionary) -> bool:
	return SPLASH_KINDS.has(str(offer.get("kind", "")))


## Returns a splash key's texture, or null when it has no file (the screen then draws the fallback).
## key: a splash key from key_for().
static func texture_for(key: String) -> Texture2D:
	# path: where its file would be.
	var path: String = splash_path(key)
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Returns the path a splash's file would have, or "" when the key is not a plain snake_case id (so
## no data value can reach a path outside SPLASH_DIR).
## key: a splash key.
static func splash_path(key: String) -> String:
	if key.is_empty() or not key.is_valid_ascii_identifier() or key.to_lower() != key:
		return ""
	return SPLASH_DIR.path_join(key + SPLASH_EXTENSION)
