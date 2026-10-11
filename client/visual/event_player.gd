## Plays the events a request returned as short animations on the combatant views, one after
## another in event order (task 028). Lane: client (Agent B).
##
## It reads events only and changes only how views look: game state is never read or written here,
## and the screen redraws every view from the returned state once play() finishes, so skipping or
## cutting an animation short can never leave the screen wrong. With seconds <= 0 every event plays
## instantly and play() returns without waiting, so tests never depend on frame timing.
##
## Task 055: each event also starts its sound (client/audio/sounds.gd kind_for_event()) as it plays.
## Sounds are fire and forget: nothing here waits for one, whatever seconds is.
##
## Task 047: banners. banners_for() finds where the fight's rhythm changes inside a request's events
## (a new turn, the enemy phase, the fight's end) from the events alone, and play() shows each banner
## (through its on_banner callback) after the events before it have played and before the ones after
## it, waiting banner_seconds() for it. Nothing here decides a rule: the events say what happened.
extends RefCounted

## [added, task 055] The sound lookup and player.
const Sounds := preload("res://client/audio/sounds.gd")

## Animation kinds effect_for() can return, each with what the view does:
## "damage": a hit that took HP (flash red, shake, number pops up). "blocked": a hit Guard took
## whole (blue flash). "guard": Guard changed (number updates; a gain flashes blue). "heal": HP
## restored (green flash). "death": an enemy died (fades out). "leave": an enemy fled or split (fades
## out). "passed_out": a Dude Passed Out (greys and tips over). "log": no animation, the line only.
## Changed only by the client lane.
const KINDS: Array[String] = ["damage", "blocked", "guard", "heal", "death", "leave", "passed_out", "log"]

## [added, task 047] Banner kinds banners_for() can return: "your_turn" (a new turn starts: turn
## flow step 1, the player phase follows), "enemy_turn" (the enemy phase starts: the first enemy's
## action), "victory" (the fight is won), "passed_out" (every Dude Passed Out: the fight is lost).
## Their words are client/fight/messages.gd BANNERS. Changed only by the client lane.
const BANNERS: Array[String] = ["your_turn", "enemy_turn", "victory", "passed_out"]
## [added, task 047] Event types that are an enemy's action in the enemy phase (turn flow step 5):
## the first of them in a turn starts the enemy phase. "armless" comes before the enemy_skipped of an
## Armless enemy (core/combat/statuses.gd skip_action_in_place()). Changed only by the client lane,
## when core/schema/event.gd adds an enemy-action event.
const ENEMY_ACTION_EVENTS: Array[String] = ["enemy_acted", "enemy_skipped", "armless"]
## [added, task 047] How long a turn banner ("your_turn", "enemy_turn") shows, as a multiple of
## seconds (one event's length). Changed only by the client lane.
const TURN_BANNER_FACTOR: float = 3.0
## [added, task 047] How long a result banner ("victory", "passed_out") shows, as a multiple of
## seconds; the screen moves on to the rewards or the run-over view only after it. Changed only by
## the client lane.
const RESULT_BANNER_FACTOR: float = 6.0

## Seconds each animated event lasts; "log" events never wait. 0 or less plays everything
## instantly (tests use 0). Changed by whoever owns the player (the fight screen).
var seconds: float = 0.3
## One line per event played, "<kind> <target>" (target "" for a log event), in order. Read by
## tests. Only grows.
var played: Array[String] = []
## [added, task 047] One line per banner shown, "<kind>@<n>" where n is how many events of that
## play() call had played before it, in order. Read by tests. Only grows.
var banners_played: Array[String] = []


## Returns what an event looks like on screen: {"kind": one of KINDS, "target": the player_id or
## enemy uid it happens to ("" for "log"), "amount": the size of the change (0 when none), "value":
## the new HP or Guard where the event says it (-1 otherwise), "blocked": Guard used up by a hit}.
## Pure: depends on the event only.
## event: one event from the gateway (core/schema/event.gd).
static func effect_for(event: Dictionary) -> Dictionary:
	# effect: the "log" default, filled in below.
	var effect: Dictionary = {"kind": "log", "target": "", "amount": 0, "value": -1, "blocked": 0}
	match event["type"]:
		"damage_dealt":
			effect = {"kind": "damage" if event["hp_lost"] > 0 else "blocked", "target": event["target_id"],
				"amount": event["hp_lost"], "value": -1, "blocked": event["blocked"]}
		"guard_changed":
			effect = {"kind": "guard", "target": event["target_id"], "amount": event["delta"], "value": event["guard"], "blocked": 0}
		"healed":
			effect = {"kind": "heal", "target": event["target_id"], "amount": event["amount"], "value": event["hp"], "blocked": 0}
		"enemy_died":
			effect["kind"] = "death"
			effect["target"] = event["enemy_uid"]
		"enemy_fled", "enemy_split":
			effect["kind"] = "leave"
			effect["target"] = event["enemy_uid"]
		"dude_passed_out":
			effect["kind"] = "passed_out"
			effect["target"] = event["player_id"]
	return effect


