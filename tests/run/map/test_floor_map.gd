## Tests for core/run/map/floor_map.gd: floor map generation and the map format (task 023, gap G18).
## Lane: run (Agent A).
##
## The recorded-map test uses a fixed in-memory ruleset (FIXTURE_CONSTANTS), so tuning
## data/constants.json never needs a test change. The property test uses the real constants and
## checks the G18 rules against whatever values they hold. The rule checker here (_problems) is
## written independently of the generator, so it does not just repeat its logic.
extends "res://tests/framework/test_case.gd"

const FloorMap := preload("res://core/run/map/floor_map.gd")
const Rng := preload("res://core/rng/rng.gd")
const RunState := preload("res://core/schema/run_state.gd")
const DudeState := preload("res://core/schema/dude_state.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")
const Snapshot := preload("res://core/run/save/snapshot.gd")

## The real constants file on disk, read by the property tests. Tests may read files; the core may not.
const CONSTANTS_FILE := "res://data/constants.json"

## The map constants with the G18 / GDD values, used where a test must not depend on tuning.
const FIXTURE_CONSTANTS := {
	"MAP_ROWS": 7, "MAP_MIN_NODES_PER_ROW": 2, "MAP_MAX_NODES_PER_ROW": 4, "MAP_MAX_LINKS": 2,
	"NODE_SHARE_BRAWL": 45, "NODE_SHARE_RIVAL": 10, "NODE_SHARE_SIDE_QUEST": 20,
	"NODE_SHARE_TAILGATE": 12, "NODE_SHARE_BAILEYS": 8, "NODE_SHARE_LOOT": 5,
}

## Seed of the recorded map.
const RECORDED_SEED: int = 23

## The map generated for RECORDED_SEED with FIXTURE_CONSTANTS on floor 1, recorded on Godot
## 4.7.2-stable. One line per node, in map order: "<id> <type> <link ids, comma-separated>".
## If this changes, every seed's map changed (draw order, draw count or rules): a save made before
## would now hold a map the same seed no longer makes. Re-record only on purpose, and say so.
const RECORDED_MAP: Array[String] = [
	"r0c0 start r1c0,r1c1,r1c2",
	"r1c0 brawl r2c0,r2c1",
	"r1c1 brawl r2c1,r2c2",
	"r1c2 brawl r2c2",
	"r2c0 brawl r3c0",
	"r2c1 brawl r3c1,r3c2",
	"r2c2 side_quest r3c3",
	"r3c0 brawl r4c0",
	"r3c1 rival r4c1",
	"r3c2 baileys r4c1",
	"r3c3 brawl r4c1,r4c2",
	"r4c0 side_quest r5c0,r5c1",
	"r4c1 side_quest r5c2",
	"r4c2 brawl r5c2",
	"r5c0 loot r6c0",
	"r5c1 rival r6c0,r6c1",
	"r5c2 brawl r6c2",
	"r6c0 baileys r7c0",
	"r6c1 side_quest r7c1",
	"r6c2 brawl r7c2",
	"r7c0 tailgate r8c0",
	"r7c1 tailgate r8c0",
	"r7c2 tailgate r8c0",
	"r8c0 boss",
]

## The map stream's state after generating RECORDED_MAP, recorded with it. Catches a change in the
## number of draws even when the map happens to come out the same.
const RECORDED_STREAM_STATE: int = 300249470722516875

## How many seeds the property test generates (task 023 acceptance check: 1,000).
const PROPERTY_SEEDS: int = 1000

## First seed of the property test; seeds run from here upward, so negative seeds are covered too.
const PROPERTY_FIRST_SEED: int = -500

## Most failures the property test reports before stopping, so a broken generator prints a short log.
const MAX_REPORTED: int = 10

## The share-taking node types in GDD "Node types" order, written out here rather than read from
## the generator, with each type's constant.
const SHARES := {
	"brawl": "NODE_SHARE_BRAWL", "rival": "NODE_SHARE_RIVAL", "side_quest": "NODE_SHARE_SIDE_QUEST",
	"tailgate": "NODE_SHARE_TAILGATE", "baileys": "NODE_SHARE_BAILEYS", "loot": "NODE_SHARE_LOOT",
}


