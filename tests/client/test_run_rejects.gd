## Reject wording on the run screen (task 020): on the offer screen an "unplayable" refusal (a Baileys
## buy without the Dolla Bills or a free Brew slot) reads as a shop refusal, not as a card that can't be
## played; elsewhere the fight wording from client/fight/messages.gd stays. Lane: tools/client (Agent B).
extends "res://tests/framework/test_case.gd"

const RunScreen := preload("res://client/run/run_screen.tscn")
const Messages := preload("res://client/fight/messages.gd")


## The offer screen uses OFFER_REJECTS; any other screen uses Messages.reject().
func test_offer_rejects_use_shop_wording() -> void:
	# screen: a run screen instance; only its current screen name is set, nothing is applied.
	var screen: Control = RunScreen.instantiate()
	screen.current = "offer"
	assert_eq(screen._reject_text("unplayable"), screen.OFFER_REJECTS["unplayable"])
	assert_false(screen._reject_text("unplayable").to_lower().contains("card"), "no card wording at Baileys")
	assert_eq(screen._reject_text("bad_target"), Messages.reject("bad_target"), "other codes keep their words")
	screen.current = "map"
	assert_eq(screen._reject_text("unplayable"), Messages.reject("unplayable"))
	screen.free()
