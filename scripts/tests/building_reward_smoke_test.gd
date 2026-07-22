extends SceneTree

const MOUSE_SCENE: PackedScene = preload("res://scenes/mice/wild_mouse.tscn")
const TEST_STRUCTURE: BuildingDefinition = preload("res://resources/buildings/test_structure.tres")
const CATNIP_GARDEN: BuildingDefinition = preload("res://resources/buildings/catnip_garden.tres")
const MOUSE_HUT: BuildingDefinition = preload("res://resources/buildings/mouse_hut.tres")
const CHEESE_VAULT: BuildingDefinition = preload("res://resources/buildings/cheese_vault.tres")


func _initialize() -> void:
	call_deferred("_run")


func _make_worker() -> Phase1WildMouse:
	var mouse := MOUSE_SCENE.instantiate() as Phase1WildMouse
	root.add_child(mouse)
	mouse.is_recruited = true
	return mouse


func _make_reward_building(definition: BuildingDefinition, builders: Array[Phase1WildMouse]) -> CompletedBuilding:
	var building := definition.completed_scene.instantiate() as CompletedBuilding
	building.building_definition = definition
	root.add_child(building)
	building.configure_builders(builders)
	building.grant_completion_rewards()
	return building


func _run() -> void:
	await process_frame
	var game_state := root.get_node("GameState") as Phase1GameState
	game_state.reset()

	var test_workers: Array[Phase1WildMouse] = [_make_worker(), _make_worker()]
	var founder_before := game_state.get_cheese()
	var test_building := _make_reward_building(TEST_STRUCTURE, test_workers)
	assert(game_state.get_cheese() == founder_before + 1, "Test Structure must give the founder 1 recruitment cheese")
	for mouse in test_workers:
		assert(mouse.get_personal_cheese() == 1, "Test Structure must give each builder 1 personal cheese")
	for turn in range(1, 5):
		test_building._on_need_cycle(turn)
	assert(test_workers[0].get_personal_cheese() == 1, "Recurring worker cheese must wait five turns")
	test_building._on_need_cycle(5)
	assert(test_workers[0].get_personal_cheese() == 2, "Every completed building must pay each builder after five turns")

	var garden_workers: Array[Phase1WildMouse] = [_make_worker(), _make_worker(), _make_worker()]
	var catnip_before := game_state.get_catnip()
	_make_reward_building(CATNIP_GARDEN, garden_workers)
	assert(game_state.get_catnip() == catnip_before + 1, "Catnip Garden must grant 1 catnip on completion")
	for mouse in garden_workers:
		assert(mouse.get_personal_cheese() == 1, "Catnip Garden must give each builder 1 personal cheese")

	var hut_workers: Array[Phase1WildMouse] = [_make_worker(), _make_worker(), _make_worker(), _make_worker()]
	founder_before = game_state.get_cheese()
	_make_reward_building(MOUSE_HUT, hut_workers)
	assert(game_state.get_cheese() == founder_before + 2, "Mouse Hut must give the founder 2 recruitment cheese")
	for mouse in hut_workers:
		assert(mouse.get_personal_cheese() == 1, "Mouse Hut must give each builder 1 personal cheese")
		assert(mouse.get_contentment_score() == 13, "Mouse Hut must increase each builder's contentment by 3")

	var vault_workers: Array[Phase1WildMouse] = [_make_worker(), _make_worker(), _make_worker(), _make_worker(), _make_worker()]
	founder_before = game_state.get_cheese()
	_make_reward_building(CHEESE_VAULT, vault_workers)
	assert(game_state.get_cheese() == founder_before + 3, "Cheese Vault must give the founder 3 recruitment cheese")
	for mouse in vault_workers:
		assert(mouse.get_personal_cheese() == 1, "Cheese Vault must give each builder 1 personal cheese")

	var uneasy_mouse := _make_worker()
	uneasy_mouse.receive_personal_cheese(2)
	uneasy_mouse.adjust_contentment(-6)
	assert(uneasy_mouse.get_contentment_score() == 6, "An uneasy mouse must eat as much personal cheese as it has")
	assert(uneasy_mouse.get_personal_cheese() == 0, "Consumed personal cheese must leave the mouse's balance")
	uneasy_mouse.receive_personal_cheese(4)
	assert(uneasy_mouse.get_contentment_score() == 10, "New personal cheese must restore an uneasy mouse to 10 contentment")
	assert(uneasy_mouse.get_personal_cheese() == 0, "Only the cheese required for recovery should be consumed")

	print("BUILDING_REWARD_SMOKE_TEST_PASS")
	quit(0)