## [added, task 047] Returns where banners go in a request's events: event index -> banner kind (one
## of BANNERS), the banner showing just before that event. "your_turn" at each turn_started;
## "enemy_turn" at the first enemy action of a turn (ENEMY_ACTION_EVENTS), moved back over the
## guard_changed that drops that enemy's Guard as its action starts (core/ai/intents.gd
## begin_action_in_place()); "victory" or "passed_out" at fight_ended, by its result. Pure: reads the
## events only.
## events: the gateway's events, in order.
static func banners_for(events: Array) -> Dictionary:
	# out: the result.
	var out: Dictionary = {}
	# enemy_phase_seen: true once this turn's enemy phase has its banner.
	var enemy_phase_seen: bool = false
	for i: int in events.size():
		# event: the event at i.
		var event: Dictionary = events[i]
		match event["type"]:
			"turn_started":
				out[i] = "your_turn"
				enemy_phase_seen = false
			"fight_ended":
				out[i] = "victory" if event["result"] == "won" else "passed_out"
		if ENEMY_ACTION_EVENTS.has(event["type"]) and not enemy_phase_seen:
			enemy_phase_seen = true
			# start: where the acting enemy's phase begins.
			var start: int = i
			while start > 0 and events[start - 1]["type"] == "guard_changed" and events[start - 1]["target_id"] == event["enemy_uid"]:
				start -= 1
			out[start] = "enemy_turn"
	return out


## [added, task 047] Returns how long a banner shows, in seconds: seconds times TURN_BANNER_FACTOR or
## RESULT_BANNER_FACTOR; 0 when seconds <= 0 (instant, as tests play).
## kind: a banner kind (BANNERS).
func banner_seconds(kind: String) -> float:
	if seconds <= 0.0:
		return 0.0
	return seconds * (RESULT_BANNER_FACTOR if kind == "victory" or kind == "passed_out" else TURN_BANNER_FACTOR)


## Plays events in order. Before each one it calls on_event(event) (the screen shows its line),
## then animates it and, unless seconds <= 0, waits until the animation ends before the next.
## Task 047: where banners_for() puts a banner, on_banner(kind, seconds) is called first and play()
## waits banner_seconds(kind) before the event.
## events: the gateway's events. views: player_id or enemy uid -> combatant_view.gd, as drawn before
## the request. on_event: called with each event first. clock: any node in the tree, for its timers.
## on_banner: [added, task 047] called with a banner kind and its length in seconds; an invalid
## Callable (the default) shows no banners.
func play(events: Array, views: Dictionary, on_event: Callable, clock: Node, on_banner: Callable = Callable()) -> void:
	# banners: where banners go.
	var banners: Dictionary = banners_for(events) if on_banner.is_valid() else {}
	for i: int in events.size():
		# event: the event at i.
		var event: Dictionary = events[i]
		if banners.has(i):
			banners_played.append("%s@%d" % [banners[i], i])
			# length: how long the banner shows.
			var length: float = banner_seconds(banners[i])
			on_banner.call(banners[i], length)
			if length > 0.0:
				await clock.get_tree().create_timer(length).timeout
		on_event.call(event)
		# wait: how long this event's animation runs.
		var wait: float = play_one(event, views)
		if wait > 0.0:
			await clock.get_tree().create_timer(wait).timeout


## Starts one event's animation and its sound (task 055), and returns how long the animation runs, in seconds: 0 for a "log" event, for
## a target with no view (an enemy that spawned during this request), for a change that only
## updates a number (Guard lost, a hit of 0), and when seconds <= 0.
## event: one event. views: as in play().
func play_one(event: Dictionary, views: Dictionary) -> float:
	# effect: what to show.
	var effect: Dictionary = effect_for(event)
	played.append("%s %s" % [effect["kind"], effect["target"]])
	Sounds.play_event(event)
	# view: the combatant it happens to, or null.
	var view: Variant = views.get(effect["target"])
	if effect["kind"] == "log" or view == null or not is_instance_valid(view):
		return 0.0
	# time: this animation's length, 0 when instant.
	var time: float = maxf(seconds, 0.0)
	match effect["kind"]:
		"damage", "blocked":
			view.hit(effect["amount"], effect["blocked"], time)
		"guard":
			view.guard_to(effect["value"], effect["amount"], time)
		"heal":
			view.heal_to(effect["value"], effect["amount"], time)
		"death", "leave":
			view.die(time)
		"passed_out":
			view.pass_out(time)
	# still: true when the view only updated a number (a Guard loss, or a hit of 0 with no Guard used).
	var still: bool = (effect["kind"] == "guard" and effect["amount"] <= 0) or (effect["kind"] == "blocked" and effect["blocked"] <= 0)
	return 0.0 if still else time
