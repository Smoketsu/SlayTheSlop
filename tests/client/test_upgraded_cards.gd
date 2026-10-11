## Tests for showing upgraded (Lifted) card copies with their upgraded definition on the fight
## screen and in the run screens' card lists (task upgraded-card-display). Lane: tools/client
## (Agent B).
##
## A copy is marked upgraded by the core's own Lift path (core/run/grants.gd upgrade_card_in_place())
## on a fresh state before any screen gets it; the screen's state is then frozen read-only, so any
## client write to game state fails the test. Expected values come from the core's
## core/combat/upgrades.gd definition_of(), not from hard-coded strings.
extends "res://tests/framework/test_case.gd"

const FightScreen := preload("res://client/fight/fight_screen.tscn")
const FightModel := preload("res://client/fight/fight_model.gd")
const RunText := preload("res://client/run/run_text.gd")
## [added, task 041] The card face the hand is drawn with.
const CardView := preload("res://client/visual/card_view.gd")
const DevFight := preload("res://client/dev/dev_fight.gd")
const Core := preload("res://core/core.gd")
const Upgrades := preload("res://core/combat/upgrades.gd")
const Grants := preload("res://core/run/grants.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const RunState := preload("res://core/schema/run_state.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")
const DataFiles := preload("res://tools/data_files.gd")

## The real card with an upgrade on main: Arm Bar (GDD "Example card definition", 8 -> 11 damage).
const ARM_BAR_ID: String = "tom_arm_bar"
## Arm Bar's damage after its upgrade (GDD "Example card definition"), to prove the copy is upgraded.
const ARM_BAR_UPGRADED_DAMAGE: int = 11
## Id of an in-memory test card whose upgrade changes its target and name. Not a real content id;
## never saved or shipped.
const REACH_ID: String = "neutral_test_reach"
## The test card: targets "self" (nothing to pick) until Lifted, then "enemy" with a new name and text.
const REACH_CARD := {
	"id": REACH_ID, "name": "Short Reach", "owner": "neutral", "type": "skill", "rarity": "common",
	"cost": 1, "target": "self", "effects": [{"op": "guard", "amount": 5}],
	"keywords": [], "crunch": null, "text": "Gain 5 Guard",
	"upgrade": {"target": "enemy", "name": "Long Reach", "text": "Gain 5 Guard. Reach out"},
}
## Id of an in-memory test card with no upgrade, for a copy marked upgraded anyway (G15: it has no
## definition, and the core refuses it as unplayable). Not a real content id.
const STUCK_ID: String = "neutral_test_stuck"
## The test card with an empty upgrade.
const STUCK_CARD := {
	"id": STUCK_ID, "name": "Stuck", "owner": "neutral", "type": "skill", "rarity": "common",
	"cost": 1, "target": "self", "effects": [{"op": "guard", "amount": 1}],
	"keywords": [], "crunch": null, "upgrade": {}, "text": "Gain 1 Guard",
}


## The hand shows a Lifted Arm Bar as "Arm Bar+" with the cost and text of its upgraded definition,
## and the button on the screen says the same. A copy that is not Lifted keeps its plain name.
func test_hand_shows_upgraded_arm_bar() -> void:
	# started: the real fight. state: its state. dude: the one Dude.
	var started: Dictionary = DevFight.start()
	var state: Dictionary = started["state"]
	var dude: Dictionary = state["dudes"][0]
	# uids: Arm Bar copies, in card_uid order.
	var uids: Array = _copies_of(dude, ARM_BAR_ID)
	assert_true(uids.size() >= 1, "the starter deck has an Arm Bar")
	if uids.is_empty():
		return
	# uid: the copy to Lift.
	var uid: String = uids[0]
	_to_hand(dude, uid)
	Grants.upgrade_card_in_place(state, 0, uid, [])
	assert_no_errors(RunState.check(state), "state after Lift")
	# lifted: the copy's effective definition, from the core.
	var lifted: Dictionary = Upgrades.definition_of(started["ruleset"], dude, uid)
	assert_eq(lifted["effects"][0]["amount"], ARM_BAR_UPGRADED_DAMAGE, "the copy is upgraded")
	_freeze(state)
	# entry: the copy's hand entry in the display model.
	var entry: Dictionary = _hand_entry(FightModel.build(started["ruleset"], state, started["player_id"]), uid)
	# base_name: Arm Bar's name in the data.
	var base_name: String = started["ruleset"]["cards"][ARM_BAR_ID]["name"]
	assert_eq(entry["name"], lifted["name"] + RunText.UPGRADED_MARK, "name has the upgrade mark")
	assert_eq(entry["name"], base_name + "+", "shows as Arm Bar+")
	assert_eq(entry["cost"], RunText.card_cost(lifted), "cost from the upgraded definition")
	assert_eq(entry["text"], lifted["text"], "text from the upgraded definition")
	assert_true(entry["upgraded"], "marked upgraded")
	# screen: the fight screen on the frozen state.
	var screen: Control = _screen(started)
	assert_true(_hand_texts(screen).has("[%s] %s\n%s" % [entry["cost"], entry["name"], entry["text"]]), "the card face shows the upgraded copy: %s" % str(_hand_texts(screen)))
	_free(screen)
	# other: a plain card in hand keeps its plain name.
	for other: String in dude["hand"]:
		if other != uid:
			var plain: Dictionary = _hand_entry(FightModel.build(started["ruleset"], state, started["player_id"]), other)
			assert_false(plain["name"].ends_with(RunText.UPGRADED_MARK), "%s is not Lifted" % other)
			assert_false(plain["upgraded"])


## A Lifted Arm Bar still asks for an enemy, and plays once one is picked; the screen's state is
## frozen, so the client wrote nothing itself.
func test_upgraded_arm_bar_plays_through_the_screen() -> void:
	# started: the real fight with an Arm Bar Lifted and in hand.
	var started: Dictionary = DevFight.start()
	var dude: Dictionary = started["state"]["dudes"][0]
	# uid: the Lifted Arm Bar.
	var uid: String = _copies_of(dude, ARM_BAR_ID)[0]
	_to_hand(dude, uid)
	Grants.upgrade_card_in_place(started["state"], 0, uid, [])
	_freeze(started["state"])
	# screen: the fight screen.
	var screen: Control = _screen(started)
	screen.press_card(uid)
	assert_eq(screen.message, "Pick an enemy.")
	assert_eq(screen._state["state_version"], 0, "nothing sent before a target is picked")
	screen.press_enemy(screen._state["combat"]["enemies"][0]["uid"])
	assert_eq(screen._state["state_version"], 1, "sent once the enemy is picked")
	assert_false(screen._state["dudes"][0]["hand"].has(uid), "the card left the hand")
	_free(screen)


## Targeting follows the copy's effective definition: a test card whose upgrade changes its target
## from "self" to "enemy" asks for an enemy only when Lifted, and shows its upgraded name with "+"
## in the hand and in the run screens' card lists (RunText.card_copy_name()).
func test_targeting_and_name_follow_the_upgrade() -> void:
	# started: the real fight plus two copies of the test card in hand, one Lifted.
	var started: Dictionary = _started_with(REACH_CARD)
	assert_true(Upgrades.can_upgrade(REACH_CARD), "the test card's upgrade applies")
	# plain_uid, lifted_uid: the two copies.
	var plain_uid: String = _give(started["state"], REACH_ID)
	var lifted_uid: String = _give(started["state"], REACH_ID)
	Grants.upgrade_card_in_place(started["state"], 0, lifted_uid, [])
	_freeze(started["state"])
	# dude: the one Dude.
	var dude: Dictionary = started["state"]["dudes"][0]
	assert_eq(RunText.card_copy_name(started["ruleset"], dude, lifted_uid), "Long Reach+", "run screens use the upgraded name")
	assert_eq(RunText.card_copy_name(started["ruleset"], dude, plain_uid), "Short Reach")
	# model: the display model.
	var model: Dictionary = FightModel.build(started["ruleset"], started["state"], started["player_id"])
	assert_eq(_hand_entry(model, lifted_uid)["name"], "Long Reach+")
	assert_eq(_hand_entry(model, lifted_uid)["target"], "enemy")
	assert_eq(_hand_entry(model, plain_uid)["target"], "self")
	# screen: the fight screen.
	var screen: Control = _screen(started)
	screen.press_card(lifted_uid)
	assert_eq(screen.message, "Pick an enemy.", "the Lifted copy asks for an enemy")
	assert_eq(screen._state["state_version"], 0, "nothing sent yet")
	_free(screen)


## A copy marked upgraded whose card has no upgrade (G15) has no definition: the hand shows its id
## with "+" and cost "-", pressing it asks for nothing, and the core refuses it as unplayable.
func test_copy_without_a_usable_upgrade_does_not_break_the_hand() -> void:
	# started: the real fight plus a Lifted copy of the test card with an empty upgrade.
	var started: Dictionary = _started_with(STUCK_CARD)
	# uid: the copy, marked upgraded as the core's Lift path marks it.
	var uid: String = _give(started["state"], STUCK_ID)
	Grants.upgrade_card_in_place(started["state"], 0, uid, [])
	_freeze(started["state"])
	assert_eq(Upgrades.definition_of(started["ruleset"], started["state"]["dudes"][0], uid), {})
	# entry: its hand entry.
	var entry: Dictionary = _hand_entry(FightModel.build(started["ruleset"], started["state"], started["player_id"]), uid)
	assert_eq(entry["name"], STUCK_ID + RunText.UPGRADED_MARK)
	assert_eq(entry["cost"], "-")
	# screen: the fight screen.
	var screen: Control = _screen(started)
	screen.press_card(uid)
	assert_eq(screen._state["state_version"], 0, "the core refused it")
	assert_eq(screen.message, "That card can't be played.")
	_free(screen)


## Returns a DevFight.start() result whose ruleset is built from data/ plus one test card (as if it
## were a file in data/cards/); the built ruleset is read-only, so the card goes in before the build.
## card: a card definition with a test id.
func _started_with(card: Dictionary) -> Dictionary:
	# started: the real fight.
	var started: Dictionary = DevFight.start()
	# files: every data file's text, plus the test card's.
	var files: Dictionary = DataFiles.read_all()
	files["data/cards/%s.json" % card["id"]] = JSON.stringify(card)
	# built: the ruleset build result.
	var built: Dictionary = Ruleset.build(files)
	assert_true(built["ok"], "the test ruleset builds: %s" % "; ".join(built["errors"]))
	started["ruleset"] = built["ruleset"]
	return started


## Returns the card_uids of a Dude's copies of one card, sorted. dude: a Dude state. def_id: a card id.
func _copies_of(dude: Dictionary, def_id: String) -> Array:
	# uids: the result.
	var uids: Array = []
	for uid: String in dude["cards"]:
		if dude["cards"][uid]["def_id"] == def_id:
			uids.append(uid)
	uids.sort()
	return uids


## Moves a card copy into the hand from whichever pile holds it (test setup on a fresh state).
## dude: a Dude state. uid: one of its card copies.
func _to_hand(dude: Dictionary, uid: String) -> void:
	for pile: String in DudeState.PILES:
		dude[pile].erase(uid)
	dude["hand"].append(uid)


## Puts a new, not upgraded copy of a card in the first Dude's deck and hand (test setup on a fresh
## state) and returns its card_uid. state: a fight. def_id: a card id in the ruleset.
func _give(state: Dictionary, def_id: String) -> String:
	# uid: the new copy's card_uid, from the state's uid counter.
	var uid: String = "c%d" % state["next_uid"]
	state["next_uid"] += 1
	state["dudes"][0]["cards"][uid] = {"def_id": def_id, "upgraded": false}
	state["dudes"][0]["hand"].append(uid)
	state["dudes"][0]["deck"].append(uid)
	return uid


## Returns a card copy's entry in a display model's hand, or {} (and fails) when it is not there.
## model: FightModel.build()'s result. uid: a card copy.
func _hand_entry(model: Dictionary, uid: String) -> Dictionary:
	for card: Dictionary in model["hand"]:
		if card["card_uid"] == uid:
			return card
	fail("%s is not in the hand" % uid)
	return {}


## Returns what every card in a screen's hand shows, left to right, as "[cost] name\ntext". Task 041:
## the hand holds card faces (client/visual/card_view.gd), so this reads each face's shown cost, name
## and rules text. screen: from _screen().
func _hand_texts(screen: Control) -> Array[String]:
	# texts: the result.
	var texts: Array[String] = []
	for child: Node in screen._hand_box.get_children():
		if child is CardView:
			texts.append("[%s] %s\n%s" % [child.shown_cost, child.shown_name, child.shown_text])
	return texts


## Returns a fight screen in the tree with no animation time, on the real core.
## started: a DevFight.start() result.
func _screen(started: Dictionary) -> Control:
	# screen: the new screen.
	var screen: Control = FightScreen.instantiate()
	screen.animation_seconds = 0.0
	screen.setup(Core.new(), started["ruleset"], started["state"], started["player_id"])
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


## Removes a screen from the tree and frees it now. screen: a screen from _screen().
func _free(screen: Control) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()


## Makes value read-only at every level (make_read_only() alone is shallow).
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
