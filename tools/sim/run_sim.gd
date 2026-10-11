## The fight simulation command (task 022). Lane: tools (Agent B). Usage is in tools/README.md:
##
##   "$(tools/install_godot.sh)" --headless --path . --script res://tools/sim/run_sim.gd -- \
##       --party-sizes 1 --seeds 1..100 --encounters all [--bots greedy,random] [--dudes tom] \
##       [--turn-cap 50] [--out sim_report.txt]
##
## Builds the ruleset from the project's data/ folder, runs tools/sim/fight_sim.gd run(), prints the
## report and, with --out, also writes it to that file. Exits 0 when every fight was played, 1 when the
## arguments, the data or the simulation stopped it (the reason is printed to stderr).
extends SceneTree

const FightSim := preload("res://tools/sim/fight_sim.gd")
const DataFiles := preload("res://tools/data_files.gd")
const Ruleset := preload("res://core/ruleset/ruleset.gd")


## Runs the command and quits with its exit code.
func _initialize() -> void:
	quit(main(OS.get_cmdline_user_args()))


## Runs the simulation for these arguments and returns the exit code: 0 done, 1 stopped.
## args: the user arguments (after "--").
func main(args: PackedStringArray) -> int:
	# parsed: the options.
	var parsed: Dictionary = FightSim.options_from_args(args)
	if parsed["error"] != "":
		printerr("run_sim: %s" % parsed["error"])
		return 1
	# built: the ruleset from data/.
	var built: Dictionary = Ruleset.build(DataFiles.read_all())
	if not built["ok"]:
		printerr("run_sim: the data does not build:\n  %s" % "\n  ".join(built["errors"]))
		return 1
	# result: the simulation's result.
	var result: Dictionary = FightSim.run(built["ruleset"], parsed["options"])
	if result["error"] != "":
		printerr("run_sim: stopped: %s" % result["error"])
		return 1
	print(result["report"].trim_suffix("\n"))
	if parsed["out"] != "":
		# file: the report file, or null when it cannot be written.
		var file: FileAccess = FileAccess.open(parsed["out"], FileAccess.WRITE)
		if file == null:
			printerr("run_sim: cannot write %s" % parsed["out"])
			return 1
		file.store_string(result["report"])
		file.close()
	return 0
