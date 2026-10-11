## Plays the placeholder sound effects (task 055). Lane: client (Agent B).
##
## One lookup table, FILES, from a sound kind to its file in SOUND_DIR, as client/visual/sprites.gd
## does for art. Events pick their sound through kind_for_event(); screens play UI sounds (CLICK) by
## kind. A kind with no file, or a file that is missing or does not load, is silent: play() returns
## "" and never reports an error.
##
## Sounds are fire and forget: play() starts the sound and returns at once. Nothing anywhere waits
## for a sound to end, so a headless run (Godot's dummy audio driver, no device) and the tests are
## never held up by audio. The players live under one node, HOST_NAME, added to the scene tree's
## root on first use (one AudioStreamPlayer per kind, so overlapping sounds of different kinds never
## cut each other off), so a sound outlives the screen that started it (the victory jingle keeps
## playing after the fight screen is replaced). With no scene tree (a plain script) nothing plays.
## Under Godot's dummy audio driver (SILENT_DRIVER: --headless, the tests, CI) the lookup and the
## players are made as usual but the sound is not started, since nothing can hear it and a playback
## still running when Godot quits is reported as a leaked resource.
##
## Volume and mute are not here: client/audio/volume.gd sets them on the Master bus, which every
## player here uses. Reads events only; never reads or changes game state.
extends RefCounted

## Folder the sound files are read from, one "<kind>.wav" per entry of FILES. Changed only by the
## client lane, together with assets/placeholder/README.md "Sounds".
const SOUND_DIR: String = "res://assets/placeholder/sounds"

## Sound kind: a card was played (card_played, or a Bro Move's bro_move_used).
const CARD_PLAYED: String = "card_played"
## Sound kind: a hit took HP (damage_dealt with hp_lost > 0).
const HIT: String = "hit"
## Sound kind: Guard took a hit whole (damage_dealt with hp_lost 0 and blocked > 0).
const BLOCKED: String = "blocked"
## Sound kind: someone gained Guard (guard_changed with delta > 0).
const GUARD: String = "guard"
## Sound kind: an enemy died (enemy_died).
const ENEMY_DEATH: String = "enemy_death"
## Sound kind: a Dude Passed Out (dude_passed_out).
const PASSED_OUT: String = "passed_out"
## Sound kind: the player pressed a button (UI only, never from an event).
const CLICK: String = "click"
## Sound kind: a Dude gained Dolla Bills (dolla_bills_changed with delta > 0).
const DOLLA_BILLS: String = "dolla_bills"
## Sound kind: a fight was won (fight_ended, result "won").
const VICTORY: String = "victory"
## Sound kind: a fight was lost (fight_ended, result "lost"), which ends the run.
const DEFEAT: String = "defeat"

## Sound kind -> its file name in SOUND_DIR. Every kind above has an entry. A kind whose file is
## missing plays nothing. Changed only by the client lane, together with the generator
## (assets/placeholder/source/make_sounds.py SOUNDS) and assets/placeholder/README.md.
const FILES := {
	CARD_PLAYED: "card_played.wav",
	HIT: "hit.wav",
	BLOCKED: "blocked.wav",
	GUARD: "guard.wav",
	ENEMY_DEATH: "enemy_death.wav",
	PASSED_OUT: "passed_out.wav",
	CLICK: "click.wav",
	DOLLA_BILLS: "dolla_bills.wav",
	VICTORY: "victory.wav",
	DEFEAT: "defeat.wav",
}

## Name of the node under the tree's root that holds the players. Changed only by the client lane.
const HOST_NAME: String = "ClientSounds"
## How many copies of one kind may sound at once (AudioStreamPlayer.max_polyphony), 1 or more; a
## further copy cuts off the oldest. Changed only by the client lane.
const POLYPHONY: int = 4
## Bus every sound plays on. Master, so client/audio/volume.gd's volume and mute apply. Changed only
## by the client lane.
const BUS: StringName = &"Master"
## AudioServer.get_driver_name() of Godot's dummy audio driver, used when there is no audio device
## (always with --headless). Fixed by Godot.
const SILENT_DRIVER: String = "Dummy"
## How many kinds recent keeps, 1 or more. Changed only by the client lane.
const RECENT_MAX: int = 32

