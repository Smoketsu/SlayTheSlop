## Floor map generation and the map format (task 023). Lane: run (Agent A).
##
## Makes the branching map of one floor (GDD "Run structure"; structure from gap G18 in
## docs/proposals/solo-slice-rule-gaps.md) and owns the shape of run_state.map and the meaning of
## run_state.node_index (summary in core/schema/README.md "The floor map").
##
## Shape of a map (only JSON-shaped values, ints only, every list in a fixed order):
##   {"floor": int, the floor the map belongs to, 1 or more;
##    "nodes": Array of node Dictionaries, ordered by row, then by column}
##   A node: {"id": String "r<row>c<column>", unique in the map, what vote_node.node_id names;
##            "row": int, 0 the entrance, 1..MAP_ROWS the floor's rows, MAP_ROWS + 1 the boss row;
##            "column": int, 0.. the node's order within its row, left to right;
##            "type": String, one of the NODE_ constants below;
##            "links": Array of String, the ids of the next row's nodes this node leads to, in
##                     column order; [] for the boss}.
##   nodes[0] is the entrance (row 0, type "start"): where the party stands before the first vote,
##   linked to every row-1 node. It is not a node of the floor in the GDD sense (no share, nothing
##   to resolve). run_state.node_index is an index into nodes, so its blank() value 0 means "at the
##   start of the floor".
##
## Structure (G18, numbers from data/constants.json):
##   - Rows 1..MAP_ROWS hold MAP_MIN_NODES_PER_ROW..MAP_MAX_NODES_PER_ROW nodes each; then one boss
##     row with one "boss" node.
##   - Row 1 is all "brawl"; row MAP_ROWS (the row before the boss) is all "tailgate".
##   - Each node of rows 1..MAP_ROWS - 1 links to 1..MAP_MAX_LINKS nodes of the next row, and every
##     node of the next row has a link into it. Row MAP_ROWS links only to the boss. So every node
##     is reachable from the entrance and every path reaches the boss.
##   - Links never cross: if node a is left of node b in a row, none of a's targets is right of any
##     of b's. Not a G18 rule; it keeps the map drawable, and it is what makes "every node linked"
##     easy to guarantee. Within that, every valid link pattern between two rows is equally likely.
##
## Node types (GDD "Node types" shares, the NODE_SHARE_ constants, whole percents totalling 100):
##   - "A floor's nodes" are rows 1..MAP_ROWS; the entrance and the boss are not counted.
##   - Rounding to whole nodes per floor (apportion()): with N nodes, a type with share s gets
##     N * s / 100 nodes rounded down; the nodes left over go one each to the types with the
##     largest remainders, ties to the type earlier in SHARED_TYPES (the GDD table order). So each
##     type's count is its exact share rounded down or up, and the counts total N.
##   - The fixed rows count toward their type: row 1's Brawls toward the Brawl count, the pre-boss
##     row's Tailgates toward the Tailgate count. When a fixed row is larger than its type's count
##     rounded down, that type is rounded up instead (it can never exceed rounded up; see below).
##   - The pre-boss row's size is drawn only from the sizes that keep this possible (a row of 4
##     Tailgates needs a floor of at least 26 nodes at a 12% share). See draw step 2.
##   - The nodes of rows 2..MAP_ROWS - 1 get the remaining counts, shuffled. There are no placement
##     rules beyond G18 (a Rival may be in row 2, two Baileys may be adjacent): the GDD gives none.
##
## Random draws, all from the "map" stream (core/rng/rng.gd), in this order. Changing the order or
## the number of draws changes every seed's map; tests/run/map/test_floor_map.gd records one.
##   1. Sizes of rows 1..MAP_ROWS - 1, in row order: Rng.next_int(MAP_MIN_NODES_PER_ROW, MAP_MAX_NODES_PER_ROW).
##   2. Size of row MAP_ROWS: Rng.next_int over the sizes in MIN..MAX (ascending) for which apportion()
##      succeeds; one draw even when only one size fits.
##   3. Types of rows 2..MAP_ROWS - 1: Rng.shuffle of the remaining type list (in SHARED_TYPES order,
##      each type repeated by its count), assigned to those nodes in row then column order.
##   4. Links from row r to row r + 1 for r = 1..MAP_ROWS - 1: Rng.next_int index into
##      link_patterns(size of r, size of r + 1, MAP_MAX_LINKS).
##   The entrance's and the pre-boss row's links are fixed and draw nothing.
##
## Pure and deterministic: no file, clock, network or scene access; no randomness but the map
## stream; no Dictionary iteration order affects a result. Bad input (constants missing or out of
## range, a state without the map stream) is reported in the result's "error"; nothing asserts.
## Who may change values: only the run lane, through these functions.
extends RefCounted

