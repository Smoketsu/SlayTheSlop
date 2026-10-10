## Exact fractions for the multipliers in the damage order and Hungover (task 009). Lane: core (Agent A).
##
## A ratio is an Array of two ints, [numerator, denominator], with the denominator 1 or more and the
## numerator 0 or more, always reduced to lowest terms. Multipliers from data/constants.json (0.75,
## 1.5, 0.4 ...) are turned into ratios once, through core/combat/party_scaling.gd to_millionths(),
## so 0.75 is exactly [3, 4] and 1.5 exactly [3, 2]. Products are reduced at every step, so the
## numbers stay small and nothing overflows, and a value is rounded down only when floor_times() is
## called: the GDD's "round down once" (damage order step 5). No float is ever used in a product.
## Constants with more than six decimals would lose precision; none exist.
##
## Pure: no file, clock, network or random access.
extends RefCounted

const Scaling := preload("res://core/combat/party_scaling.gd")

## The ratio 1 (multiplying by it changes nothing). Fixed by arithmetic, not a tuning number.
const ONE: Array = [1, 1]


## Returns a constant's value as an exact ratio in lowest terms: 0.75 -> [3, 4], 1.5 -> [3, 2], 2 -> [2, 1].
## value: an int or float from ruleset.constants, 0 or more.
static func from_constant(value: Variant) -> Array:
	return reduced(Scaling.to_millionths(value), Scaling.RATIO_DENOMINATOR)


## Returns numerator / denominator in lowest terms as a ratio.
## numerator: 0 or more. denominator: 1 or more.
static func reduced(numerator: int, denominator: int) -> Array:
	# divisor: the greatest common divisor, at least 1.
	var divisor: int = maxi(1, gcd(numerator, denominator))
	return [numerator / divisor, denominator / divisor]


## Returns the product of two ratios, in lowest terms. Cross-reduces first so the ints stay small.
## a: a ratio. b: a ratio.
static func times(a: Array, b: Array) -> Array:
	# left: a's numerator over b's denominator, reduced.
	var left: Array = reduced(a[0], b[1])
	# right: b's numerator over a's denominator, reduced.
	var right: Array = reduced(b[0], a[1])
	return [left[0] * right[0], left[1] * right[1]]


## Returns value times ratio, rounded down. value and the ratio are never negative, so integer
## division rounds down.
## value: an int, 0 or more. ratio: a ratio.
static func floor_times(value: int, ratio: Array) -> int:
	return value * ratio[0] / ratio[1]


## Returns the greatest common divisor of two ints, 0 or more (0 when both are 0).
## a: 0 or more. b: 0 or more.
static func gcd(a: int, b: int) -> int:
	# x: the first of the pair being reduced by Euclid's algorithm.
	var x: int = absi(a)
	# y: the other half; the loop ends when it reaches 0.
	var y: int = absi(b)
	while y != 0:
		# rest: the remainder of x / y.
		var rest: int = x % y
		x = y
		y = rest
	return x
