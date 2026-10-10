## Effect conditions: the optional "if" field any effect may carry (task 013). Lane: core (Agent A).
## Catalogue: core/ops/README.md "Fields every op may have".
##
## An effect with "if" runs only when the condition holds at the moment the effect would run, so
## after the card's earlier effects. A condition about "the target" holds when at least one of the
## effect's targets is an enemy still in the fight that meets it; with no such target (no target at
## all, or the target died) it does not hold, and the effect is skipped without any event.
##
## Conditions (GDD "Tom, the Enforcer"):
##   "target_has_broken_arm": the target has at least 1 Broken Arm (Wrist Lock).
##   "target_now_armless":    the target is Armless: it has arms and every one is broken (Snap City,
##                            "If the target is now Armless"). Checked after the card's earlier
##                            effects, so the arm Snap City breaks counts. A target that was already
##                            Armless before the card still is "now" Armless.
##
## Reads only. Pure: no file, clock, network or random access.
extends RefCounted

const Bodies := preload("res://core/combat/bodies.gd")
const Statuses := preload("res://core/combat/statuses.gd")

## Every condition name an effect's "if" may hold. Only the core lane adds one, with a test and a
## README entry.
const CONDITIONS: Array[String] = ["target_has_broken_arm", "target_now_armless"]


## True when the condition holds for at least one of the targets (see the file header).
## state: the run state, in a fight. condition: one of CONDITIONS. targets: the effect's target ids.
static func holds(state: Dictionary, condition: String, targets: Array) -> bool:
	for target_id: String in targets:
		# body: the target, or {} if it is gone.
		var body: Dictionary = Bodies.find_alive(state, target_id)
		if body.is_empty() or not Statuses.is_enemy(body):
			continue
		match condition:
			"target_has_broken_arm":
				if body["broken_arms"] > 0:
					return true
			"target_now_armless":
				if Statuses.is_armless(body):
					return true
	return false
