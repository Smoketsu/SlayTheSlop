## Shape of one Dude's state during a run (GDD "Dude state"). Shared contract.
##
## One of these exists per player, in run_state.dudes. Nothing in it is specific to Tom.
## Fields only another Dude uses (abs_ready, auras, puppets, scaffolding, nap_turns ...)
## are not here yet; they are added, additively, when that Dude is built.
##
## Fields marked [added] are not in the GDD table; they are needed to implement the
## GDD's rules and are listed in docs/changes/2026-10-10-001.md.
##
## Who may change values: only the rules core (core/), through apply(). The client and
## tools read this state and never write it.
extends RefCounted

const Shape := preload("res://core/schema/shape.gd")

## Required fields and their types. Comments give meaning, unit and range.
const SPEC := {
	# The network player who controls this Dude. "p1".."p4", by seat order. Never changes during a run.
	"player_id": TYPE_STRING,
	# Which Dude this is: the id of a file in data/dudes/, for example "tom". Never changes during a run.
	"dude_id": TYPE_STRING,
	# Current hit points, 0..max_hp. Carried between fights.
	"hp": TYPE_INT,
	# Maximum hit points. Starts at the Dude's max_hp; Gear can raise it.
	"max_hp": TYPE_INT,
	# Damage absorbed before HP. 0 or more. Reset to 0 at Refresh.
	"guard": TYPE_INT,
	# Hype left to spend this turn. 0 or more.
	"hype": TYPE_INT,
	# Hype granted at Refresh. Starts at constant BASE_HYPE (3).
	"hype_per_turn": TYPE_INT,
	# Cards drawn at Refresh. Starts at constant BASE_DRAW (5).
	"draw_per_turn": TYPE_INT,
	# Added to every hit of every attack (GDD "Stats"). Base 0.
	"swole": TYPE_INT,
	# Added to Guard gained from each card. Base 0.
	"chill": TYPE_INT,
	# Added to the Dude's signature effect (Tom: Ick applied). Base 0.
	"clout": TYPE_INT,
	# Status id -> stack count, for example {"exposed": 2}. Stacks are 1 or more; a status at 0 is removed.
	# Status ids are listed in core/schema/README.md.
	"statuses": {"map_of": TYPE_INT},
	# [added] Every card_uid this Dude owns for the run, in the order acquired. The deck a fight starts from.
	"deck": {"list_of": TYPE_STRING},
	# [added] card_uid -> card instance (see CARD_SPEC). Holds every card this Dude has, including
	# fight-only Junk such as Paperwork. Every uid in deck and in the four piles is a key here.
	"cards": {"map_of": TYPE_DICTIONARY},
	# Cards waiting to be drawn, as card_uids. Index 0 is the top: the next card drawn.
	"draw_pile": {"list_of": TYPE_STRING},
	# Cards in hand, as card_uids, in the order they arrived.
	"hand": {"list_of": TYPE_STRING},
	# Discarded cards, as card_uids. The last entry is the most recently discarded.
	"discard_pile": {"list_of": TYPE_STRING},
	# Cards removed for the rest of the fight by Tapped, as card_uids.
	"tapped_pile": {"list_of": TYPE_STRING},
	# Cards played this turn. Reset at Refresh. Used by Noise Complaint, Detention and the solo Bro Meter.
	"cards_played_this_turn": TYPE_INT,
	# Ids of Gear owned, in the order gained. Ids are files in data/gear/.
	"gear": {"list_of": TYPE_STRING},
	# Brew ids held, one per filled slot, in slot order. Length is at most brew_slots.
	"brews": {"list_of": TYPE_STRING},
	# How many Brews can be held. Base 3 (GDD "Items"). Not a tuning constant yet; see docs/proposals/solo-slice-rule-gaps.md.
	"brew_slots": TYPE_INT,
	# Currency held (GDD "dolla_bills"), a whole number of Dolla Bills, 0 or more.
	"dolla_bills": TYPE_INT,
	# True at 0 HP. The Dude skips turns until woken.
	"passed_out": TYPE_BOOL,
	# True once the player has ended their turn. Cleared at Refresh.
	"ready": TYPE_BOOL,
	# [added] The seq of the last request from this player that core APPLIED, -1 before any. A rejected
	# request leaves it unchanged (the whole state is unchanged), so its seq may be reused. Lets core
	# drop duplicates: a request with seq <= last_seq is rejected as "stale_seq". Set only by core.
	"last_seq": TYPE_INT,
	# [added, task 013] card_uids of the Power cards this Dude has played in the current fight, oldest
	# first. A played Power leaves the four piles and stays here, active, for the rest of the fight
	# (GDD "Card types and keywords": a Power "lasts the rest of the fight"); its definition's
	# power_triggers say what it does (core/schema/card_def.gd). Every uid here is a key of cards and
	# is in none of the four piles. Emptied when the next fight starts. Changed only by the rules core.
	"powers": {"list_of": TYPE_STRING},
	# [added, task 013] Damage, 0 or more, that each enemy hit on this Dude deals back to the enemy that
	# landed it ("enemies that hit Tom take 3 damage", Chrome Dome; G9: per hit). Not attack damage
	# (G3). Raised by the "thorns" op; reset to 0 at this Dude's Refresh, so it lasts "this turn",
	# including the enemy phase that follows. Changed only by the rules core.
	"thorns": TYPE_INT,
}

