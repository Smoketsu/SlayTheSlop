## Which move an enemy uses next (task 011). Lane: core (Agent A).
##
## Rules, in the order they are applied:
##   1. Scripted pattern (core/schema/enemy_def.gd "pattern"). When the definition has one, the
##      enemy's n-th intent of the fight (n = the size of its move_history, counting from 0) is
##      pattern[n % pattern size]. Weights are ignored and no random draw is made. The pattern is
##      followed exactly, so the no-three rule below does not apply (G11, answered "accept").
##   2. Weighted random choice (GDD "Enemy fields": each move has a weight for random choice).
##      Only moves with weight above 0 are candidates. Weight-0 moves are "only chosen by a rule"
##      (enemy_def.gd): a pattern, or a later rule (tasks 017, 019), never this draw.
##   3. Never the same move three times in a row (GDD "Enemies"). This applies to random choice only (G11).
##      If the last MAX_REPEATS entries of move_history are the same move, that move is left out of
##      the candidates BEFORE the draw. The draw then picks among the other moves with their own
##      weights (the "re-pick" is this single draw over the rest, not a second draw), so each of
##      them keeps its share relative to the others.
##   4. Draws. The combat_ai stream (core/rng/rng.gd) is drawn from exactly once, with
##      Rng.weighted_index over the candidates in definition order, and ONLY when there are two or
##      more candidates. A single candidate is taken without a draw, so an enemy with one usable
##      move never moves the stream.
##
## Cases the GDD does not decide (reported in task 011's log; the core does the least surprising
## thing until a person answers):
##   - Every weighted move is banned by rule 3. This happens when the enemy has only one move with
##     weight above 0, as the Goblin Pledge in the GDD's table does ("Hits for 5"). The no-three
##     rule cannot be met, so the ban is lifted and the move repeats.
##   - No pattern and no move with weight above 0 (a content error). No move is chosen ("") and the
##     enemy shows no intent and does nothing that turn.
##   - The draw fails (combat_ai missing; Fight.check_start refuses such a state). The first
##     candidate is taken, so the result is still deterministic.
##
## Pure and deterministic: randomness only through core/rng/rng.gd's combat_ai stream; no file,
## clock or network access. Lists are walked in definition order; no Dictionary order is relied on.
extends RefCounted

const Rng := preload("res://core/rng/rng.gd")

## Most times in a row the same move may be chosen at random: the GDD's "never repeats one three
## times in a row" means at most 2. This is a GDD rule, not a tuning number. Changes only with the GDD.
const MAX_REPEATS: int = 2

## Name of the random stream used for enemy move and target choice (GDD "Random streams").
## Fixed by the GDD; changes only with it.
const STREAM: String = "combat_ai"


## Chooses the move the enemy will use next and returns its id, or "" when it has none (no
## pattern and no move with weight above 0). Draws from combat_ai only when there is a real choice;
## when it draws, state's "rng" is replaced with the advanced streams. Does not change the enemy:
## the caller records the choice in move_history.
## state: the working copy (core/combat/bodies.gd "in place"); only state.rng changes.
## definition: the enemy's definition (core/schema/enemy_def.gd), read-only.
## enemy: the enemy's state (core/schema/enemy_state.gd), read-only here.
static func choose_in_place(state: Dictionary, definition: Dictionary, enemy: Dictionary) -> String:
	if definition.has("pattern") and not definition["pattern"].is_empty():
		return pattern_move(definition["pattern"], enemy["move_history"].size())
	# candidates: the moves that may be drawn, in definition order.
	var candidates: Array = random_candidates(definition["moves"], enemy["move_history"])
	if candidates.is_empty():
		return ""
	if candidates.size() == 1:
		return candidates[0]["id"]
	# weights: each candidate's weight, in the same order.
	var weights: Array = []
	for move: Dictionary in candidates:
		weights.append(move["weight"])
	# drawn: Rng.weighted_index's result, {"state", "value"} (plus "error" once task 029 merges).
	var drawn: Dictionary = {"error": "random stream %s is missing" % STREAM}
	if state.get("rng", {}).has(Rng.key_for(STREAM)):
		drawn = Rng.weighted_index(state, Rng.key_for(STREAM), weights)
	if drawn.get("error", "") != "":
		return candidates[0]["id"]
	state["rng"] = drawn["state"]["rng"]
	return candidates[drawn["value"]]["id"]


## Returns the move id a scripted pattern gives for the enemy's n-th intent: pattern[n % size].
## pattern: the definition's pattern, one or more move ids. count: intents chosen so far this
## fight (the size of move_history), 0 or more.
static func pattern_move(pattern: Array, count: int) -> String:
	return pattern[count % pattern.size()]


## Returns the moves a random choice may pick, in definition order: those with weight above 0,
## minus the move banned by the no-three rule (banned_move). If the ban would leave nothing, it is
## lifted (see the file header). Empty only when no move has weight above 0.
## moves: the definition's moves. history: the enemy's move_history, oldest first.
static func random_candidates(moves: Array, history: Array) -> Array:
	# weighted: every move with weight above 0.
	var weighted: Array = moves.filter(func(move: Dictionary) -> bool: return move["weight"] > 0)
	# banned: the move that may not be chosen again, or "".
	var banned: String = banned_move(history)
	# allowed: weighted without the banned move.
	var allowed: Array = weighted.filter(func(move: Dictionary) -> bool: return move["id"] != banned)
	return allowed if not allowed.is_empty() else weighted


## Returns the move id that the no-three rule forbids next: the move of the last MAX_REPEATS
## intents, when they are all the same move. Otherwise returns "".
## history: the enemy's move_history, oldest first.
static func banned_move(history: Array) -> String:
	if history.size() < MAX_REPEATS:
		return ""
	# last: the most recent move id.
	var last: String = history[-1]
	for i: int in range(history.size() - MAX_REPEATS, history.size()):
		if history[i] != last:
			return ""
	return last
