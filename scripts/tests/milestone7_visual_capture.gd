extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const COMPONENTS: Array[StringName] = [&"component_rain_lens", &"component_copper_gear", &"component_heirloom_seeds"]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.get_node("CommunityProjectService").restore_state({"completed":true,"phase_index":4,"player_participated":true,"resident_participated":true})
	root.get_node("DiscoveryService").reset()
	root.get_node("SeasonalResonanceService").reset()
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	for component_id: StringName in COMPONENTS:
		root.get_node("DiscoveryService").find(component_id)
		root.get_node("DiscoveryService").investigate(component_id)
	for index in range(3): root.get_node("SeasonalResonanceService").place_component(index, COMPONENTS[index])
	await create_timer(0.35).timeout
	var player := world.get_node("RebootFounderCat") as Node3D
	player.global_position = Vector3(-7.0, 0.2, 14.5)
	for frame in range(20): await process_frame
	root.get_texture().get_image().save_png("/tmp/catmando_milestone7_aligned.png")
	root.get_node("SeasonalResonanceService").autosave_path = "user://milestone7_visual_capture.json"
	root.get_node("WeatherService").debug_force_transition(&"rain_to_sunrise", root.get_node("CalendarService").current_day)
	await create_timer(0.7).timeout
	root.get_texture().get_image().save_png("/tmp/catmando_milestone7_activated.png")
	for suffix in ["", ".bak", ".tmp"]:
		var absolute := ProjectSettings.globalize_path("user://milestone7_visual_capture.json" + suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	print("MILESTONE_7_VISUAL_CAPTURE_PASS /tmp/catmando_milestone7_aligned.png /tmp/catmando_milestone7_activated.png")
	world.queue_free()
	await process_frame
	quit(0)
