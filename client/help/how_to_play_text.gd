## The words of the How to play panels (task 049). Lane: client (Agent B).
##
## Pure: panels() reads the ruleset and returns text; it changes nothing and reads no file. Every
## number in the text comes from the ruleset: tuning constants from data/constants.json (the names
## in USED_CONSTANTS and PERCENT_CONSTANTS), and the Bro Move's name and text from the Dude's card
## in data/cards/. No digit is typed into a sentence here (a fixed amount the GDD states without a
## constant is said in words, like "a notch"), so retuning a constant retunes the help. Names of
## map nodes come from client/run/run_text.gd NODE_LABELS, as on the map.
##
## Text follows GDD "Rules for writers" and its glossary: Hype, Guard, Dolla Bills, Gear, Brew,
## The Tailgate, Baileys. Baileys sells weed, not drinks (CLAUDE.md), so it is only ever said to
## sell Shake. Jokes land on the Dudes or the monsters. Every rule stated is one the GDD states
## ("Turn flow", "Bro Meter", "Node types", "Items"). Writers may change any sentence; keep the
## %d placeholders fed from the ruleset.
extends RefCounted

const RunText := preload("res://client/run/run_text.gd")

## Constants (data/constants.json names) the panels show as whole numbers, as stored. Tests change
## each one and check the text follows. Add a name here when a sentence starts showing it.
const USED_CONSTANTS: Array[String] = [
	"BASE_DRAW",
	"BASE_HYPE",
	"BRO_METER_SOLO_CARDS",
	"BRO_METER_MAX",
	"CARD_REWARD_CHOICES",
	"BRAWL_DOLLA_MIN",
	"BRAWL_DOLLA_MAX",
	"START_DOLLA_BILLS",
	"BASE_BREW_SLOTS",
]
## Constants the panels show as a percent: a fraction from 0 to 1 in the data, shown times 100 and
## rounded to a whole number. Same rule as USED_CONSTANTS for adding a name.
const PERCENT_CONSTANTS: Array[String] = [
	"TAILGATE_NAP_HEAL",
]


## Returns the panels in order, each {"title": String, "body": String}: Hype and cards, Guard,
## enemy intents, the Bro Meter and the Bro Move, the map's fights, the other stops on the map,
## and Brews and Gear.
## ruleset: read-only content (core/ruleset/ruleset.gd), with every name in USED_CONSTANTS and
## PERCENT_CONSTANTS. dude_id: whose Bro Move the Bro Meter panel names; "" (the main menu, no run
## yet) means the first Dude in the data by id, the one New Run starts with.
static func panels(ruleset: Dictionary, dude_id: String) -> Array[Dictionary]:
	# c: the tuning constants, name -> value.
	var c: Dictionary = ruleset["constants"]
	# labels: map node type -> its name on the map.
	var labels: Dictionary = RunText.NODE_LABELS
	return [
		{
			"title": "Hype and cards",
			"body": ("Each turn you draw %d cards and get %d Hype. A card costs the Hype shown on it. "
				+ "Spend it all: Hype refills every turn, and the Dudes have never saved anything in "
				+ "their lives.") % [c["BASE_DRAW"], c["BASE_HYPE"]],
		},
		{
			"title": "Guard",
			"body": "Guard soaks up damage before your HP does. It is gone when your next turn "
				+ "starts, like every good intention. HP carries over between fights; run out and "
				+ "you pass out.",
		},
		{
			"title": "Enemy intents",
			"body": "Every enemy shows what it will do next and which Dude it is aiming at. Press "
				+ "Ready when you are done, and the enemies act left to right. Dungeon monsters are "
				+ "terrible at keeping secrets.",
		},
		{
			"title": _bro_title(ruleset, dude_id),
			"body": _bro_body(ruleset, dude_id),
		},
		{
			"title": "The map",
			"body": ("Pick your path one node at a time. A %s is a normal fight: pick a card out of "
				+ "%d, plus %d to %d Dolla Bills and sometimes a Brew. A %s is a tougher fight with "
				+ "Gear in it. The %s waits at the end of the floor.") % [
					labels["brawl"], c["CARD_REWARD_CHOICES"], c["BRAWL_DOLLA_MIN"],
					c["BRAWL_DOLLA_MAX"], labels["rival"], labels["boss"]],
		},
		{
			"title": "Stops along the way",
			"body": ("%s: a safe choice and a dumb one.\n%s: Nap to heal %d%% of your max HP, or "
				+ "Lift to upgrade a card.\n%s: spend Dolla Bills (you start with %d) on cards, Gear "
				+ "and Shake, or pay to get rid of a card.\n%s: free Gear from a cooler nobody is "
				+ "watching.") % [
					labels["side_quest"], labels["tailgate"], _percent(c["TAILGATE_NAP_HEAL"]),
					labels["baileys"], c["START_DOLLA_BILLS"], labels["loot"]],
		},
		{
			"title": "Brews and Gear",
			"body": ("Gear stays with you for the whole run. A Brew is used once: you start with %d "
				+ "Brew slots, and drinking one costs no Hype and works any time on your turn. Shake from "
				+ "%s goes in a Brew slot too.") % [c["BASE_BREW_SLOTS"], labels["baileys"]],
		},
	]


