extends SceneTree

const UNDERSEA := "expansion_undersea"
const SPACE_MICE := "expansion_space_mice"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var data_registry: Node = root.get_node("DataRegistry")
	var inventory: Node = root.get_node("Inventory")
	var event_bus: Node = root.get_node("EventBus")
	var animal_manager: Node = root.get_node("AnimalManager")

	assert(data_registry.load_errors.is_empty(), "Expansion registry validation must pass: %s" % str(data_registry.load_errors))

	var kelp: Dictionary = data_registry.call("get_item", "%s:kelp" % UNDERSEA)
	var burrow: Dictionary = data_registry.call("get_building", "%s:building_crab_burrow" % UNDERSEA)
	var crab: Dictionary = data_registry.call("get_animal_type", "%s:crab" % UNDERSEA)
	assert(not kelp.is_empty(), "Undersea Kelp must load")
	assert(not burrow.is_empty(), "Undersea Crab Burrow must load")
	assert(not crab.is_empty(), "Undersea Crab must load")
	assert(kelp.id == "%s:kelp" % UNDERSEA, "Expansion item ids must be canonical")
	assert(burrow.id == "%s:building_crab_burrow" % UNDERSEA, "Expansion building ids must be canonical")
	assert(crab.id == "%s:crab" % UNDERSEA, "Expansion animal ids must be canonical")
	assert(crab.housing_building_type == burrow.id, "Same-file housing reference must resolve locally")
	assert(crab.job_roles[0].output == kelp.id, "Same-file job output must resolve locally")
	assert(crab.upkeep.item == kelp.id, "Same-file upkeep item must resolve locally")

	var kelp_item: InventoryItem = data_registry.call("make_inventory_item", kelp.id)
	assert(kelp_item != null and kelp_item.id == kelp.id, "Expansion resources must use the generic inventory pipeline")
	assert(int(inventory.call("add_item", kelp_item, 2)) == 0, "Expansion item must fit in inventory")
	event_bus.building_placed_as_blueprint.emit(burrow.id, Vector2i(2, 2))
	assert(int(animal_manager.call("housing_capacity", crab.id)) == 2, "Expansion housing must feed the generic animal framework")
	assert(bool(animal_manager.call("recruit", crab.id)), "Expansion animal must recruit without species-specific code")
	assert(int(animal_manager.call("recruited_count", crab.id)) == 1, "Expansion recruit must enter the shared roster")

	var comet: Dictionary = data_registry.call("get_founder_cat", "%s:comet" % SPACE_MICE)
	var moon_cheese: Dictionary = data_registry.call("get_item", "%s:moon_cheese" % SPACE_MICE)
	var space_achievement: Dictionary = data_registry.call("get_achievement", "%s:spacefarers_first_hut" % SPACE_MICE)
	assert(comet.id == "%s:comet" % SPACE_MICE, "Expansion founder must retain its namespace")
	assert(moon_cheese.id == "%s:moon_cheese" % SPACE_MICE, "Second expansion item must retain its namespace")
	assert(space_achievement.condition.building_id == "building_mouse_hut", "Expansion-to-core reference must preserve the core runtime id")
	assert(data_registry.call("get_item", "kelp").id == kelp.id, "Unique bare-id compatibility lookup must still work")

	print("MILESTONE_8_EXPANSION_SMOKE_TEST_PASS")
	quit()
