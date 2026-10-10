## Offer screen (task 020): the local player's first open choice in dude_state.offers (a card
## reward, the Boss Gear pick, The Tailgate, Baileys or a Side Quest), drawn from the offer's own
## options and prices, sending choose_reward. Interface: client/run/run_screen_api.md.
## Lane: client (Agent B). Skeleton; filled in by task 020's offer work.
extends Control

## Emitted with {"type": "choose_reward", "reward_id": <offer id>, "choice_index": <index or -1>}
## and, for a Lift or a removal, "card_uid". The run screen adds player_id and seq.
## request: the request's type and own fields (core/schema/request.gd).
signal request_made(request: Dictionary)


## Redraws the offer from a run state snapshot; reads only.
## ruleset: the read-only content. state: the run state. player_id: the local player.
func show_state(ruleset: Dictionary, state: Dictionary, player_id: String) -> void:
	pass
