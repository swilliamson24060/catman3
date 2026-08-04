extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var world: Node = (load("res://scenes/world/village_clearing.tscn") as PackedScene).instantiate(); get_root().add_child(world)
	await process_frame; await create_timer(0.5).timeout
	var shell := world.get_node("RebootUIShell") as RebootUIShell; shell.open_menu(); await process_frame; await RenderingServer.frame_post_draw
	var path := "/tmp/catmando_milestone10_ui.png"
	var error := get_root().get_texture().get_image().save_png(path)
	if error != OK: push_error("Could not capture Milestone 10 UI: %s" % error); quit(1)
	print("MILESTONE_10_UI_VISUAL_CAPTURE_PASS %s" % path); quit(0)
