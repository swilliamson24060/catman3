extends Node
## Autoload "ExpeditionService". Owns which resident is away on a solo
## expedition, each away resident's destination TileFogPlot, and the
## currently-visited exploration area (at most one visited/rendered at a
## time -- visiting is what makes an area's ExplorationArea scene content
## exist; unvisited away-expeditions still generate/resolve via the same
## away-time mechanism, just with nothing on screen).

signal post_requested

const EXPEDITION_CAP_SECONDS := 60.0 * 60.0 * 24.0   # 24 real hours credited, max
const AREA_WIDTH := 8
const AREA_HEIGHT := 8
const TICK_INTERVAL := 1.0
const FOUNDER_REVEAL_RADIUS := 2

var _expeditions: Dictionary = {}    # resident_id (StringName) -> {area_id: StringName, timer: AwayTimer, plot: TileFogPlot, seed: int}
var _visited_area_id: StringName = &""
var _stage_root: Node3D
var _visited_area_node: ExplorationArea
var _tick_accum: float = 0.0

func _process(delta: float) -> void:
	_tick_accum += delta
	if _tick_accum >= TICK_INTERVAL:
		_tick_accum = 0.0
		check_expeditions()

func new_game() -> void:
	_expeditions.clear()
	_visited_area_id = &""
	_clear_visited_node()

func bind_world(stage: Node3D) -> void:
	_stage_root = stage
	if not _visited_area_id.is_empty():
		_show_visited_area()

func unbind_world(stage: Node3D) -> void:
	if _stage_root == stage:
		_clear_visited_node()
		_stage_root = null

## Every roster resident not currently on an expedition.
func available_residents() -> Array:
	var out: Array = []
	for agent in get_node("/root/ResidentManager").get_agents():
		if not _expeditions.has(agent.resident_id):
			out.append(agent)
	return out

func away_residents() -> Array:
	return _expeditions.keys()

func is_away(resident_id: StringName) -> bool:
	return _expeditions.has(resident_id)

func depart(resident_id: StringName) -> bool:
	if _expeditions.has(resident_id):
		return false
	var agent = get_node("/root/ResidentManager").get_agent(resident_id)
	if agent == null:
		return false
	agent.set_away(true)
	var area_id := StringName("area_%d_%s" % [int(Time.get_unix_time_from_system()), String(resident_id)])
	var plot := TileFogPlot.new()
	plot.plot_id = area_id
	plot.width = AREA_WIDTH
	plot.height = AREA_HEIGHT
	var timer := AwayTimer.new()
	timer.start(EXPEDITION_CAP_SECONDS)
	var seed_value := int(Time.get_unix_time_from_system()) ^ hash(String(resident_id))
	_expeditions[resident_id] = {"area_id": area_id, "timer": timer, "plot": plot, "seed": seed_value}
	get_node("/root/EventBus").expedition_departed.emit(resident_id, area_id)
	return true

## Ends an expedition immediately, whatever its progress -- early recall
## simply means less of the area got explored.
func recall(resident_id: StringName) -> bool:
	if not _expeditions.has(resident_id):
		return false
	var entry: Dictionary = _expeditions[resident_id]
	var area_id: StringName = entry.area_id
	if _visited_area_id == area_id:
		leave_visited_area()
	var agent = get_node("/root/ResidentManager").get_agent(resident_id)
	if agent != null:
		agent.set_away(false)
	_expeditions.erase(resident_id)
	get_node("/root/EventBus").expedition_returned.emit(resident_id, area_id)
	return true

## Advances WFC generation for every pending expedition based on elapsed
## away-time, and feeds any newly-discovered non-starter tile back into
## GrowthPlotService's unlocked vocabulary. Safe to call often (per-second
## tick, on load, on visiting).
func check_expeditions() -> void:
	for resident_id in _expeditions.keys():
		var entry: Dictionary = _expeditions[resident_id]
		var timer: AwayTimer = entry.timer
		var plot: TileFogPlot = entry.plot
		var total_cells := AREA_WIDTH * AREA_HEIGHT
		var credited := timer.credited_seconds()
		var target_generated := int(credited / EXPEDITION_CAP_SECONDS * total_cells)
		var already_generated := total_cells - plot.ungenerated_cells().size()
		var budget := target_generated - already_generated
		if budget > 0:
			WfcGenerator.generate(plot, int(entry.seed), _starter_pool(), budget)
			_feed_discoveries(plot)
			if _visited_area_id == entry.area_id and _visited_area_node != null and is_instance_valid(_visited_area_node):
				_visited_area_node.apply_area_state(plot)

