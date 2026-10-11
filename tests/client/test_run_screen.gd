## Tests for the run screen and main menu, client/run/run_screen.gd and main_menu.gd (task 020), on
## the real core and the real data. Lane: tools/client (Agent B). Each test maps to an acceptance
## check in docs/tasks/020-client-run-screens.md: the screen comes from the state alone, New Run and
## Continue, a corrupt save, run over, and one code path.
##
## The map vote in the one-code-path test goes through the map screen's own press_node(), as a click
## does; the reject test emits request_made directly with a node no click could pick.
extends "res://tests/framework/test_case.gd"

const RunScreen := preload("res://client/run/run_screen.tscn")
const RunScreenScript := preload("res://client/run/run_screen.gd")
const SaveStore := preload("res://client/run/save_store.gd")
const Messages := preload("res://client/fight/messages.gd")
const Targeting := preload("res://client/fight/targeting.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")
const NewRun := preload("res://core/run/new_run.gd")
const Core := preload("res://core/core.gd")
const Request := preload("res://core/schema/request.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")
## [added, task 049] The settings store and the overlay's seen key, for _screen().
const UserSettings := preload("res://client/settings/user_settings.gd")
const HowToPlay := preload("res://client/help/how_to_play.gd")

## The save file these tests use, so they never touch a player's real save. Deleted before and
## after each test that writes it.
const PATH: String = "user://test_run_screen.save"
## [added, task 049] The client settings file these screens use, so they never touch a player's real
## settings. _screen() marks How to play as seen in it, so these tests see the screens without the
## overlay (task 049's own tests cover it).
const SETTINGS_PATH: String = "user://test_run_screen_settings.cfg"
## The fixed seed of the runs here: its first node (the entrance's first link) is a Brawl that the
## simple play below wins, so the run reaches its first card reward.
const SEED: int = 7
## Most steps a fight may take before the test gives up (a safety stop, not a rule).
const MAX_STEPS: int = 400


## A gateway that applies nothing and returns the state with run_phase set to a fixed value, so the
## run-over view can be reached without playing a whole floor.
class PhaseGateway extends RefCounted:
	## The run_phase every apply() returns. Set by the test.
	var phase: String = ""

	## Returns a copy of state with run_phase = phase and state_version + 1, and no events.
	## ruleset: unused. state: copied. request: unused.
	func apply(ruleset: Dictionary, state: Dictionary, request: Dictionary) -> Dictionary:
		# next: the changed copy.
		var next: Dictionary = state.duplicate(true)
		next["run_phase"] = phase
		next["state_version"] += 1
		return {"state": next, "events": [], "reject": ""}


## screen_for() routes from the state alone, on states of a real fixed-seed run: the map, a running
## fight, the first card reward, and copies of it set to floor_end and lost; and the routing is the
## same for a co-op player still waiting on others (no offers of their own).
func test_screen_for_routes_from_state_alone() -> void:
	# ruleset: the real data. state: a new run.
	var ruleset: Dictionary = _ruleset()
	var state: Dictionary = _new_run(ruleset)
	# player: the local player.
	var player: String = state["dudes"][0]["player_id"]
	assert_eq(RunScreenScript.screen_for(state, player), "map", "a new run is on the map")
	state = Core.apply(ruleset, state, _vote(state))["state"]
	assert_eq(RunScreenScript.screen_for(state, player), "fight", "the first Brawl")
	state = _win_fight_through_core(ruleset, state)
	assert_ne(state["dudes"][0]["offers"], [], "a card reward is open")
	assert_eq(RunScreenScript.screen_for(state, player), "offer", "the card reward")
	# copy: the reward state with one field changed (routing only reads run_phase, combat and offers).
	var copy: Dictionary = state.duplicate(true)
	copy["run_phase"] = "floor_end"
	assert_eq(RunScreenScript.screen_for(copy, player), "won")
	copy["run_phase"] = "lost"
	assert_eq(RunScreenScript.screen_for(copy, player), "lost")
	copy = state.duplicate(true)
	copy["dudes"][0]["offers"] = []
	assert_eq(RunScreenScript.screen_for(copy, player), "offer", "waiting on the other Dudes' choices")