const Rng := preload("res://core/rng/rng.gd")

## The random stream every draw comes from (GDD "Random streams": map = floor layouts). Fixed by the GDD.
const STREAM: String = "map"

## Type of the entrance node, nodes[0]. Not a GDD node type; never resolved. Part of the map format.
const NODE_START: String = "start"
## Type of a Brawl node (GDD "Node types": a normal fight). Part of the map format.
const NODE_BRAWL: String = "brawl"
## Type of a Rival node (an elite fight). Part of the map format.
const NODE_RIVAL: String = "rival"
## Type of a Side Quest node (a choice with a safe and a dumb option). Part of the map format.
const NODE_SIDE_QUEST: String = "side_quest"
## Type of a The Tailgate node (Nap or Lift). Part of the map format.
const NODE_TAILGATE: String = "tailgate"
## Type of a Baileys node (the shop). Part of the map format.
const NODE_BAILEYS: String = "baileys"
## Type of a Loot node (free Gear; a Mimic Cooler is decided by encounters, gap G19). Part of the map format.
const NODE_LOOT: String = "loot"
## Type of the boss node, the one node of the last row (GDD: 1 per floor). Part of the map format.
const NODE_BOSS: String = "boss"

## Node types that take a share of the floor, in GDD "Node types" table order. The order breaks
## rounding ties and orders the type list before it is shuffled, so changing it changes maps.
const SHARED_TYPES: Array[String] = [NODE_BRAWL, NODE_RIVAL, NODE_SIDE_QUEST, NODE_TAILGATE, NODE_BAILEYS, NODE_LOOT]

## Node type -> the data/constants.json constant holding its share, in whole percent. Read in SHARED_TYPES order.
const SHARE_CONSTANTS := {
	NODE_BRAWL: "NODE_SHARE_BRAWL",
	NODE_RIVAL: "NODE_SHARE_RIVAL",
	NODE_SIDE_QUEST: "NODE_SHARE_SIDE_QUEST",
	NODE_TAILGATE: "NODE_SHARE_TAILGATE",
	NODE_BAILEYS: "NODE_SHARE_BAILEYS",
	NODE_LOOT: "NODE_SHARE_LOOT",
}

## Structure constants read from data/constants.json (G18), each a whole number.
const STRUCTURE_CONSTANTS: Array[String] = ["MAP_ROWS", "MAP_MIN_NODES_PER_ROW", "MAP_MAX_NODES_PER_ROW", "MAP_MAX_LINKS"]

## Type of every node in row 1 (G18: "Row 1 is always Brawls"). A rule, not a tuning number.
const FIRST_ROW_TYPE: String = NODE_BRAWL

## Type of every node in row MAP_ROWS, the row before the boss (G18). A rule, not a tuning number.
const PRE_BOSS_ROW_TYPE: String = NODE_TAILGATE

## Row of the entrance node. Part of the map format.
const ENTRANCE_ROW: int = 0

## The shares are whole percents: they must total this, and a share of N nodes is N * share / PERCENT.
const PERCENT: int = 100


