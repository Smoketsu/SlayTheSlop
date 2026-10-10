## Shapes of the events the rules core returns from apply(). Shared contract.
##
## Events describe what happened, in order, so the client can animate it. They never
## carry instructions: the client must be able to ignore any event and still show the
## correct state afterwards (it can always redraw from the returned state).
##
## Every event is a Dictionary with a "type" key plus the fields listed for its type in TYPES.
## The GDD names three examples (damage dealt, status applied, enemy died); the rest of this
## starting catalogue is [added] so the core and client lanes can work in parallel. Expect
## additions: add a type here, in a contract PR, before emitting it.
##
## Ids in events: Dudes are referred to by player_id ("p1"), enemies by uid ("e3"),
## cards by card_uid ("c12"). A field named *_id or target_id may hold either a player_id
## or an enemy uid.
##
## Who may change this file: a contract PR (see CLAUDE.md "Shared contracts").
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")

## Event type -> its fields (besides "type").
const TYPES := {
	# A fight began. enemy_uids: the enemies, left to right.
	"fight_started": {"enemy_uids": {"list_of": TYPE_STRING}},
	# A new turn began (step 1 of the turn flow). turn: the new turn number, from 1.
	"turn_started": {"turn": TYPE_INT},
	# An enemy chose what it will do. enemy_uid: who. move_id: the move. target_ids: who it is aimed at.
	"intent_set": {"enemy_uid": TYPE_STRING, "move_id": TYPE_STRING, "target_ids": {"list_of": TYPE_STRING}},
	# A player's discard pile was shuffled into their draw pile. player_id: whose.
	"deck_shuffled": {"player_id": TYPE_STRING},
	# A card moved between piles. from / to: one of draw_pile, hand, discard_pile, tapped_pile, or "deck" when it is removed from or added to the run deck.
	"card_moved": {"player_id": TYPE_STRING, "card_uid": TYPE_STRING, "from": TYPE_STRING, "to": TYPE_STRING},
	# A new card copy was created (a reward, or Junk such as Paperwork). to: the pile it was put in.
	"card_created": {"player_id": TYPE_STRING, "card_uid": TYPE_STRING, "def_id": TYPE_STRING, "to": TYPE_STRING},
	# A card was played. target_id: as in the request, "" for none. Its effects follow as their own events.
	"card_played": {"player_id": TYPE_STRING, "card_uid": TYPE_STRING, "target_id": TYPE_STRING},
	# A Dude's Hype changed. delta: the change (negative when spent). hype: the new value.
	"hype_changed": {"player_id": TYPE_STRING, "delta": TYPE_INT, "hype": TYPE_INT},
	# Someone's Guard changed. delta: the change. guard: the new value.
	"guard_changed": {"target_id": TYPE_STRING, "delta": TYPE_INT, "guard": TYPE_INT},
	# One hit landed (GDD example). amount: damage after step 4 of the damage order, before Guard.
	# blocked: how much Guard absorbed. hp_lost: what came off HP. source_id: "" for damage with no attacker (Burn, Bedbugs).
	"damage_dealt": {"source_id": TYPE_STRING, "target_id": TYPE_STRING, "amount": TYPE_INT, "blocked": TYPE_INT, "hp_lost": TYPE_INT},
	# Someone healed. amount: HP actually restored. hp: the new value.
	"healed": {"target_id": TYPE_STRING, "amount": TYPE_INT, "hp": TYPE_INT},
	# A status, Ick or Broken Arm changed (GDD example "status applied"). status: a status id from README.md
	# ("ick" and "broken_arm" included). delta: the change. stacks: the new total, 0 when it wore off.
	"status_changed": {"target_id": TYPE_STRING, "status": TYPE_STRING, "delta": TYPE_INT, "stacks": TYPE_INT},
	# An enemy reached its Ick threshold. new_threshold: its raised threshold.
	"grossed_out": {"enemy_uid": TYPE_STRING, "new_threshold": TYPE_INT},
	# An enemy lost its next attack to being Armless (once per fight).
	"armless": {"enemy_uid": TYPE_STRING},
	# An enemy carried out a move. move_id: the move.
	"enemy_acted": {"enemy_uid": TYPE_STRING, "move_id": TYPE_STRING},
	# An enemy skipped its action. reason: "grossed_out" or "armless".
	"enemy_skipped": {"enemy_uid": TYPE_STRING, "reason": TYPE_STRING},
	# An enemy joined the fight. index: its position in the left-to-right list.
	"enemy_spawned": {"enemy_uid": TYPE_STRING, "def_id": TYPE_STRING, "index": TYPE_INT},
	# An enemy died (GDD example).
	"enemy_died": {"enemy_uid": TYPE_STRING},
	# A Dude reached 0 HP.
	"dude_passed_out": {"player_id": TYPE_STRING},
	# The shared Bro Meter changed. delta: the change. bro_meter: the new value.
	"bro_meter_changed": {"delta": TYPE_INT, "bro_meter": TYPE_INT},
	# A Dude's Dolla Bills changed. delta: the change. dolla_bills: the new value.
	"dolla_bills_changed": {"player_id": TYPE_STRING, "delta": TYPE_INT, "dolla_bills": TYPE_INT},
	# A player pressed or released Ready.
	"ready_changed": {"player_id": TYPE_STRING, "ready": TYPE_BOOL},
	# The fight ended. result: "won" or "lost".
	"fight_ended": {"result": TYPE_STRING},
}


## Builds an event Dictionary. Use this rather than writing the literal, so the type is checked in tests.
## type: a key of TYPES. fields: that type's fields.
static func make(type: String, fields: Dictionary) -> Dictionary:
	# event: the result, the fields plus "type".
	var event: Dictionary = fields.duplicate()
	event["type"] = type
	return event


## Checks an event's shape. Returns a list of problems; empty means valid.
## event: the value to check. path: label for messages.
static func check(event: Variant, path: String = "event") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	if typeof(event) != TYPE_DICTIONARY or typeof(event.get("type")) != TYPE_STRING:
		errors.append("%s: expected a Dictionary with a String 'type'" % path)
		return errors
	if not TYPES.has(event["type"]):
		errors.append("%s.type: unknown event type %s (add it to core/schema/event.gd)" % [path, event["type"]])
		return errors
	# spec: this type's fields plus "type" itself.
	var spec: Dictionary = TYPES[event["type"]].duplicate()
	spec["type"] = TYPE_STRING
	return Shape.check(event, spec, path)
