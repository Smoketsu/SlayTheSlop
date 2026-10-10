## Player-facing words for the fight screen, in the GDD's themed terms. Lane: client (Agent B).
## Writers may change any message; codes and status ids come from core/schema and must not change
## here.
extends RefCounted

## Every reject code in core/schema/request.gd REJECT_REASONS -> what the player reads.
## tests/client checks that no code is missing.
const REJECTS := {
	"bad_request": "That move didn't make sense. Try again.",
	"unknown_player": "You're not in this fight, bro.",
	"stale_seq": "Already got that one. Ignoring the echo.",
	"wrong_phase": "Not now. Wait for your turn.",
	"passed_out": "You're Passed Out. Someone has to wake you up.",
	"not_in_hand": "That card isn't in your hand anymore.",
	"unplayable": "That card can't be played.",
	"no_hype": "Not enough Hype.",
	"bad_target": "That target's gone. Pick a new one.",
	"empty_slot": "That Brew slot is empty.",
	"not_ready": "The Bro Meter isn't full yet.",
}

## Status ids (core/schema/README.md "Status ids") -> the GDD's name for them.
const STATUSES := {
	"exposed": "Exposed",
	"noodle_arms": "Noodle Arms",
	"hungover": "Hungover",
	"foggy": "Foggy",
	"broken_arm": "Broken Arm",
	"ick": "Ick",
	"faded": "Faded",
}


## Returns the message for a reject code, or a generic one for a code this build does not know.
## code: a reject reason from the core.
static func reject(code: String) -> String:
	return REJECTS.get(code, "Can't do that right now (%s)." % code)


## Returns the display name of a status id, falling back to the id itself.
## status: a status id such as "noodle_arms".
static func status_name(status: String) -> String:
	return STATUSES.get(status, status.capitalize())
