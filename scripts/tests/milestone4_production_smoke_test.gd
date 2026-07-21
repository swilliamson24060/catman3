extends SceneTree

const GARDEN_DEFINITION: BuildingDefinition = preload("res://resources/buildings/catnip_garden.tres")
const GARDEN_SCENE: PackedScene = preload("res://scenes/buildings/catnip_garden.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState") as Phase1GameState
	var simulation_clock := root.get_node("SimulationClock") as Phase2SimulationClock
	var settlement_manager := root.get_node("SettlementManager") as Phase2SettlementManager
	simulation_clock.set_simulation_paused(true)
	game_state.reset()
	var container := Node3D.new()
	container.add_to_group("completed_building_container")
	root.add_child(container)
	var garden := _make_building(GARDEN_DEFINITION, container)

	assert(garden.is_producer(), "Catnip Garden must be configured as a producer.")
	assert(game_state.get_catnip() == 0, "Smoke test requires an empty catnip balance.")
	garden._on_simulation_advanced(GARDEN_DEFINITION.production_interval_seconds - 0.01)
	assert(game_state.get_catnip() == 0, "Production must not complete early.")
	garden._on_simulation_advanced(0.01)
	assert(game_state.get_catnip() == GARDEN_DEFINITION.production_amount, "Completed production must enter GameState.")
	assert(is_zero_approx(garden.production_elapsed_seconds), "A completed cycle must retain no phantom progress.")

	# Recipe inputs are all-or-nothing and a blocked cycle remains ready.
	var converter_definition := BuildingDefinition.new()
	converter_definition.id = &"test_converter"
	converter_definition.display_name = "Test Converter"
	converter_definition.completed_scene = GARDEN_SCENE
	converter_definition.production_resource = &"cheese"
	converter_definition.production_amount = 3
	converter_definition.production_interval_seconds = 5.0
	converter_definition.production_inputs = {&"catnip": 2}
	var converter := _make_building(converter_definition, container)
	var cheese_before := game_state.get_cheese()
	converter._on_simulation_advanced(5.0)
	assert(game_state.get_cheese() == cheese_before, "A blocked recipe must not create output.")
	assert(game_state.get_catnip() == 1, "A blocked recipe must not consume partial inputs.")
	assert(converter.get_pause_reason().begins_with("Missing"), "Blocked production must expose its pause reason.")
	game_state.add_catnip(1)
	converter._on_simulation_advanced(0.01)
	assert(game_state.get_catnip() == 0, "An unblocked recipe must consume its exact input.")
	assert(game_state.get_cheese() == cheese_before + 3, "An unblocked recipe must deposit its exact output.")

	# Debug acceleration reaches every producer through the shared clock.
	garden.production_elapsed_seconds = 0.0
	var second_garden := _make_building(GARDEN_DEFINITION, container)
	var catnip_before := game_state.get_catnip()
	simulation_clock.set_debug_time_multiplier(10.0)
	simulation_clock.set_simulation_paused(false)
	simulation_clock._process(2.0)
	simulation_clock.set_simulation_paused(true)
	assert(game_state.get_catnip() == catnip_before + 2, "One accelerated cycle must advance both producers.")

	# Completed building transforms and partial cycles survive a manager round trip.
	garden.position = Vector3(3.0, 0.0, -4.0)
	garden.production_elapsed_seconds = 7.5
	settlement_manager.register_completed_building(garden, GARDEN_DEFINITION)
	settlement_manager.register_completed_building(second_garden, GARDEN_DEFINITION)
	var snapshot := settlement_manager.serialize_completed_buildings()
	assert(snapshot.size() == 2, "Both registered producers must be serialized.")
	converter.queue_free()
	settlement_manager.restore_completed_buildings(snapshot)
	await process_frame
	var restored := settlement_manager.get_completed_buildings()
	assert(restored.size() == 2, "Both producers must be restored.")
	var restored_garden := restored[0] as CompletedBuilding
	assert(restored_garden.position.is_equal_approx(Vector3(3.0, 0.0, -4.0)), "Building transform must round-trip.")
	assert(is_equal_approx(restored_garden.production_elapsed_seconds, 7.5), "Partial production progress must round-trip.")

	print("MILESTONE_4_PRODUCTION_SMOKE_TEST_PASS")
	quit(0)


func _make_building(definition: BuildingDefinition, parent: Node) -> CompletedBuilding:
	var building := definition.completed_scene.instantiate() as CompletedBuilding
	building.building_definition = definition
	parent.add_child(building)
	return building
