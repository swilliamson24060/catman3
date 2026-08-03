extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var started_usec := Time.get_ticks_usec()
	var scene := CLEARING.instantiate()
	root.add_child(scene)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var destinations: Dictionary = scene.get_authored_destinations()
	assert(destinations.size() == 6, "Clearing must expose five village destinations plus the ruin overlook")
	assert(scene.get_node("TerrainZones/ClearingBase") != null)
	var clearing_mesh := scene.get_node("TerrainZones/ClearingBase/Visual") as MeshInstance3D
	assert((clearing_mesh.mesh as BoxMesh).size == Vector3(45.0, 0.25, 45.0), "Clearing footprint must be locked to 45 x 45 meters")
	assert(scene.get_node("WoodlandRoute/MainRoute") != null)
	assert(scene.get_node("WoodlandRoute/WestBranch") != null)
	assert(scene.get_node("WoodlandRoute/EastBranch") != null)
	assert(scene.get_node("WoodlandRoute/RuinBranch") != null)
	assert(scene.get_node("AncientRuin").get_child_count() == 4, "Ruin silhouette needs three uprights and a lintel")
	assert(scene.get_node("Ambience").get_child_count() == 3, "Clearing, woodland, and ruin ambience zones are required")
	assert(scene.get_node("AuthoredInteractionAnchors").get_child_count() == destinations.size())

	var player := scene.get_node("RebootFounderCat") as RebootFounderCat
	var camera_rig := scene.get_node("IsometricCameraRig") as IsometricCameraRig
	assert(is_equal_approx(player.maximum_speed, 5.25))
	assert(player.acceleration > 0.0 and player.deceleration > player.acceleration)
	assert(camera_rig.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	for angle in range(4):
		camera_rig.set_angle_index(angle)
		assert(camera_rig.angle_index == angle)

	# The actual collision world is sampled into a one-meter AStar grid. A cell
	# is walkable only when it has terrain beneath it and a cat-sized capsule
	# does not overlap a prop. This verifies authored destinations are reachable
	# without depending on a pre-baked navigation resource.
	var grid := _build_walkability_grid(scene)
	var origin := _point_id(Vector2i(0, 5))
	assert(grid.has_point(origin), "Player spawn must be walkable")
	for destination_id: StringName in destinations:
		var point := destinations[destination_id] as Vector3
		var cell := Vector2i(roundi(point.x), roundi(point.z))
		var target_id := _nearest_walkable_id(grid, cell)
		assert(target_id >= 0, "Destination must have a nearby walkable point: %s" % destination_id)
		assert(not grid.get_id_path(origin, target_id).is_empty(), "Player must reach %s without snagging" % destination_id)

	# Interaction icons intentionally render through occluders while the fader
	# softens intervening props. Beside the player, an authored interaction must
	# stay inside the viewport at the current angle or the next snap angle.
	for anchor_node: Node in scene.get_node("AuthoredInteractionAnchors").get_children():
		var anchor := anchor_node as InteractionAnchor
		player.global_position = anchor.global_position + Vector3(0.0, 0.2, 1.2)
		camera_rig.global_position = player.global_position
		player._process(0.0)
		assert(player.get_active_anchor() == anchor, "Authored anchor must drive the contextual prompt")
		for start_angle in range(4):
			var visible := _anchor_visible(camera_rig, anchor, start_angle) or _anchor_visible(camera_rig, anchor, start_angle + 1)
			assert(visible, "Interaction %s must become visible within one camera snap" % anchor.anchor_id)

	for _frame in range(120):
		await process_frame
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var average_frame_ms := elapsed_ms / 120.0
	assert(average_frame_ms < 16.67, "Greybox headless frame-time baseline must remain at least 60 FPS")

	scene.queue_free()
	await process_frame
	await process_frame
	print("MILESTONE_1_CLEARING_SMOKE_TEST_PASS average_frame_ms=%.3f" % average_frame_ms)
	quit(0)

func _build_walkability_grid(scene: Node3D) -> AStar2D:
	var grid := AStar2D.new()
	var space := scene.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.25
	for z in range(-56, 23):
		for x in range(-22, 23):
			var cell := Vector2i(x, z)
			if not _has_ground(space, cell) or _has_obstacle(space, capsule, cell):
				continue
			grid.add_point(_point_id(cell), Vector2(cell.x, cell.y))
	for z in range(-56, 23):
		for x in range(-22, 23):
			var cell := Vector2i(x, z)
			var source := _point_id(cell)
			if not grid.has_point(source):
				continue
			for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var target := _point_id(cell + offset)
				if grid.has_point(target):
					grid.connect_points(source, target)
	return grid

func _has_ground(space: PhysicsDirectSpaceState3D, cell: Vector2i) -> bool:
	var from := Vector3(cell.x, 2.0, cell.y)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, 1)
	return not space.intersect_ray(query).is_empty()

func _has_obstacle(space: PhysicsDirectSpaceState3D, capsule: CapsuleShape3D, cell: Vector2i) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, Vector3(cell.x, 0.65, cell.y))
	query.collision_mask = 4
	query.collide_with_areas = false
	return not space.intersect_shape(query, 1).is_empty()

func _anchor_visible(camera_rig: IsometricCameraRig, anchor: InteractionAnchor, angle: int) -> bool:
	camera_rig.set_angle_index(angle)
	var camera := camera_rig.camera
	var screen_position := camera.unproject_position(anchor.global_position + Vector3.UP * 1.0)
	var viewport_size := camera.get_viewport().get_visible_rect().size
	if screen_position.x < 0.0 or screen_position.y < 0.0 or screen_position.x > viewport_size.x or screen_position.y > viewport_size.y:
		return false
	return true

func _nearest_walkable_id(grid: AStar2D, cell: Vector2i) -> int:
	for radius in range(0, 4):
		for z in range(cell.y - radius, cell.y + radius + 1):
			for x in range(cell.x - radius, cell.x + radius + 1):
				var id := _point_id(Vector2i(x, z))
				if grid.has_point(id):
					return id
	return -1

func _point_id(cell: Vector2i) -> int:
	return (cell.y + 64) * 128 + (cell.x + 64)
