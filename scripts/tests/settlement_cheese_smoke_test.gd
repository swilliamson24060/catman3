extends SceneTree

const MOUSE_SCENE: PackedScene = preload("res://scenes/mice/wild_mouse.tscn")
const SPAWNER_SCRIPT := preload("res://world/resource_node_spawner.gd")
const SETTLEMENT_CHEESE_SCRIPT := preload("res://world/settlement_cheese_pickup.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var game_state := root.get_node("GameState") as Phase1GameState
	var inventory := root.get_node("Inventory")
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
	var founder_inventory_before: int = int(inventory.call("get_item_count", "cheese_mild"))
	assert(bool(first_pickup.call("collect", founder)), "The founder must be able to collect settlement cheese")
	assert(int(inventory.call("get_item_count", "cheese_mild")) == founder_inventory_before + 1, "Founder pickup must enter the founder inventory")
	assert(game_state.get_cheese() == founder_cheese_before, "Physical cheese must not become recruitment currency before the player uses it")
	var cheese_slot := -1
	for index in inventory.slots.size():
		var slot: Dictionary = inventory.call("get_slot", index)
		if not slot.is_empty() and slot.item.id == "cheese_mild":
			cheese_slot = index
			break
	assert(cheese_slot >= 0, "Collected cheese must occupy an inventory slot")
	assert(bool(inventory.call("use_item_at", cheese_slot).success), "Collected cheese must be usable from inventory")
	assert(game_state.get_cheese() == founder_cheese_before + 1, "Using cheese must increase recruitment currency")
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

	# A full inventory must leave the pickup untouched in the world. Collection
	# is all-or-nothing so no partial stack can duplicate or destroy resources.
	var wood: InventoryItem = root.get_node("DataRegistry").call("make_inventory_item", "wood")
	for index in inventory.slots.size():
		var slot: Dictionary = inventory.call("get_slot", index)
		if not slot.is_empty():
			inventory.call("remove_item_at", index, int(slot.quantity))
	inventory.call("add_item", wood, inventory.slots.size() * wood.max_stack)
	var blocked_pickup := Area3D.new()
	blocked_pickup.set_script(SETTLEMENT_CHEESE_SCRIPT)
	blocked_pickup.position = Vector3(100.0, 0.0, 100.0)
	root.add_child(blocked_pickup)
	await process_frame
	assert(not bool(blocked_pickup.call("collect", founder)), "A full inventory must reject the complete pickup")
	assert(is_instance_valid(blocked_pickup) and not blocked_pickup.is_queued_for_deletion(), "A rejected pickup must remain available in the world")

	print("SETTLEMENT_CHEESE_SMOKE_TEST_PASS")
	quit(0)
