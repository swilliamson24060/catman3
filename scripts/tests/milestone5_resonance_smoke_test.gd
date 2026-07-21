extends SceneTree

const GARDEN: BuildingDefinition = preload("res://resources/buildings/catnip_garden.tres")
const HUT: BuildingDefinition = preload("res://resources/buildings/mouse_hut.tres")
const PATTERN_ID := "pattern_phase2_catnip_triangle"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState") as Phase1GameState
	var clock := root.get_node("SimulationClock") as Phase2SimulationClock
	var settlement := root.get_node("SettlementManager") as Phase2SettlementManager
	var save_service: Node = root.get_node("SaveService")
	var stats_service: Node = root.get_node("StatsService")
	var resonance_service: Node = root.get_node("ResonanceService")
	clock.set_simulation_paused(true)
	game_state.reset()
	save_service.call("new_game", "")
	stats_service.call("reset")

	var container := Node3D.new()
	container.add_to_group("completed_building_container")
	root.add_child(container)
	settlement.restore_completed_buildings([])

	var garden := _place(GARDEN, Vector2i.ZERO, container, settlement)
	# 90-degree rotation of the documented offsets.
	_place(HUT, Vector2i(-2, 0), container, settlement)
	_place(HUT, Vector2i(1, -2), container, settlement)
	assert(not PATTERN_ID in save_service.current.discovered_patterns, "Incomplete pattern must not discover early.")
	_place(HUT, Vector2i(1, 2), container, settlement)

	assert(PATTERN_ID in save_service.current.discovered_patterns, "Rotated Herbal Triad must be discovered.")
	assert(is_equal_approx(float(stats_service.call("get_effective", "catnip_garden", "production_rate", 1.0)), 1.5), "Pattern must grant the 1.5x garden production bonus.")
	resonance_service.call("_on_phase2_building_registered", garden)
	assert(save_service.current.discovered_patterns.count(PATTERN_ID) == 1, "Pattern reward must be one-time only.")
	assert(is_equal_approx(float(stats_service.call("get_effective", "catnip_garden", "production_rate", 1.0)), 1.5), "One-time discovery must not stack its bonus.")

	garden._on_simulation_advanced(13.34)
	assert(game_state.get_catnip() == 1, "Discovered production bonus must affect an existing garden live.")

	print("MILESTONE_5_RESONANCE_SMOKE_TEST_PASS")
	quit(0)


func _place(
	definition: BuildingDefinition,
	grid_position: Vector2i,
	container: Node3D,
	settlement: Phase2SettlementManager
) -> CompletedBuilding:
	var building := definition.completed_scene.instantiate() as CompletedBuilding
	building.building_definition = definition
	container.add_child(building)
	building.global_position = settlement.resonance_grid_to_world(grid_position)
	settlement.register_completed_building(building, definition)
	return building