## Returns a ruleset holding only the given constants, shaped as core/ruleset/ruleset.gd makes it.
## constants: constant name -> value.
func _ruleset_with(constants: Dictionary) -> Dictionary:
	return {"constants": constants.duplicate()}


## Returns the real ruleset built from data/constants.json, or {} after recording a failure.
func _real_ruleset() -> Dictionary:
	# built: Ruleset.build()'s result for the constants file alone.
	var built: Dictionary = Ruleset.build({"data/constants.json": FileAccess.get_file_as_string(CONSTANTS_FILE)})
	assert_no_errors(built["errors"], "real ruleset")
	return built["ruleset"]


## Returns a fresh one-player run state with every random stream created from the seed.
## run_seed: the run's seed, any 64-bit int.
func _state(run_seed: int) -> Dictionary:
	return Rng.with_new_streams(RunState.blank(run_seed, [DudeState.blank("p1", "tom")]))


## Turns RECORDED_MAP lines into the map Dictionary they describe.
## lines: RECORDED_MAP-style lines. floor_number: the map's floor.
func _map_from_lines(lines: Array[String], floor_number: int) -> Dictionary:
	# id_parts: captures row and column from an id.
	var id_parts: RegEx = RegEx.create_from_string("^r(\\d+)c(\\d+)$")
	# nodes: the nodes built from the lines.
	var nodes: Array = []
	for line: String in lines:
		# words: id, type and, if present, the comma-separated links.
		var words: PackedStringArray = line.split(" ")
		# parts: the id's row and column.
		var parts: RegExMatch = id_parts.search(words[0])
		# links: the link ids.
		var links: Array = []
		if words.size() > 2:
			for link: String in words[2].split(","):
				links.append(link)
		nodes.append({"id": words[0], "row": parts.get_string(1).to_int(), "column": parts.get_string(2).to_int(),
			"type": words[1], "links": links})
	return {"floor": floor_number, "nodes": nodes}