## Shape of one card instance, the values in the "cards" map. [added]
const CARD_SPEC := {
	# Id of the card definition in data/cards/, for example "tom_punch". Never changes.
	"def_id": TYPE_STRING,
	# True once the card has been Lifted (upgraded) at a Tailgate. The definition's "upgrade" then applies.
	"upgraded": TYPE_BOOL,
}

## Names of the four combat piles, in a fixed order, for code that walks all of them.
const PILES: Array[String] = ["draw_pile", "hand", "discard_pile", "tapped_pile"]


## Returns a Dude state with every field present and zero or empty values.
## The rules core fills in real values (HP, Hype, deck) from content data and constants
## when a run starts; this function deliberately knows no tuning numbers.
## player_id: the controlling player, "p1".."p4". dude_id: which Dude, for example "tom".
static func blank(player_id: String, dude_id: String) -> Dictionary:
	return {
		"player_id": player_id,
		"dude_id": dude_id,
		"hp": 0,
		"max_hp": 0,
		"guard": 0,
		"hype": 0,
		"hype_per_turn": 0,
		"draw_per_turn": 0,
		"swole": 0,
		"chill": 0,
		"clout": 0,
		"statuses": {},
		"deck": [],
		"cards": {},
		"draw_pile": [],
		"hand": [],
		"discard_pile": [],
		"tapped_pile": [],
		"cards_played_this_turn": 0,
		"gear": [],
		"brews": [],
		"brew_slots": 0,
		"dolla_bills": 0,
		"passed_out": false,
		"ready": false,
		"last_seq": -1,
		"powers": [],
		"thorns": 0,
	}


## Checks a Dude state's shape and its card bookkeeping. Returns a list of problems; empty means valid.
## dude: the value to check. path: label for messages, for example "dudes[0]".
static func check(dude: Variant, path: String = "dude") -> Array[String]:
	# errors: problems found, returned at the end.
	var errors: Array[String] = Shape.check(dude, SPEC, path)
	if not errors.is_empty():
		return errors
	# cards: the card instance map, checked entry by entry.
	var cards: Dictionary = dude["cards"]
	for uid: String in cards.keys():
		errors.append_array(Shape.check(cards[uid], CARD_SPEC, "%s.cards.%s" % [path, uid]))
	# seen: card_uids already found in a pile, to catch a card in two places at once.
	var seen: Dictionary = {}
	for pile: String in PILES:
		for uid: String in dude[pile]:
			if not cards.has(uid):
				errors.append("%s.%s: %s is not in cards" % [path, pile, uid])
			if seen.has(uid):
				errors.append("%s.%s: %s is also in %s" % [path, pile, uid, seen[uid]])
			seen[uid] = pile
	# Task 013: active Powers are out of the four piles, so a uid may not be in both.
	for uid: String in dude["powers"]:
		if not cards.has(uid):
			errors.append("%s.powers: %s is not in cards" % [path, uid])
		if seen.has(uid):
			errors.append("%s.powers: %s is also in %s" % [path, uid, seen[uid]])
		seen[uid] = "powers"
	if dude["thorns"] < 0:
		errors.append("%s.thorns: %d is below 0" % [path, dude["thorns"]])
	for uid: String in dude["deck"]:
		if not cards.has(uid):
			errors.append("%s.deck: %s is not in cards" % [path, uid])
	for status: String in dude["statuses"].keys():
		if dude["statuses"][status] <= 0:
			errors.append("%s.statuses.%s: stacks must be 1 or more" % [path, status])
	return errors
