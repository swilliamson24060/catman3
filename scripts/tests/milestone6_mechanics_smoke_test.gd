extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/world/main.tscn")
const HUT: BuildingDefinition = preload("res://resources/buildings/mouse_hut.tres")
const GARDEN: BuildingDefinition = preload("res://resources/buildings/catnip_garden.tres")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var weather: Node = root.get_node("WeatherService")
	var drift: Node = root.get_node("CatnipDriftService")
	var dream: Node = root.get_node("DreamModeService")
	var scaffold: Node = root.get_node("ScaffoldService")
	var settlement := root.get_node("SettlementManager") as Phase2SettlementManager
	var clock := root.get_node("SimulationClock") as Phase2SimulationClock
	clock.set_simulation_paused(true)

	var packed_main := MAIN_SCENE.instantiate()
	assert(packed_main.has_node("Milestone6WorldSystems/ResourceNodeSpawner"), "Resource/radar systems must be mounted.")
	assert(packed_main.has_node("Milestone6WorldSystems/DustBunnySpawner"), "Dust Bunny spawner must be mounted.")
	assert(packed_main.has_node("Milestone6WorldSystems/StrayCatSpawner"), "Stray visitor spawner must be mounted.")
	assert(packed_main.has_node("WhiskerRadar") and packed_main.has_node("DreamOverlay"), "Milestone 6 overlays must be mounted.")
	assert(packed_main.has_node("InventoryUI"), "Resource, dust, salary, and tool rewards must be inspectable.")
	packed_main.free()

	var container := Node3D.new()
	container.add_to_group("completed_building_container")
	root.add_child(container)
	settlement.restore_completed_buildings([])
	var hut := _place(HUT, Vector2i.ZERO, container, settlement)
	var garden := _place(GARDEN, Vector2i.ZERO, container, settlement)
	weather.call("force_weather", "rain")
	hut._on_simulation_advanced(5.0)
	garden._on_simulation_advanced(5.0)
	assert(is_equal_approx(hut.durability, HUT.max_durability - 10.0), "Rain must damage cardboard huts.")
	assert(is_equal_approx(garden.durability, GARDEN.max_durability), "Waterproof gardens must ignore rain.")

	weather.call("force_wind", Vector2i.RIGHT)
	var downwind := float(drift.call("get_scent_at", Vector2i(2, 0)))
	var upwind := float(drift.call("get_scent_at", Vector2i(-2, 0)))
	assert(downwind > 0.0 and is_zero_approx(upwind), "Catnip scent must follow wind direction.")

	dream.call("set_active", true)
	assert(is_equal_approx(Engine.time_scale, 5.0), "Dream Mode must fast-forward time.")
	dream.call("set_active", false)
	assert(is_equal_approx(Engine.time_scale, 1.0), "Leaving Dream Mode must restore time.")

	weather.call("force_wind", Vector2i.ZERO)
	var resolved := [false, false]
	scaffold.challenge_resolved.connect(func(success: bool) -> void:
		resolved[0] = true
		resolved[1] = success
	)
	assert(bool(scaffold.call("start_challenge", 1.0)), "Scaffold challenge must start.")
	scaffold.call("_process", 1.0)
	assert(resolved[0] and resolved[1], "A centered scaffold must resolve successfully.")

	weather.call("force_weather", "clear")
	print("MILESTONE_6_MECHANICS_SMOKE_TEST_PASS")
	quit(0)


func _place(definition: BuildingDefinition, grid: Vector2i, parent: Node3D, settlement: Phase2SettlementManager) -> CompletedBuilding:
	var building := definition.completed_scene.instantiate() as CompletedBuilding
	building.building_definition = definition
	parent.add_child(building)
	building.global_position = settlement.resonance_grid_to_world(grid)
	settlement.register_completed_building(building, definition)
	return building