## Generates the map of one floor from the state's "map" stream.
## ruleset: the loaded ruleset (core/ruleset/ruleset.gd); only ruleset["constants"] is read, for
##   STRUCTURE_CONSTANTS and the NODE_SHARE_ constants. Not changed.
## state: a run state (core/schema/run_state.gd) whose rng holds the "map" stream. Not changed.
## floor_number: the floor the map is for, 1 or more; stored in map.floor. The rules are the same
##   on every floor today (the GDD gives one share table).
## Returns {"state": the run state with only its "map" stream advanced (a shallow copy, see
##   core/rng/rng.gd), "map": the new map (shape in the file header), "error": ""}. On bad input,
##   {"state": state unchanged, "map": {}, "error": why}. The caller stores the map in
##   run_state.map and sets node_index to 0; this function does neither.
static func generate(ruleset: Dictionary, state: Dictionary, floor_number: int) -> Dictionary:
	# read: the constants this file needs, or an error.
	var read: Dictionary = _read_constants(ruleset)
	if read["error"] != "":
		return _refuse(state, read["error"])
	# values: constant name -> int value.
	var values: Dictionary = read["values"]
	if floor_number < 1:
		return _refuse(state, "floor_number must be 1 or more, got %d" % floor_number)
	if typeof(state.get("rng")) != TYPE_DICTIONARY or not state["rng"].has(STREAM):
		return _refuse(state, "state has no '%s' random stream; create the streams at run start (core/rng/rng.gd with_new_streams)" % STREAM)
	# rows: MAP_ROWS, the rows before the boss row.
	var rows: int = values["MAP_ROWS"]
	# min_nodes: MAP_MIN_NODES_PER_ROW.
	var min_nodes: int = values["MAP_MIN_NODES_PER_ROW"]
	# max_nodes: MAP_MAX_NODES_PER_ROW.
	var max_nodes: int = values["MAP_MAX_NODES_PER_ROW"]
	# max_links: MAP_MAX_LINKS.
	var max_links: int = values["MAP_MAX_LINKS"]
	# shares: whole-percent share of each type, in SHARED_TYPES order.
	var shares: Array[int] = []
	for type: String in SHARED_TYPES:
		shares.append(values[SHARE_CONSTANTS[type]])
	# current: the state as the map stream advances.
	var current: Dictionary = state

	# Draw 1: sizes of rows 1..rows - 1.
	# sizes: node count of rows 1..rows, index row - 1.
	var sizes: Array[int] = []
	for row: int in range(1, rows):
		# size_draw: one row size.
		var size_draw: Dictionary = Rng.next_int(current, STREAM, min_nodes, max_nodes)
		if size_draw.get("error", "") != "":
			return _refuse(state, size_draw["error"])
		current = size_draw["state"]
		sizes.append(size_draw["value"])

	# Draw 2: size of the pre-boss row, among the sizes the shares can hold.
	# fitting: candidate pre-boss row sizes, ascending, for which apportion() succeeds.
	var fitting: Array[int] = []
	# misfit: apportion()'s error for the last size that did not fit, reported if none fits.
	var misfit: String = ""
	for size: int in range(min_nodes, max_nodes + 1):
		# trial: the row sizes with this pre-boss size.
		var trial: Array[int] = sizes.duplicate()
		trial.append(size)
		# split: apportion()'s result for this trial.
		var split: Dictionary = apportion(_sum(trial), shares, _fixed_counts(trial))
		if split["error"] == "":
			fitting.append(size)
		else:
			misfit = split["error"]
	if fitting.is_empty():
		return _refuse(state, "no pre-boss row size in %d..%d fits the node shares: %s" % [min_nodes, max_nodes, misfit])
	# pick_draw: index into fitting.
	var pick_draw: Dictionary = Rng.next_int(current, STREAM, 0, fitting.size() - 1)
	if pick_draw.get("error", "") != "":
		return _refuse(state, pick_draw["error"])
	current = pick_draw["state"]
	sizes.append(fitting[pick_draw["value"]])

	# Draw 3: types of the rows between the fixed rows.
	# fixed: nodes of each type the fixed rows hold, in SHARED_TYPES order.
	var fixed: Array[int] = _fixed_counts(sizes)
	# counts: nodes of each type on the floor, in SHARED_TYPES order.
	var counts: Array = apportion(_sum(sizes), shares, fixed)["counts"]
	# free_types: one entry per node of rows 2..rows - 1, before shuffling.
	var free_types: Array = []
	for k: int in SHARED_TYPES.size():
		for n: int in counts[k] - fixed[k]:
			free_types.append(SHARED_TYPES[k])
	# type_draw: the shuffled free types.
	var type_draw: Dictionary = Rng.shuffle(current, STREAM, free_types)
	if type_draw.get("error", "") != "":
		return _refuse(state, type_draw["error"])
	current = type_draw["state"]
	# shuffled: free types in the order they are given to nodes.
	var shuffled: Array = type_draw["value"]

	# Draw 4: links between consecutive rows.
	# patterns_by_shape: "from,to" -> link_patterns(from, to, max_links), computed once per call.
	var patterns_by_shape: Dictionary = {}
	# row_links: for rows 1..rows - 1 (index row - 1), the chosen pattern: per node, next-row columns.
	var row_links: Array = []
	for row: int in range(1, rows):
		# shape: cache key for this pair of row sizes.
		var shape: String = "%d,%d" % [sizes[row - 1], sizes[row]]
		if not patterns_by_shape.has(shape):
			patterns_by_shape[shape] = link_patterns(sizes[row - 1], sizes[row], max_links)
		# patterns: every valid way to link these two rows.
		var patterns: Array = patterns_by_shape[shape]
		if patterns.is_empty():
			return _refuse(state, "rows of %d and %d nodes cannot be linked with at most %d links each" % [sizes[row - 1], sizes[row], max_links])
		# link_draw: index into patterns.
		var link_draw: Dictionary = Rng.next_int(current, STREAM, 0, patterns.size() - 1)
		if link_draw.get("error", "") != "":
			return _refuse(state, link_draw["error"])
		current = link_draw["state"]
		row_links.append(patterns[link_draw["value"]])

	# Build the nodes.
	# boss_row: the row number of the boss.
	var boss_row: int = rows + 1
	# entrance_links: ids of every row-1 node.
	var entrance_links: Array = []
	for column: int in sizes[0]:
		entrance_links.append(node_id(1, column))
	# nodes: the map's nodes in row, then column order.
	var nodes: Array = [_node(ENTRANCE_ROW, 0, NODE_START, entrance_links)]
	# next_free: index in shuffled of the next type to give a free node.
	var next_free: int = 0
	for row: int in range(1, rows + 1):
		for column: int in sizes[row - 1]:
			# type: this node's type.
			var type: String
			if row == 1:
				type = FIRST_ROW_TYPE
			elif row == rows:
				type = PRE_BOSS_ROW_TYPE
			else:
				type = shuffled[next_free]
				next_free += 1
			# links: ids of the next-row nodes this node leads to.
			var links: Array = []
			if row == rows:
				links.append(node_id(boss_row, 0))
			else:
				for target: int in row_links[row - 1][column]:
					links.append(node_id(row + 1, target))
			nodes.append(_node(row, column, type, links))
	nodes.append(_node(boss_row, 0, NODE_BOSS, []))
	return {"state": current, "map": {"floor": floor_number, "nodes": nodes}, "error": ""}