## Returns every way map breaks the map format or the G18 rules under the given constants, written
## independently of the generator. Empty means the map is valid.
## map: the map to check. constants: constant name -> value (the ruleset's constants).
## floor_number: the floor the map must say it belongs to.
func _problems(map: Dictionary, constants: Dictionary, floor_number: int) -> Array[String]:
	# out: problems found.
	var out: Array[String] = []
	# rows: MAP_ROWS; the boss row is rows + 1.
	var rows: int = constants["MAP_ROWS"]
	if map.keys().size() != 2 or typeof(map.get("floor")) != TYPE_INT or map.get("floor") != floor_number \
			or typeof(map.get("nodes")) != TYPE_ARRAY:
		out.append("map must be exactly {floor: %d, nodes: Array}, got keys %s" % [floor_number, str(map.keys())])
		return out
	# nodes: the map's nodes.
	var nodes: Array = map["nodes"]
	# by_row: row -> list of nodes in that row, in map order.
	var by_row: Dictionary = {}
	# by_id: id -> node.
	var by_id: Dictionary = {}
	# previous: [row, column] of the previous node, to check the order.
	var previous: Array = [-1, -1]
	for node: Variant in nodes:
		if typeof(node) != TYPE_DICTIONARY or node.keys().size() != 5 or typeof(node.get("id")) != TYPE_STRING \
				or typeof(node.get("row")) != TYPE_INT or typeof(node.get("column")) != TYPE_INT \
				or typeof(node.get("type")) != TYPE_STRING or typeof(node.get("links")) != TYPE_ARRAY:
			out.append("node is not {id: String, row: int, column: int, type: String, links: Array}: %s" % str(node))
			return out
		for link: Variant in node["links"]:
			if typeof(link) != TYPE_STRING:
				out.append("%s: link %s is not a String" % [node["id"], str(link)])
		if node["id"] != "r%dc%d" % [node["row"], node["column"]]:
			out.append("%s: id does not match row %d column %d" % [node["id"], node["row"], node["column"]])
		if by_id.has(node["id"]):
			out.append("%s: duplicate id" % node["id"])
		by_id[node["id"]] = node
		if node["row"] < previous[0] or (node["row"] == previous[0] and node["column"] != previous[1] + 1) \
				or (node["row"] > previous[0] and node["column"] != 0):
			out.append("%s: nodes are not in row, then column order with columns 0, 1, 2 ..." % node["id"])
		previous = [node["row"], node["column"]]
		if not by_row.has(node["row"]):
			by_row[node["row"]] = []
		by_row[node["row"]].append(node)
	# row_numbers: the rows present, sorted.
	var row_numbers: Array = by_row.keys()
	row_numbers.sort()
	if row_numbers != range(0, rows + 2):
		out.append("rows must be exactly 0..%d, got %s" % [rows + 1, str(row_numbers)])
		return out
	# entrance: the row-0 node.
	var entrance: Array = by_row[0]
	if entrance.size() != 1 or entrance[0]["type"] != "start" or nodes[0] != entrance[0]:
		out.append("row 0 must be one start node at nodes[0]")
	# boss_nodes: the last row.
	var boss_nodes: Array = by_row[rows + 1]
	if boss_nodes.size() != 1 or boss_nodes[0]["type"] != "boss" or boss_nodes[0]["links"] != []:
		out.append("row %d must be one boss node with no links" % (rows + 1))
	# row1_ids: ids of row 1, which the entrance must link to.
	var row1_ids: Array = by_row[1].map(func(n: Dictionary) -> String: return n["id"])
	if entrance[0]["links"] != row1_ids:
		out.append("the entrance must link to every row-1 node in order: %s != %s" % [str(entrance[0]["links"]), str(row1_ids)])
	# counts: node type -> how many in rows 1..rows.
	var counts: Dictionary = {}
	# total: nodes in rows 1..rows.
	var total: int = 0
	for row: int in range(1, rows + 1):
		# row_nodes: this row.
		var row_nodes: Array = by_row[row]
		if row_nodes.size() < constants["MAP_MIN_NODES_PER_ROW"] or row_nodes.size() > constants["MAP_MAX_NODES_PER_ROW"]:
			out.append("row %d has %d nodes" % [row, row_nodes.size()])
		# reached: next-row columns some node of this row links to.
		var reached: Dictionary = {}
		# highest_so_far: largest target column of the nodes left of the current one, for the crossing check.
		var highest_so_far: int = -1
		for node: Dictionary in row_nodes:
			total += 1
			counts[node["type"]] = counts.get(node["type"], 0) + 1
			if row == 1 and node["type"] != "brawl":
				out.append("%s: row 1 must be all brawl, got %s" % [node["id"], node["type"]])
			elif row == rows and node["type"] != "tailgate":
				out.append("%s: the pre-boss row must be all tailgate, got %s" % [node["id"], node["type"]])
			elif not SHARES.has(node["type"]):
				out.append("%s: type %s is not a floor node type" % [node["id"], node["type"]])
			# links: this node's links.
			var links: Array = node["links"]
			if links.size() < 1 or links.size() > (1 if row == rows else constants["MAP_MAX_LINKS"]):
				out.append("%s: has %d links" % [node["id"], links.size()])
				continue
			# last_column: the previous target's column, to check ascending order.
			var last_column: int = -1
			for link: String in links:
				# target: the linked node, or null.
				var target: Variant = by_id.get(link)
				if target == null or target["row"] != row + 1:
					out.append("%s: link %s is not a node of the next row" % [node["id"], link])
					continue
				if target["column"] <= last_column:
					out.append("%s: links are not in ascending column order" % node["id"])
				if target["column"] < highest_so_far:
					out.append("%s: link to %s crosses a link from a node to its left" % [node["id"], link])
				last_column = target["column"]
				reached[target["column"]] = true
			highest_so_far = maxi(highest_so_far, last_column)
		if reached.size() != by_row[row + 1].size():
			out.append("row %d: only %d of %d next-row nodes have a link into them" % [row, reached.size(), by_row[row + 1].size()])
	# Reachability, computed by walking the links rather than from the per-row checks above.
	# forward: ids reachable from the entrance.
	var forward: Dictionary = {nodes[0]["id"]: true}
	# backward: ids from which the boss is reachable; filled walking rows from the boss upward.
	var backward: Dictionary = {boss_nodes[0]["id"]: true}
	for node: Dictionary in nodes:
		if forward.has(node["id"]):
			for link: String in node["links"]:
				forward[link] = true
	for i: int in range(nodes.size() - 1, -1, -1):
		for link: String in nodes[i]["links"]:
			if backward.has(link):
				backward[nodes[i]["id"]] = true
	for node: Dictionary in nodes:
		if not forward.has(node["id"]):
			out.append("%s: not reachable from the entrance" % node["id"])
		if not backward.has(node["id"]):
			out.append("%s: no path from it reaches the boss" % node["id"])
	# Shares: each type's count is its exact share rounded down or up, and they total the floor.
	# type_names: the share types in a fixed order.
	var type_names: Array = SHARES.keys()
	type_names.sort()
	# share_total: sum of the counts of share types.
	var share_total: int = 0
	for type: String in type_names:
		# count: nodes of this type.
		var count: int = counts.get(type, 0)
		share_total += count
		# exact_hundredths: the exact share in hundredths of a node.
		var exact_hundredths: int = total * constants[SHARES[type]]
		if absi(count * 100 - exact_hundredths) >= 100:
			out.append("%s: %d nodes, but %d%% of %d is %d.%02d" % [type, count, constants[SHARES[type]], total,
				exact_hundredths / 100, exact_hundredths % 100])
	if share_total != total:
		out.append("share types cover %d of %d floor nodes" % [share_total, total])
	return out


