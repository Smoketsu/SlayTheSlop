## The words of every hover tooltip (task 045). Lane: client (Agent B).
##
## One table, TOOLTIPS, holds what a stat, status, intent kind, pile, card keyword or the Bro Meter
## does, keyed by the GDD field name or core id as written (the client/visual/icons.gd keys: guard,
## swole, broken_arms, ick, exposed, attack, draw_pile ...; card keywords from core/schema/card_def.gd
## KEYWORDS). No other client file holds tooltip text: the fight screen, the combatant views, the card
## faces, the run header and the offer screen all ask here.
##
## Gear and Brew tooltips are not in the table: they are the item's own "name" and "text" from its
## data file (data/gear/, data/brews/), read through the ruleset, so a data change shows at once.
## At Baileys every Brew is a Shake (CLAUDE.md "Baileys sells weed, not drinks"), in tooltips too:
## brew() then uses client/run/run_text.gd shake_text().
##
## Numbers: no digit is typed into a sentence. A tuning constant is written as a placeholder that
## fill() replaces with its value from data/constants.json (through the ruleset):
##   {NAME}       the value as stored, a whole number (ICK_THRESHOLD_STEP -> 3)
##   {NAME:more}  a multiplier above 1 as the percent it adds (EXPOSED_MULT 1.5 -> 50)
##   {NAME:less}  a multiplier below 1 as the percent it takes off (NOODLE_MULT 0.75 -> 25)
##   {NAME:pct}   a fraction as a percent (BROKEN_ARM_MAX_REDUCTION 0.4 -> 40)
## A fixed amount the GDD states without a constant ("1 stack per turn", "1 fewer card") is said in
## words, as client/help/how_to_play_text.gd does.
##
## Text follows GDD "Rules for writers", its glossary and "Statuses" / "Stats" / "Card types and
## keywords" / "Bro Meter": every rule stated is one the GDD (or the core's schema) states; where
## the GDD says nothing, nothing is said. Jokes land on the Dudes or the monsters. Writers may
## change any sentence; keep the placeholders. Pure: reads only its arguments.
extends RefCounted

const RunText := preload("res://client/run/run_text.gd")
const Messages := preload("res://client/fight/messages.gd")

