extends SceneTree

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	_check_determinism()
	_check_partial_budget()
	_check_contradiction_fallback()

	if _failure.is_empty():
		print("MILESTONE_12_WFC_GENERATOR_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _simple_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	pool.append({"id": "grass", "starter": true, "adjacency": {
		"north": ["grass", "path"], "south": ["grass", "path"], "east": ["grass", "path"], "west": ["grass", "path"],
	}})
	pool.append({"id": "path", "starter": true, "adjacency": {
		"north": ["grass", "path"], "south": ["grass", "path"], "east": ["grass", "path"], "west": ["grass", "path"],
	}})
	return pool

func _check_determinism() -> void:
	var pool := _simple_pool()

	var plot_a := TileFogPlot.new(); plot_a.width = 6; plot_a.height = 6
	var resolved_a := WfcGenerator.generate(plot_a, 4242, pool, 36)

	var plot_b := TileFogPlot.new(); plot_b.width = 6; plot_b.height = 6
	var resolved_b := WfcGenerator.generate(plot_b, 4242, pool, 36)

	_check(resolved_a == 36, "a full 6x6 budget with two always-compatible tiles should fully resolve: got %d" % resolved_a)
	_check(resolved_a == resolved_b, "same seed should resolve the same number of cells")
	for cell in plot_a.all_cells():
		_check(plot_a.get_tile_id(cell) == plot_b.get_tile_id(cell), "same seed + same pool + same budget must produce an identical layout at %s" % cell)

	var plot_c := TileFogPlot.new(); plot_c.width = 6; plot_c.height = 6
	WfcGenerator.generate(plot_c, 777, pool, 36)
	var any_difference := false
	for cell in plot_a.all_cells():
		if plot_a.get_tile_id(cell) != plot_c.get_tile_id(cell):
			any_difference = true
			break
	_check(any_difference, "a different seed should be capable of producing a different layout (this can theoretically flake, but is expected to pass in practice)")

func _check_partial_budget() -> void:
	var pool := _simple_pool()
	var plot := TileFogPlot.new(); plot.width = 5; plot.height = 5   # 25 cells total
	var resolved := WfcGenerator.generate(plot, 99, pool, 10)
	_check(resolved == 10, "a budget smaller than the plot should resolve exactly that many cells: got %d" % resolved)
	var generated_count := 0
	for cell in plot.all_cells():
		if plot.is_generated(cell):
			generated_count += 1
	_check(generated_count == 10, "exactly 10 cells should actually be marked generated on the plot: got %d" % generated_count)
	_check(plot.ungenerated_cells().size() == 15, "the remaining 15 cells should stay ungenerated: got %d" % plot.ungenerated_cells().size())

	# A second, later pass (simulating more credited away-time) should only
	# advance the still-ungenerated cells, respecting the first pass's tiles.
	var second_resolved := WfcGenerator.generate(plot, 99, pool, 10)
	_check(second_resolved == 10, "a second partial pass should resolve its own budget worth of the remaining cells: got %d" % second_resolved)
	_check(plot.ungenerated_cells().size() == 5, "after two passes of 10, 5 cells should remain: got %d" % plot.ungenerated_cells().size())

func _check_contradiction_fallback() -> void:
	# A single tile whose adjacency lists are all empty can never legally
	# neighbor itself -- any plot bigger than 1x1 is unsolvable as authored.
	var impossible_pool: Array[Dictionary] = [
		{"id": "lonely", "starter": true, "adjacency": {"north": [], "south": [], "east": [], "west": []}},
	]
	var plot := TileFogPlot.new(); plot.width = 3; plot.height = 3
	var resolved := WfcGenerator.generate(plot, 1, impossible_pool, 9)
	_check(resolved == 9, "an unsolvable ruleset must still fully resolve via fallback rather than leaving cells empty: got %d" % resolved)
	for cell in plot.all_cells():
		_check(plot.get_tile_id(cell) == "lonely", "fallback should fill every remaining cell with the only available (starter) tile")

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
