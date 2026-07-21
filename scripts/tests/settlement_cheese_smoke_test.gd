extends SceneTree

const MOUSE_SCENE: PackedScene = preload("res://scenes/mice/wild_mouse.tscn")
const SPAWNER_SCRIPT := preload("res://world/resource_node_spawner.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var game_state := root.get_node("GameState") as Phase1GameState
	var settlement_manager := root.get_node("SettlementManager") as Phase2SettlementManager
	game_state.reset()

	var spawner := Node3D.new()
	spawner.set_script(SPAWNER_SCRIPT)
	spawner.set("wood_count", 0)
	spawner.set("twigs_count", 0)
	spawner.set("yarn_count", 0)
	spawner.set("cheese_count", 0)
	spawner.set("moonstone_count", 0)
	spawner.set("rng_seed", 2407)
	root.add_child(spawner)
	await process_frame
	await process_frame

	var pickups := get_nodes_in_group("settlement_cheese_pickups")
	assert(pickups.size() == 1, "One random settlement cheese must spawn initially")
	var first_pickup := pickups[0] as Node3D
	assert(settlement_manager.is_position_inside_settlement(first_pickup.global_position), "Settlement cheese must spawn inside controlled territory")

	var founder := CharacterBody3D.new()
	founder.add_to_group("player_cat")
	root.add_child(founder)
	var founder_cheese_before := game_state.get_cheese()
	assert(bool(first_pickup.call("collect", founder)), "The founder must be able to collect settlement cheese")
	assert(game_state.get_cheese() == founder_cheese_before + 1, "Founder pickup must increase recruitment currency")
	await process_frame

	spawner.call("_on_need_cycle", 1)
	spawner.call("_on_need_cycle", 2)
	assert(get_nodes_in_group("settlement_cheese_pickups").is_empty(), "Cheese must not replenish before three turns")
	spawner.call("_on_need_cycle", 3)
	assert(get_nodes_in_group("settlement_cheese_pickups").size() == 1, "Cheese must replenish on the third turn")

	var mouse := MOUSE_SCENE.instantiate() as Phase1WildMouse
	root.add_child(mouse)
	await process_frame
	var mouse_price_before := mouse.get_recruitment_cost()
	var second_pickup := get_nodes_in_group("settlement_cheese_pickups")[0] as Node3D
	assert(bool(second_pickup.call("collect", mouse)), "An unrecruited mouse must be able to collect settlement cheese")
	assert(mouse.get_recruitment_cost() == mouse_price_before + 1, "Every random cheese found must add to that mouse's asking price")
	assert(game_state.get_cheese() == founder_cheese_before + 1, "Mouse pickup must not deposit cheese for the founder")

	print("SETTLEMENT_CHEESE_SMOKE_TEST_PASS")
	quit(0)
