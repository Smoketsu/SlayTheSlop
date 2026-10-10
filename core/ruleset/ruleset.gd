## Builds the ruleset: the read-only content the rules core runs on (task 005). Lane: core (Agent A).
##
## The core may not read files, so a caller (client, tools, tests) reads every content file and
## passes its text in. build() parses, validates and cross-checks it all and returns either a
## ruleset or every problem it found, each starting with the file path.
##
## Shape of a ruleset (every level read-only, see build()):
##   "constants": Dictionary, constant name -> its "value" from data/constants.json (int, float or
##                bool). The "unit" and "meaning" docs are dropped; keys starting with "_" are skipped.
##   "cards":     Dictionary, card id -> card definition (core/schema/card_def.gd), from data/cards/.
##   "enemies":   Dictionary, enemy id -> enemy definition (core/schema/enemy_def.gd), from data/enemies/.
##   "dudes":     Dictionary, Dude id -> Dude definition (core/schema/dude_def.gd), from data/dudes/.
## Definitions are the parsed JSON (through json_values.parse, so whole numbers are ints),
## unchanged. Keys are inserted in sorted file-path order, so the result is the same on every run.
##
## Cross-checks: a Dude's starter_deck and bro_move, and (task 015) the card_id of every add_card
## effect in cards (effects and trigger lists) and enemy moves, must name cards in the ruleset.
##
## Not checked yet: a Dude's starting_gear. No Gear definition format exists until task 021, so
## data/gear/ is an unknown folder here and Gear ids cannot be resolved. Task 021 adds both.
##
## Pure: works on text the caller already read. No file, clock, network or random access.
extends RefCounted

const JsonValues := preload("res://core/schema/json_values.gd")
const CardDef := preload("res://core/schema/card_def.gd")
const EnemyDef := preload("res://core/schema/enemy_def.gd")
const DudeDef := preload("res://core/schema/dude_def.gd")

## Repo-relative path of the constants file. Fixed by the repository layout; changes only with it.
const CONSTANTS_PATH := "data/constants.json"

## File extension every content file must have.
const EXTENSION := ".json"

## Definition folders the builder knows. Folder (repo path, trailing slash) -> {
##   "key":    ruleset key that holds this kind's definitions by id,
##   "label":  word used in error messages for one definition of this kind,
##   "schema": the core/schema/ script whose check(value, path) validates one definition }.
## A new kind of content is added here only after its schema exists (a core-lane change).
const KINDS := {
	"data/cards/": {"key": "cards", "label": "card", "schema": CardDef},
	"data/enemies/": {"key": "enemies", "label": "enemy", "schema": EnemyDef},
	"data/dudes/": {"key": "dudes", "label": "dude", "schema": DudeDef},
}

## Value types a constant may have: whole numbers, multipliers and switches.
const CONSTANT_TYPES: Array[int] = [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]


## Builds a ruleset from the text of every content file.
## files: Dictionary, repo-relative path (for example "data/cards/tom_punch.json") -> that file's
##   full text as a String. Must include data/constants.json; definition folders may be empty.
## Returns {"ok": bool, "ruleset": Dictionary, "errors": Array[String]}:
##   ok is true when errors is empty. ruleset is the full ruleset (shape in the file header) when
##   ok, and an empty Dictionary otherwise, so a broken set can never be run by accident. ruleset is
##   read-only at every level. errors lists every problem found, in sorted path order, each
##   starting with the path of the file it is about.
static func build(files: Dictionary) -> Dictionary:
	# errors: every problem found, returned at the end.
	var errors: Array[String] = []
	# ruleset: the result being filled; returned only when no error was found.
	var ruleset: Dictionary = {"constants": {}, "cards": {}, "enemies": {}, "dudes": {}}
	# id_paths: ruleset key -> {definition id -> path of the first file that used it}, to report duplicates.
	var id_paths: Dictionary = {}
	for kind: Dictionary in KINDS.values():
		id_paths[kind["key"]] = {}
	# paths: the String keys of files, sorted so processing and errors are in a stable order.
	var paths: Array[String] = []
	# bad_keys: keys of files that are not Strings, as text, sorted for stable messages.
	var bad_keys: Array[String] = []
	for key: Variant in files.keys():
		if typeof(key) == TYPE_STRING:
			paths.append(key)
		else:
			bad_keys.append(var_to_str(key))
	paths.sort()
	bad_keys.sort()
	for key_text: String in bad_keys:
		errors.append("%s: file path must be a String" % key_text)
	if not files.has(CONSTANTS_PATH):
		errors.append("%s: missing; every ruleset needs the tuning constants" % CONSTANTS_PATH)
	for path: String in paths:
		if typeof(files[path]) != TYPE_STRING:
			errors.append("%s: file text must be a String, got %s" % [path, type_string(typeof(files[path]))])
			continue
		if path == CONSTANTS_PATH:
			_add_constants(files[path], path, ruleset["constants"], errors)
			continue
		# folder: the KINDS key this path belongs to, or "" when it is in no known folder.
		var folder: String = _folder_of(path)
		if folder == "":
			errors.append("%s: not in a known data folder (%s) and not %s; a new kind of data needs a schema first" % [
				path, ", ".join(PackedStringArray(KINDS.keys())), CONSTANTS_PATH])
			continue
		if not path.ends_with(EXTENSION):
			errors.append("%s: content files must end in %s" % [path, EXTENSION])
			continue
		_add_definition(files[path], path, KINDS[folder], ruleset, id_paths, errors)
	_check_references(ruleset, id_paths, errors)
	# Task 015: add_card effects must name a card.
	_check_added_cards(ruleset, id_paths, errors)
	if not errors.is_empty():
		ruleset = {}
	freeze(ruleset)
	return {"ok": errors.is_empty(), "ruleset": ruleset, "errors": errors}


