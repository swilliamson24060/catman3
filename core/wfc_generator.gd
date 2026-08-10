class_name WfcGenerator
extends RefCounted
## Classic tile-adjacency Wave Function Collapse, operating on a TileFogPlot's
## ungenerated cells. Stateless (all static) -- callers own the plot, the
## seed, and which tile_pool applies (home growth vs. a fresh exploration
## area use different pools drawn from the same DataRegistry terrain_tiles
## category, see GrowthPlotService/ExpeditionService).

const MAX_ATTEMPTS := 5

const DIRECTIONS := {
	"north": Vector2i(0, -1),
	"south": Vector2i(0, 1),
	"east": Vector2i(1, 0),
	"west": Vector2i(-1, 0),
}

## Resolves up to `cell_budget` of `plot`'s currently-ungenerated cells and
## writes the result into `plot` via set_tile_id(). Returns how many cells
## were actually filled (may be less than cell_budget if the plot ran out of
## ungenerated cells first). Deterministic for a given (plot state, seed,
## tile_pool, cell_budget) -- same inputs always produce the same output.
static func generate(plot: TileFogPlot, seed_value: int, tile_pool: Array[Dictionary], cell_budget: int) -> int:
	if cell_budget <= 0:
		return 0
	var rng := RandomNumberGenerator.new()
	for attempt in MAX_ATTEMPTS:
		rng.seed = seed_value + attempt
		var result := _attempt(plot, rng, tile_pool, cell_budget)
		if bool(result.ok):
			var chosen: Dictionary = result.chosen
			for cell in chosen:
				plot.set_tile_id(cell, chosen[cell])
			return chosen.size()
	# Every attempt contradicted -- almost always a badly-authored ruleset
	# (e.g. a mod tile with no valid neighbors at all). Degrade gracefully
	# instead of leaving the plot stuck: force-fill with a safe default tile,
	# matching DataRegistry's own "never crash, degrade and warn" philosophy.
	push_warning("[WfcGenerator] Contradiction persisted after %d attempts for plot '%s' -- falling back to a default tile." % [MAX_ATTEMPTS, String(plot.plot_id)])
	return _fill_fallback(plot, tile_pool, cell_budget)

## One full WFC trial. Reads plot's already-resolved cells (as fixed boundary
## constraints) but never writes to plot -- a contradicted attempt must be
## fully discardable, so nothing is committed until the caller confirms
## success and applies `chosen` itself.
static func _attempt(plot: TileFogPlot, rng: RandomNumberGenerator, tile_pool: Array[Dictionary], cell_budget: int) -> Dictionary:
	var possibilities: Dictionary = {}   # Vector2i -> Array[String], ungenerated cells only
	var all_ids: Array = []
	for tile in tile_pool:
		all_ids.append(str(tile.get("id", "")))
	for cell in plot.all_cells():
		if plot.get_tile_id(cell) == "":
			possibilities[cell] = all_ids.duplicate()

	# A partial-budget pass must still respect tiles resolved in an earlier
	# pass, not just ones chosen during this attempt.
	for cell in possibilities.keys():
		for direction in DIRECTIONS:
			var neighbor_cell: Vector2i = cell + DIRECTIONS[direction]
			var neighbor_id := plot.get_tile_id(neighbor_cell)
			if neighbor_id == "":
				continue
			var neighbor_def := _find_tile(tile_pool, neighbor_id)
			if neighbor_def.is_empty():
				continue
			var allowed: Array = (neighbor_def.get("adjacency", {}) as Dictionary).get(_opposite_direction(direction), [])
			possibilities[cell] = (possibilities[cell] as Array).filter(func(option): return option in allowed)

	var chosen: Dictionary = {}
	while chosen.size() < cell_budget and not possibilities.is_empty():
		var cell: Vector2i = _lowest_entropy_cell(possibilities)
		var options: Array = possibilities[cell]
		if options.is_empty():
			return {"ok": false, "chosen": {}}
		var pick: String = options[rng.randi() % options.size()]
		chosen[cell] = pick
		possibilities.erase(cell)
		_propagate(cell, pick, possibilities, tile_pool)
	return {"ok": true, "chosen": chosen}

## Narrows unresolved neighbors' possibility lists to whatever `chosen_id`
## allows in that direction. Only touches `possibilities` (this attempt's
## local, discardable state) -- never plot.
static func _propagate(cell: Vector2i, chosen_id: String, possibilities: Dictionary, tile_pool: Array[Dictionary]) -> void:
	var chosen_def := _find_tile(tile_pool, chosen_id)
	if chosen_def.is_empty():
		return
	var adjacency: Dictionary = chosen_def.get("adjacency", {})
	for direction in DIRECTIONS:
		var neighbor_cell: Vector2i = cell + DIRECTIONS[direction]
		if not possibilities.has(neighbor_cell):
			continue
		var allowed: Array = adjacency.get(direction, [])
		possibilities[neighbor_cell] = (possibilities[neighbor_cell] as Array).filter(func(option): return option in allowed)

## Fewest-remaining-options cell (classic WFC heuristic -- keeps generation
## locally coherent rather than degenerating into noise). Ties break on
## plot.all_cells() iteration order, which is fixed, so this stays
## deterministic given the same rng draws.
static func _lowest_entropy_cell(possibilities: Dictionary) -> Vector2i:
	var best_cell: Vector2i = Vector2i.ZERO
	var best_count := -1
	for cell in possibilities:
		var count: int = (possibilities[cell] as Array).size()
		if best_count == -1 or count < best_count:
			best_cell = cell
			best_count = count
	return best_cell

static func _find_tile(tile_pool: Array[Dictionary], id: String) -> Dictionary:
	for tile in tile_pool:
		if str(tile.get("id", "")) == id:
			return tile
	return {}

static func _opposite_direction(direction: String) -> String:
	match direction:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
	return direction

## Last resort when every attempt contradicts: force-fill remaining
## ungenerated cells (up to cell_budget) with the first starter tile found,
## so generation always completes. Returns how many cells were actually
## filled (0 if tile_pool is empty -- nothing sane to place).
static func _fill_fallback(plot: TileFogPlot, tile_pool: Array[Dictionary], cell_budget: int) -> int:
	var fallback_id := ""
	for tile in tile_pool:
		if bool(tile.get("starter", false)):
			fallback_id = str(tile.get("id", ""))
			break
	if fallback_id == "" and not tile_pool.is_empty():
		fallback_id = str(tile_pool[0].get("id", ""))
	if fallback_id == "":
		return 0
	var filled := 0
	for cell in plot.all_cells():
		if filled >= cell_budget:
			break
		if plot.get_tile_id(cell) == "":
			plot.set_tile_id(cell, fallback_id)
			filled += 1
	return filled
