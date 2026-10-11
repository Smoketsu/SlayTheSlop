## Player-facing words for the map and offer screens (task 020), in the GDD's themed terms
## ("Glossary of themed terms", "Node types"). Lane: client (Agent B).
##
## Reads only: every function takes the ruleset and parts of a run state and returns text. Nothing
## here works out a price, a discount, an amount or a chance; those come from the state's offers
## (core/run/*.gd fill them in). Baileys sells weed, not drinks (CLAUDE.md): a Brew option there is
## always labelled Shake, and no string in this file names a drink.
## Writers may change any word here; keys are codes from core/schema/ and must not change.
extends RefCounted

## [added, task upgraded-card-display] The core's reader of a card copy's effective definition.
const Upgrades := preload("res://core/combat/upgrades.gd")

## Map node types (core/schema/run_state.gd map node "type") -> the label on the map. Changed only
## by the client lane. A type missing here shows as the code itself.
const NODE_LABELS := {
	"start": "Entrance",
	"brawl": "Brawl",
	"rival": "Rival",
	"side_quest": "Side Quest",
	"tailgate": "The Tailgate",
	"baileys": "Baileys",
	"loot": "Loot",
	"boss": "Boss",
}

## Floor number (run_state.floor, 1..4) -> the floor's name (GDD "Floors"). Only floor 1 is in the
## solo slice; the others are listed so the header never shows a bare number. Changed only by the
## client lane.
const FLOOR_NAMES := {
	1: "The Basement",
	2: "Dylan's Keep",
	3: "Firefly Music Festival",
	4: "The Drive Home",
}

## Offer kinds (core/schema/dude_state.gd OFFER_KINDS) -> the offer screen's title. A Side Quest's
## title is the quest's own name instead (see offer_title()). Changed only by the client lane.
const OFFER_TITLES := {
	"card": "Pick a card",
	"boss_gear": "Pick a Boss Gear",
	"tailgate": "The Tailgate",
	"baileys": "Baileys",
	"side_quest": "Side Quest",
}

## Offer kinds -> the line under the title. A Side Quest's line is the quest's own text instead.
## Changed only by the client lane.
const OFFER_PROMPTS := {
	"card": "Take one card into your deck, or skip it.",
	"boss_gear": "The boss dropped three pieces of Gear. Take one.",
	"tailgate": "Take a Nap, or Lift to upgrade a card.",
	"baileys": "Cards, Gear and Shake. Or pay to get rid of a card.",
	"side_quest": "",
}

## Offer kinds whose -1 choice is "leave" rather than "skip" -> the button's words. Any other
## skippable offer uses SKIP_LABEL. Changed only by the client lane.
const LEAVE_LABELS := {
	"baileys": "Leave Baileys",
}

## The skip button's words on a skippable offer that is not in LEAVE_LABELS (a card reward).
## Changed only by the client lane.
const SKIP_LABEL: String = "Skip"

## The label prefix of a Brew sold at Baileys (GDD "Prices at Baileys", G29: "Shake: <Brew name>").
## Must stay "Shake" (CLAUDE.md "Baileys sells weed, not drinks"). Changed only by a person's decision.
const SHAKE_PREFIX: String = "Shake"

## Joins an item's name to its effect text in an option label. Changed only by the client lane.
const TEXT_JOIN: String = " — "

## Option kinds that need a card picked from the option's card_uids before the request is sent
## (core/schema/dude_state.gd OPTION_OPTIONAL "card_uids"). Follows core/schema/request.gd OPTIONAL
## "card_uid"; changed only if that contract changes.
const CARD_PICK_KINDS: Array[String] = ["lift", "remove"]

## Option kind -> the heading over its card list while the player picks a card. Changed only by
## the client lane.
const PICK_PROMPTS := {
	"lift": "Pick a card to Lift (upgrade):",
	"remove": "Pick a card to get rid of:",
}