## Makes value read-only at every level and returns it. Godot's make_read_only() only protects the
## container it is called on, so every nested Dictionary and Array is frozen too.
## value: any JSON-shaped value; Dictionaries and Arrays are changed in place, others pass through.
static func freeze(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			for key: Variant in value.keys():
				freeze(value[key])
			value.make_read_only()
		TYPE_ARRAY:
			for item: Variant in value:
				freeze(item)
			value.make_read_only()
	return value


## Returns the KINDS key (folder) that directly contains path, or "" when there is none.
## A file in a sub-folder, such as data/cards/old/x.json, is in no known folder.
## path: repo-relative file path.
static func _folder_of(path: String) -> String:
	for folder: String in KINDS.keys():
		if path.begins_with(folder) and not path.trim_prefix(folder).contains("/"):
			return folder
	return ""


## Parses data/constants.json and puts each constant's value into constants.
## text: the file's text. path: its repo path, for messages.
## constants: the ruleset's constants Dictionary, filled here.
## errors: the list problems are appended to.
static func _add_constants(text: String, path: String, constants: Dictionary, errors: Array[String]) -> void:
	# parsed: the parse result, numbers normalized.
	var parsed: Dictionary = JsonValues.parse(text)
	if not parsed["ok"]:
		errors.append("%s: %s" % [path, parsed["error"]])
		return
	if typeof(parsed["value"]) != TYPE_DICTIONARY:
		errors.append("%s: expected a JSON object of constants" % path)
		return
	# names: the constant names, sorted so the constants map and messages are in a stable order.
	var names: Array = parsed["value"].keys()
	names.sort()
	for name: String in names:
		if name.begins_with("_"):
			continue
		# entry: one constant's {value, unit, meaning} record.
		var entry: Variant = parsed["value"][name]
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("value"):
			errors.append("%s: %s: expected {value, unit, meaning}" % [path, name])
			continue
		if not CONSTANT_TYPES.has(typeof(entry["value"])):
			errors.append("%s: %s: value must be a number or true/false, got %s" % [
				path, name, type_string(typeof(entry["value"]))])
			continue
		constants[name] = entry["value"]


## Parses and checks one definition file and, when it is valid, adds it to the ruleset.
## text: the file's text. path: its repo path, for messages.
## kind: the KINDS entry for the file's folder.
## ruleset: the ruleset being built; the definition goes into ruleset[kind.key].
## id_paths: ruleset key -> {id -> first path using it}; updated here to catch duplicate ids.
## errors: the list problems are appended to.
static func _add_definition(text: String, path: String, kind: Dictionary, ruleset: Dictionary,
		id_paths: Dictionary, errors: Array[String]) -> void:
	# parsed: the parse result, numbers normalized.
	var parsed: Dictionary = JsonValues.parse(text)
	if not parsed["ok"]:
		errors.append("%s: %s" % [path, parsed["error"]])
		return
	# found: the schema problems with this definition.
	var found: Array[String] = kind["schema"].check(parsed["value"], "%s: %s" % [path, kind["label"]])
	if not found.is_empty():
		errors.append_array(found)
		return
	# definition: the valid parsed definition.
	var definition: Dictionary = parsed["value"]
	# id: the definition's id field.
	var id: String = definition["id"]
	# file_id: the file name without its extension, which must equal id.
	var file_id: String = path.get_file().trim_suffix(EXTENSION)
	# ok: false once this file has an id problem, so it is not added.
	var ok: bool = true
	if id != file_id:
		errors.append("%s: %s.id: \"%s\" must equal the file name \"%s\"" % [path, kind["label"], id, file_id])
		ok = false
	# seen: id -> first path, for this kind.
	var seen: Dictionary = id_paths[kind["key"]]
	if seen.has(id):
		errors.append("%s: %s.id: duplicate id \"%s\", already used by %s" % [path, kind["label"], id, seen[id]])
		ok = false
	else:
		seen[id] = path
	if ok:
		ruleset[kind["key"]][id] = definition


## Checks that ids named inside definitions exist: each Dude's starter_deck entries and bro_move
## must be cards in the ruleset. starting_gear is not checked until a Gear format exists (task 021).
## ruleset: the ruleset built so far (only valid definitions are in it).
## id_paths: ruleset key -> {id -> path}, used to name the Dude's file in messages.
## errors: the list problems are appended to.
static func _check_references(ruleset: Dictionary, id_paths: Dictionary, errors: Array[String]) -> void:
	# cards: card id -> definition, the ids references must name.
	var cards: Dictionary = ruleset["cards"]
	# dude_ids: Dude ids, sorted for stable messages.
	var dude_ids: Array = ruleset["dudes"].keys()
	dude_ids.sort()
	for dude_id: String in dude_ids:
		# dude: the Dude definition being checked.
		var dude: Dictionary = ruleset["dudes"][dude_id]
		# path: the Dude's file, for messages.
		var path: String = id_paths["dudes"][dude_id]
		for i: int in dude["starter_deck"].size():
			if not cards.has(dude["starter_deck"][i]):
				errors.append("%s: dude.starter_deck[%d]: card \"%s\" is not a valid card in data/cards/" % [
					path, i, dude["starter_deck"][i]])
		if not cards.has(dude["bro_move"]):
			errors.append("%s: dude.bro_move: card \"%s\" is not a valid card in data/cards/" % [path, dude["bro_move"]])


## Task 015: checks that every add_card effect names a card in the ruleset. Looks at each card's
## effects and trigger lists (card_def.gd TRIGGER_FIELDS) and each enemy move's effects. Effects that
## are not Dictionaries or have no String card_id are left to Ops.check(), which reports them.
## ruleset: the ruleset built so far (only valid definitions are in it).
## id_paths: ruleset key -> {id -> path}, used to name the file in messages.
## errors: the list problems are appended to.
static func _check_added_cards(ruleset: Dictionary, id_paths: Dictionary, errors: Array[String]) -> void:
	# lists: [path, label, effects list] for every effects list to scan, in sorted id order.
	var lists: Array = []
	# card_ids: card ids, sorted for stable messages.
	var card_ids: Array = ruleset["cards"].keys()
	card_ids.sort()
	for card_id: String in card_ids:
		# card: the card definition.
		var card: Dictionary = ruleset["cards"][card_id]
		lists.append([id_paths["cards"][card_id], "card.effects", card["effects"]])
		for field: String in CardDef.TRIGGER_FIELDS:
			if card.has(field):
				lists.append([id_paths["cards"][card_id], "card." + field, card[field]])
	# enemy_ids: enemy ids, sorted for stable messages.
	var enemy_ids: Array = ruleset["enemies"].keys()
	enemy_ids.sort()
	for enemy_id: String in enemy_ids:
		for move: Dictionary in ruleset["enemies"][enemy_id]["moves"]:
			lists.append([id_paths["enemies"][enemy_id], "enemy.moves.%s.effects" % move["id"], move["effects"]])
	for entry: Array in lists:
		for i: int in entry[2].size():
			# effect: one effect of the list.
			var effect: Variant = entry[2][i]
			if typeof(effect) == TYPE_DICTIONARY and effect.get("op") == "add_card" \
					and typeof(effect.get("card_id")) == TYPE_STRING and not ruleset["cards"].has(effect["card_id"]):
				errors.append("%s: %s[%d].card_id: card \"%s\" is not a valid card in data/cards/" % [
					entry[0], entry[1], i, effect["card_id"]])