## Key (an icons.gd key, a card keyword or a card type) -> what it does, one or two short sentences
## with {CONSTANT} placeholders (see the file header). Changed only by the client lane; tests/client
## fails when a status or intent kind the core can put in state has no entry here.
const TOOLTIPS := {
	# Stats (GDD "Stats", "Dude state").
	"hp": "Hit points. A Dude carries them between fights and Passes Out when they run out.",
	"guard": "Soaks up damage before HP does. A Dude's Guard is gone at Refresh.",
	"swole": "Added to every hit of every attack. Leg day is still pending.",
	"chill": "Added to the Guard gained from each card. Nothing gets to a Chill Dude.",
	"clout": "Added to the Dude's signature effect, like Ick. Being known is half the work.",
	"hype": "Spent to play cards. Refills at Refresh every turn, so spend it all.",
	# Statuses (GDD "Statuses"; ids from core/schema/README.md "Status ids", with Broken Arm and Ick
	# under their own fields' names, as in icons.gd).
	"exposed": "Takes {EXPOSED_MULT:more}% more attack damage. Loses a stack every turn.",
	"noodle_arms": "Deals {NOODLE_MULT:less}% less attack damage. Loses a stack every turn.",
	"hungover": "Gains {HUNGOVER_MULT:less}% less Guard from cards. Loses a stack every turn.",
	"foggy": "Draws one fewer card at Refresh. Loses a stack every turn.",
	"broken_arms": "Each broken arm weakens its attacks; with every arm broken they deal "
		+ "{BROKEN_ARM_MAX_REDUCTION:pct}% less, and it is Armless: it loses its next attack, once per fight. "
		+ "Arms stay broken.",
	"ick": "At its Ick threshold it is Grossed Out: it skips its next action, its Ick resets "
		+ "and the threshold rises by {ICK_THRESHOLD_STEP}. It is not charisma.",
	"faded": "A ghost thing. While Faded it takes at most {FADED_MAX_DAMAGE} damage per hit.",
	# Intent kinds (core/schema/enemy_def.gd MOVE_SPEC "intent" and every kind data/enemies/ uses).
	"attack": "It will attack the Dude it is aiming at. The number is its damage per hit.",
	"defend": "It will gain Guard.",
	"buff": "It will make itself or its crew stronger.",
	"debuff": "It will stick a Dude with a status.",
	"summon": "It will call more monsters into the fight.",
	"charge": "It is winding up something big. Brace for it.",
	"flee": "It will run off, and anything it stole goes with it.",
	"unknown": "Nobody knows what it will do next. Not even it.",
	# Client keys of icons.gd: a skipped intent, the target and seat markers.
	"skipped": "It loses this action.",
	"target": "The Dude this attack is aimed at.",
	"seat": "This Dude's colour. Attacks aimed at them carry the same colour.",
	# The Bro Meter (GDD "Bro Meter").
	"bro_meter": "Shared by the party. Solo, it gains a point for every {BRO_METER_SOLO_CARDS} cards played "
		+ "in a turn; in co-op, for hitting an enemy a teammate debuffed this turn. At {BRO_METER_MAX}, "
		+ "empty it for a free Bro Move.",
	# Piles (GDD "Turn flow", "Dude state" draw_pile / discard_pile / tapped_pile).
	"draw_pile": "Cards waiting to be drawn. When it runs dry, the discard pile is shuffled back in.",
	"discard_pile": "Played cards, and whatever was left in hand at end of turn.",
	"tapped_pile": "Tapped cards: gone for the rest of the fight.",
	# Card keywords (core/schema/card_def.gd KEYWORDS; GDD "Card types and keywords").
	"tapped": "After play, the card is removed for the rest of the fight.",
	"pocketed": "The card is not discarded at end of turn.",
	"assist": "Can target a teammate. In solo play it targets yourself.",
	"tech": "A Tech card. Some Gear makes Tech attacks hit more.",
	# The Junk card type (GDD "Card types and keywords").
	"junk": "Unplayable or harmful. Enemies and bad decisions put it in your deck.",
}
## Card keywords (core/schema/card_def.gd KEYWORDS) -> the word a card face uses for them, so a
## keyword tooltip line starts with the word the player reads. Changed only by the client lane.
const KEYWORD_NAMES := {
	"tapped": "Tapped",
	"pocketed": "Pocketed",
	"assist": "Assist",
	"tech": "Tech",
}
## Card types (core/schema/card_def.gd TYPES) whose TOOLTIPS entry a card face of that type shows.
## Only Junk: the other types are plain to read on the face. Changed only by the client lane.
const TYPE_TIPS: Array[String] = ["junk"]
## Joins a name to its value or text on a tooltip's first line ("Exposed: 2"). Changed only by the
## client lane.
const NAME_JOIN: String = ": "
## The pattern of a placeholder in a TOOLTIPS sentence: the constant's name, then an optional form.
## Fixed: fill() and the tests read it.
const PLACEHOLDER: String = "\\{([A-Z_]+)(?::(more|less|pct))?\\}"


## Returns what a key does, its placeholders filled from the ruleset's constants; "" for a key with
## no entry (the caller then shows only the name and value).
## ruleset: read-only content with "constants" (data/constants.json, name -> value).
## key: an icons.gd key, a card keyword or a card type.
static func describe(ruleset: Dictionary, key: String) -> String:
	if not TOOLTIPS.has(key):
		return ""
	return fill(ruleset.get("constants", {}), TOOLTIPS[key])


## Returns every TOOLTIPS entry filled: key -> sentence. The fight screen builds it once per redraw
## and hands it to the views, which have no ruleset of their own.
## ruleset: read-only content with "constants".
static func all(ruleset: Dictionary) -> Dictionary:
	# out: the result.
	var out: Dictionary = {}
	for key: String in TOOLTIPS:
		out[key] = describe(ruleset, key)
	return out


