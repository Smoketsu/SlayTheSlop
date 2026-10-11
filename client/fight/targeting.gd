## What a card asks the player to pick before it is played (task 018). Lane: client (Agent B).
##
## Follows the card definition's "target" (core/schema/card_def.gd TARGETS):
##   enemy                    -> the player picks a living enemy.
##   ally (Assist cards)      -> the player picks a Dude; in solo it is the player's own Dude
##                               without asking (GDD "Card types and keywords": Assist). Task
##                               ally-pick: the fight screen asks only when more than one Dude is
##                               not Passed Out (mode_in_state()), as the core accepts any such Dude,
##                               the player's own included, and refuses a Passed Out one (G62).
##   all_enemies, self, none  -> nothing to pick; target_id is "".
##   puppet                   -> Grube only, not in the solo slice; treated as nothing to pick.
## The core decides legality; this only decides what to ask.
## Task upgraded-card-display: callers pass a card copy's effective definition (core/combat/
## upgrades.gd definition_of()), which is {} for a copy with no usable definition; a definition
## without "target" is treated as "none" (nothing to pick) and the core refuses the card.
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
	match card.get("target", NONE):
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
	return player_id if card.get("target", NONE) == "ally" and party_size == 1 else ""


## [added, task ally-pick] Returns the player_ids of the Dudes an "ally" card may target: every Dude
## not Passed Out, the local player's own included (G62, as core/combat/play.gd targets() checks),
## in seat order (state "dudes" order). Reads only.
## state: a run state with a fight in it.
static func pickable_dudes(state: Dictionary) -> Array[String]:
	# ids: the result.
	var ids: Array[String] = []
	for dude: Dictionary in state["dudes"]:
		if not dude["passed_out"]:
			ids.append(dude["player_id"])
	return ids


## [added, task ally-pick] Returns what the player must pick for this card in this state: NONE, ENEMY
## or DUDE. Like mode(), except that an "ally" card asks for a Dude only when more than one Dude is
## pickable (pickable_dudes()); with one (solo, or a co-op teammate Passed Out) it asks nothing and
## auto_target_in_state() gives the target. Reads only.
## card: the card definition. state: a run state with a fight in it.
static func mode_in_state(card: Dictionary, state: Dictionary) -> String:
	if card.get("target", NONE) == "ally":
		return DUDE if pickable_dudes(state).size() > 1 else NONE
	return mode(card, state["party_size"])


## [added, task ally-pick] Returns the target_id to send when mode_in_state() is NONE: the local
## player's own id for an "ally" card (the only pickable Dude, since a Passed Out player cannot play
## cards), otherwise "".
## card: the card definition. player_id: the local player.
static func auto_target_in_state(card: Dictionary, player_id: String) -> String:
	return player_id if card.get("target", NONE) == "ally" else ""
