## Shapes of the requests a player sends to the rules core (GDD "Network messages",
## client-to-host rows that change game state). Shared contract.
##
## In solo play the client builds these and calls apply() directly; in co-op the host
## receives the same Dictionaries over the network. There is one code path.
##
## Every request has the COMMON fields plus the fields of its type in TYPES, and may have the
## fields of its type in OPTIONAL (task 013).
## join_lobby, ping_card and emote are not here: they never reach the rules core.
##
## Who may change this file: a contract PR (see CLAUDE.md "Shared contracts").
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")

## Fields every request carries.
const COMMON := {
	# Which request this is: a key of TYPES.
	"type": TYPE_STRING,
	# The player sending it, "p1".."p4". Must match a Dude in the state.
	"player_id": TYPE_STRING,
	# Per-player counter, starting at 0 and rising by 1 with every request that player sends.
	# The core rejects a seq that is not above that Dude's last_seq ("stale_seq").
	"seq": TYPE_INT,
}

## Request type -> its own fields (in addition to COMMON). Meanings are from the GDD table.
const TYPES := {
	"pick_dude": {
		# Which Dude the player wants: a file id in data/dudes/.
		"dude_id": TYPE_STRING,
	},
	"vote_node": {
		# The map node the player votes for. Format set by the run lane's map: the id ("r<row>c<column>")
		# of one of the links of the node the party stands on (task 025, core/run/node_flow.gd).
		"node_id": TYPE_STRING,
	},
	"play_card": {
		# The specific card copy to play, a card_uid in the player's hand.
		"card_uid": TYPE_STRING,
		# The chosen enemy uid, Dude player_id, or (later) Puppet id; "" when the card has no target.
		"target_id": TYPE_STRING,
		# True if the player pays the Crunch cost. Nate only; always false in the solo slice.
		"crunch": TYPE_BOOL,
	},
	"use_brew": {
		# Which Brew slot to drink, 0..brew_slots-1.
		"slot": TYPE_INT,
		# Target if the Brew needs one, otherwise "".
		"target_id": TYPE_STRING,
	},
	"use_bro_move": {},
	"set_ready": {
		# True when the player is done with the turn. In solo, true ends the player phase.
		"ready": TYPE_BOOL,
	},
	"choose_reward": {
		# Which reward screen the choice is for. Format set by the run lane (task 025): the "id" of one
		# of the player's open offers in dude_state.offers. Every node choice uses this request: card
		# rewards, the Boss Gear pick, The Tailgate (Nap or Lift), Baileys (each purchase, a removal,
		# leaving) and Side Quests (safe or dumb).
		"reward_id": TYPE_STRING,
		# Which option was picked: an index into the offer's options, 0 or more, or -1 to skip (a card
		# reward) or leave (Baileys). -1 is refused (bad_target) for an offer whose "skippable" is false.
		"choice_index": TYPE_INT,
	},
}

## [added, task 013] Request type -> fields it MAY carry (in addition to COMMON and TYPES), with
## their types. A request without them is still well-formed, so older senders keep working.
const OPTIONAL := {
	"use_bro_move": {
		# The chosen enemy uid when the Dude's Bro Move card has target "enemy" (Chest Bump), the
		# player's own id or "" for "self", "" otherwise. Missing means "".
		"target_id": TYPE_STRING,
	},
	"choose_reward": {
		# [added, task 025] The card the picked option acts on: one of the option's card_uids, for a
		# "lift" (The Tailgate) or "remove" (Baileys) option. Required for those two kinds, refused
		# (bad_target) with any other. Missing means "".
		"card_uid": TYPE_STRING,
	},
}

## Reason codes the core returns when it refuses a request. Short, snake_case, stable:
## the client maps them to messages. no_hype and bad_target are from the GDD; the rest are
## [added]. Add new codes here in a contract PR.
const REJECT_REASONS: Array[String] = [
	"bad_request",   # Malformed: unknown type, missing field, wrong field type.
	"unknown_player", # player_id matches no Dude in the state.
	"stale_seq",     # seq is not above the Dude's last_seq (duplicate or out of order).
	"wrong_phase",   # The request is not allowed right now (for example play_card outside the player phase).
	"passed_out",    # The Dude is Passed Out and cannot act.
	"not_in_hand",   # card_uid is not in the player's hand.
	"unplayable",    # The card cannot be played (cost -1, or a rule such as Detention forbids it).
	"no_hype",       # Not enough Hype for the card's cost.
	"bad_target",    # target_id is missing, dead, or not a legal target for this card.
	"empty_slot",    # use_brew names a slot with no Brew in it.
	"not_ready",     # use_bro_move while the Bro Meter is below BRO_METER_MAX.
]
# [added, task 025] The run flow's requests reuse the codes above, so the client's message for every
# code keeps working (tests/client checks one exists per code):
#   wrong_phase  vote_node outside run_phase "map"; choose_reward outside run_phase "node", or naming
#                no open offer of this player; pick_dude (the lobby is not built).
#   bad_target   vote_node names no link of the party's node, or a node the ruleset has nothing for
#                (no encounter or Side Quest); choose_reward's choice_index is out of range, -1 on an
#                offer whose "skippable" is false, an option whose "available" is false, or a missing
#                or wrong card_uid for a "lift" or "remove" option (or any card_uid for another kind).
#   unplayable   a Baileys option costs more Dolla Bills than the Dude holds, or a Shake is bought
#                with every Brew slot full.
# Separate codes (bad_node, unknown_reward, bad_choice, no_dolla_bills, no_slot) are proposed for a
# later contract PR made together with the client's messages for them (docs/tasks/025-run-flow.md).


## Checks a request's shape (not whether it is legal right now; that is the core's job).
## Returns a list of problems; empty means well-formed.
## request: the value to check. path: label for messages.
static func check(request: Variant, path: String = "request") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	if typeof(request) != TYPE_DICTIONARY or typeof(request.get("type")) != TYPE_STRING:
		errors.append("%s: expected a Dictionary with a String 'type'" % path)
		return errors
	# kind: the request type name.
	var kind: String = request["type"]
	if not TYPES.has(kind):
		errors.append("%s.type: unknown request type %s" % [path, kind])
		return errors
	# spec: COMMON merged with this type's own fields.
	var spec: Dictionary = COMMON.duplicate()
	spec.merge(TYPES[kind])
	return Shape.check(request, spec, path, OPTIONAL.get(kind, {}))
