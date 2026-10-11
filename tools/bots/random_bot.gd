## The random bot (task 022): each step it sends one legal request chosen uniformly at random,
## set_ready included, so it ends its turn as often as it plays any single card. Lane: tools (Agent B).
##
## Legal requests come from tools/bots/bot_moves.gd (built from what a player sees, kept when
## Core.validate() accepts them). The choice uses the bot's own RandomNumberGenerator, seeded from
## the seed under test and the bot's player_id (BotMoves.bot_seed()); it never uses global random
## functions, the clock or the run's random streams. Same seed, same player_id, same states: same
## requests.
##
## Interface shared by every bot (tools/bots/bots.gd makes them):
##   var bot = RandomBot.new(run_seed, player_id)
##   bot.choose(rules, state, player_index) -> a request to send, or {} when it has nothing to send
extends RefCounted

const BotMoves := preload("res://tools/bots/bot_moves.gd")

## The name the simulation and its report use for this bot. Fixed.
const NAME: String = "random"

## The bot's own random generator. Seeded once in _init(); only choose() draws from it.
var generator: RandomNumberGenerator = RandomNumberGenerator.new()


## Seeds the bot's generator.
## run_seed: the seed under test, any 64-bit int. player_id: the seat this bot plays, "p1".."p4".
func _init(run_seed: int, player_id: String) -> void:
	generator.seed = BotMoves.bot_seed(run_seed, player_id)


## Returns one legal request chosen uniformly at random, or {} when there is none (not the player
## phase, or the Dude cannot act).
## rules: the read-only ruleset. state: the run state, not changed. player_index: the Dude's seat, 0-based.
func choose(rules: Dictionary, state: Dictionary, player_index: int) -> Dictionary:
	# options: every legal request, in canonical order.
	var options: Array = BotMoves.legal_requests(rules, state, player_index, BotMoves.next_seq(state, player_index))
	if options.is_empty():
		return {}
	return options[generator.randi_range(0, options.size() - 1)]