## Returns the id of the node at a row and column: "r<row>c<column>", for example "r3c1".
## row: the node's row, 0 (entrance) to MAP_ROWS + 1 (boss). column: its order in the row, 0 or more.
static func node_id(row: int, column: int) -> String:
	return "r%dc%d" % [row, column]


## Returns the index in map.nodes of the node with the given id (what run_state.node_index holds
## once the party is on it), or -1 when the map has no such node.
## map: a map in this file's shape. Not changed. id: a node id, for example vote_node.node_id.
static func index_of(map: Dictionary, id: String) -> int:
	# nodes: the map's nodes, or [] for an empty map.
	var nodes: Array = map.get("nodes", [])
	for i: int in nodes.size():
		if nodes[i].get("id") == id:
			return i
	return -1


## Rounds the type shares of a floor to whole nodes (see "Node types" in the file header).
## total: nodes on the floor (rows 1..MAP_ROWS), 0 or more.
## shares: whole-percent share of each type in SHARED_TYPES order, each 0 or more, totalling PERCENT.
## fixed: nodes of each type (SHARED_TYPES order) the fixed rows already hold, each 0 or more;
##   each type gets at least this many.
## Returns {"counts": Array of int, nodes of each type in SHARED_TYPES order, totalling total;
##   "error": ""}, or {"counts": [], "error": why} when a fixed row holds more of a type than its
##   share rounded up, or the input is malformed.
static func apportion(total: int, shares: Array, fixed: Array) -> Dictionary:
	if shares.size() != SHARED_TYPES.size() or fixed.size() != SHARED_TYPES.size():
		return {"counts": [], "error": "apportion needs %d shares and %d fixed counts" % [SHARED_TYPES.size(), SHARED_TYPES.size()]}
	# counts: the result being built, one per type.
	var counts: Array = []
	# ceilings: each type's share rounded up, the most it may get.
	var ceilings: Array[int] = []
	# remainders: each type's share of total, in hundredths of a node, beyond its whole nodes.
	var remainders: Array[int] = []
	# assigned: nodes given out so far.
	var assigned: int = 0
	for k: int in SHARED_TYPES.size():
		# exact: this type's share of total, in hundredths of a node.
		var exact: int = total * shares[k]
		# whole: the share rounded down.
		var whole: int = exact / PERCENT
		remainders.append(exact % PERCENT)
		ceilings.append(whole + (1 if exact % PERCENT != 0 else 0))
		# count: rounded down, raised to what the fixed rows hold.
		var count: int = maxi(whole, fixed[k])
		if count > ceilings[k]:
			return {"counts": [], "error": "%s: the fixed row holds %d but a %d%% share of %d nodes rounds up to %d" % [
				SHARED_TYPES[k], fixed[k], shares[k], total, ceilings[k]]}
		counts.append(count)
		assigned += count
	# candidates: type indices that may still be rounded up, largest remainder first, ties by SHARED_TYPES order.
	var candidates: Array[int] = []
	for k: int in SHARED_TYPES.size():
		if counts[k] < ceilings[k]:
			candidates.append(k)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return remainders[a] > remainders[b] or (remainders[a] == remainders[b] and a < b))
	# left: nodes not yet given a type.
	var left: int = total - assigned
	if left < 0 or left > candidates.size():
		return {"counts": [], "error": "the fixed rows and shares cannot total %d nodes" % total}
	for n: int in left:
		counts[candidates[n]] += 1
	return {"counts": counts, "error": ""}


