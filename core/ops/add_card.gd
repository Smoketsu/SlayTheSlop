## The "add_card" effect operation (task 015). Lane: core (Agent A). Catalogue: core/ops/README.md.
##
## Creates new copies of a card for a Dude: Junk from enemies (Skeleton Intern shuffles Paperwork
## into the target's deck, Hall Monitor Golem adds Detention to a discard pile), from Brews (Special
## Brownie adds a Hangover) and from cards.
##
## Fields: card_id (text: a card definition id), to ("draw_pile", "discard_pile" or "hand"),
## shuffle_in (bool, optional, default false, only with to "draw_pile": put each copy at a random
## position of the draw pile instead of on top), count (int, 1 or more, optional, default 1),
## lasts (text, optional, task 033: "fight" makes every copy last this fight only, even when its
## definition lasts the run; Beer Helmet's Hangover, I7). Without lasts a copy lasts as its
## definition says. A copy can be made to last less than its definition, never more, so "fight" is
## the only value (LASTS_VALUES).
##
## Recipient: when the actor is a Dude (a card, a Brew, a card trigger), that Dude, whatever the
## card's target is. When the actor is an enemy, every Dude among the effect's targets (the intent's
## target_ids that are not Passed Out). Passed Out Dudes get nothing.
##
## Each copy gets a fresh card_uid ("c" + run_state.next_uid, next_uid rises by 1) and goes into the
## Dude's cards map (not upgraded). If it lasts the run (its definition lasts "run", card_def.gd
## DEFAULT_LASTS when left out, and the effect has no lasts "fight") it also joins the end of the
## Dude's run deck; a fight-only copy does not, and is removed when the fight ends because it is not
## in the run deck (core/combat/card_triggers.gd). No state field marks it: dude_state.deck is
## "every card_uid this Dude owns for the run". Then it goes to the pile:
##   draw_pile: on top (index 0), or with shuffle_in at a position from 0 (top) to the pile's size
##              (bottom), each equally likely, drawn from the RECEIVING Dude's "shuffle" stream;
##   discard_pile: on top of the discard pile (the end of the list);
##   hand: the end of the hand. This is not a draw: on_draw triggers do not run.
## Copies are made one at a time, recipient by recipient, so with count 2 each copy draws its own
## position. Emits card_created per copy (to = the pile).
##
## A card_id the ruleset does not have creates nothing; core/ruleset/ruleset.gd reports such ids
## when the content is built, so it cannot happen with valid content. If the shuffle stream is
## missing (only in a hand-built state) the copy goes on top.
##
## Changes the working copy it is given (see core/combat/bodies.gd). Pure: randomness only through
## core/rng/rng.gd.
extends RefCounted

const Event := preload("res://core/schema/event.gd")
const CardDef := preload("res://core/schema/card_def.gd")
const Rng := preload("res://core/rng/rng.gd")
const Bodies := preload("res://core/combat/bodies.gd")

## True: from an enemy move this op lands on Dudes, so the move's intent is aimed at Dudes.
const NEEDS_TARGET: bool = true

## Copies per effect when the effect has no "count" field. Not a tuning number: "one card" is what
## an add_card effect without a count means.
const DEFAULT_COUNT: int = 1

## Prefix of a card_uid; must equal core/combat/party.gd CARD_UID_PREFIX (core/schema/README.md "Ids").
const CARD_UID_PREFIX: String = "c"

## The card_def.gd LASTS value of a copy that lasts one fight only. Changed only with card_def.gd LASTS.
const FIGHT_ONLY: String = "fight"

## Piles a copy may be put in (the "to" field). Changed only by the core lane, with README.md.
const DESTINATIONS: Array[String] = ["draw_pile", "discard_pile", "hand"]

## Task 033: values the optional "lasts" field may have. Only FIGHT_ONLY: a copy may be made to last
## less than its definition says, never more. Changed only by the core lane, with README.md.
const LASTS_VALUES: Array[String] = [FIGHT_ONLY]

## The one destination shuffle_in may be used with.
const SHUFFLE_DESTINATION: String = "draw_pile"

## Fields an add_card effect may have, besides "op", and their types. Anything else is an error.
const FIELDS := {
	# Id of the card definition to copy, for example "junk_paperwork". Must be a card in the ruleset.
	"card_id": TYPE_STRING,
	# One of DESTINATIONS: the pile each copy goes to.
	"to": TYPE_STRING,
	# Optional, default false. true puts each copy at a random draw-pile position (to "draw_pile" only).
	"shuffle_in": TYPE_BOOL,
	# Optional, default DEFAULT_COUNT. Copies made per recipient, 1 or more.
	"count": TYPE_INT,
	# Task 033. Optional, one of LASTS_VALUES ("fight"): every copy lasts this fight only, whatever
	# its definition's lasts. Left out: the definition decides.
	"lasts": TYPE_STRING,
}


