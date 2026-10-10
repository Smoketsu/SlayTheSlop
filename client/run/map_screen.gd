## Map screen (task 020): floor 1's nodes and links from run_state.map, the party's position, and a
## vote_node request when the player picks a linked node. Interface: client/run/run_screen_api.md.
## Lane: client (Agent B). Skeleton; filled in by task 020's map work.
extends Control

## Emitted with {"type": "vote_node", "node_id": <id>} when the player picks a node. The run screen
## adds player_id and seq. request: the request's type and own fields (core/schema/request.gd).
signal request_made(request: Dictionary)


## Redraws the map from a run state snapshot; reads only.
## ruleset: the read-only content. state: the run state. player_id: the local player.
func show_state(ruleset: Dictionary, state: Dictionary, player_id: String) -> void:
	pass
