## Upgraded cards: what a Lifted card does (task 025). Lane: core (Agent A).
##
## A card definition's "upgrade" (core/schema/card_def.gd) maps field paths to their new values after
## the card is Lifted at The Tailgate, for example {"effects[0].amount": 11} (GDD "Example card
## definition", Arm Bar 8 -> 11). A card copy is upgraded when its instance in dude_state.cards has
## "upgraded": true; the run lane sets that (Lift, The Unlabeled Brownie). This file turns a
## definition into its upgraded form, and every place that reads a copy's definition in a fight goes
## through definition_of(), so an upgraded copy plays, triggers and keeps its keywords as upgraded.
##
## Path grammar: field names separated by ".", each optionally followed by one or more "[index]"
## (an index into a list), for example "effects[0].amount", "cost", "power_triggers[1].effects[0].stacks".
## Every step must already exist (a key of a Dictionary, an index inside a list), and the new value
## must have the same type as the old one, so an upgrade only ever changes numbers and texts that are
## there. The upgraded definition must still pass core/schema/card_def.gd check().
##
## G15 (answered "accept"): Lift is only offered for cards whose upgrade is not empty. A card whose
## upgrade is empty or broken (a path that does not exist, a type change) cannot be upgraded
## (can_upgrade() is false), and a copy marked upgraded anyway has no definition here ({}), so the
## fight refuses it as "unplayable" rather than guessing.
##
## Pure: no file, clock, network or random access. Nothing here changes its arguments.
extends RefCounted

const CardDef := preload("res://core/schema/card_def.gd")

## Separator between the field names of a path. Part of the path grammar above; never changes.
const PATH_SEPARATOR: String = "."

## Character that opens a list index in a path step ("effects[0]"). Part of the path grammar.
const INDEX_OPEN: String = "["

## Character that closes a list index in a path step. Part of the path grammar.
const INDEX_CLOSE: String = "]"


## Returns the definition a Dude's card copy plays with: the ruleset's definition, upgraded when the
## copy's instance says "upgraded". Returns {} when the Dude does not own the copy, the ruleset lacks
## its definition, or the copy is upgraded but its definition cannot be upgraded.
## rules: the ruleset, or any Dictionary holding its "cards" (an op context from core/ops/ops.gd).
## dude: the owner's Dude state. card_uid: a key of dude.cards.
static func definition_of(rules: Dictionary, dude: Dictionary, card_uid: String) -> Dictionary:
	if not dude["cards"].has(card_uid):
		return {}
	# instance: the copy's {def_id, upgraded}.
	var instance: Dictionary = dude["cards"][card_uid]
	# definition: the card's definition, or {}.
	var definition: Dictionary = rules.get("cards", {}).get(instance["def_id"], {})
	if definition.is_empty() or not instance["upgraded"]:
		return definition
	# lifted: upgraded()'s result.
	var lifted: Dictionary = upgraded(definition)
	return lifted["definition"] if lifted["ok"] else {}


## True when the card can be upgraded: its upgrade is not empty and applies cleanly (G15).
## definition: a card definition.
static func can_upgrade(definition: Dictionary) -> bool:
	return not definition.get("upgrade", {}).is_empty() and upgraded(definition)["ok"]


## Returns the upgraded form of a card definition. Paths are applied in sorted order, so the result
## never depends on the order the upgrade map was written in.
## definition: a card definition (core/schema/card_def.gd); not changed.
## Returns {"ok": true, "definition": a new upgraded copy, "error": ""}, or {"ok": false,
## "definition": {}, "error": why} when the upgrade is empty or a path or value is not allowed.
static func upgraded(definition: Dictionary) -> Dictionary:
	# upgrade: path -> new value.
	var upgrade: Dictionary = definition.get("upgrade", {})
	if upgrade.is_empty():
		return {"ok": false, "definition": {}, "error": "the card has no upgrade"}
	# result: the writable deep copy being upgraded.
	var result: Dictionary = definition.duplicate(true)
	# paths: the upgrade's paths, sorted.
	var paths: Array = upgrade.keys()
	paths.sort()
	for path: Variant in paths:
		if typeof(path) != TYPE_STRING:
			return {"ok": false, "definition": {}, "error": "upgrade path %s is not text" % var_to_str(path)}
		# error: why this path could not be set, or "".
		var error: String = _set_path(result, path, upgrade[path])
		if error != "":
			return {"ok": false, "definition": {}, "error": "upgrade %s: %s" % [path, error]}
	# problems: the upgraded card's schema problems.
	var problems: Array[String] = CardDef.check(result, "upgraded card")
	if not problems.is_empty():
		return {"ok": false, "definition": {}, "error": problems[0]}
	return {"ok": true, "definition": result, "error": ""}


## Sets one path in a definition, in place. Returns "" on success or why it failed.
## root: the writable definition copy. path: one upgrade path. value: its new value.
static func _set_path(root: Dictionary, path: String, value: Variant) -> String:
	# steps: the path as a list of String keys and int indexes.
	var steps: Array = _steps(path)
	if steps.is_empty():
		return "not a valid path"
	# container: the Dictionary or Array that holds the next step.
	var container: Variant = root
	for i: int in steps.size():
		# step: a key (String) or an index (int).
		var step: Variant = steps[i]
		# found: whether the step exists in container.
		var found: bool = false
		if typeof(step) == TYPE_STRING and typeof(container) == TYPE_DICTIONARY:
			found = container.has(step)
		elif typeof(step) == TYPE_INT and typeof(container) == TYPE_ARRAY:
			found = step >= 0 and step < container.size()
		if not found:
			return "step %s does not exist" % str(step)
		if i == steps.size() - 1:
			if typeof(container[step]) != typeof(value):
				return "the new value must have the same type as the old one"
			container[step] = value
			return ""
		container = container[step]
	return "not a valid path"


## Splits a path into its steps: field names as Strings, list indexes as ints. Returns [] when the
## path does not follow the grammar in the file header.
## path: one upgrade path, for example "effects[0].amount".
static func _steps(path: String) -> Array:
	# steps: the result.
	var steps: Array = []
	for part: String in path.split(PATH_SEPARATOR):
		# open: where the first index starts in this part, or -1.
		var open: int = part.find(INDEX_OPEN)
		# name: the field name before any index.
		var name: String = part if open == -1 else part.substr(0, open)
		if not name.is_valid_ascii_identifier():
			return []
		steps.append(name)
		# rest: the "[n][m]" tail of the part.
		var rest: String = "" if open == -1 else part.substr(open)
		while rest != "":
			# close: where this index ends.
			var close: int = rest.find(INDEX_CLOSE)
			if not rest.begins_with(INDEX_OPEN) or close == -1:
				return []
			# digits: the index's text.
			var digits: String = rest.substr(1, close - 1)
			if digits == "" or not digits.is_valid_int() or digits.begins_with("-") or digits.begins_with("+"):
				return []
			steps.append(digits.to_int())
			rest = rest.substr(close + 1)
	return steps