## Returns the problems with an add_card effect's fields; empty means it can run.
## effect: one entry of a card's or move's effects. path: label for messages.
static func check(effect: Dictionary, path: String) -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = []
	for field: Variant in effect.keys():
		if field != "op" and not FIELDS.has(field):
			errors.append("%s.%s: unknown field for op add_card" % [path, field])
	if typeof(effect.get("card_id")) != TYPE_STRING or effect["card_id"] == "":
		errors.append("%s.card_id: must be a card id" % path)
	if typeof(effect.get("to")) != TYPE_STRING or not DESTINATIONS.has(effect["to"]):
		errors.append("%s.to: must be one of %s" % [path, str(DESTINATIONS)])
	if effect.has("shuffle_in"):
		if typeof(effect["shuffle_in"]) != TYPE_BOOL:
			errors.append("%s.shuffle_in: must be true or false" % path)
		elif effect["shuffle_in"] and effect.get("to") != SHUFFLE_DESTINATION:
			errors.append("%s.shuffle_in: only works with to \"%s\"" % [path, SHUFFLE_DESTINATION])
	if effect.has("count") and (typeof(effect["count"]) != TYPE_INT or effect["count"] < 1):
		errors.append("%s.count: must be an int, 1 or more" % path)
	if effect.has("lasts") and (typeof(effect["lasts"]) != TYPE_STRING or not LASTS_VALUES.has(effect["lasts"])):
		errors.append("%s.lasts: must be one of %s" % [path, str(LASTS_VALUES)])
	return errors


## Runs an add_card effect (see the file header): count copies for each recipient Dude.
## state: the working copy. effect: an add_card effect that passed check().
## context: {"actor_id": who uses the card or move, "targets": ids it lands on when the actor is an
##           enemy, "cards": ruleset.cards, read-only, to look up the copied definition}.
## events: the event list, appended to.
static func run(state: Dictionary, effect: Dictionary, context: Dictionary, events: Array) -> void:
	# definition: the card being copied, or {} when the ruleset lacks it.
	var definition: Dictionary = context.get("cards", {}).get(effect["card_id"], {})
	if definition.is_empty():
		return
	# fight_only: task 033, true when the effect makes every copy last this fight only.
	var fight_only: bool = effect.get("lasts", "") == FIGHT_ONLY
	for player_id: String in recipients(state, context):
		for copy: int in effect.get("count", DEFAULT_COUNT):
			create_in_place(state, Bodies.dude_index(state, player_id), definition,
				effect["to"], effect.get("shuffle_in", false), events, fight_only)


## True when copies of this card last one fight only (definition lasts "fight"); false for
## "run" or no lasts field (card_def.gd DEFAULT_LASTS). Reads only.
## definition: a card definition.
static func is_fight_only(definition: Dictionary) -> bool:
	return definition.get("lasts", CardDef.DEFAULT_LASTS) == FIGHT_ONLY


## Returns the player_ids an add_card effect lands on: the actor when it is a Dude who is not
## Passed Out, otherwise the Dudes among context.targets who are not Passed Out, in target order.
## Reads only.
## state: the run state. context: the op context (actor_id, targets).
static func recipients(state: Dictionary, context: Dictionary) -> Array:
	# ids: the result.
	var ids: Array = []
	# candidates: the actor if it is a Dude, else the targets.
	var candidates: Array = [context["actor_id"]] if Bodies.dude_index(state, context["actor_id"]) != -1 else context.get("targets", [])
	for id: String in candidates:
		if Bodies.dude_index(state, id) != -1 and not Bodies.find_alive(state, id).is_empty():
			ids.append(id)
	return ids


## Makes one new copy of a card for one Dude and puts it in a pile (see the file header). Emits
## card_created. Returns the new card_uid. Callable by other core code that grants a card (the run
## lane's rewards may reuse it).
## state: the working copy; next_uid and rng change. dude_index: the receiving Dude's seat, 0-based.
## definition: the card definition being copied (from ruleset.cards).
## to: one of DESTINATIONS. shuffle_in: true for a random draw-pile position (to "draw_pile" only).
## events: the event list, appended to. fight_only: task 033, true to make this copy last this
## fight only even when its definition lasts the run (it then stays out of the run deck); false
## (the default) lets the definition decide.
static func create_in_place(state: Dictionary, dude_index: int, definition: Dictionary, to: String,
		shuffle_in: bool, events: Array, fight_only: bool = false) -> String:
	# dude: the receiving Dude, inside state.
	var dude: Dictionary = state["dudes"][dude_index]
	# uid: the new copy's card_uid.
	var uid: String = CARD_UID_PREFIX + str(state["next_uid"])
	state["next_uid"] += 1
	dude["cards"][uid] = {"def_id": definition["id"], "upgraded": false}
	if not fight_only and not is_fight_only(definition):
		dude["deck"].append(uid)
	match to:
		"draw_pile":
			# position: where the copy goes in the draw pile, 0 = top.
			var position: int = 0
			if shuffle_in:
				# drawn: next_int's result over 0..size, from the receiver's shuffle stream.
				var drawn: Dictionary = Rng.next_int(state, Rng.key_for("shuffle", dude["player_id"]), 0, dude["draw_pile"].size())
				if drawn["error"] == Rng.NO_ERROR:
					state["rng"] = drawn["state"]["rng"]
					position = drawn["value"]
			dude["draw_pile"].insert(position, uid)
		"discard_pile":
			dude["discard_pile"].append(uid)
		"hand":
			dude["hand"].append(uid)
	events.append(Event.make("card_created", {"player_id": dude["player_id"], "card_uid": uid,
		"def_id": definition["id"], "to": to}))
	return uid
