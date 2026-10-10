## Tests for enemy move choice (core/ai/move_choice.gd, task 011): weighted draws from combat_ai,
## weight-0 moves, the no-three rule, scripted patterns. Lane: core (Agent A).
##
## Recorded values (exact sequences and counts) come from the combat_ai stream on Godot 4.7.2-stable.
## They change only if core/rng/rng.gd or the move-choice rule changes, and then on purpose.
extends "res://tests/framework/test_case.gd"

const MoveChoice := preload("res://core/ai/move_choice.gd")
const Rng := preload("res://core/rng/rng.gd")
const AiFixtures := preload("res://tests/core/ai/ai_fixtures.gd")

## Seeds of the recorded sequences in test_recorded_sequences, in order.
const SEQUENCE_SEEDS: Array[int] = [1, 2, 20261010]

## The first 16 moves of ai_weighted for each of SEQUENCE_SEEDS, each move recorded in move_history before the next.
const RECORDED_SEQUENCES: Array = [
	["heavy", "heavy", "medium", "heavy", "heavy", "light", "heavy", "light",
		"medium", "medium", "heavy", "light", "heavy", "medium", "medium", "light"],
	["medium", "medium", "heavy", "light", "heavy", "light", "light", "heavy",
		"heavy", "light", "heavy", "heavy", "medium", "heavy", "heavy", "medium"],
	["heavy", "medium", "light", "medium", "heavy", "heavy", "light", "heavy",
		"heavy", "medium", "heavy", "heavy", "light", "light", "heavy", "heavy"],
]

## How many seeds test_first_choice_frequencies draws from (seeds 0 .. FREQUENCY_SEEDS - 1).
const FREQUENCY_SEEDS: int = 4000

## ai_weighted's first-move counts over FREQUENCY_SEEDS seeds: light (weight 1), medium (2), heavy
## (5), special (0), recorded.
const RECORDED_COUNTS: Array = [503, 1046, 2451, 0]

## Length of each long run in the no-three and weight-0 tests, in intents.
const LONG_RUN: int = 3000


## Plays count intents of one enemy with move_choice only, appending each move to move_history.
## Returns {"moves": the move ids in order, "state": the state with its advanced streams}.
## rules: the ruleset. def_id: the enemy definition. run_seed: the streams' seed. count: intents to choose.
func _run(rules: Dictionary, def_id: String, run_seed: int, count: int) -> Dictionary:
	# state: the minimal AI state; its rng advances.
	var state: Dictionary = AiFixtures.ai_state(run_seed, 1)
	# enemy: the enemy whose history grows.
	var enemy: Dictionary = AiFixtures.ai_enemy(def_id)
	for i: int in count:
		enemy["move_history"].append(MoveChoice.choose_in_place(state, rules["enemies"][def_id], enemy))
	return {"moves": enemy["move_history"], "state": state}


## Returns the longest run of one move in a row in a move list, 0 for an empty list.
## moves: move ids in order.
func _longest_streak(moves: Array) -> int:
	# best: the longest streak so far.
	var best: int = 0
	# streak: the length of the current streak.
	var streak: int = 0
	for i: int in moves.size():
		streak = streak + 1 if i > 0 and moves[i] == moves[i - 1] else 1
		best = maxi(best, streak)
	return best


## The first choice is exactly Rng.weighted_index over the weight > 0 moves on combat_ai, and only
## combat_ai moves.
func test_first_choice_is_one_weighted_draw() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	for run_seed: int in [1, 2, 3, 99]:
		# state: a fresh AI state.
		var state: Dictionary = AiFixtures.ai_state(run_seed, 1)
		# expected: the same draw made by hand, over light / medium / heavy.
		var expected: Dictionary = Rng.weighted_index(state, "combat_ai", [1, 2, 5])
		# before: the streams before the choice.
		var before: Dictionary = state["rng"].duplicate()
		# move_id: the choice.
		var move_id: String = MoveChoice.choose_in_place(state, rules["enemies"]["ai_weighted"], AiFixtures.ai_enemy("ai_weighted"))
		assert_eq(move_id, ["light", "medium", "heavy"][expected["value"]], "seed %d" % run_seed)
		assert_eq(state["rng"]["combat_ai"], expected["state"]["rng"]["combat_ai"], "one draw on combat_ai")
		for key: String in before:
			if key != "combat_ai":
				assert_eq(state["rng"][key], before[key], "%s untouched" % key)


## Fixed seeds give recorded move sequences, and the same seed always gives the same sequence.
func test_recorded_sequences() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# actual: the sequence for each seed.
	var actual: Array = []
	for run_seed: int in SEQUENCE_SEEDS:
		actual.append(_run(rules, "ai_weighted", run_seed, 16)["moves"])
		assert_eq(_run(rules, "ai_weighted", run_seed, 16)["moves"], actual[-1], "replay of seed %d" % run_seed)
	assert_eq(actual, RECORDED_SEQUENCES, "recorded sequences")