## The last kinds play() started, oldest first, at most RECENT_MAX. Read by tests and debugging;
## written only by play().
static var recent: Array[String] = []


## Returns the sound kind an event plays, or "" for an event with no sound. Pure: depends on the
## event only. The kinds follow client/visual/event_player.gd effect_for(): a "damage" effect is
## HIT, a "blocked" one that used Guard is BLOCKED, a Guard gain is GUARD, "death" is ENEMY_DEATH
## and "passed_out" is PASSED_OUT; card plays, Dolla Bills gained and a fight's end add their own.
## event: one event from the gateway (core/schema/event.gd).
static func kind_for_event(event: Dictionary) -> String:
	match event.get("type", ""):
		"card_played", "bro_move_used":
			return CARD_PLAYED
		"damage_dealt":
			if event["hp_lost"] > 0:
				return HIT
			return BLOCKED if event["blocked"] > 0 else ""
		"guard_changed":
			return GUARD if event["delta"] > 0 else ""
		"enemy_died":
			return ENEMY_DEATH
		"dude_passed_out":
			return PASSED_OUT
		"dolla_bills_changed":
			return DOLLA_BILLS if event["delta"] > 0 else ""
		"fight_ended":
			return VICTORY if event["result"] == "won" else DEFEAT
	return ""


## Returns the res:// path of a kind's file, or "" for a kind not in FILES.
## kind: a sound kind (one of the constants above).
static func path_for(kind: String) -> String:
	if not FILES.has(kind):
		return ""
	return SOUND_DIR.path_join(FILES[kind])


## Returns a kind's sound, or null when the kind is unknown or its file is missing or not a sound.
## kind: a sound kind.
static func stream_for(kind: String) -> AudioStream:
	return stream_at(path_for(kind))


## Returns the sound at a res:// path, or null when the path is "", has no file, or holds something
## that is not a sound. Never reports an error.
## path: a res:// file path.
static func stream_at(path: String) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


## Starts a kind's sound and returns at once; never waits for it to end. Returns the path played,
## or "" when nothing played (unknown kind, missing file, or no scene tree). Under SILENT_DRIVER it
## does everything but start the player, and returns the path as if it had.
## kind: a sound kind.
static func play(kind: String) -> String:
	# stream: the sound, or null.
	var stream: AudioStream = stream_for(kind)
	if stream == null:
		return ""
	# player: this kind's player under the host, or null with no scene tree.
	var player: AudioStreamPlayer = _player_for(kind, stream)
	if player == null:
		return ""
	if AudioServer.get_driver_name() != SILENT_DRIVER:
		player.play()
	recent.append(kind)
	if recent.size() > RECENT_MAX:
		recent = recent.slice(-RECENT_MAX)
	return path_for(kind)


## Plays an event's sound (kind_for_event()), if it has one. Returns what play() returns, "" for an
## event with no sound.
## event: one event from the gateway.
static func play_event(event: Dictionary) -> String:
	# kind: the event's sound kind, or "".
	var kind: String = kind_for_event(event)
	return "" if kind == "" else play(kind)


## Returns the host node holding the players, making it under the tree's root on first use; null
## when there is no scene tree.
static func host() -> Node:
	# tree: the running scene tree, or null in a plain script.
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	# found: the host, if it exists already.
	var found: Node = tree.root.get_node_or_null(HOST_NAME)
	if found == null:
		found = Node.new()
		found.name = HOST_NAME
		found.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(found)
	return found


## Returns the player for one kind under the host, making it on first use; null with no scene tree.
## kind: a sound kind, used as the player's node name. stream: the kind's sound, set when made.
static func _player_for(kind: String, stream: AudioStream) -> AudioStreamPlayer:
	# parent: the host node.
	var parent: Node = host()
	if parent == null:
		return null
	# player: the kind's player, if it exists already.
	var player: AudioStreamPlayer = parent.get_node_or_null(NodePath(kind)) as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = kind
		player.bus = BUS
		player.max_polyphony = POLYPHONY
		player.stream = stream
		parent.add_child(player)
	return player
