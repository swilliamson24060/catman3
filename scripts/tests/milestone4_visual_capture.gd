extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const CAPTURE_PATH := "/tmp/catmando_milestone4_social.png"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene := CLEARING.instantiate()
	root.add_child(scene)
	for _frame in range(45):
		await process_frame
	var manager := root.get_node("ResidentManager")
	var relationships := root.get_node("RelationshipService")
	var participants: Array[StringName] = [&"resident_mara", &"resident_pip", &"resident_elowen"]
	var session_id: StringName = manager.plan_social_activity(&"shared_meal", participants, &"garden_table", 30.0)
	assert(session_id != &"")
	for resident_id: StringName in participants:
		var agent: ResidentAgent = manager.get_agent(resident_id)
		agent.global_position = agent.activity_position()
		agent._physics_process(0.016)
	manager._process(0.01)
	relationships.record_moment(&"resident_mara", &"resident_pip", &"shared_meal", "Mara and Pip shared a quiet meal beneath the old branches.", "visual_capture")
	for _frame in range(8):
		await process_frame
	assert(root.get_texture().get_image().save_png(CAPTURE_PATH) == OK)
	manager.cancel_social_activity(session_id)
	print("MILESTONE_4_VISUAL_CAPTURE_PASS")
	scene.queue_free()
	quit(0)