## Returns a sentence with each {NAME}, {NAME:more}, {NAME:less} and {NAME:pct} replaced by the
## constant's value (see the file header). A name missing from constants is left as written, so a
## gap shows instead of a made-up number.
## constants: tuning constants, name -> value (int or float). template: a TOOLTIPS sentence.
static func fill(constants: Dictionary, template: String) -> String:
	# out: the sentence being filled.
	var out: String = template
	for found: RegExMatch in RegEx.create_from_string(PLACEHOLDER).search_all(template):
		# name: the constant's name. form: how to show it ("" for as stored).
		var name: String = found.get_string(1)
		var form: String = found.get_string(2)  # "more", "less", "pct" or ""
		if not constants.has(name):
			continue
		# value: the constant as a float, for the percent forms.
		var value: float = float(constants[name])
		# shown: the number as written in the sentence.
		var shown: String = str(constants[name])
		match form:
			"more":
				shown = str(roundi((value - 1.0) * 100.0))
			"less":
				shown = str(roundi((1.0 - value) * 100.0))
			"pct":
				shown = str(roundi(value * 100.0))
		out = out.replace(found.get_string(0), shown)
	return out


## Returns a badge's whole tooltip: "<name>: <value>" (or the name alone when value is ""), then the
## description on the next line when there is one.
## name: the player-facing name (icons.gd look()). value: what the badge says after the name, "" for
## none. description: what it does (describe()), "" for none.
static func badge(name: String, value: String, description: String) -> String:
	# first: the name and value line.
	var first: String = name + (NAME_JOIN + value if value != "" else "")
	return first + ("\n" + description if description != "" else "")


## Returns a Gear's tooltip from its data file: "<name>: <text>". The id itself when the ruleset has
## no such Gear.
## ruleset: read-only content. gear_id: a Gear id (data/gear/).
static func gear(ruleset: Dictionary, gear_id: String) -> String:
	# item: the definition, or {}.
	var item: Dictionary = ruleset.get("gear", {}).get(gear_id, {})
	if item.is_empty():
		return gear_id
	return item.get("name", gear_id) + NAME_JOIN + item.get("text", "")


## Returns a Brew's tooltip from its data file: "<name>: <text>", or, at Baileys, the Shake line
## RunText.shake_text() gives ("Shake: <name> — <text>"), never the word Brew. The id itself (or
## "Shake" at Baileys) when the ruleset has no such Brew.
## ruleset: read-only content. brew_id: a Brew id (data/brews/). at_baileys: true while the player is
## at Baileys (the shop screen is up).
static func brew(ruleset: Dictionary, brew_id: String, at_baileys: bool) -> String:
	# item: the definition, or {}.
	var item: Dictionary = ruleset.get("brews", {}).get(brew_id, {})
	if at_baileys:
		return RunText.shake_text(ruleset, brew_id)
	if item.is_empty():
		return brew_id
	return item.get("name", brew_id) + NAME_JOIN + item.get("text", "")


## Returns a card face's tooltip: one line per keyword on the card ("Tapped: After play, ..."), in
## the definition's keyword order, then the Junk line for a Junk card; "" when there is nothing to
## explain. Only the card's own "keywords" and "type" count, so it never guesses from the rules text.
## ruleset: read-only content with "constants". definition: the card copy's effective definition
## (core/combat/upgrades.gd definition_of()), or {}.
static func card(ruleset: Dictionary, definition: Dictionary) -> String:
	# lines: the tooltip lines.
	var lines: Array[String] = []
	for keyword: String in definition.get("keywords", []):
		if TOOLTIPS.has(keyword):
			lines.append(KEYWORD_NAMES.get(keyword, keyword.capitalize()) + NAME_JOIN + describe(ruleset, keyword))
	# type: the card's type code.
	var type: String = definition.get("type", "")
	if TYPE_TIPS.has(type):
		lines.append(Messages.card_type_name(type) + NAME_JOIN + describe(ruleset, type))
	return "\n".join(lines)


## Returns an offer option's tooltip (core/schema/dude_state.gd OPTION_SPEC): a card option's keyword
## lines (card()), a Gear option's data text (gear()), a Shake option's Shake line (brew() at
## Baileys); "" for any other kind (Nap, Lift, removal, Side Quest choices say it all on the button).
## ruleset: read-only content. option: one entry of an offer's "options".
static func option_tooltip(ruleset: Dictionary, option: Dictionary) -> String:
	match option.get("kind", ""):
		"card":
			return card(ruleset, ruleset.get("cards", {}).get(option.get("card_id", ""), {}))
		"gear":
			return gear(ruleset, option.get("gear_id", ""))
		"shake":
			return brew(ruleset, option.get("brew_id", ""), true)
	return ""