## Over many seeds the first choice follows the weights 1 : 2 : 5 : 0. The exact counts are
## recorded (deterministic), and they are also checked to be within 3 percentage points of the
## weights' shares. The weight-0 move is never chosen.
func test_first_choice_frequencies() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# ids: ai_weighted's moves, in definition order.
	var ids: Array = ["light", "medium", "heavy", "special"]
	# counts: how often each move came first.
	var counts: Array = [0, 0, 0, 0]
	for run_seed: int in FREQUENCY_SEEDS:
		counts[ids.find(_run(rules, "ai_weighted", run_seed, 1)["moves"][0])] += 1
	assert_eq(counts, RECORDED_COUNTS, "recorded counts")
	assert_eq(counts[3], 0, "weight 0 is never chosen at random")
	# shares: each weight as a share of the total 8, in percent times FREQUENCY_SEEDS.
	var shares: Array = [1, 2, 5, 0]
	for i: int in 3:
		# percent_diff: how far the count is from its expected share, in hundredths of the seeds.
		var percent_diff: int = absi(counts[i] * 8 - shares[i] * FREQUENCY_SEEDS) * 100 / (8 * FREQUENCY_SEEDS)
		assert_true(percent_diff < 3, "%s: %d of %d" % [ids[i], counts[i], FREQUENCY_SEEDS])


## Over long runs on several seeds a weight-0 move is never chosen at random.
func test_weight_zero_never_chosen() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	for run_seed: int in [5, 6, 7]:
		assert_false(_run(rules, "ai_weighted", run_seed, LONG_RUN)["moves"].has("special"), "seed %d" % run_seed)


## Over long runs no move is chosen three times in a row, even a move ten times as likely as the
## other; after two in a row the other move always follows. The rule is really exercised: the
## likely move comes twice in a row hundreds of times.
func test_never_three_in_a_row() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	for def_id: String in ["ai_heavy", "ai_weighted", "ai_duo"]:
		for run_seed: int in [11, 12, 13]:
			# moves: a long run.
			var moves: Array = _run(rules, def_id, run_seed, LONG_RUN)["moves"]
			assert_true(_longest_streak(moves) <= MoveChoice.MAX_REPEATS, "%s seed %d: longest streak %d" % [def_id, run_seed, _longest_streak(moves)])
	# heavy: a long ai_heavy run.
	var heavy: Array = _run(rules, "ai_heavy", 11, LONG_RUN)["moves"]
	# doubles: how often "often" came twice in a row.
	var doubles: int = 0
	for i: int in range(1, heavy.size()):
		if heavy[i] == "often" and heavy[i - 1] == "often":
			doubles += 1
			if i + 1 < heavy.size():
				assert_eq(heavy[i + 1], "seldom", "after two in a row at %d" % i)
	assert_true(doubles > 500, "the ban was exercised (%d doubles)" % doubles)


## banned_move: the move of the last two intents when they match, otherwise "".
func test_banned_move() -> void:
	assert_eq(MoveChoice.banned_move([]), "")
	assert_eq(MoveChoice.banned_move(["a"]), "")
	assert_eq(MoveChoice.banned_move(["a", "b"]), "")
	assert_eq(MoveChoice.banned_move(["a", "a"]), "a")
	assert_eq(MoveChoice.banned_move(["b", "a", "a"]), "a")
	assert_eq(MoveChoice.banned_move(["a", "a", "b"]), "")


## With only one candidate no draw is made, so combat_ai does not move. An enemy with one weighted
## move repeats it even after two in a row: the ban is lifted because nothing else may be chosen.
func test_single_candidate_no_draw_and_ban_lifted() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# result: ten intents of ai_lonely.
	var result: Dictionary = _run(rules, "ai_lonely", 3, 10)
	assert_eq(result["moves"], ["only", "only", "only", "only", "only", "only", "only", "only", "only", "only"])
	assert_eq(result["state"]["rng"], AiFixtures.ai_state(3, 1)["rng"], "no stream moved")


## No pattern and no move with weight above 0: no move ("").
func test_no_choosable_move() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# state: a fresh AI state.
	var state: Dictionary = AiFixtures.ai_state(4, 1)
	assert_eq(MoveChoice.choose_in_place(state, rules["enemies"]["ai_stuck"], AiFixtures.ai_enemy("ai_stuck")), "")
	assert_eq(state["rng"], AiFixtures.ai_state(4, 1)["rng"], "no draw")


## A scripted pattern is followed exactly, cycling, with no draw. It ignores weights (Bouncer's
## moves are weight 0) and the no-three rule (ai_triple stomps three times in a row, G11).
func test_pattern_followed_exactly() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# bouncer: eight Bouncer intents.
	var bouncer: Dictionary = _run(rules, "ai_bouncer", 8, 8)
	assert_eq(bouncer["moves"], ["guard_up", "hit", "guard_up", "hit", "guard_up", "hit", "guard_up", "hit"])
	assert_eq(bouncer["state"]["rng"], AiFixtures.ai_state(8, 1)["rng"], "patterns never draw")
	# triple: nine ai_triple intents.
	var triple: Dictionary = _run(rules, "ai_triple", 9, 9)
	assert_eq(triple["moves"], ["stomp", "stomp", "stomp", "rest", "stomp", "stomp", "stomp", "rest", "stomp"])
	assert_eq(MoveChoice.pattern_move(["a", "b", "c"], 7), "b", "7 % 3 = 1")


## When the combat_ai stream is missing and a draw is needed, the first candidate is taken and
## nothing fails (Fight.check_start refuses such a fight; this only guards hand-made states).
func test_missing_stream_takes_first_candidate() -> void:
	# rules: the AI test ruleset.
	var rules: Dictionary = AiFixtures.ruleset()
	# state: an AI state without streams.
	var state: Dictionary = AiFixtures.ai_state(1, 1)
	state["rng"] = {}
	assert_eq(MoveChoice.choose_in_place(state, rules["enemies"]["ai_weighted"], AiFixtures.ai_enemy("ai_weighted")), "light")
	assert_eq(state["rng"], {})