func _starter_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for tile: Dictionary in get_node("/root/DataRegistry").get_all_terrain_tiles():
		if bool(tile.get("starter", false)):
			pool.append(tile)
	return pool

## An exploration area is always a fresh discovery surface -- drawn only
## from starter tiles, independent of the home plot's unlocked vocabulary.
## Any non-starter tile it *does* place (from a future richer ruleset) feeds
## straight back into GrowthPlotService.
func _feed_discoveries(plot: TileFogPlot) -> void:
	var growth := get_node("/root/GrowthPlotService")
	var registry := get_node("/root/DataRegistry")
	for cell in plot.all_cells():
		var tile_id := plot.get_tile_id(cell)
		if tile_id == "":
			continue
		var tile_def: Dictionary = registry.get_terrain_tile(tile_id)
		if not bool(tile_def.get("starter", true)):
			growth.unlock_tile(tile_id)

func visit_area(resident_id: StringName) -> void:
	if not _expeditions.has(resident_id):
		return
	if not _visited_area_id.is_empty():
		leave_visited_area()
	_visited_area_id = _expeditions[resident_id].area_id
	_show_visited_area()

func leave_visited_area() -> void:
	_clear_visited_node()
	_visited_area_id = &""

func _show_visited_area() -> void:
	if _stage_root == null:
		return
	_clear_visited_node()
	var plot := _plot_for_area(_visited_area_id)
	if plot == null:
		_visited_area_id = &""
		return
	_visited_area_node = ExplorationArea.new()
	_stage_root.add_child(_visited_area_node)
	_visited_area_node.apply_area_state(plot)

func _clear_visited_node() -> void:
	if _visited_area_node != null and is_instance_valid(_visited_area_node):
		_visited_area_node.queue_free()
	_visited_area_node = null

func _plot_for_area(area_id: StringName) -> TileFogPlot:
	for resident_id in _expeditions:
		var entry: Dictionary = _expeditions[resident_id]
		if entry.area_id == area_id:
			return entry.plot
	return null

## Called every physics frame by the founder script (reboot_founder_cat.gd);
## cheap early-return unless an area is actually being visited and the
## founder is standing near its tiles, in which case fog clears live around
## them -- the same technique the legacy player.gd/GridService pairing uses,
## applied to this new per-place instance instead of a global singleton.
func notify_founder_moved(world_position: Vector3) -> void:
	if _visited_area_node == null or not is_instance_valid(_visited_area_node):
		return
	var plot := _plot_for_area(_visited_area_id)
	if plot == null:
		return
	var local_position := world_position - _visited_area_node.global_position
	var cell := plot.world_to_grid(local_position)
	if not plot.in_bounds(cell):
		return
	var before := plot.revealed_fraction()
	plot.reveal_around(cell, FOUNDER_REVEAL_RADIUS)
	if plot.revealed_fraction() != before:
		_visited_area_node.apply_area_state(plot)

func request_post() -> void:
	post_requested.emit()

func serialize_state() -> Dictionary:
	var expeditions: Dictionary = {}
	for resident_id in _expeditions:
		var entry: Dictionary = _expeditions[resident_id]
		expeditions[String(resident_id)] = {
			"area_id": String(entry.area_id),
			"timer": (entry.timer as AwayTimer).serialize(),
			"plot": (entry.plot as TileFogPlot).serialize(),
			"seed": entry.seed,
		}
	return {"expeditions": expeditions, "visited_area_id": String(_visited_area_id)}

func restore_state(data: Dictionary) -> void:
	_clear_visited_node()
	_expeditions.clear()
	var expeditions: Dictionary = data.get("expeditions", {})
	for resident_id_str in expeditions:
		var raw: Dictionary = expeditions[resident_id_str]
		var resident_id := StringName(resident_id_str)
		_expeditions[resident_id] = {
			"area_id": StringName(str(raw.get("area_id", ""))),
			"timer": AwayTimer.from_data(raw.get("timer", {})),
			"plot": TileFogPlot.from_data(raw.get("plot", {})),
			"seed": int(raw.get("seed", 0)),
		}
		# ResidentManager.restore_state() (called before this -- see
		# save_service.gd) respawns every agent fresh via _select_routine_activity(),
		# which does NOT know about expeditions. Re-apply away status now that
		# the correct freshly-spawned agent actually exists to apply it to.
		var agent = get_node("/root/ResidentManager").get_agent(resident_id)
		if agent != null:
			agent.set_away(true)
	_visited_area_id = StringName(str(data.get("visited_area_id", "")))
	if not _visited_area_id.is_empty() and _stage_root != null:
		_show_visited_area()
	check_expeditions()
