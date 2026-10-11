## The bot catalogue (task 022): makes a bot by name. Lane: tools (Agent B).
##
##   const Bots := preload("res://tools/bots/bots.gd")
##   var bot: RefCounted = Bots.make("greedy", run_seed, "p1")   # null for an unknown name
##   var request: Dictionary = bot.choose(rules, state, 0)
##
## Every bot has the interface described in tools/bots/random_bot.gd. To add a bot, add its script
## here; the simulation (tools/sim/fight_sim.gd) and its command take the names from NAMES.
extends RefCounted

const RandomBot := preload("res://tools/bots/random_bot.gd")
const GreedyBot := preload("res://tools/bots/greedy_bot.gd")

## Bot name -> its script. Keys are the names the simulation command accepts. Changed by the tools lane.
const SCRIPTS := {
	RandomBot.NAME: RandomBot,
	GreedyBot.NAME: GreedyBot,
}

## Every bot name, sorted. Derived from SCRIPTS; keep the two in step.
const NAMES: Array[String] = [GreedyBot.NAME, RandomBot.NAME]


## Returns a new bot for one seat of one seed, or null when name is not a bot.
## bot_name: a key of SCRIPTS. run_seed: the seed under test. player_id: the seat it plays, "p1".."p4".
static func make(bot_name: String, run_seed: int, player_id: String) -> RefCounted:
	if not SCRIPTS.has(bot_name):
		return null
	return SCRIPTS[bot_name].new(run_seed, player_id)
