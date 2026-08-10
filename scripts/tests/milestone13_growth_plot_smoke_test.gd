extends SceneTree

# Mirrors core/growth_plot_service.gd's own constants -- kept local (rather
# than read dynamically off the Node-typed autoload reference) to sidestep
# GDScript's static-inference limits on generically-typed Node access.
const GROWTH_CAP_SECONDS := 60.0 * 60.0 * 24.0 * 3.0
const PLOT_CELLS := 6 * 6

var _failure := ""
var _resolved_signal_seen := false
var _unlocked_signal_seen := false

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("feature/reboot_mode", true)
	var growth: Node = root.get_node("GrowthPlotService")
	var event_bus: Node = root.get_node("EventBus")
	event_bus.seed_resolved.connect(func(): _resolved_signal_seen = true)
	event_bus.terrain_tile_unlocked.connect(func(_id): _unlocked_signal_seen = true)

	growth.new_game()
	_check(not bool(growth.is_growing()), "a freshly-reset growth plot should not be growing")
	_check(bool(growth.plant_seed(12345)), "plant_seed should succeed when idle")
	_check(bool(growth.is_growing()), "after planting, the plot should be growing")
	_check(not bool(growth.plant_seed(999)), "a second plant_seed while already growing should be refused")

	# Backdate to simulate elapsed time short of the cap.
	var timer: AwayTimer = growth._timer
	timer.started_at = Time.get_unix_time_from_system() - (GROWTH_CAP_SECONDS * 0.5)
	growth.check_growth()
	var plot_after_partial: TileFogPlot = growth.plot()
	var partial_generated: int = PLOT_CELLS - plot_after_partial.ungenerated_cells().size()
	_check(partial_generated > 0, "roughly half the cap's elapsed time should resolve some cells: got %d" % partial_generated)
	_check(partial_generated < PLOT_CELLS, "roughly half the cap's elapsed time should not resolve every cell yet: got %d" % partial_generated)
	_check(bool(growth.is_growing()), "should still be growing before the cap is reached")
	_check(not _resolved_signal_seen, "seed_resolved should not fire before the cap is reached")

	# Backdate past the cap.
	var timer2: AwayTimer = growth._timer
	timer2.started_at = Time.get_unix_time_from_system() - (GROWTH_CAP_SECONDS * 2.0)
	growth.check_growth()
	_check(not bool(growth.is_growing()), "past the cap, growth should be complete")
	var plot_after_full: TileFogPlot = growth.plot()
	_check(plot_after_full.ungenerated_cells().is_empty(), "past the cap, every cell should be generated")
	_check(_resolved_signal_seen, "seed_resolved should fire once the cap is reached")

	# Unlock feed: a non-starter tile should become eligible only once unlocked.
	var registry: Node = root.get_node("DataRegistry")
	var kelp: Dictionary = registry.get_terrain_tile("expansion_undersea:kelp_bed")
	_check(not bool(kelp.get("starter", true)), "sanity: kelp_bed should not already be a starter tile")

	var pool_before: Array = growth._tile_pool()
	var ids_before: Array = []
	for tile in pool_before: ids_before.append(str(tile.get("id", "")))
	_check(not ("expansion_undersea:kelp_bed" in ids_before), "kelp_bed should not be in the pool before being unlocked")

	growth.unlock_tile("expansion_undersea:kelp_bed")
	_check(_unlocked_signal_seen, "terrain_tile_unlocked should fire when a new tile is unlocked")
	growth.unlock_tile("expansion_undersea:kelp_bed")   # idempotent: unlocking twice must not duplicate

	var pool_after: Array = growth._tile_pool()
	var ids_after: Array = []
	for tile in pool_after: ids_after.append(str(tile.get("id", "")))
	_check("expansion_undersea:kelp_bed" in ids_after, "kelp_bed should be eligible in the tile pool after being unlocked")
	_check(ids_after.count("expansion_undersea:kelp_bed") == 1, "unlocking the same tile twice must not duplicate it in the pool")

	# Persistence: unlocked vocabulary must survive a fresh new_game() reset
	# only if explicitly re-unlocked -- confirm new_game() actually clears it.
	growth.new_game()
	var pool_reset: Array = growth._tile_pool()
	var ids_reset: Array = []
	for tile in pool_reset: ids_reset.append(str(tile.get("id", "")))
	_check(not ("expansion_undersea:kelp_bed" in ids_reset), "new_game() should clear previously-unlocked vocabulary")

	if _failure.is_empty():
		print("MILESTONE_13_GROWTH_PLOT_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