## Option kind -> what an unavailable option says after its label (dude_state.gd OPTION_SPEC
## "available": already bought, nothing to Lift or remove, or not qualified). The state does not
## say why; these follow the reasons the schema lists for each kind. Changed only by the client lane.
const UNAVAILABLE := {
	"card": "Sold",
	"gear": "Sold",
	"shake": "Sold",
	"remove": "Nothing to get rid of",
	"lift": "Nothing to Lift",
	"safe": "You can't do this one",
	"dumb": "You can't do this one",
}

## Marks an upgraded (Lifted) card copy's name in a card list. Changed only by the client lane.
const UPGRADED_MARK: String = "+"

## The money word (GDD glossary: Gold -> Dolla Bills). Changed only by a person's decision.
const MONEY: String = "Dolla Bills"


## Returns the map label of a node type, or the type code when it has none.
## node_type: a map node "type" (core/run/map/floor_map.gd NODE_ constants).
static func node_label(node_type: String) -> String:
	return NODE_LABELS.get(node_type, node_type)


## Returns the map screen's header, for example "Floor 1: The Basement".
## floor_number: run_state.floor, 1 or more.
static func floor_title(floor_number: int) -> String:
	if FLOOR_NAMES.has(floor_number):
		return "Floor %d: %s" % [floor_number, FLOOR_NAMES[floor_number]]
	return "Floor %d" % floor_number


## Returns a Dude's display name from the ruleset, or its dude_id when the ruleset lacks it.
## ruleset: the read-only content. dude: a Dude state (core/schema/dude_state.gd).
static func dude_name(ruleset: Dictionary, dude: Dictionary) -> String:
	return ruleset.get("dudes", {}).get(dude["dude_id"], {}).get("name", dude["dude_id"])


## Returns the line naming a Dude's HP and Dolla Bills, read from the state as they are.
## ruleset: the read-only content. dude: a Dude state.
static func dude_line(ruleset: Dictionary, dude: Dictionary) -> String:
	return "%s: %d / %d HP, %d %s" % [dude_name(ruleset, dude), dude["hp"], dude["max_hp"], dude["dolla_bills"], MONEY]


## Returns the offer screen's title: the quest's name for a Side Quest, else OFFER_TITLES.
## ruleset: the read-only content. offer: one entry of dude_state.offers.
static func offer_title(ruleset: Dictionary, offer: Dictionary) -> String:
	if offer["kind"] == "side_quest":
		return ruleset.get("side_quests", {}).get(offer["def_id"], {}).get("name", OFFER_TITLES["side_quest"])
	return OFFER_TITLES.get(offer["kind"], offer["kind"])


## Returns the line under the offer's title: the quest's text for a Side Quest, else OFFER_PROMPTS.
## ruleset: the read-only content. offer: one entry of dude_state.offers.
static func offer_prompt(ruleset: Dictionary, offer: Dictionary) -> String:
	if offer["kind"] == "side_quest":
		return ruleset.get("side_quests", {}).get(offer["def_id"], {}).get("text", "")
	return OFFER_PROMPTS.get(offer["kind"], "")


## Returns the skip button's words for a skippable offer.
## offer: one entry of dude_state.offers.
static func skip_label(offer: Dictionary) -> String:
	return LEAVE_LABELS.get(offer["kind"], SKIP_LABEL)


## Returns a card definition's cost as shown: the number, "X" for a cost that is a word, "-" for
## an unplayable card (cost below 0), as the fight screen shows it (client/fight/fight_model.gd).
## card: a card definition, or {} when the ruleset lacks it.
static func card_cost(card: Dictionary) -> String:
	# cost: the raw cost.
	var cost: Variant = card.get("cost", -1)
	if typeof(cost) == TYPE_STRING:
		return "X"
	return "-" if cost < 0 else str(cost)


## Returns one card definition as "<name> (<cost> Hype) — <text>".
## ruleset: the read-only content. card_id: a card definition id (data/cards/).
static func card_text(ruleset: Dictionary, card_id: String) -> String:
	# card: the definition, or {}.
	var card: Dictionary = ruleset.get("cards", {}).get(card_id, {})
	return "%s (%s Hype)%s%s" % [card.get("name", card_id), card_cost(card), TEXT_JOIN, card.get("text", "")]