## Fixed seed: the generated map, and the map stream after it, equal the recorded ones exactly.
func test_fixed_seed_gives_recorded_map() -> void:
	# result: generate() for the recorded seed.
	var result: Dictionary = FloorMap.generate(_ruleset_with(FIXTURE_CONSTANTS), _state(RECORDED_SEED), 1)
	assert_eq(result["error"], "")
	assert_eq(result["map"], _map_from_lines(RECORDED_MAP, 1), "recorded map")
	assert_eq(result["state"]["rng"]["map"], RECORDED_STREAM_STATE, "map stream after generation")
	assert_no_errors(_problems(result["map"], FIXTURE_CONSTANTS, 1), "recorded map breaks a rule")


## The same seed twice gives identical results, map and state.
func test_same_seed_same_map() -> void:
	for run_seed: int in [0, 1, -7, 1152921504606846977]:
		# first: one generation.
		var first: Dictionary = FloorMap.generate(_real_ruleset(), _state(run_seed), 1)
		# second: the same again from a fresh state.
		var second: Dictionary = FloorMap.generate(_real_ruleset(), _state(run_seed), 1)
		assert_eq(first, second, "seed %d" % run_seed)


## Different seeds give different maps: no two of the first twenty seeds share a map.
func test_different_seeds_differ() -> void:
	# seen: map text -> the seed that made it.
	var seen: Dictionary = {}
	for run_seed: int in 20:
		# text: the map as text, for comparison.
		var text: String = var_to_str(FloorMap.generate(_real_ruleset(), _state(run_seed), 1)["map"])
		assert_false(seen.has(text), "seed %d gives the same map as seed %d" % [run_seed, seen.get(text, 0)])
		seen[text] = run_seed


## Property test over PROPERTY_SEEDS seeds with the real constants: every G18 rule and the share
## rounding hold for each (rows, nodes per row, links 1..MAP_MAX_LINKS, row 1 Brawl, pre-boss
## Tailgate, one boss, reachable both ways, shares within rounding, no crossing links).
func test_g18_rules_hold_for_many_seeds() -> void:
	# ruleset: the real ruleset.
	var ruleset: Dictionary = _real_ruleset()
	# reported: failures recorded so far.
	var reported: int = 0
	for n: int in PROPERTY_SEEDS:
		# run_seed: this round's seed.
		var run_seed: int = PROPERTY_FIRST_SEED + n
		# result: generate() for this seed.
		var result: Dictionary = FloorMap.generate(ruleset, _state(run_seed), 1)
		# problems: everything wrong with this seed's map.
		var problems: Array[String] = _problems(result["map"], ruleset["constants"], 1)
		if result["error"] != "":
			problems.append("error: " + result["error"])
		if not problems.is_empty():
			fail("seed %d:\n  %s" % [run_seed, "\n  ".join(problems)])
			reported += 1
			if reported >= MAX_REPORTED:
				return


