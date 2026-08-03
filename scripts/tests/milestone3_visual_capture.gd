extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const COMMUNITY_PATH := "/tmp/catmando_milestone3_community.png"
const DIALOGUE_PATH := "/tmp/catmando_milestone3_dialogue.png"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene := CLEARING.instantiate()
	root.add_child(scene)
	for _frame in range(45):
		await process_frame
	var manager := root.get_node("ResidentManager")
	var positions := [Vector3(-4.0,0.2,3.0), Vector3(1.0,0.2,1.0), Vector3(5.0,0.2,4.0)]
	var agents: Array[ResidentAgent] = manager.get_agents()
	for index in range(agents.size()):
		agents[index].global_position = positions[index]
		agents[index].current_state = ResidentAgent.State.ROUTINE_ACTIVITY
	await process_frame
	await process_frame
	assert(root.get_texture().get_image().save_png(COMMUNITY_PATH) == OK)
	manager._on_conversation_requested(manager.get_agent(&"resident_mara"))
	await process_frame
	await process_frame
	assert(root.get_texture().get_image().save_png(DIALOGUE_PATH) == OK)
	manager.close_dialogue()
	print("MILESTONE_3_VISUAL_CAPTURE_PASS")
	scene.queue_free()
	quit(0)
