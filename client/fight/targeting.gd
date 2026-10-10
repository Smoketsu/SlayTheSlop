## What a card asks the player to pick before it is played (task 018). Lane: client (Agent B).
##
## Follows the card definition's "target" (core/schema/card_def.gd TARGETS):
##   enemy                    -> the player picks a living enemy.
##   ally (Assist cards)      -> the player picks a Dude; in solo it is the player's own Dude
##                               without asking (GDD "Card types and keywords": Assist).
##   all_enemies, self, none  -> nothing to pick; target_id is "".
##   puppet                   -> Grube only, not in the solo slice; treated as nothing to pick.
## The core decides legality; this only decides what to ask.
extends RefCounted

## Pick mode: nothing to pick.
const NONE := "none"
## Pick mode: the player picks an enemy.
const ENEMY := "enemy"
## Pick mode: the player picks a Dude.
const DUDE := "dude"


## Returns what the player must pick for this card: NONE, ENEMY or DUDE.
## card: the card definition. party_size: players in the run, 1-4.
static func mode(card: Dictionary, party_size: int) -> String:
	match card["target"]:
		"enemy":
			return ENEMY
		"ally":
			return DUDE if party_size > 1 else NONE
		_:
			return NONE


## Returns the target_id to send when mode() is NONE: the player's own id for an ally card in solo,
## otherwise "".
## card: the card definition. player_id: the local player. party_size: players in the run.
static func auto_target(card: Dictionary, player_id: String, party_size: int) -> String:
	return player_id if card["target"] == "ally" and party_size == 1 else ""
