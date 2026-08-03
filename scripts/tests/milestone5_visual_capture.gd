extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.get_node("CommunityProjectService").reset()
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	root.get_node("ResidentManager").propose_priority(&"project_restore_garden")
	var service := root.get_node("CommunityProjectService")
	service.restore_state({"active":true, "phase_index":3, "phase_contributors":["founder"], "player_participated":true, "resident_participated":true, "deposited_materials":{"garden_seed":2}, "source_remaining":{"reclaimed_wood":1,"smooth_stone":1,"garden_seed":1}})
	root.get_node("ResidentManager").consider_project_contributions()
	for agent: ResidentAgent in root.get_node("ResidentManager").get_agents():
		if agent.current_state == ResidentAgent.State.CONTRIBUTION_TRAVEL: agent.global_position = agent.activity_position()
	for frame in range(45): await process_frame
	var image := root.get_texture().get_image()
	image.save_png("/tmp/catmando_milestone5_garden.png")
	print("MILESTONE_5_VISUAL_CAPTURE_PASS /tmp/catmando_milestone5_garden.png")
	world.queue_free()
	await process_frame
	quit(0)