## Returns the Bro Meter panel's title: "Bro Meter and <Bro Move name>", or "Bro Meter" when the
## Dude has no Bro Move in the data.
## ruleset: read-only content. dude_id: as in panels().
static func _bro_title(ruleset: Dictionary, dude_id: String) -> String:
	# bro: the Bro Move card's definition, or {}.
	var bro: Dictionary = _bro_move(ruleset, dude_id)
	return ("Bro Meter and %s" % bro["name"]) if bro.has("name") else "Bro Meter"


## Returns the Bro Meter panel's text (GDD "Bro Meter", solo rule): how it fills, its top, and the
## Dude's Bro Move by name with its card text, both from the data.
## ruleset: read-only content. dude_id: as in panels().
static func _bro_body(ruleset: Dictionary, dude_id: String) -> String:
	# c: the tuning constants. bro: the Bro Move card's definition, or {}.
	var c: Dictionary = ruleset["constants"]
	var bro: Dictionary = _bro_move(ruleset, dude_id)
	# fill: how the meter fills, from the constants.
	var fill: String = "Every %d cards you play in one turn push the Bro Meter up a notch." % [
		c["BRO_METER_SOLO_CARDS"]]
	if not bro.has("name"):
		return fill + " At %d, your Dude's Bro Move is ready." % c["BRO_METER_MAX"]
	# effect: the card's own text, ending in a full stop.
	var effect: String = str(bro.get("text", "")).strip_edges()
	if effect != "" and not effect.ends_with("."):
		effect += "."
	return fill + " At %d, press Bro Move to play %s for free and empty the meter. %s" % [
		c["BRO_METER_MAX"], bro["name"], effect]


## Returns the Bro Move card definition of a Dude, or {} when the Dude or its card is not in the
## data.
## ruleset: read-only content. dude_id: as in panels().
static func _bro_move(ruleset: Dictionary, dude_id: String) -> Dictionary:
	# dudes: Dude id -> definition. id: the Dude to read.
	var dudes: Dictionary = ruleset.get("dudes", {})
	var id: String = dude_id
	if id == "":
		# ids: every Dude id, sorted, so the pick is the same one New Run makes.
		var ids: Array = dudes.keys()
		ids.sort()
		id = ids[0] if not ids.is_empty() else ""
	# card_id: the Dude's bro_move card id, or "".
	var card_id: String = dudes.get(id, {}).get("bro_move", "")
	return ruleset.get("cards", {}).get(card_id, {})


## Returns a fraction from the data as a whole percent, for example 0.3 -> 30.
## fraction: a float (or int) from 0 to 1.
static func _percent(fraction: Variant) -> int:
	return roundi(float(fraction) * 100.0)
