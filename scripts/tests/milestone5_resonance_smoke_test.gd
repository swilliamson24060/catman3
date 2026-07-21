extends SceneTree

const GARDEN: BuildingDefinition = preload("res://resources/buildings/catnip_garden.tres")
const HUT: BuildingDefinition = preload("res://resources/buildings/mouse_hut.tres")
const HUD: PackedScene = preload("res://scenes/ui/phase1_hud.tscn")
const PATTERN_ID := "pattern_phase2_catnip_triangle"
const SAVE_TEST_PATH := "/tmp/catmando_milestone5_save_test.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState") as Phase1GameState
	var clock := root.get_node("SimulationClock") as Phase2SimulationClock
	var settlement := root.get_node("SettlementManager") as Phase2SettlementManager
	var save_service: Node = root.get_node("SaveService")
	var stats_service: Node = root.get_node("StatsService")
	var resonance_service: Node = root.get_node("ResonanceService")
	var event_bus: Node = root.get_node("EventBus")
	var discovery_events := [0]
	event_bus.pattern_discovered.connect(func(_pattern_id: String) -> void: discovery_events[0] += 1)
	clock.set_simulation_paused(true)
	game_state.reset()
	save_service.call("new_game", "")
	stats_service.call("reset")

	var container := Node3D.new()
	container.add_to_group("completed_building_container")
	root.add_child(container)
	var hud := HUD.instantiate()
	root.add_child(hud)
	settlement.restore_completed_buildings([])

	var garden := _place(GARDEN, Vector2i.ZERO, container, settlement)
	# 90-degree rotation of the documented offsets.
	_place(HUT, Vector2i(-2, 0), container, settlement)
	_place(HUT, Vector2i(1, -2), container, settlement)
	assert(not PATTERN_ID in save_service.current.discovered_patterns, "Incomplete pattern must not discover early.")
	_place(HUT, Vector2i(1, 2), container, settlement)

	assert(PATTERN_ID in save_service.current.discovered_patterns, "Rotated Herbal Triad must be discovered.")
	assert(is_equal_approx(float(stats_service.call("get_effective", "catnip_garden", "production_rate", 1.0)), 1.5), "Pattern must grant the 1.5x garden production bonus.")
	assert(is_equal_approx(float(stats_service.call("get_effective", "global_mice", "movement_speed", 1.0)), 1.15), "Pattern must grant the mouse movement bonus.")
	assert(discovery_events[0] == 1, "Discovery UI signal must fire exactly once.")
	assert(hud.get_node("ResonanceBanner").visible, "Discovery banner must become visible.")
	assert(hud.get_node("ResonanceBanner/MarginContainer/VBoxContainer/PatternName").text == "The Herbal Triad", "Discovery banner must show pattern details.")
	resonance_service.call("_on_phase2_building_registered", garden)
	assert(save_service.current.discovered_patterns.count(PATTERN_ID) == 1, "Pattern reward must be one-time only.")
	assert(is_equal_approx(float(stats_service.call("get_effective", "catnip_garden", "production_rate", 1.0)), 1.5), "One-time discovery must not stack its bonus.")

	garden._on_simulation_advanced(13.34)
	assert(game_state.get_catnip() == 1, "Discovered production bonus must affect an existing garden live.")

	# Save loading restores both the one-time record and named bonuses without
	# replaying discovery UI or stacking across repeated loads.
	assert(bool(save_service.call("save_game", SAVE_TEST_PATH)), "Milestone 5 state must save to disk.")
	stats_service.call("reset")
	save_service.call("new_game", "")
	settlement.restore_completed_buildings([])
	assert(bool(save_service.call("load_game", SAVE_TEST_PATH)), "Milestone 5 state must load from disk.")
	await process_frame
	assert(PATTERN_ID in save_service.current.discovered_patterns, "Pattern discovery must persist.")
	assert(is_equal_approx(float(stats_service.call("get_effective", "catnip_garden", "production_rate", 1.0)), 1.5), "Load must restore the production reward.")
	assert(is_equal_approx(float(stats_service.call("get_effective", "global_mice", "movement_speed", 1.0)), 1.15), "Load must restore the movement reward.")
	assert(discovery_events[0] == 1, "Loading must not replay the discovery banner signal.")
	assert(bool(save_service.call("load_game", SAVE_TEST_PATH)), "Repeated loading must remain valid.")
	assert(is_equal_approx(float(stats_service.call("get_effective", "catnip_garden", "production_rate", 1.0)), 1.5), "Repeated loading must not stack rewards.")
	DirAccess.remove_absolute(SAVE_TEST_PATH)

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
