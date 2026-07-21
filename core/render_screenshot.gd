extends Node
## Top-down and side views to unambiguously determine stripe orientation
## relative to the character's front-back (Z) vs left-right (X) axes.
## Safe to delete after use.

func _ready() -> void:
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player_cat")
	var founder_select := get_tree().root.find_child("FounderSelectUI", true, false)
	founder_select._on_founder_selected("turbo")
	for i in 8:
		await get_tree().process_frame

	var body: MeshInstance3D = player.get_node_or_null("animal-cat2/animal-cat/root/body")
	var aabb := body.get_aabb()
	var global_aabb: AABB = body.global_transform * aabb
	var center: Vector3 = global_aabb.position + global_aabb.size * 0.5

	var cam := get_tree().root.find_child("Camera3D", true, false)

	# Top-down view: shows both front-back and left-right extent at once.
	if cam:
		cam.global_position = center + Vector3(0, 3.0, 0)
		cam.look_at(center, Vector3.FORWARD)
		cam.fov = 50.0
	for i in 6:
		await get_tree().process_frame
	var img_top := get_viewport().get_texture().get_image()
	img_top.save_png("res://debug_orientation_top.png")
	print("[Orientation] saved debug_orientation_top.png")

	# Pure side view: camera looking straight down local +X (the axis the
	# shader currently stripes on). If stripes are truly left-right, this
	# view should show a solid, unstriped silhouette (looking straight down
	# the stripe axis). If it still shows alternating bands, the stripe
	# axis is actually front-back.
	if cam:
		cam.global_position = center + Vector3(2.5, 0, 0)
		cam.look_at(center, Vector3.UP)
		cam.fov = 45.0
	for i in 6:
		await get_tree().process_frame
	var img_side := get_viewport().get_texture().get_image()
	img_side.save_png("res://debug_orientation_side.png")
	print("[Orientation] saved debug_orientation_side.png")