## The checker used by the property test catches broken maps, so a passing property test means something.
func test_checker_catches_broken_maps() -> void:
	# good: the recorded map, valid.
	var good: Dictionary = _map_from_lines(RECORDED_MAP, 1)
	assert_no_errors(_problems(good, FIXTURE_CONSTANTS, 1), "recorded map")
	# breaks: label -> the edits that break one rule, each [index in nodes, field, new value].
	# Node indices in the recorded map: 0 entrance, 1-3 row 1, 4-6 row 2, 7-10 row 3, 20-22 row 7.
	var breaks: Dictionary = {
		"row 1 not brawl": [[1, "type", "rival"]],
		"pre-boss not tailgate": [[20, "type", "brawl"]],
		"unreached node": [[6, "links", ["r3c2"]]],
		"dead end": [[4, "links", []]],
		"too many links": [[7, "links", ["r4c0", "r4c1", "r4c2"]]],
		"crossing links": [[4, "links", ["r3c1"]], [5, "links", ["r3c0", "r3c2"]]],
		"share off by more than rounding": [[4, "type", "loot"], [7, "type", "loot"]],
		"float row": [[3, "row", 1.0]],
		"id not matching row and column": [[3, "column", 3]],
	}
	for label: String in breaks.keys():
		# broken: a fresh copy with one rule broken.
		var broken: Dictionary = good.duplicate(true)
		for edit: Array in breaks[label]:
			broken["nodes"][edit[0]][edit[1]] = edit[2]
		assert_false(_problems(broken, FIXTURE_CONSTANTS, 1).is_empty(), label + " should be caught")
	assert_false(_problems(good, FIXTURE_CONSTANTS, 2).is_empty(), "wrong floor should be caught")


## Generating advances the map stream and changes nothing else; the input state is not modified.
func test_generation_advances_only_the_map_stream() -> void:
	# before: a fresh state.
	var before: Dictionary = _state(RECORDED_SEED)
	# untouched: a deep copy kept to prove before is not modified.
	var untouched: Dictionary = before.duplicate(true)
	# result: generate() on before.
	var result: Dictionary = FloorMap.generate(_real_ruleset(), before, 1)
	assert_eq(result["error"], "")
	assert_eq(before, untouched, "the input state must not change")
	# after: the returned state.
	var after: Dictionary = result["state"]
	assert_ne(after["rng"]["map"], before["rng"]["map"], "the map stream must advance")
	for key: String in before["rng"].keys():
		if key != "map":
			assert_eq(after["rng"][key], before["rng"][key], "stream %s must not change" % key)
	assert_eq(after["rng"].keys().size(), before["rng"].keys().size(), "no stream added or removed")
	# rest_before / rest_after: both states without rng.
	var rest_before: Dictionary = before.duplicate(true)
	var rest_after: Dictionary = after.duplicate(true)  # Same as rest_before, for the returned state.
	rest_before.erase("rng")
	rest_after.erase("rng")
	assert_eq(rest_after, rest_before, "fields other than rng must not change")


## A state holding a generated map passes run_state.check() and survives a save and load unchanged.
func test_state_with_map_passes_check_and_round_trips() -> void:
	for run_seed: int in [RECORDED_SEED, -1, 9223372036854775807]:
		# result: generate() for this seed.
		var result: Dictionary = FloorMap.generate(_real_ruleset(), _state(run_seed), 1)
		# state: the returned state with the map stored, as the run flow will do it.
		var state: Dictionary = result["state"].duplicate()
		state["map"] = result["map"]
		state["node_index"] = 0
		assert_no_errors(RunState.check(state), "seed %d" % run_seed)
		# loaded: the state after to_bytes / from_bytes.
		var loaded: Dictionary = Snapshot.from_bytes(Snapshot.to_bytes(state))
		assert_true(loaded["ok"], "seed %d: %s" % [run_seed, loaded["error"]])
		assert_eq(loaded["state"], state, "seed %d round trip" % run_seed)
		assert_eq(FloorMap.generate(_real_ruleset(), _state(run_seed), 1)["map"], loaded["state"]["map"],
			"seed %d: the loaded map is the one the seed makes" % run_seed)


