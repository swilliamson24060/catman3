extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.get_node("RumorService").reset()
	root.get_node("DiscoveryService").reset()
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	root.get_node("DiscoveryService").resident_observed(&"component_copper_gear", &"resident_pip")
	root.get_node("DiscoveryService").find(&"component_rain_lens")
	root.get_node("ResidentManager").meet_for_investigation(&"history")
	for frame in range(30): await process_frame
	var image := root.get_texture().get_image()
	image.save_png("/tmp/catmando_milestone6_exploration.png")
	print("MILESTONE_6_VISUAL_CAPTURE_PASS /tmp/catmando_milestone6_exploration.png")
	world.queue_free()
	await process_frame
	quit(0)
