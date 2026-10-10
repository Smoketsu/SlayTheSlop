## Party-size scaling of enemy numbers (GDD "Difficulty scaling"). Lane: core (Agent A).
##
## Enemy HP multiplier = 1 + HP_SCALE_PER_EXTRA_PLAYER x (party_size - 1), which gives the GDD's
## 1.0 / 1.8 / 2.6 / 3.4. "Ick thresholds scale with the HP multiplier, rounded up" (GDD).
## The GDD does not say how scaled enemy HP rounds (core/schema/enemy_state.gd: "rounded as the core
## decides"): it is rounded DOWN here, like the damage order's step 5. Task 007 asks both people to
## confirm that.
##
## Exact integer math: the multiplier constant is turned once into a whole number of millionths
## (RATIO_DENOMINATOR), and every product is computed in ints, so 5 x 1.8 is exactly 9 and never
## 9.000000000000002 (which would round up to 10). Constants with more than six decimals would lose
## precision; none exist.
##
## Pure: no file, clock, network or random access.
extends RefCounted

## Denominator used to turn a fractional constant into an exact ratio: values are held as a whole
## number of millionths. A precision setting, not a tuning number; never needs changing.
const RATIO_DENOMINATOR: int = 1_000_000


## Returns value as a whole number of millionths (0.8 -> 800000), rounded to the nearest one.
## value: a constant from ruleset.constants, an int or a float, 0 or more.
static func to_millionths(value: Variant) -> int:
	return roundi(float(value) * RATIO_DENOMINATOR)


## Returns the party's enemy HP multiplier in millionths: 1000000 solo, 1800000 for two players.
## constants: ruleset.constants; reads HP_SCALE_PER_EXTRA_PLAYER. party_size: players in the run, 1..4.
static func hp_multiplier(constants: Dictionary, party_size: int) -> int:
	return RATIO_DENOMINATOR + to_millionths(constants["HP_SCALE_PER_EXTRA_PLAYER"]) * (party_size - 1)


## Returns base times the party's HP multiplier, rounded down. Used for enemy max_hp.
## base: the solo value, 0 or more. constants: ruleset.constants. party_size: players in the run, 1..4.
static func scale_down(base: int, constants: Dictionary, party_size: int) -> int:
	return base * hp_multiplier(constants, party_size) / RATIO_DENOMINATOR


## Returns base times the party's HP multiplier, rounded up. Used for Ick thresholds (GDD).
## base: the solo value, 0 or more. constants: ruleset.constants. party_size: players in the run, 1..4.
static func scale_up(base: int, constants: Dictionary, party_size: int) -> int:
	return (base * hp_multiplier(constants, party_size) + RATIO_DENOMINATOR - 1) / RATIO_DENOMINATOR
