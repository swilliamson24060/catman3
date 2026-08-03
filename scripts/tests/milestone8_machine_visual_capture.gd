extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	await process_frame
	root.get_node("SaveService").new_game("visual_m8")
	root.get_node("CommunityProjectService").restore_state({"active":true,"phase_index":3,"player_participated":true,"resident_participated":true})
	var clearing := CLEARING.instantiate()
	root.add_child(clearing)
	await process_frame
	var machine := root.get_node("CommunityMachineService")
	machine.restore_state({"installed":true,"resonant":true,"craft_unlocked":true,"completed_crafts":["craft_sunrise_cloth","craft_rainpetal_cloth"],"current_state":"resonant","operation_count":2})
	var camera := clearing.get_node("IsometricCameraRig/YawPivot/PitchPivot/Camera3D") as Camera3D
	clearing.get_node("Interface").visible = false
	camera.size = 8.0
	camera.global_position = Vector3(16, 12, 17)
	camera.look_at_from_position(camera.global_position, Vector3(16, 0.8, -1))
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("/tmp/catmando_milestone8_machine.png")
	print("MILESTONE_8_MACHINE_VISUAL_CAPTURE_PASS /tmp/catmando_milestone8_machine.png")
	quit(0)
