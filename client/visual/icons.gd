## Looks up the small icon of a stat, status, intent kind or pile by its key (task 057).
## Lane: client (Agent B).
##
## One table for every badge, intent and pile icon on the fight screen, like client/visual/
## sprites.gd for characters. Keys are the GDD field names and core ids as written (guard, swole,
## chill, broken_arms, ick, the status ids of core/schema/README.md "Status ids", the intent kinds of
## core/schema/enemy_def.gd MOVE_SPEC "intent"), plus a few client keys for things that have no field
## of their own (the piles, the target marker, a skipped action). Art lives in
## res://assets/placeholder/icons/<file>.svg (assets/placeholder/README.md "Icons"). A key with no
## entry, or whose file is missing, falls back to a short text badge: never an error. Pure lookup:
## reads files only through ResourceLoader, never touches game state.
extends RefCounted

const Messages := preload("res://client/fight/messages.gd")

## Folder the icons are read from, one "<file>.svg" each. Changed only by the client lane, together
## with assets/placeholder/README.md.
const ICON_DIR: String = "res://assets/placeholder/icons"
## File extension of an icon, with the dot. Changed only by the client lane.
const ICON_EXTENSION: String = ".svg"
## Key -> how to show it. Changed only by the client lane.
##   "file": the icon's file name in ICON_DIR, without the extension. Several keys may share a file.
##   "name": the player-facing name used in tooltips, in the GDD's themed terms. Optional for a
##           status id: Messages.status_name() names it then, so status names live in one place.
## Tooltip text beyond the name is task 045's.
const ICONS := {
	# Stats (GDD "Stats") and other per-body fields (core/schema/dude_state.gd, enemy_state.gd).
	"hp": {"file": "heart", "name": "HP"},
	"guard": {"file": "shield", "name": "Guard"},
	"swole": {"file": "flex", "name": "Swole"},
	"chill": {"file": "snowflake", "name": "Chill"},
	"clout": {"file": "crown", "name": "Clout"},
	"hype": {"file": "hype_orb", "name": "Hype"},
	# Statuses (core/schema/README.md "Status ids"). Broken Arm and Ick are stored in their own
	# fields, so they are keyed by field name; STATUS_FIELDS maps their status ids here.
	"exposed": {"file": "bullseye"},
	"noodle_arms": {"file": "noodle"},
	"hungover": {"file": "queasy"},
	"foggy": {"file": "cloud"},
	"faded": {"file": "ghost"},
	"broken_arms": {"file": "broken_bone", "name": "Broken Arm"},
	"ick": {"file": "stink", "name": "Ick"},
	# Intent kinds (core/schema/enemy_def.gd MOVE_SPEC "intent", and every kind data/enemies/ uses).
	"attack": {"file": "sword", "name": "Attack"},
	"defend": {"file": "shield", "name": "Defend"},
	"buff": {"file": "arrow_up", "name": "Buff"},
	"debuff": {"file": "arrow_down", "name": "Debuff"},
	"summon": {"file": "summon", "name": "Summon"},
	"charge": {"file": "hourglass", "name": "Charging"},
	"flee": {"file": "flee", "name": "Flee"},
	"unknown": {"file": "question", "name": "Unknown"},
	# Client keys: an intent the enemy will skip (core/combat/statuses.gd skip_reason()), the marker
	# naming an attack's target and the matching marker over each Dude in co-op (tinted by seat), the
	# Bro Meter, and the three piles (GDD "Turn flow"; Tapped is the GDD's word for exhausted cards).
	"skipped": {"file": "zzz", "name": "Skips its turn"},
	"target": {"file": "aim", "name": "Aiming at"},
	"seat": {"file": "aim", "name": "Seat"},
	"bro_meter": {"file": "fist_bump", "name": "Bro Meter"},
	"draw_pile": {"file": "draw_pile", "name": "Draw pile"},
	"discard_pile": {"file": "discard_pile", "name": "Discard pile"},
	"tapped_pile": {"file": "tapped_pile", "name": "Tapped"},
}
## Status ids that are stored in a field of their own (core/schema/README.md "Status ids") -> that
## field's key in ICONS. Changed only by the client lane, when core/schema/README.md moves a status.
const STATUS_FIELDS := {
	"broken_arm": "broken_arms",
}
## Most letters of a fallback text badge (a key with no icon). Changed only by the client lane.
const SHORT_LETTERS: int = 3


## Returns how to show a key: {"texture": its icon, or null when it has none (draw "short" instead),
## "name": the player-facing name, "short": up to SHORT_LETTERS capital letters for the text
## fallback, "key": the ICONS key used (STATUS_FIELDS applied)}. Never fails, whatever the key.
## key: a GDD field name, status id, intent kind or client key from ICONS; anything else falls back.
static func look(key: String) -> Dictionary:
	# used: the key after mapping a status id to its field.
	var used: String = STATUS_FIELDS.get(key, key)
	# entry: the ICONS entry, or {} when there is none.
	var entry: Dictionary = ICONS.get(used, {})
	# name: the tooltip name.
	var name: String = entry.get("name", Messages.status_name(used))
	return {"texture": _load(entry.get("file", "")), "name": name, "short": short_text(name), "key": used}


## Returns true when a key has an ICONS entry whose file exists (status ids are mapped through
## STATUS_FIELDS first).
## key: as for look().
static func has_icon(key: String) -> bool:
	return look(key)["texture"] != null


## Returns the fallback text of a name: its first SHORT_LETTERS letters, in capitals ("?" for an
## empty name).
## name: a player-facing name, such as "Noodle Arms".
static func short_text(name: String) -> String:
	# letters: the name without spaces and punctuation.
	var letters: String = ""
	for character: String in name:
		if character.to_upper() != character.to_lower():
			letters += character
	return letters.substr(0, SHORT_LETTERS).to_upper() if letters != "" else "?"


## Returns the path an icon file would have, or "" when the name is not a plain snake_case name (so
## no data value can reach a path outside ICON_DIR).
## file: an ICONS "file" value.
static func icon_path(file: String) -> String:
	if file.is_empty() or not file.is_valid_ascii_identifier() or file.to_lower() != file:
		return ""
	return ICON_DIR.path_join(file + ICON_EXTENSION)


## Returns an icon file's texture, or null when it has no file.
## file: an ICONS "file" value, or "".
static func _load(file: String) -> Texture2D:
	# path: where its file would be.
	var path: String = icon_path(file)
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