## Returns every valid way to link a row of from_count nodes to the next row of to_count nodes,
## in a fixed order (so a drawn index always means the same pattern). Valid: every node of both
## rows has at least one link, no node has more than max_links, and no two links cross. Such a
## pattern is a staircase from (0, 0) to (from_count - 1, to_count - 1) whose every step moves to
## the next node of one row or of both; it is enumerated depth-first, trying "next in this row",
## then "next in both", then "next in the next row".
## from_count: nodes in the row the links leave, 1 or more. to_count: nodes in the next row, 1 or
## more. max_links: most links one node of the first row may have, 1 or more.
## Returns an Array of patterns; a pattern is an Array of from_count Arrays, the i-th holding the
## next-row columns (ascending) node i links to. [] when no valid pattern exists.
static func link_patterns(from_count: int, to_count: int, max_links: int) -> Array:
	# found: the patterns, in enumeration order.
	var found: Array = []
	if from_count < 1 or to_count < 1 or max_links < 1:
		return found
	_extend_staircase([[0, 0]], 1, from_count, to_count, max_links, found)
	return found


## Continues one staircase of links depth-first and adds every finished valid one to found, as a
## pattern (see link_patterns()).
## path: the links so far, each [from column, to column], in order; not changed.
## degree: links the last path entry's from-node has so far, 1..max_links.
## from_count, to_count, max_links: as in link_patterns(). found: receives finished patterns.
static func _extend_staircase(path: Array, degree: int, from_count: int, to_count: int, max_links: int, found: Array) -> void:
	# at: the last link, [from column, to column].
	var at: Array = path[path.size() - 1]
	if at[0] == from_count - 1 and at[1] == to_count - 1:
		# pattern: next-row columns per from-node.
		var pattern: Array = []
		for i: int in from_count:
			pattern.append([])
		for link: Array in path:
			pattern[link[0]].append(link[1])
		found.append(pattern)
		return
	if at[0] + 1 < from_count:
		_extend_staircase(path + [[at[0] + 1, at[1]]], 1, from_count, to_count, max_links, found)
	if at[0] + 1 < from_count and at[1] + 1 < to_count:
		_extend_staircase(path + [[at[0] + 1, at[1] + 1]], 1, from_count, to_count, max_links, found)
	if at[1] + 1 < to_count and degree < max_links:
		_extend_staircase(path + [[at[0], at[1] + 1]], degree + 1, from_count, to_count, max_links, found)


