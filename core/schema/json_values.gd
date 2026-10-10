## JSON helpers for content data. Shared contract.
##
## Godot's JSON parser returns every number as a float: 3 comes back as 3.0. The rules
## use ints for game values, so content text must go through parse() here, which turns
## every whole-number float back into an int. A number written with a fraction, such as
## 1.5, stays a float.
##
## Consequence for data authors: 2.0 in a JSON file is read as the int 2. Floats only
## exist where the value really has a fraction (multipliers in constants.json).
##
## JSON is for content data only. Do not use it for state snapshots: JSON numbers are
## doubles, so ints above 2^53 (seeds, random stream states) would be corrupted.
## Snapshots use var_to_bytes / bytes_to_var instead; see core/schema/README.md.
##
## Pure: works on text already read by the caller. No file access.
extends RefCounted


## Parses JSON text and normalizes its numbers.
## text: the JSON source.
## Returns {"ok": bool, "value": parsed value or null, "error": "" or "line N: message"}.
static func parse(text: String) -> Dictionary:
	# json: parser instance, kept so its error line and message can be reported.
	var json := JSON.new()
	# status: Godot error code from the parse, OK on success.
	var status: Error = json.parse(text)
	if status != OK:
		return {"ok": false, "value": null,
			"error": "line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	return {"ok": true, "value": normalize(json.data), "error": ""}


## Returns a deep copy of value with every whole-number float turned into an int.
## value: any JSON-shaped value (Dictionary, Array, String, float, bool or null).
static func normalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			# number: the float under inspection.
			var number: float = value
			if is_finite(number) and number == floorf(number) and absf(number) <= 9007199254740992.0:
				return int(number)
			return number
		TYPE_ARRAY:
			# out: normalized copy of the array.
			var out: Array = []
			for item: Variant in value:
				out.append(normalize(item))
			return out
		TYPE_DICTIONARY:
			# out: normalized copy of the dictionary, keys unchanged.
			var out: Dictionary = {}
			for key: Variant in value.keys():
				out[key] = normalize(value[key])
			return out
		_:
			return value