## One code path: from the menu with a fixed seed, the run screen's input handlers play to the first
## reward (the map's vote through the map screen's press_node(), the whole fight through the fight screen's presses
## with the state frozen read-only before each); replaying the requests it sent straight through
## Core.apply() from NewRun.start() gives an equal final state. The reward state is also saved.
func test_one_code_path_from_menu_to_first_reward() -> void:
	SaveStore.delete_save(PATH)
	# screen: the run screen on the real data.
	var screen: Control = _screen()
	assert_eq(screen.current, "menu")
	screen.press_new_run(str(SEED))
	assert_eq(screen.current, "map", "New Run opens the map")
	_freeze(screen.run_state())
	screen.child_screen().press_node(_vote(screen.run_state())["node_id"])
	assert_eq(screen.current, "fight", "the vote starts the Brawl")
	# steps: presses made in the fight.
	var steps: int = 0
	while screen.current == "fight" and steps < MAX_STEPS:
		_freeze(screen.run_state())
		steps += _press_one_step(screen.child_screen())
	assert_eq(screen.current, "offer", "the fight was won and the first reward is open")
	# final: the run screen's state.
	var final: Dictionary = screen.run_state()
	assert_no_errors(RunState.check(final), "final state")
	for request: Dictionary in screen.sent_requests:
		assert_no_errors(Request.check(request), "sent request")
	# replayed: the same requests straight through the core from the same start.
	var ruleset: Dictionary = _ruleset()
	var replayed: Dictionary = _new_run(ruleset)
	for request: Dictionary in screen.sent_requests:
		replayed = Core.apply(ruleset, replayed, request)["state"]
	assert_eq(replayed, final, "replay through Core.apply")
	assert_eq(SaveStore.load_state(PATH)["state"], final, "the reward state was saved")
	_free(screen)
	SaveStore.delete_save(PATH)


## New Run with an empty seed picks one and shows it (the menu message and the run header both
## carry it); a seed that is not a whole number starts nothing; a new run is saved at once.
func test_new_run_seed_is_picked_and_shown() -> void:
	SaveStore.delete_save(PATH)
	# screen: the run screen on the real data.
	var screen: Control = _screen()
	screen.press_new_run("not a seed")
	assert_eq(screen.current, "menu", "a bad seed starts nothing")
	assert_true(screen.child_screen().message.contains("whole number"), screen.child_screen().message)
	# menu: the menu, to read the seed it picked.
	var menu: Control = screen.child_screen()
	screen.press_new_run("")
	assert_eq(screen.current, "map")
	assert_eq(screen.run_state()["run_seed"], menu.last_seed, "the run uses the picked seed")
	assert_eq(menu.message, "Seed: %d" % menu.last_seed, "the menu showed it")
	assert_true(screen.drawn_text().contains("Seed %d" % menu.last_seed), "the header shows it")
	assert_eq(SaveStore.load_state(PATH)["state"], screen.run_state(), "a new run is saved at once")
	_free(screen)
	SaveStore.delete_save(PATH)


## Continue opens the screen the saved state calls for, mid-run: a saved card reward opens the offer
## screen with the same state, and further requests carry the next seq.
func test_continue_opens_the_right_screen() -> void:
	# ruleset: the real data. state: a run at its first card reward.
	var ruleset: Dictionary = _ruleset()
	var state: Dictionary = _new_run(ruleset)
	state = _win_fight_through_core(ruleset, Core.apply(ruleset, state, _vote(state))["state"])
	assert_eq(SaveStore.save_state(state, PATH), "")
	# screen: a fresh run screen.
	var screen: Control = _screen()
	screen.press_continue()
	assert_eq(screen.current, "offer", "Continue opens the reward")
	assert_eq(screen.run_state(), state, "the loaded state")
	# offer: the open card reward.
	var offer: Dictionary = state["dudes"][0]["offers"][0]
	assert_eq(screen.send({"type": "choose_reward", "reward_id": offer["id"], "choice_index": -1}), "", "skipping the reward applies")
	assert_eq(screen.sent_requests[0]["seq"], state["dudes"][0]["last_seq"] + 1, "seq follows the loaded last_seq")
	_free(screen)
	SaveStore.delete_save(PATH)