## Rounding to whole nodes: largest remainders, ties by table order, and a fixed row raising its type.
func test_apportion_rounds_by_largest_remainder() -> void:
	# shares: the GDD shares in table order.
	var shares: Array = [45, 10, 20, 12, 8, 5]
	# none: no fixed nodes.
	var none: Array = [0, 0, 0, 0, 0, 0]
	# 14 nodes: exact 6.30 1.40 2.80 1.68 1.12 0.70; rounded down 6 1 2 1 1 0; the 3 left go to .80, .70, .68.
	assert_eq(FloorMap.apportion(14, shares, none), {"counts": [6, 1, 3, 2, 1, 1], "error": ""}, "14 nodes")
	# 21 nodes: exact 9.45 2.10 4.20 2.52 1.68 1.05; the 2 left go to .68 and .52.
	assert_eq(FloorMap.apportion(21, shares, none), {"counts": [9, 2, 4, 3, 2, 1], "error": ""}, "21 nodes")
	# 20 nodes: every share is whole.
	assert_eq(FloorMap.apportion(20, shares, none)["counts"], [9, 2, 4, 2, 2, 1], "20 nodes")
	# Ties: two 50% shares of 1 node; the earlier type wins.
	assert_eq(FloorMap.apportion(1, [50, 50, 0, 0, 0, 0], none)["counts"], [1, 0, 0, 0, 0, 0], "tie")
	# 16 nodes: exact 7.20 1.60 3.20 1.92 1.28 0.80, down 7 1 3 1 1 0 = 13, the 3 left go to .92, .80, .60.
	assert_eq(FloorMap.apportion(16, shares, none)["counts"], [7, 2, 3, 2, 1, 1], "16 nodes")
	# 15 nodes, pre-boss row of 2: exact Tailgate 1.80 would round up anyway.
	assert_eq(FloorMap.apportion(15, shares, [2, 0, 0, 2, 0, 0])["counts"], [7, 1, 3, 2, 1, 1], "15 nodes, 2 Tailgates")
	# 17 nodes, pre-boss row of 3: Tailgate 2.04 must round up to 3, taking a leftover node from a larger remainder.
	# Exact 7.65 1.70 3.40 2.04 1.36 0.85; down 7 1 3 2 1 0 = 14; Tailgate raised to 3 = 15; 2 left go to .85 and .70.
	assert_eq(FloorMap.apportion(17, shares, [2, 0, 0, 3, 0, 0])["counts"], [7, 2, 3, 3, 1, 1], "17 nodes, 3 Tailgates")
	# 17 nodes, pre-boss row of 4: more than Tailgate's share rounded up (3), refused.
	assert_true(FloorMap.apportion(17, shares, [2, 0, 0, 4, 0, 0])["error"] != "", "4 Tailgates in 17 nodes")


## link_patterns() lists exactly the valid non-crossing patterns, in a fixed order.
func test_link_patterns() -> void:
	assert_eq(FloorMap.link_patterns(2, 4, 2), [[[0, 1], [2, 3]]], "2 to 4: only one way")
	assert_eq(FloorMap.link_patterns(2, 2, 2), [[[0], [0, 1]], [[0], [1]], [[0, 1], [1]]], "2 to 2")
	assert_eq(FloorMap.link_patterns(1, 3, 2), [], "1 to 3 with 2 links: impossible")
	assert_eq(FloorMap.link_patterns(3, 1, 2), [[[0], [0], [0]]], "3 to 1")
	for shape: Array in [[2, 3], [3, 3], [4, 4], [4, 2], [3, 4]]:
		for pattern: Array in FloorMap.link_patterns(shape[0], shape[1], 2):
			# reached: next-row columns this pattern links to.
			var reached: Dictionary = {}
			# highest: the largest target so far, for the crossing check.
			var highest: int = 0
			for targets: Array in pattern:
				assert_true(targets.size() >= 1 and targets.size() <= 2, "%s: %s links" % [str(shape), str(targets)])
				assert_true(targets[0] >= highest, "%s: %s crosses" % [str(shape), str(pattern)])
				highest = targets[targets.size() - 1]
				for target: int in targets:
					reached[target] = true
			assert_eq(reached.size(), shape[1], "%s: %s leaves a node unlinked" % [str(shape), str(pattern)])


