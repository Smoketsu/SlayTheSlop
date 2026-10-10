## Tests for the run flow's event lines in client/fight/event_text.gd (the 14 task 025 event types).
## Lane: tools/client (Agent B).
extends "res://tests/framework/test_case.gd"

const EventText := preload("res://client/fight/event_text.gd")
const Event := preload("res://core/schema/event.gd")

## A tiny ruleset with only the fields names_for() reads: one Dude, one card, one Brew, one Side Quest.
const RULESET := {
	"cards": {"x_card": {"name": "Test Card"}},
	"enemies": {},
	"gear": {},
	"brews": {"x_brew": {"name": "Test Brew"}},
	"side_quests": {"x_quest": {"name": "Test Quest"}},
	"dudes": {"x_dude": {"name": "Test Dude"}},
}

## A run state outside a fight with only the fields names_for() reads: one Dude holding one card
## copy "c1", and a two-node map (entrance r0c0, a Baileys at r1c0).
const STATE := {
	"dudes": [{"player_id": "p1", "dude_id": "x_dude", "cards": {"c1": {"def_id": "x_card"}}}],
	"map": {"floor": 1, "nodes": [
		{"id": "r0c0", "row": 0, "column": 0, "type": "start", "links": ["r1c0"]},
		{"id": "r1c0", "row": 1, "column": 0, "type": "baileys", "links": []},
	]},
	"combat": null,
}


## Returns the line for an event built with Event.make, after checking its shape, with names from
## RULESET and STATE. type: an Event.TYPES key. fields: its fields.
func _line(type: String, fields: Dictionary) -> String:
	# event: the built event.
	var event: Dictionary = Event.make(type, fields)
	assert_no_errors(Event.check(event), type)
	return EventText.line(event, EventText.names_for(RULESET, [STATE]))


## Run lines fill ids with display names: a Dude, a card copy, a map node, a Side Quest and a code.
func test_run_lines_resolve_names() -> void:
	assert_eq(_line("vote_cast", {"player_id": "p1", "node_id": "r1c0"}), "Test Dude votes for Baileys.")
	assert_eq(_line("node_entered", {"node_id": "r1c0", "node_type": "baileys"}), "The party heads into Baileys.")
	assert_eq(_line("offer_opened", {"player_id": "p1", "reward_id": "o1", "kind": "tailgate"}), "Test Dude has a choice: Nap or Lift.")
	assert_eq(_line("card_upgraded", {"player_id": "p1", "card_uid": "c1"}), "Test Card is upgraded.")
	assert_eq(_line("side_quest_rolled", {"player_id": "p1", "side_quest_id": "x_quest", "percent": 35, "won": false}), "Test Quest: 35% chance... it doesn't.")
	assert_eq(_line("pending_status_added", {"player_id": "p1", "status": "hungover", "stacks": 3}), "Test Dude will start the next fight with 3 Hungover.")
	assert_eq(_line("floor_started", {"floor": 1}), "Floor 1 begins.")


## Buying at Baileys never calls the item a Brew or a drink: every Brew there is a Shake (CLAUDE.md,
## GDD G29). item_bought and brew_gained (which follows a Shake bought at Baileys) name only the Brew.
func test_baileys_lines_say_no_brew_or_drink() -> void:
	# bought: the line for a purchase of 30 Dolla Bills.
	var bought: String = _line("item_bought", {"player_id": "p1", "reward_id": "o1", "choice_index": 2, "price": 30})
	assert_eq(bought, "Test Dude pays 30 Dolla Bills at Baileys.")
	# gained: the line for the Brew that goes into slot 0.
	var gained: String = _line("brew_gained", {"player_id": "p1", "brew_id": "x_brew", "slot": 0})
	assert_eq(gained, "Test Dude stashes Test Brew for later.")
	# placeholder: a {field} or {field@} in a template, removed before looking for words.
	var placeholder := RegEx.create_from_string("\\{[^}]*\\}")
	for type: String in ["item_bought", "brew_gained"]:
		# words: the template's own words, without its placeholders.
		var words: String = placeholder.sub(EventText.TEMPLATES[type], "", true).to_lower()
		for word: String in ["brew", "beer", "drink"]:
			assert_false(words.contains(word), "%s template says %s" % [type, word])


## Every template's placeholders name real fields of its event type: a line built from any event of
## that type has no "{" left over.
func test_every_template_fills_every_placeholder() -> void:
	# names: display names for the fixed ruleset and state.
	var names: Dictionary = EventText.names_for(RULESET, [STATE])
	for type: String in Event.TYPES:
		# fields: a sample value for each of this type's fields, by its declared type.
		var fields: Dictionary = {}
		for field: String in Event.TYPES[type]:
			# spec: the field's declared type (an int TYPE_* or a {"list_of": ...} Dictionary).
			var spec: Variant = Event.TYPES[type][field]
			if typeof(spec) == TYPE_DICTIONARY:
				fields[field] = []
			elif spec == TYPE_INT:
				fields[field] = 1
			elif spec == TYPE_BOOL:
				fields[field] = true
			else:
				fields[field] = "x"
		# text: the filled line.
		var text: String = EventText.line(Event.make(type, fields), names)
		assert_false(text.contains("{"), "%s line has an unfilled placeholder: %s" % [type, text])
