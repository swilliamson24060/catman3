extends SceneTree

const GARDEN_DEFINITION: BuildingDefinition = preload("res://resources/buildings/catnip_garden.tres")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState") as Phase1GameState
	game_state.reset()
	var garden := GARDEN_DEFINITION.completed_scene.instantiate() as CompletedBuilding
	garden.building_definition = GARDEN_DEFINITION
	root.add_child(garden)

	assert(garden.is_producer(), "Catnip Garden must be configured as a producer.")
	assert(game_state.get_catnip() == 0, "Smoke test requires an empty catnip balance.")
	garden._on_simulation_advanced(GARDEN_DEFINITION.production_interval_seconds - 0.01)
	assert(game_state.get_catnip() == 0, "Production must not complete early.")
	garden._on_simulation_advanced(0.01)
	assert(game_state.get_catnip() == GARDEN_DEFINITION.production_amount, "Completed production must enter GameState.")
	assert(is_zero_approx(garden.production_elapsed_seconds), "A completed cycle must retain no phantom progress.")

	print("MILESTONE_4_PRODUCTION_SMOKE_TEST_PASS")
	quit(0)