## Returns a Gear definition as "<name> — <text>".
## ruleset: the read-only content. gear_id: a Gear id (data/gear/).
static func gear_text(ruleset: Dictionary, gear_id: String) -> String:
	# gear: the definition, or {}.
	var gear: Dictionary = ruleset.get("gear", {}).get(gear_id, {})
	return "%s%s%s" % [gear.get("name", gear_id), TEXT_JOIN, gear.get("text", "")]


## Returns a Brew sold at Baileys as "Shake: <Brew name> — <effect text>" (G29). Never the Brew's id.
## ruleset: the read-only content. brew_id: a Brew id (data/brews/).
static func shake_text(ruleset: Dictionary, brew_id: String) -> String:
	# brew: the definition, or {}.
	var brew: Dictionary = ruleset.get("brews", {}).get(brew_id, {})
	return "%s: %s%s%s" % [SHAKE_PREFIX, brew.get("name", SHAKE_PREFIX), TEXT_JOIN, brew.get("text", "")]


## Returns the display name of one of a Dude's card copies, with UPGRADED_MARK when it is Lifted.
## Task upgraded-card-display: the name comes from the copy's effective definition (core/combat/
## upgrades.gd definition_of(), upgraded for a Lifted copy), falling back to the base definition's
## name, then the def_id, so it matches the fight screen's hand (client/fight/fight_model.gd).
## ruleset: the read-only content. dude: the Dude holding it. card_uid: a key of dude["cards"].
static func card_copy_name(ruleset: Dictionary, dude: Dictionary, card_uid: String) -> String:
	# copy: the card instance, or {} for an unknown uid.
	var copy: Dictionary = dude["cards"].get(card_uid, {})
	# def_id: its definition id, or the uid when unknown.
	var def_id: String = copy.get("def_id", card_uid)
	# base_name: the base definition's name, or the def_id.
	var base_name: String = ruleset.get("cards", {}).get(def_id, {}).get("name", def_id)
	# name: the effective definition's name, or base_name when the copy has no usable definition.
	var name: String = base_name if copy.is_empty() else Upgrades.definition_of(ruleset, dude, card_uid).get("name", base_name)
	return name + (UPGRADED_MARK if copy.get("upgraded", false) else "")


## Returns one option's label, built only from the option's own fields and the ruleset's names:
## the item and its text, the price and amount exactly as the state gives them, and why it cannot
## be picked when "available" is false.
## ruleset: the read-only content. offer: the option's offer. option: one entry of offer["options"].
static func option_label(ruleset: Dictionary, offer: Dictionary, option: Dictionary) -> String:
	# text: the label without price or availability.
	var text: String = ""
	match option["kind"]:
		"card":
			text = card_text(ruleset, option.get("card_id", ""))
		"gear":
			text = gear_text(ruleset, option.get("gear_id", ""))
		"shake":
			text = shake_text(ruleset, option.get("brew_id", ""))
		"remove":
			text = "Get rid of a card"
		"nap":
			text = "Nap%sheal %d HP" % [TEXT_JOIN, option.get("amount", 0)]
		"lift":
			text = "Lift%supgrade a card" % TEXT_JOIN
		"safe", "dumb":
			# choice: the quest definition's safe or dumb option.
			var choice: Dictionary = ruleset.get("side_quests", {}).get(offer["def_id"], {}).get(option["kind"], {})
			text = "%s%s%s" % [choice.get("label", option["kind"].capitalize()), TEXT_JOIN, choice.get("text", "")]
		_:
			text = option["kind"]
	if option.has("price"):
		text += " [%d %s]" % [option["price"], MONEY]
	if not option["available"]:
		text += " (%s)" % UNAVAILABLE.get(option["kind"], "Not available")
	return text
