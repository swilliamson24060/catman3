extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const DISCOVERY_IDS: Array[StringName] = [&"discovery_old_plaque", &"component_rain_lens", &"component_copper_gear", &"component_heirloom_seeds", &"clue_ruin_triangle"]
var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("feature/reboot_mode", true)
	root.get_node("RumorService").reset()
	root.get_node("DiscoveryService").reset()
	root.get_node("InvestigationService").reset()
	root.get_node("ResidentManager").new_game()
	var completed_buildings := Node3D.new()
	completed_buildings.add_to_group("completed_building_container")
	root.add_child(completed_buildings)
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var discovery := root.get_node("DiscoveryService")
	var rumor := root.get_node("RumorService")
	_check(discovery.state(&"component_copper_gear") == &"rumored", "Pip must convert one resident observation into a player rumor")
	_check(not rumor.known_rumors().is_empty(), "resident rumor should enter the unified Almanac source")
	_check(world.get_node("WoodlandRoute/RainLensSite") != null and world.get_node("WoodlandRoute/CopperGearSite") != null and world.get_node("WoodlandRoute/HeirloomSeedsSite") != null, "three woodland branches need stable discovery sites")
	_check(world.get_node("AncientRuin/TriangleClueSite") != null, "ruin needs a stable triangular clue site")

	# Reverse order proves every find is independent and cannot deadlock.
	for index in range(DISCOVERY_IDS.size() - 1, -1, -1):
		var discovery_id := DISCOVERY_IDS[index]
		_check(discovery.find(discovery_id), "%s should be findable in any order" % discovery_id)
		_check(discovery.state(discovery_id) == &"investigation_available", "found item should become available for investigation")
		_check(discovery.unidentified_name(discovery_id) != discovery.display_name(discovery_id), "unidentified inventory text must not reveal final purpose")

	root.get_node("CalendarService").debug_jump_to_period(&"night")
	root.get_node("CalendarService").debug_jump_to_period(&"morning")
	var save_path := "user://milestone6_discovery_test.json"
	_check(root.get_node("SaveService").save_game(save_path), "discovery save should succeed")
	discovery.reset()
	_check(root.get_node("SaveService").load_game(save_path), "discovery load should succeed")
	for discovery_id: StringName in DISCOVERY_IDS: _check(discovery.state(discovery_id) == &"investigation_available", "stored component/find must survive save and day transitions")

	for discovery_id: StringName in DISCOVERY_IDS:
		var result: Dictionary = root.get_node("InvestigationService").investigate(discovery_id)
		_check(not result.is_empty() and discovery.state(discovery_id) == &"interpreted", "investigation must interpret %s without a specialty gate" % discovery_id)
		_check(not StringName(str(result.resident_id)).is_empty(), "a suitable resident should meet the founder for investigation")
	_check(root.get_node("SaveService").save_game(save_path), "interpreted state save should succeed")
	discovery.reset()
	_check(root.get_node("SaveService").load_game(save_path), "interpreted state load should succeed")
	for discovery_id: StringName in DISCOVERY_IDS: _check(discovery.state(discovery_id) == &"interpreted", "interpretation must persist and update dependent context")
	_check(root.get_node("SaveService").current.discovered_patterns.is_empty(), "Milestone 6 must not confirm a Resonance pattern")
	_cleanup(save_path)
	world.queue_free()
	completed_buildings.queue_free()
	await process_frame
	if _failure.is_empty():
		print("MILESTONE_6_EXPLORATION_DISCOVERY_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var absolute := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