## Reads and checks the constants generate() needs.
## ruleset: the loaded ruleset; ruleset["constants"] maps constant names to values.
## Returns {"values": Dictionary, constant name -> int, "error": ""} or {"values": {}, "error": why}.
static func _read_constants(ruleset: Dictionary) -> Dictionary:
	# constants: the ruleset's constants, or null when missing.
	var constants: Variant = ruleset.get("constants")
	if typeof(constants) != TYPE_DICTIONARY:
		return {"values": {}, "error": "ruleset has no constants"}
	# names: every constant read, structure first, then shares in SHARED_TYPES order.
	var names: Array[String] = STRUCTURE_CONSTANTS.duplicate()
	for type: String in SHARED_TYPES:
		names.append(SHARE_CONSTANTS[type])
	# values: the result being built.
	var values: Dictionary = {}
	for name: String in names:
		if not constants.has(name):
			return {"values": {}, "error": "constant %s is missing" % name}
		if typeof(constants[name]) != TYPE_INT:
			return {"values": {}, "error": "constant %s must be a whole number, got %s" % [name, var_to_str(constants[name])]}
		values[name] = constants[name]
	if values["MAP_ROWS"] < 2:
		return {"values": {}, "error": "MAP_ROWS must be 2 or more (row 1 and the pre-boss row are different rows), got %d" % values["MAP_ROWS"]}
	if values["MAP_MIN_NODES_PER_ROW"] < 1 or values["MAP_MAX_NODES_PER_ROW"] < values["MAP_MIN_NODES_PER_ROW"]:
		return {"values": {}, "error": "need 1 <= MAP_MIN_NODES_PER_ROW <= MAP_MAX_NODES_PER_ROW, got %d and %d" % [
			values["MAP_MIN_NODES_PER_ROW"], values["MAP_MAX_NODES_PER_ROW"]]}
	if values["MAP_MAX_LINKS"] < 1:
		return {"values": {}, "error": "MAP_MAX_LINKS must be 1 or more, got %d" % values["MAP_MAX_LINKS"]}
	if values["MAP_MAX_NODES_PER_ROW"] > values["MAP_MIN_NODES_PER_ROW"] * values["MAP_MAX_LINKS"]:
		return {"values": {}, "error": "MAP_MAX_NODES_PER_ROW (%d) must be at most MAP_MIN_NODES_PER_ROW * MAP_MAX_LINKS (%d), or some rows cannot all be reached" % [
			values["MAP_MAX_NODES_PER_ROW"], values["MAP_MIN_NODES_PER_ROW"] * values["MAP_MAX_LINKS"]]}
	# total: sum of the shares.
	var total: int = 0
	for type: String in SHARED_TYPES:
		if values[SHARE_CONSTANTS[type]] < 0:
			return {"values": {}, "error": "%s must be 0 or more, got %d" % [SHARE_CONSTANTS[type], values[SHARE_CONSTANTS[type]]]}
		total += values[SHARE_CONSTANTS[type]]
	if total != PERCENT:
		return {"values": {}, "error": "the NODE_SHARE_ constants must total %d, got %d" % [PERCENT, total]}
	return {"values": values, "error": ""}


## Returns how many nodes of each type (SHARED_TYPES order) the fixed rows hold: row 1's size for
## FIRST_ROW_TYPE, the last row's size for PRE_BOSS_ROW_TYPE.
## sizes: node count of rows 1..MAP_ROWS, index row - 1; 2 or more entries.
static func _fixed_counts(sizes: Array[int]) -> Array[int]:
	# fixed: the result, one zero per type to start.
	var fixed: Array[int] = []
	for type: String in SHARED_TYPES:
		fixed.append(0)
	fixed[SHARED_TYPES.find(FIRST_ROW_TYPE)] += sizes[0]
	fixed[SHARED_TYPES.find(PRE_BOSS_ROW_TYPE)] += sizes[sizes.size() - 1]
	return fixed


## Returns the sum of a list of ints.
## numbers: the ints to add, any count.
static func _sum(numbers: Array[int]) -> int:
	# total: running sum.
	var total: int = 0
	for number: int in numbers:
		total += number
	return total


## Returns one node Dictionary in the map format.
## row: its row. column: its order in the row. type: one of the NODE_ constants.
## links: ids of the next-row nodes it leads to, in column order.
static func _node(row: int, column: int, type: String, links: Array) -> Dictionary:
	return {"id": node_id(row, column), "row": row, "column": column, "type": type, "links": links}


## Returns generate()'s result for bad input: the state unchanged, no map, and the reason.
## state: the state generate() was given. error: why nothing was generated.
static func _refuse(state: Dictionary, error: String) -> Dictionary:
	return {"state": state, "map": {}, "error": error}
