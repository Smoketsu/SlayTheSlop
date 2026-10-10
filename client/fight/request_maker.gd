## Builds the requests one local player sends, with player_id and a rising seq (task 018).
## Lane: client (Agent B).
##
## core/schema/request.gd: seq starts at 0 and rises by 1 with every request a player sends, and
## the core rejects one that is not above the Dude's last_seq. So the counter starts just above the
## state's last_seq and rises on every request made, applied or not.
extends RefCounted

## The local player these requests come from, "p1".."p4". Set once in _init.
var player_id: String
## The seq the next request will carry. Starts at the Dude's last_seq + 1; only next() raises it.
var next_seq: int


## Starts a request maker for one player.
## player: the local player's id. last_seq: that Dude's last_seq in the current state (-1 at start).
func _init(player: String, last_seq: int) -> void:
	player_id = player
	next_seq = last_seq + 1


## Returns a play_card request. crunch is always false (Nate only, not in the solo slice).
## card_uid: the card copy in hand. target_id: the picked target, or "".
func play_card(card_uid: String, target_id: String) -> Dictionary:
	return _next("play_card", {"card_uid": card_uid, "target_id": target_id, "crunch": false})


## Returns a set_ready request.
## ready: true to end the turn.
func set_ready(ready: bool) -> Dictionary:
	return _next("set_ready", {"ready": ready})


## Returns a use_brew request.
## slot: the Brew slot, from 0. target_id: the picked target, or "".
func use_brew(slot: int, target_id: String) -> Dictionary:
	return _next("use_brew", {"slot": slot, "target_id": target_id})


## Returns a use_bro_move request.
func use_bro_move() -> Dictionary:
	return _next("use_bro_move", {})


## Adds the common fields, raises the counter, and returns the request.
## type: the request type. fields: that type's own fields.
func _next(type: String, fields: Dictionary) -> Dictionary:
	# request: the result.
	var request: Dictionary = fields.duplicate()
	request["type"] = type
	request["player_id"] = player_id
	request["seq"] = next_seq
	next_seq += 1
	return request
