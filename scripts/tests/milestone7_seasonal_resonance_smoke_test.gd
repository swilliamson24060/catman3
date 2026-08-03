extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const COMPONENTS: Array[StringName] = [&"component_rain_lens", &"component_copper_gear", &"component_heirloom_seeds"]
var _failure := ""
var _activation_count := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("feature/reboot_mode", true)
	var service := root.get_node("SeasonalResonanceService")
	service.reset()
	_test_geometry(service)
	var relationship := root.get_node("RelationshipService")
	relationship.reset()
	root.get_node("ResidentManager").new_game()
	root.get_node("DiscoveryService").reset()
	root.get_node("CommunityProjectService").reset()
	root.get_node("CommunityProjectService").restore_state({"completed":true,"phase_index":4,"player_participated":true,"resident_participated":true})
	var completed_buildings := Node3D.new()
	completed_buildings.add_to_group("completed_building_container")
	root.add_child(completed_buildings)
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	service.autosave_path = "user://milestone7_activation_test.json"
	service.activation_completed.connect(func(_id: StringName) -> void: _activation_count += 1)
	for component_id: StringName in COMPONENTS:
		root.get_node("DiscoveryService").find(component_id)
		root.get_node("DiscoveryService").investigate(component_id)
	_check(service.place_component(0, COMPONENTS[0]), "rain lens should install in a stable slot")
	_check(service.place_component(1, COMPONENTS[1]), "copper gear should install in a stable slot")
	_check(service.place_component(2, COMPONENTS[2]), "heirloom seeds should install in a stable slot")
	var recovered: StringName = service.retrieve_component(1)
	_check(recovered == COMPONENTS[1] and service.place_component(1, recovered), "unique components must always be safely recoverable")
	var before: int = service.evaluation_count
	for request in range(20): service.queue_evaluation()
	await create_timer(0.32).timeout
	_check(service.evaluation_count == before + 1, "debounce must collapse an evaluation storm while a component is moving")
	_check(int(service.current_result.tier) == 3 and service.watching_condition, "correct arrangement outside rain sunrise must be Aligned and watched")
	root.get_node("ResidentManager").get_agent(&"resident_mara").global_position = Vector3(-7.0, 0.2, 15.0)
	root.get_node("WeatherService").debug_force_transition(&"rain_to_sunrise", root.get_node("CalendarService").current_day)
	await create_timer(0.7).timeout
	_check(service.activated and _activation_count == 1, "one correct transition must activate exactly once")
	_check(service.flower_palette_unlocked, "First Bloom must unlock the visible flower palette")
	_check(relationship.is_social_activity_enabled(&"garden_gathering"), "First Bloom must enable garden gathering")
	_check(root.get_node("ResidentManager").get_agent(&"resident_mara").aspiration_step >= 1, "Mara aspiration must advance")
	_check(String(service.PATTERN_ID) in root.get_node("SaveService").current.discovered_patterns, "Almanac pattern must be confirmed")
	_check(not service.reaction_log.is_empty() and "resident_mara" in service.reaction_log.back().witnessed, "nearby residents should witness and react while distant residents remain on routine")
	var recovered_after_activation: StringName = service.retrieve_component(2)
	_check(recovered_after_activation == COMPONENTS[2] and service.activated and int(service.current_result.tier) == 4, "completed pattern must remain transformed while its unique components stay recoverable")
	var effect_count: int = service.applied_effects.size()
	root.get_node("WeatherService").debug_force_transition(&"rain_to_sunrise", root.get_node("CalendarService").current_day + 1)
	await create_timer(0.1).timeout
	_check(_activation_count == 1 and service.applied_effects.size() == effect_count, "later transitions must not duplicate effects")
	_check(root.get_node("SaveService").load_game(service.autosave_path), "activation autosave must load")
	_check(service.activated and service.applied_effects.size() == effect_count and _activation_count == 1, "load must reapply state without replaying rewards or sequence")
	_check(world.get_node("FirstBloomResonanceSite/FirstBloomFlowers").visible, "activated flower palette must restore visually")
	_cleanup(service.autosave_path)
	world.queue_free()
	completed_buildings.queue_free()
	await process_frame
	if _failure.is_empty():
		print("MILESTONE_7_SEASONAL_RESONANCE_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _test_geometry(service: Node) -> void:
	for rotation_degrees: float in [0.0, 47.0, 123.0, 270.0]:
		for side: float in [3.6, 4.5, 5.4]:
			var candidate := _candidate(side, rotation_degrees, COMPONENTS)
			var result: Dictionary = service.evaluate_attempt(candidate, false)
			_check(int(result.tier) == 3, "valid triangle must be rotation independent at side %.1f rotation %.0f" % [side, rotation_degrees])
	var mirrored := _candidate(4.5, 32.0, [COMPONENTS[0], COMPONENTS[2], COMPONENTS[1]])
	_check(int(service.evaluate_attempt(mirrored, false).tier) == 2, "mirrored role assignment should Echo without aligning")
	var near := _candidate(5.7, 18.0, COMPONENTS)
	_check(int(service.evaluate_attempt(near, false).tier) == 2, "near-correct out-of-scale triangle should provide Echoing feedback")
	var dormant := {"positions":[Vector3.ZERO,Vector3.RIGHT,Vector3.RIGHT*2.0], "components":["","",""], "center":Vector3.ZERO}
	_check(int(service.evaluate_attempt(dormant, false).tier) == 0, "fundamentally wrong empty attempt should remain Dormant")
	var stirring := {"positions":[Vector3.ZERO,Vector3.RIGHT,Vector3.RIGHT*2.0], "components":[COMPONENTS[0],"",""], "center":Vector3(20,0,20)}
	_check(int(service.evaluate_attempt(stirring, false).tier) == 1, "one relevant element without useful geometry should be Stirring")
	_check(int(service.evaluate_attempt(_candidate(4.5, 80.0, COMPONENTS), true).tier) == 4, "valid condition should produce Activated tier")

func _candidate(side: float, rotation_degrees: float, components: Array) -> Dictionary:
	var radius := side / sqrt(3.0)
	var positions: Array[Vector3] = []
	for index in range(3):
		var angle := deg_to_rad(rotation_degrees - 90.0 + index * 120.0)
		positions.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	return {"positions":positions, "components":components.duplicate(), "center":Vector3.ZERO, "landmark_ready":true}

func _cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var absolute := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
