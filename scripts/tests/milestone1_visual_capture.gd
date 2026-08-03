extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const CAPTURE_PATH := "/tmp/catmando_milestone1.png"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene := CLEARING.instantiate()
	root.add_child(scene)
	for _frame in range(120):
		await process_frame
	var rendered_fps := Engine.get_frames_per_second()
	assert(rendered_fps >= 58.0, "Rendered greybox must sustain the 60 FPS development target")
	var image := root.get_texture().get_image()
	var error := image.save_png(CAPTURE_PATH)
	assert(error == OK, "Milestone 1 visual capture must save")
	scene.queue_free()
	await process_frame
	print("MILESTONE_1_VISUAL_CAPTURE_PASS fps=%.1f %s" % [rendered_fps, CAPTURE_PATH])
	quit(0)
