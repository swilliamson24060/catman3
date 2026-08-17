extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("feature/reboot_mode", true)

	_check(VillageClearingBootstrap.is_within_buildable_area(Vector3.ZERO), "the village center must be buildable")
	_check(VillageClearingBootstrap.is_within_buildable_area(Vector3(22.0, 0.0, 22.0)), "just inside the buildable margin should still be buildable")
	_check(not VillageClearingBootstrap.is_within_buildable_area(Vector3(25.0, 0.0, 0.0)), "the buffer zone itself (between the buildable area and the tree line) must not be buildable")
	_check(not VillageClearingBootstrap.is_within_buildable_area(Vector3(0.0, 0.0, 26.0)), "the buffer zone must not be buildable on the Z axis either")
	_check(VillageClearingBootstrap.BUILDABLE_HALF_EXTENT < VillageClearingBootstrap.CLEARING_HALF_EXTENT, "the buildable area must be strictly smaller than the walkable clearing -- otherwise there's no buffer at all")

	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var ground := world.get_node_or_null("TerrainZones/ClearingBase")
	_check(ground != null, "ClearingBase should exist")
	if ground != null:
		var mesh: BoxMesh = ground.get_node("Visual").mesh
		var expected_span := VillageClearingBootstrap.CLEARING_HALF_EXTENT * 2.0
		_check(is_equal_approx(mesh.size.x, expected_span) and is_equal_approx(mesh.size.z, expected_span), "the clearing ground should be resized to match CLEARING_HALF_EXTENT: got %s, expected span %f" % [mesh.size, expected_span])

	var visual_apron := world.get_node_or_null("TerrainZones/ForestFloorApron")
	_check(visual_apron != null, "a visual forest-floor apron should continue behind the boundary trees")
	if visual_apron != null:
		var apron_mesh: BoxMesh = visual_apron.get_node("Visual").mesh
		var visual_span := VillageClearingBootstrap.VISUAL_GROUND_HALF_EXTENT * 2.0
		_check(is_equal_approx(apron_mesh.size.x, visual_span) and is_equal_approx(apron_mesh.size.z, visual_span), "the visual apron must reach the configured distance beyond the treeline")
		_check(visual_apron.get_node_or_null("Collision") == null, "the terrain beyond the treeline must stay visual-only, not expand character navigation")

	var north_wall := world.get_node_or_null("PlaceholderProps/BoundaryNorth")
	_check(north_wall != null, "the north boundary wall should exist")
	if north_wall != null:
		_check(is_equal_approx(north_wall.position.z, VillageClearingBootstrap.CLEARING_HALF_EXTENT), "the north wall should sit at the new, larger clearing edge: got z=%f" % north_wall.position.z)
		_check(north_wall.is_in_group("world_boundary"), "boundary walls must stay tagged for the edge-notice check in reboot_founder_cat.gd")
	var south_west := world.get_node_or_null("PlaceholderProps/BoundarySouthWest")
	var south_east := world.get_node_or_null("PlaceholderProps/BoundarySouthEast")
	_check(south_west != null and south_east != null, "the south boundary must remain closed except for its designated gate segments")
	if south_west != null and south_east != null:
		var opening_left: float = south_west.position.x + (south_west.get_node("Collision").shape as BoxShape3D).size.x * 0.5
		var opening_right: float = south_east.position.x - (south_east.get_node("Collision").shape as BoxShape3D).size.x * 0.5
		_check(is_equal_approx(opening_left, -VillageClearingBootstrap.GATE_HALF_WIDTH) and is_equal_approx(opening_right, VillageClearingBootstrap.GATE_HALF_WIDTH), "only the designated woodland gate should remain open through the navigation boundary")

	world.queue_free()
	await process_frame
	if _failure.is_empty():
		print("VILLAGE_BUFFER_ZONE_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
