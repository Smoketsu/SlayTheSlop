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


## [added, task 041] Returns the play_card request play_card() would make next, without raising the
## counter, so the screen can ask the core whether it would be accepted (Core.validate()) and never
## send it. crunch is false, as in play_card().
## card_uid: the card copy in hand. target_id: the target to ask about, or "".
func probe_play_card(card_uid: String, target_id: String) -> Dictionary:
	return _build("play_card", {"card_uid": card_uid, "target_id": target_id, "crunch": false})


## Returns a set_ready request.
## ready: true to end the turn.
func set_ready(ready: bool) -> Dictionary:
	return _next("set_ready", {"ready": ready})


## Returns a use_brew request.
## slot: the Brew slot, from 0. target_id: the picked target, or "".
func use_brew(slot: int, target_id: String) -> Dictionary:
	return _next("use_brew", {"slot": slot, "target_id": target_id})


## Returns a use_bro_move request. target_id is sent only when not "" (it is optional in
## request.gd; Chest Bump needs an enemy, G33).
## target_id: the picked target, or "".
func use_bro_move(target_id: String = "") -> Dictionary:
	return _next("use_bro_move", {"target_id": target_id} if target_id != "" else {})


## Adds the common fields, raises the counter, and returns the request.
## type: the request type. fields: that type's own fields.
func _next(type: String, fields: Dictionary) -> Dictionary:
	# request: the result.
	var request: Dictionary = _build(type, fields)
	next_seq += 1
	return request


## [added, task 041] Returns a request with the common fields and the current next_seq, without
## raising the counter. _next() and probe_play_card() share it so both build the same shape.
## type: the request type. fields: that type's own fields; not changed.
func _build(type: String, fields: Dictionary) -> Dictionary:
	# request: the result.
	var request: Dictionary = fields.duplicate()
	request["type"] = type
	request["player_id"] = player_id
	request["seq"] = next_seq
	return request
