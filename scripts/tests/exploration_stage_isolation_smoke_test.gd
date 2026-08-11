extends SceneTree
## Regression guard for a real bug: EXPLORATION_STAGE_ORIGIN was once a fixed
## Vector3 chosen to clear the clearing's old (pre-buffer) footprint. When
## CLEARING_HALF_EXTENT grew for the build-buffer feature, nothing re-checked
## that clearance, and the exploration stage's own ground/walls/treeline
## ended up overlapping the clearing's north edge. EXPLORATION_STAGE_ORIGIN
## is now derived from CLEARING_HALF_EXTENT so this can't silently regress
## again -- this test pins that relationship down explicitly.

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var stage_south_edge := VillageClearingBootstrap.EXPLORATION_STAGE_ORIGIN.z - VillageClearingBootstrap.EXPLORATION_STAGE_HALF_EXTENT
	_check(stage_south_edge > VillageClearingBootstrap.CLEARING_HALF_EXTENT, "the exploration stage's ground must not overlap the clearing: stage edge %.1f must sit past the clearing edge %.1f" % [stage_south_edge, VillageClearingBootstrap.CLEARING_HALF_EXTENT])

	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var north_wall := world.get_node_or_null("PlaceholderProps/BoundaryNorth")
	var stage_south_wall := world.get_node_or_null("PlaceholderProps/ExplorationBoundarySouth")
	_check(north_wall != null, "the clearing's north wall should exist")
	_check(stage_south_wall != null, "the exploration stage's south wall should exist")
	if north_wall != null and stage_south_wall != null:
		_check(stage_south_wall.position.z > north_wall.position.z, "the exploration stage's south wall (z=%.1f) must sit past the clearing's north wall (z=%.1f), not inside it" % [stage_south_wall.position.z, north_wall.position.z])

	world.queue_free()
	await process_frame
	if _failure.is_empty():
		print("EXPLORATION_STAGE_ISOLATION_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
