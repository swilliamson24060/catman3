extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	await process_frame
	root.get_node("SaveService").new_game("visual_m9")
	root.get_node("CommunityProjectService").restore_state({"active":false,"completed":true,"phase_index":4,"player_participated":true,"resident_participated":true})
	root.get_node("RelationshipService").enable_social_activity(&"garden_gathering")
	root.get_node("SeasonalResonanceService").activated = true
	var clearing := CLEARING.instantiate()
	root.add_child(clearing)
	await process_frame
	var celebration := root.get_node("CelebrationService")
	celebration.restore_state({"state":"gathering", "completed_contributions":["flower_table","festival_lights","story_cards"], "player_choice":"sunrise_bunting", "activation_day":3})
	for resident: ResidentAgent in root.get_node("ResidentManager").get_agents(): resident.global_position = Vector3(-7.0 + float(resident.get_index() - 1) * 1.2, 0.2, 12.5)
	var camera := clearing.get_node("IsometricCameraRig/YawPivot/PitchPivot/Camera3D") as Camera3D
	camera.size = 11.0
	camera.global_position = Vector3(-7, 14, -2)
	camera.look_at_from_position(camera.global_position, Vector3(-7, 1.0, 13))
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("/tmp/catmando_milestone9_celebration.png")
	print("MILESTONE_9_CELEBRATION_VISUAL_CAPTURE_PASS /tmp/catmando_milestone9_celebration.png")
	quit(0)