## A truncated save shows from_bytes()'s error, keeps the menu with New Run working, and nothing
## crashes (the runner fails a test on any engine error).
func test_truncated_save_offers_new_run() -> void:
	# bytes: half of a real save.
	var bytes: PackedByteArray = Snapshot.to_bytes(_new_run(_ruleset()))
	bytes = bytes.slice(0, bytes.size() / 2)
	# file: the damaged save.
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	# screen: a fresh run screen.
	var screen: Control = _screen()
	screen.press_continue()
	assert_eq(screen.current, "menu", "still on the menu")
	# menu_text: what the menu says.
	var menu_text: String = screen.child_screen().message
	assert_true(menu_text.contains(Snapshot.from_bytes(bytes)["error"]), "shows the loader's error: " + menu_text)
	assert_true(menu_text.contains("New Run"), "offers New Run: " + menu_text)
	assert_true(screen.drawn_text().contains("New Run"), "the New Run button is there")
	screen.press_new_run(str(SEED))
	assert_eq(screen.current, "map", "New Run still works")
	_free(screen)
	SaveStore.delete_save(PATH)


## A request the core rejects shows its message and changes nothing.
func test_reject_shows_message() -> void:
	SaveStore.delete_save(PATH)
	# screen: a new run on the map.
	var screen: Control = _screen()
	screen.press_new_run(str(SEED))
	# before: the state before the bad vote.
	var before: Dictionary = screen.run_state()
	screen.child_screen().request_made.emit({"type": "vote_node", "node_id": "r99c99"})
	assert_eq(screen.message, Messages.reject("bad_target"))
	assert_true(screen.run_state() == before, "same state")
	assert_eq(screen.current, "map")
	_free(screen)
	SaveStore.delete_save(PATH)


## Run over: won and passed out each show their view and delete the save, and Back to menu returns
## to the menu. The phases come from a gateway that sets them (the routing is what is tested).
func test_run_over_and_back_to_menu() -> void:
	for phase: String in ["floor_end", "lost"]:
		SaveStore.delete_save(PATH)
		# gateway: returns the state with run_phase = phase. screen: a run screen on it.
		var gateway := PhaseGateway.new()
		gateway.phase = phase
		var screen: Control = _screen(gateway)
		screen.press_new_run(str(SEED))
		assert_true(SaveStore.has_save(PATH), "saved at the start")
		screen.send({"type": "vote_node", "node_id": "r1c0"})
		# kind: the screen name expected.
		var kind: String = "won" if phase == "floor_end" else "lost"
		assert_eq(screen.current, kind)
		assert_true(screen.drawn_text().contains(RunScreenScript.RUN_OVER_TEXT[kind]), screen.drawn_text())
		assert_false(SaveStore.has_save(PATH), "a finished run cannot be continued")
		screen.press_back_to_menu()
		assert_eq(screen.current, "menu")
		assert_eq(screen.run_state(), {})
		_free(screen)
	SaveStore.delete_save(PATH)


## Returns a run screen in the tree with no animation time, saving to PATH.
## gateway: where requests go; the real core when null.
func _screen(gateway: Object = null) -> Control:
	# screen: the new screen.
	var screen: Control = RunScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.save_path = PATH
	screen.settings_path = SETTINGS_PATH
	UserSettings.set_setting(HowToPlay.SEEN_KEY, true, SETTINGS_PATH)
	screen.setup(_ruleset(), gateway)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


