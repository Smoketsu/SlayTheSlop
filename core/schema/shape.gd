## Type checker shared by every file in core/schema/. Shared contract.
##
## A "spec" is a Dictionary from field name to the type that field must have.
## A spec value is one of:
##   - a Variant.Type constant such as TYPE_INT
##   - an Array of Variant.Type constants: any one of them is allowed (TYPE_NIL means null is allowed)
##   - {"list_of": TYPE_X}: an Array whose every element has type TYPE_X
##   - {"map_of": TYPE_X}: a Dictionary with String keys whose every value has type TYPE_X
##
## Checks are strict: an int field holding 3.0 is an error. That is deliberate, because
## Godot's JSON parser returns floats for every number (see json_values.gd).
##
## Pure: no file, clock, network or random access.
extends RefCounted


## Checks one Dictionary against a spec. Returns a list of problems; empty means valid.
## value: the thing to check; anything that is not a Dictionary is one error.
## spec: required fields and their types.
## path: label for this value in messages, for example "dudes[0]".
## optional: fields that may be missing, with their types when present. Defaults to none.
## Keys found in neither spec nor optional are errors, so every field must be declared.
static func check(value: Variant, spec: Dictionary, path: String, optional: Dictionary = {}) -> Array[String]:
	# errors: problems found so far, returned at the end.
	var errors: Array[String] = []
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s: expected Dictionary, got %s" % [path, type_string(typeof(value))])
		return errors
	# keys: the fields of value, sorted so messages come out in a stable order.
	var keys: Array = value.keys()
	keys.sort()
	for field: Variant in keys:
		if typeof(field) != TYPE_STRING:
			errors.append("%s: field name %s is not a String" % [path, var_to_str(field)])
		elif not spec.has(field) and not optional.has(field):
			errors.append("%s.%s: unknown field (add it to the schema first)" % [path, field])
	# required: spec field names, sorted for stable messages.
	var required: Array = spec.keys()
	required.sort()
	for field: String in required:
		if not value.has(field):
			errors.append("%s.%s: missing" % [path, field])
		else:
			errors.append_array(check_type(value[field], spec[field], "%s.%s" % [path, field]))
	# optional_keys: optional field names, sorted for stable messages.
	var optional_keys: Array = optional.keys()
	optional_keys.sort()
	for field: String in optional_keys:
		if value.has(field):
			errors.append_array(check_type(value[field], optional[field], "%s.%s" % [path, field]))
	return errors


## Checks one value against one spec entry (see the file header for the forms).
## value: the value to check. rule: the spec entry. path: label for messages.
static func check_type(value: Variant, rule: Variant, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	match typeof(rule):
		TYPE_INT:
			if typeof(value) != rule:
				errors.append("%s: expected %s, got %s (%s)" % [
					path, type_string(rule), type_string(typeof(value)), var_to_str(value)])
		TYPE_ARRAY:
			if not rule.has(typeof(value)):
				# names: readable names of the allowed types.
				var names: PackedStringArray = []
				for t: int in rule:
					names.append(type_string(t))
				errors.append("%s: expected one of %s, got %s" % [path, "/".join(names), type_string(typeof(value))])
		TYPE_DICTIONARY:
			if rule.has("list_of"):
				if typeof(value) != TYPE_ARRAY:
					errors.append("%s: expected Array, got %s" % [path, type_string(typeof(value))])
				else:
					for i: int in value.size():
						errors.append_array(check_type(value[i], rule["list_of"], "%s[%d]" % [path, i]))
			elif rule.has("map_of"):
				if typeof(value) != TYPE_DICTIONARY:
					errors.append("%s: expected Dictionary, got %s" % [path, type_string(typeof(value))])
				else:
					for key: Variant in value.keys():
						if typeof(key) != TYPE_STRING:
							errors.append("%s: key %s is not a String" % [path, var_to_str(key)])
						else:
							errors.append_array(check_type(value[key], rule["map_of"], "%s.%s" % [path, key]))
			else:
				errors.append("%s: bad schema rule %s" % [path, var_to_str(rule)])
		_:
			errors.append("%s: bad schema rule %s" % [path, var_to_str(rule)])
	return errors


## Checks that value is one of the allowed entries. Returns a list of problems.
## value: the value to check. allowed: the permitted values. path: label for messages.
static func check_one_of(value: Variant, allowed: Array, path: String) -> Array[String]:
	# errors: one entry if value is not allowed, otherwise empty.
	var errors: Array[String] = []
	if not allowed.has(value):
		errors.append("%s: %s is not one of %s" % [path, var_to_str(value), str(allowed)])
	return errors
