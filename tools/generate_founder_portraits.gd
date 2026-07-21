extends Node
## Dev tool: renders a front-facing portrait of each non-bonus founder cat
## (using the same CatAppearance coloring the game applies at selection
## time) and saves it to res://founder/portraits/<id>.png. founder_card.gd
## displays these automatically when present, falling back to a flat color
## swatch otherwise -- so re-run this after adding/editing a founder in
## cats.json (or an expansion's founder_cats) to refresh its portrait.
##
## Not wired into any scene by default. To run: temporarily add a Node
## with this script as a child of the root in player.tscn, run the project
## once, then remove the node again (mirrors tools/generate_cat_textures.py's
## one-shot workflow).

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player_cat")
	if player == null:
		print("[PortraitGen] No player_cat found!")
		return

	# The founder-select modal is a CanvasLayer drawn on top of everything;
	# hide it during capture so the 3D render underneath isn't obscured.
	var founder_ui := get_tree().current_scene.get_node_or_null("FounderSelectUI")
	if founder_ui:
		founder_ui.visible = false
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	var inv_ui := get_tree().current_scene.get_node_or_null("InventoryUI")
	if inv_ui:
		inv_ui.visible = false

	var dir := DirAccess.open("res://founder/")
	if dir and not dir.dir_exists("portraits"):
		dir.make_dir("portraits")

	# Bright light so the portrait isn't a silhouette (scene has no
	# DirectionalLight3D -- only ambient sky light, which is too dim/flat).
	var light := DirectionalLight3D.new()
	get_parent().add_child(light)
	light.light_energy = 1.6
	light.rotation_degrees = Vector3(-40, -30, 0)

	# Dedicated portrait camera, close and level with the model, positioned
	# to view the model's FRONT (opposite the tail side).
	var cam := Camera3D.new()
	get_parent().add_child(cam)
	cam.fov = 40.0

	var founders := DataRegistry.get_all_founder_cats()
	for founder_data in founders:
		if founder_data.get("bonus", false):
			continue
		var fid: String = founder_data.get("id", "")
		var coat: Dictionary = founder_data.get("coat", {})
		CatAppearance.apply_to_player(player, fid, coat)

		var ppos: Vector3 = player.global_position
		cam.global_position = ppos + Vector3(-1.8, 1.3, -1.8)
		cam.look_at(ppos + Vector3(0, 0.9, 0), Vector3.UP)
		cam.current = true

		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

		var full_img := get_viewport().get_texture().get_image()
		# Crop to a centered square for a portrait aspect ratio.
		var w := full_img.get_width()
		var h := full_img.get_height()
		var side: int = h
		var x_off: int = int((w - side) / 2.0)
		var cropped := full_img.get_region(Rect2i(x_off, 0, side, side))
		cropped.resize(512, 512)
		var path := "res://founder/portraits/%s.png" % fid
		var err := cropped.save_png(path)
		print("[PortraitGen] Saved %s -> %s (err=%d)" % [fid, path, err])

	if founder_ui:
		founder_ui.visible = true
	if hud:
		hud.visible = true
	if inv_ui:
		inv_ui.visible = true

	print("[PortraitGen] Done.")
