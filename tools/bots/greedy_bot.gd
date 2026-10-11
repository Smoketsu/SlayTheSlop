## The greedy bot (task 022): a fixed, written-down heuristic. Lane: tools (Agent B).
##
## Each step it looks at every legal play (tools/bots/bot_moves.gd legal_plays(), canonical order:
## hand order, then Brew slots, then the Bro Move) and picks, in this order of preference:
##   1. the play that removes the most enemy HP, if any removes some;
##   2. else the play that gains the party the most Guard, if any gains some;
##   3. else the first card it can play (hand order), whatever it does (Ick, Broken Arm, Powers ...);
##   4. else set_ready true.
## Ties go to the earlier play in canonical order, so the first copy in hand wins.
##
## How a play is scored: the bot asks the core what the play would do, by applying it to the current
## state with Core.apply() (pure: the state passed in is not changed) and reading only what the
## screen would show next: total enemy HP (an enemy that leaves counts as all of its HP removed) and
## the Dudes' total Guard. The forecast state is thrown away; only the chosen request is sent to the
## game. It never reads the draw pile, the random streams or enemy plans, and it does not
## re-implement the damage rules. Copies of the same card (same definition, same upgrade, same
## target) are forecast once.
##
## It uses no randomness. It still owns a generator seeded like every bot's (BotMoves.bot_seed()), so
## all bots share one interface (see tools/bots/random_bot.gd).
extends RefCounted

const Core := preload("res://core/core.gd")
const BotMoves := preload("res://tools/bots/bot_moves.gd")

## The name the simulation and its report use for this bot. Fixed.
const NAME: String = "greedy"

## The bot's own random generator, seeded in _init(). The heuristic never draws from it.
var generator: RandomNumberGenerator = RandomNumberGenerator.new()


## Seeds the bot's generator.
## run_seed: the seed under test, any 64-bit int. player_id: the seat this bot plays, "p1".."p4".
func _init(run_seed: int, player_id: String) -> void:
	generator.seed = BotMoves.bot_seed(run_seed, player_id)


## Returns the request the heuristic picks (file header), or {} when the player cannot act.
## rules: the read-only ruleset. state: the run state, not changed. player_index: the Dude's seat, 0-based.
func choose(rules: Dictionary, state: Dictionary, player_index: int) -> Dictionary:
	# seq: the seq every request carries.
	var seq: int = BotMoves.next_seq(state, player_index)
	# plays: the legal plays, in canonical order.
	var plays: Array = BotMoves.legal_plays(rules, state, player_index, seq)
	# best_hp: the play that removes the most enemy HP, or {} when none removes any.
	var best_hp: Dictionary = {}
	# best_guard: the play that gains the most Guard, or {} when none gains any.
	var best_guard: Dictionary = {}
	# most_hp: best_hp's score, enemy HP removed, 0 or more.
	var most_hp: int = 0
	# most_guard: best_guard's score, Guard gained, 0 or more.
	var most_guard: int = 0
	# first_card: the first legal play_card, or {}.
	var first_card: Dictionary = {}
	# seen: forecast keys already scored, so identical copies are forecast once.
	var seen: Dictionary = {}
	# enemy_hp_before: every enemy's HP now, the HP score's baseline.
	var enemy_hp_before: int = total_enemy_hp(state)
	# guard_before: every Dude's Guard now, the Guard score's baseline.
	var guard_before: int = total_guard(state)
	for play: Dictionary in plays:
		if play["type"] == BotMoves.PLAY_CARD and first_card.is_empty():
			first_card = play
		# key: what makes two plays identical.
		var key: String = forecast_key(state, player_index, play)
		if seen.has(key):
			continue
		seen[key] = true
		# result: what the core would do with this play.
		var result: Dictionary = Core.apply(rules, state, play)
		if result["reject"] != "":
			continue
		# hp_removed: enemy HP the play removes (an enemy that leaves counts all its HP).
		var hp_removed: int = enemy_hp_before - total_enemy_hp(result["state"])
		# guard_gained: Guard the play gives the party (negative when it costs Guard).
		var guard_gained: int = total_guard(result["state"]) - guard_before
		if hp_removed > most_hp:
			most_hp = hp_removed
			best_hp = play
		if guard_gained > most_guard:
			most_guard = guard_gained
			best_guard = play
	if not best_hp.is_empty():
		return best_hp
	if not best_guard.is_empty():
		return best_guard
	if not first_card.is_empty():
		return first_card
	return BotMoves.ready_request(rules, state, player_index, seq)


## Returns the key under which a play is forecast: two plays with the same key do the same thing
## (same card definition and upgrade, or same Brew, or the Bro Move, aimed at the same target).
## state: the run state. player_index: the Dude's seat. play: a legal request.
static func forecast_key(state: Dictionary, player_index: int, play: Dictionary) -> String:
	# dude: the player's Dude.
	var dude: Dictionary = state["dudes"][player_index]
	match play["type"]:
		BotMoves.PLAY_CARD:
			# instance: the copy's {def_id, upgraded}.
			var instance: Dictionary = dude["cards"][play["card_uid"]]
			return "card/%s/%s/%s" % [instance["def_id"], str(instance["upgraded"]), play["target_id"]]
		BotMoves.USE_BREW:
			return "brew/%s/%s" % [dude["brews"][play["slot"]], play["target_id"]]
	return "%s/%s" % [play["type"], play.get("target_id", "")]


## Returns the HP of every enemy still in the fight, added up; 0 outside a fight.
## state: a run state.
static func total_enemy_hp(state: Dictionary) -> int:
	# total: the sum.
	var total: int = 0
	if state["combat"] != null:
		for enemy: Dictionary in state["combat"]["enemies"]:
			total += enemy["hp"]
	return total


## Returns every Dude's Guard, added up.
## state: a run state.
static func total_guard(state: Dictionary) -> int:
	# total: the sum.
	var total: int = 0
	for dude: Dictionary in state["dudes"]:
		total += dude["guard"]
	return total