## index_of() finds a node's index by id, and returns -1 for an unknown id or an empty map.
func test_index_of() -> void:
	# map: the recorded map.
	var map: Dictionary = _map_from_lines(RECORDED_MAP, 1)
	assert_eq(FloorMap.index_of(map, "r0c0"), 0, "entrance")
	assert_eq(FloorMap.index_of(map, "r3c1"), 8, "r3c1")
	assert_eq(FloorMap.index_of(map, "r8c0"), RECORDED_MAP.size() - 1, "boss")
	assert_eq(FloorMap.index_of(map, "r9c0"), -1, "unknown")
	assert_eq(FloorMap.index_of({}, "r0c0"), -1, "empty map")
	assert_eq(FloorMap.node_id(3, 1), "r3c1", "node_id")


## Bad input is reported in "error" with the state unchanged and no map; nothing asserts or crashes.
func test_bad_input_is_reported() -> void:
	# cases: label -> [constants, state, floor_number].
	var cases: Dictionary = {}
	# missing: one constant missing.
	var missing: Dictionary = FIXTURE_CONSTANTS.duplicate()
	missing.erase("MAP_MAX_LINKS")
	cases["missing constant"] = [missing, _state(1), 1]
	# not_100: shares that do not total 100.
	var not_100: Dictionary = FIXTURE_CONSTANTS.duplicate()
	not_100["NODE_SHARE_LOOT"] = 6
	cases["shares total 101"] = [not_100, _state(1), 1]
	# fraction: a share written as a fraction.
	var fraction: Dictionary = FIXTURE_CONSTANTS.duplicate()
	fraction["NODE_SHARE_BRAWL"] = 0.45
	cases["float share"] = [fraction, _state(1), 1]
	# wide: rows too wide to link with 2 links per node.
	var wide: Dictionary = FIXTURE_CONSTANTS.duplicate()
	wide["MAP_MAX_NODES_PER_ROW"] = 5
	cases["unlinkable rows"] = [wide, _state(1), 1]
	# one_row: MAP_ROWS 1, where row 1 and the pre-boss row would be the same row.
	var one_row: Dictionary = FIXTURE_CONSTANTS.duplicate()
	one_row["MAP_ROWS"] = 1
	cases["one row"] = [one_row, _state(1), 1]
	# no_tailgates: a Tailgate share of 0 cannot hold a pre-boss row of Tailgates.
	var no_tailgates: Dictionary = FIXTURE_CONSTANTS.duplicate()
	no_tailgates["NODE_SHARE_TAILGATE"] = 0
	no_tailgates["NODE_SHARE_BRAWL"] = 57
	cases["no tailgate share"] = [no_tailgates, _state(1), 1]
	cases["no map stream"] = [FIXTURE_CONSTANTS, RunState.blank(1, [DudeState.blank("p1", "tom")]), 1]
	cases["floor 0"] = [FIXTURE_CONSTANTS, _state(1), 0]
	for label: String in cases.keys():
		# state: the state passed in.
		var state: Dictionary = cases[label][1]
		# untouched: a copy to prove it is not modified.
		var untouched: Dictionary = state.duplicate(true)
		# result: generate()'s result.
		var result: Dictionary = FloorMap.generate(_ruleset_with(cases[label][0]), state, cases[label][2])
		assert_true(result["error"] != "", label + ": should report an error")
		assert_eq(result["map"], {}, label + ": no map")
		assert_eq(result["state"], untouched, label + ": state unchanged")
	assert_true(FloorMap.generate({}, _state(1), 1)["error"] != "", "ruleset without constants")
