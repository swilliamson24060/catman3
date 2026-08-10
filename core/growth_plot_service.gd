extends Node
## Autoload "GrowthPlotService". Owns the home village's growth plot: the
## player plants a seed (an explicit, deliberate, repeatable action), and it
## fills in via WfcGenerator, credited by real-world elapsed time since
## planting (capped) -- not by simulated in-session ticks, so it resolves
## whether the app was closed in the meantime or not.

const GROWTH_CAP_SECONDS := 60.0 * 60.0 * 24.0 * 3.0   # 3 real days credited, max
const PLOT_WIDTH := 6
const PLOT_HEIGHT := 6
const PLOT_ORIGIN := Vector3(9.0, 0.0, 12.0)

var _plot: TileFogPlot
var _timer: AwayTimer
var _pending_seed: int = 0
var unlocked_tile_ids: Array[String] = []

func _ready() -> void:
	_plot = _new_plot()

func new_game() -> void:
	_plot = _new_plot()
	_timer = null
	_pending_seed = 0
	unlocked_tile_ids.clear()

func plot() -> TileFogPlot:
	return _plot

func is_growing() -> bool:
	return _timer != null

func plant_seed(seed_value: int) -> bool:
	if _timer != null:
		return false   # one pending growth at a time
	_plot = _new_plot()
	_timer = AwayTimer.new()
	_timer.start(GROWTH_CAP_SECONDS)
	_pending_seed = seed_value
	get_node("/root/EventBus").seed_planted.emit(seed_value)
	return true

## Resolves whatever real-world time has accrued since plant_seed() into
## generated cells. Safe to call often (revisiting the plot, after a save
## load) -- a no-op when nothing is pending or the budget hasn't grown since
## the last check.
func check_growth() -> void:
	if _timer == null:
		return
	var total_cells := PLOT_WIDTH * PLOT_HEIGHT
	var credited := _timer.credited_seconds()
	var target_generated := int(credited / GROWTH_CAP_SECONDS * total_cells)
	var already_generated := total_cells - _plot.ungenerated_cells().size()
	var budget := target_generated - already_generated
	if budget > 0:
		var resolved := WfcGenerator.generate(_plot, _pending_seed, _tile_pool(), budget)
		if resolved > 0:
			get_node("/root/EventBus").growth_plot_advanced.emit(resolved)
	if _timer.is_fully_credited():
		_timer = null
		get_node("/root/EventBus").seed_resolved.emit()

## Called when a resident's expedition discovers new terrain vocabulary --
## expands what future plant_seed() generations can draw from.
func unlock_tile(tile_id: String) -> void:
	if tile_id == "" or tile_id in unlocked_tile_ids:
		return
	unlocked_tile_ids.append(tile_id)
	get_node("/root/EventBus").terrain_tile_unlocked.emit(tile_id)

func _tile_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for tile: Dictionary in get_node("/root/DataRegistry").get_all_terrain_tiles():
		var id := str(tile.get("id", ""))
		if bool(tile.get("starter", false)) or id in unlocked_tile_ids:
			pool.append(tile)
	return pool

func _new_plot() -> TileFogPlot:
	var plot := TileFogPlot.new()
	plot.plot_id = &"home_growth_plot"
	plot.width = PLOT_WIDTH
	plot.height = PLOT_HEIGHT
	plot.origin = PLOT_ORIGIN
	return plot

func serialize_state() -> Dictionary:
	return {
		"plot": _plot.serialize(),
		"timer": (_timer.serialize() if _timer != null else {}),
		"pending_seed": _pending_seed,
		"unlocked_tile_ids": unlocked_tile_ids.duplicate(),
	}

func restore_state(data: Dictionary) -> void:
	var plot_data: Dictionary = data.get("plot", {})
	_plot = TileFogPlot.from_data(plot_data) if not plot_data.is_empty() else _new_plot()
	var timer_data: Dictionary = data.get("timer", {})
	_timer = AwayTimer.from_data(timer_data) if not timer_data.is_empty() else null
	_pending_seed = int(data.get("pending_seed", 0))
	unlocked_tile_ids.assign(data.get("unlocked_tile_ids", []))
	check_growth()   # apply any credit accrued while this save wasn't loaded
