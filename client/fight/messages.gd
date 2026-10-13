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

## [added, task 057] Why an enemy will skip its intended move (core/combat/statuses.gd SKIP_GROSSED_OUT,
## SKIP_FALLEN, SKIP_ARMLESS) -> the words the skipped-intent tooltip uses. Writers may change the
## words; the codes come from the core. tests/client checks that no code is missing.
const SKIP_REASONS := {
	"grossed_out": "Grossed Out",
	"fallen": "fell over",
	"armless": "Armless",
}

## [added, task 047] Banner kinds (client/visual/event_player.gd BANNERS) -> {"title": the big word,
## "line": a smaller line under it, "" for none}. Writers may change the words; the kinds are the
## client's. tests/client checks that no kind is missing. [changed, task 059] The victory banner is a
## short cheer in Smoketsu's words; the profanity lives only here, so it is one line to change if the
## GDD's open rating question goes the other way.
const BANNERS := {
	"your_turn": {"title": "Your turn", "line": ""},
	"enemy_turn": {"title": "Enemy turn", "line": ""},
	"victory": {"title": "FUCK YEAH", "line": "LETS GOOOO"},
	"passed_out": {"title": "Passed Out", "line": "Lights out, bro."},
}

## [added, task 043] Fight piles (core/schema/dude_state.gd PILES, the three the pile viewer opens)
## -> the note under the viewer's title. The draw pile is shown sorted, never in draw order, and says
## so. Writers may change the words; the keys are the schema's pile names.
const PILE_NOTES := {
	"draw_pile": "Sorted by type, then name. The draw order stays a secret.",
	"discard_pile": "Oldest first. The latest one is at the end.",
	"tapped_pile": "Gone for the rest of the fight.",
}

## [added, task 041] Card types (core/schema/card_def.gd TYPES) -> the label on a card face, in the
## GDD "Card types and keywords" terms. tests/client checks that no type is missing.
const CARD_TYPES := {
	"attack": "Attack",
	"skill": "Skill",
	"power": "Power",
	"aura": "Aura",
	"junk": "Junk",
}

## [added, task 041] Card rarities (core/schema/card_def.gd RARITIES) -> the label on a card face.
## "special" is Junk and Bro Move cards (G17), never offered as a reward. tests/client checks that no
## rarity is missing.
const CARD_RARITIES := {
	"starter": "Starter",
	"common": "Common",
	"uncommon": "Uncommon",
	"rare": "Rare",
	"special": "Special",
}

## Map node types (core/schema/run_state.gd map node "type") -> how a line names that node, in the
## GDD "Node types" terms. Used for node_entered and, through event_text.gd names_for(), vote_cast.
const NODE_TYPES := {
	"start": "the entrance",
	"brawl": "a Brawl",
	"rival": "a Rival fight",
	"side_quest": "a Side Quest",
	"tailgate": "The Tailgate",
	"baileys": "Baileys",
	"loot": "the Loot",
	"boss": "the Boss fight",
}

## Offer kinds (core/schema/dude_state.gd OFFER_KINDS) -> what the choice is, for offer_opened.
const OFFER_KINDS := {
	"card": "pick a card",
	"boss_gear": "pick a Boss Gear",
	"tailgate": "Nap or Lift",
	"baileys": "shop at Baileys",
	"side_quest": "safe or dumb",
}

## side_quest_rolled "won" as text (true when the Side Quest's "then" outcome happens, good or bad)
## -> the end of its line. Neutral on purpose: the "then" outcome is sometimes the bad one.
const SIDE_QUEST_ROLLS := {
	"true": "it happens.",
	"false": "it doesn't.",
}


## Returns the message for a reject code, or a generic one for a code this build does not know.
## code: a reject reason from the core.
static func reject(code: String) -> String:
	return REJECTS.get(code, "Can't do that right now (%s)." % code)


## Returns the display name of a status id, falling back to the id itself.
## status: a status id such as "noodle_arms".
static func status_name(status: String) -> String:
	return STATUSES.get(status, status.capitalize())


## [added, task 041] Returns the card-face label of a card type, falling back to the type code
## capitalized.
## type: a card definition's "type", such as "attack".
static func card_type_name(type: String) -> String:
	return CARD_TYPES.get(type, type.capitalize())


## [added, task 041] Returns the card-face label of a rarity, falling back to the code capitalized.
## rarity: a card definition's "rarity", such as "common".
static func rarity_name(rarity: String) -> String:
	return CARD_RARITIES.get(rarity, rarity.capitalize())


## Returns the player-facing word for an event field whose value is a code rather than an id: a
## status, a node type, an offer kind or a Side Quest roll. Any other field's value comes back as is.
## key: the event field's name, such as "status". value: the field's value as text.
static func field_word(key: String, value: String) -> String:
	match key:
		"status":
			return status_name(value)
		"node_type":
			return NODE_TYPES.get(value, value)
		"kind":
			return OFFER_KINDS.get(value, value)
		"won":
			return SIDE_QUEST_ROLLS.get(value, value)
	return value