## Presses one step of a simple fight policy on a fight screen: the Bro Move when it is ready (at
## the leftmost enemy if it needs one), else the first card in hand that applies (aimed at the
## leftmost enemy), else Ready. Returns how many presses it made.
## fight: the fight screen.
func _press_one_step(fight: Control) -> int:
	# state: the fight screen's state. version: its state_version before this step.
	var state: Dictionary = fight._state
	var version: int = state["state_version"]
	# first: the leftmost enemy still in the fight.
	var first: String = state["combat"]["enemies"][0]["uid"]
	# presses: presses made.
	var presses: int = 1
	fight.press_bro_move()
	if fight._pending_bro:
		fight.press_enemy(first)
	if fight._state["state_version"] != version:
		return presses
	for uid: String in state["dudes"][0]["hand"]:
		presses += 1
		fight.press_card(uid)
		if fight._pending_card != "":
			fight.press_enemy(first)
		if fight._state["state_version"] != version:
			return presses
	fight.press_ready()
	return presses + 1


## Plays a running fight straight through the core with the same policy as _press_one_step() (Bro
## Move, then the first card that applies, then Ready) until it is decided. Returns the state after.
## ruleset: the real data. state: a run state in a fight.
func _win_fight_through_core(ruleset: Dictionary, state: Dictionary) -> Dictionary:
	# player: the local player. steps: requests tried.
	var player: String = state["dudes"][0]["player_id"]
	var steps: int = 0
	while state["combat"] != null and state["combat"]["result"] == "" and steps < MAX_STEPS:
		# first: the leftmost enemy. seq: the next seq. tries: the requests to try, in order.
		var first: String = state["combat"]["enemies"][0]["uid"]
		var seq: int = state["dudes"][0]["last_seq"] + 1
		var tries: Array = [{"type": "use_bro_move", "player_id": player, "seq": seq}]
		for uid: String in state["dudes"][0]["hand"]:
			# card: the card's definition.
			var card: Dictionary = ruleset["cards"][state["dudes"][0]["cards"][uid]["def_id"]]
			# target: an enemy for enemy cards, otherwise what the screen would pick.
			var target: String = first if Targeting.mode(card, 1) == Targeting.ENEMY else Targeting.auto_target(card, player, 1)
			tries.append({"type": "play_card", "player_id": player, "seq": seq, "card_uid": uid, "target_id": target, "crunch": false})
		tries.append({"type": "set_ready", "player_id": player, "seq": seq, "ready": true})
		for request: Dictionary in tries:
			steps += 1
			# result: the core's answer.
			var result: Dictionary = Core.apply(ruleset, state, request)
			if result["reject"] == "":
				state = result["state"]
				break
	# A won fight's rewards end the fight part of the node (combat null) and open the card reward.
	assert_eq(state["combat"], null, "the fight is over within %d steps" % MAX_STEPS)
	assert_eq(state["run_phase"], "node", "won, not lost")
	return state


## Returns the vote a player makes for the entrance's first link (any request field but player_id
## and seq is what the map screen would emit).
## state: a run state on the map at the entrance.
func _vote(state: Dictionary) -> Dictionary:
	return {"type": "vote_node", "player_id": state["dudes"][0]["player_id"], "seq": state["dudes"][0]["last_seq"] + 1,
		"node_id": state["map"]["nodes"][state["node_index"]]["links"][0]}


## Returns the ruleset built from data/.
func _ruleset() -> Dictionary:
	return Ruleset.build(DataFiles.read_all())["ruleset"]


## Returns a new run's first state on the real data, with the first Dude by id, at SEED.
## ruleset: the real data.
func _new_run(ruleset: Dictionary) -> Dictionary:
	# dude_ids: the Dudes, sorted.
	var dude_ids: Array = ruleset["dudes"].keys()
	dude_ids.sort()
	return NewRun.start(ruleset, SEED, [dude_ids[0]])["state"]


## Removes a screen from the tree and frees it now.
## screen: a screen from _screen().
func _free(screen: Control) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()


## Makes value read-only at every level (make_read_only() alone is shallow), so any client write
## to game state is a runtime error, which fails the test.
## value: a Dictionary or Array from a state.
func _freeze(value: Variant) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key: Variant in value:
			_freeze(value[key])
		value.make_read_only()
	elif typeof(value) == TYPE_ARRAY:
		for item: Variant in value:
			_freeze(item)
		value.make_read_only()
