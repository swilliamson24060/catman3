class_name Phase2SettlementManager
extends Node

signal influence_changed
signal building_registered(building: Node3D)

const INITIAL_RADIUS: float = 10.0
const INITIAL_WALLED_HALF_EXTENT: float = 14.5
const SETTLEMENT_ORIGIN := Vector3.ZERO
const BUILDING_DEFINITION_DIRECTORY := "res://resources/buildings"
const RESONANCE_GRID_SIZE: float = 3.0
const INFLUENCE_RING_WIDTH: float = 0.16
const INFLUENCE_RING_SEGMENTS: int = 64
const WORLD_HALF_EXTENT: float = 33.5

var _influence_sources: Dictionary = {}
var _completed_buildings: Array[Node3D] = []


func is_position_inside_settlement(world_position: Vector3) -> bool:
	var flat := world_position
	flat.y = 0.0
	# The starting settlement is the square enclosed by the four visible walls.
	# Influence granted by completed buildings remains circular beyond that area.
	if absf(flat.x - SETTLEMENT_ORIGIN.x) <= INITIAL_WALLED_HALF_EXTENT and absf(flat.z - SETTLEMENT_ORIGIN.z) <= INITIAL_WALLED_HALF_EXTENT:
		return true
	for source: Node3D in _influence_sources:
		if is_instance_valid(source) and flat.distance_to(Vector3(source.global_position.x, 0.0, source.global_position.z)) <= float(_influence_sources[source]):
			return true
	return false


func constrain_position_to_settlement(previous_position: Vector3, desired_position: Vector3) -> Vector3:
	if is_position_inside_settlement(desired_position):
		return desired_position
	if not is_position_inside_settlement(previous_position):
		return SETTLEMENT_ORIGIN + Vector3.UP * desired_position.y
	var inside := previous_position
	var outside := desired_position
	# Find the current territory edge along this movement segment. Keeping a
	# small inset prevents physics jitter when velocity continues toward fog.
	for _iteration: int in range(14):
		var midpoint := inside.lerp(outside, 0.5)
		if is_position_inside_settlement(midpoint):
			inside = midpoint
		else:
			outside = midpoint
	var inward := (previous_position - inside)
	inward.y = 0.0
	if not inward.is_zero_approx():
		inside += inward.normalized() * 0.04
	inside.y = desired_position.y
	return inside


func get_random_position_inside_settlement(rng: RandomNumberGenerator, margin: float = 0.0) -> Vector3:
	if rng == null:
		return SETTLEMENT_ORIGIN
	var safe_initial_extent := maxf(INITIAL_WALLED_HALF_EXTENT - margin, 1.0)
	var valid_sources: Array[Node3D] = []
	for source: Node3D in _influence_sources:
		if is_instance_valid(source) and float(_influence_sources[source]) > margin:
			valid_sources.append(source)
	# Expansion zones receive half the spawn opportunities once one exists.
	if not valid_sources.is_empty() and rng.randf() < 0.5:
		var source := valid_sources[rng.randi_range(0, valid_sources.size() - 1)]
		var radius := maxf(float(_influence_sources[source]) - margin, 0.5)
		var angle := rng.randf_range(0.0, TAU)
		var distance := sqrt(rng.randf()) * radius
		var candidate := source.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		candidate.x = clampf(candidate.x, -WORLD_HALF_EXTENT, WORLD_HALF_EXTENT)
		candidate.z = clampf(candidate.z, -WORLD_HALF_EXTENT, WORLD_HALF_EXTENT)
		return candidate
	return Vector3(
		rng.randf_range(-safe_initial_extent, safe_initial_extent),
		0.0,
		rng.randf_range(-safe_initial_extent, safe_initial_extent)
	)


func get_nearest_settlement_edge(world_position: Vector3) -> Vector3:
	var direction := Vector3(world_position.x, 0.0, world_position.z) - SETTLEMENT_ORIGIN
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	return SETTLEMENT_ORIGIN + direction.normalized() * INITIAL_RADIUS


func world_to_resonance_grid(world_position: Vector3) -> Vector2i:
	return Vector2i(
		roundi(world_position.x / RESONANCE_GRID_SIZE),
		roundi(world_position.z / RESONANCE_GRID_SIZE)
	)


func resonance_grid_to_world(grid_position: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3(grid_position.x * RESONANCE_GRID_SIZE, height, grid_position.y * RESONANCE_GRID_SIZE)


func snap_to_resonance_grid(world_position: Vector3) -> Vector3:
	return resonance_grid_to_world(world_to_resonance_grid(world_position), world_position.y)


func register_influence_source(source: Node3D, radius: float) -> void:
	if source == null or radius <= 0.0:
		return
	_influence_sources[source] = radius
	_add_influence_ring(source, radius)
	influence_changed.emit()


func unregister_influence_source(source: Node3D) -> void:
	if _influence_sources.erase(source):
		influence_changed.emit()


func register_completed_building(building: Node3D, definition: BuildingDefinition) -> void:
	if building == null or building in _completed_buildings:
		return
	_completed_buildings.append(building)
	if definition != null and definition.settlement_influence_radius > 0.0:
		register_influence_source(building, definition.settlement_influence_radius)
	building_registered.emit(building)


func _add_influence_ring(source: Node3D, radius: float) -> void:
	var existing := source.get_node_or_null("SettlementInfluenceRing")
	if existing != null:
		existing.queue_free()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index: int in range(INFLUENCE_RING_SEGMENTS + 1):
		var angle := TAU * float(index) / float(INFLUENCE_RING_SEGMENTS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		mesh.surface_add_vertex(direction * (radius - INFLUENCE_RING_WIDTH))
		mesh.surface_add_vertex(direction * radius)
	mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.28, 0.72, 1.0, 0.62)
	var ring := MeshInstance3D.new()
	ring.name = "SettlementInfluenceRing"
	ring.position.y = 0.035
	ring.mesh = mesh
	ring.material_override = material
	source.add_child(ring)


func unregister_completed_building(building: Node3D) -> void:
	if building == null:
		return
	_completed_buildings.erase(building)
	unregister_influence_source(building)


func get_completed_buildings() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for building: Node3D in _completed_buildings:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			result.append(building)
	return result


func get_completed_buildings_of_type(definition_id: StringName) -> Array[CompletedBuilding]:
	var result: Array[CompletedBuilding] = []
	for node: Node3D in get_completed_buildings():
		var building := node as CompletedBuilding
		if building != null and building.building_definition != null and building.building_definition.id == definition_id:
			result.append(building)
	return result


func has_completed_building_at(grid_position: Vector2i, definition_id: StringName) -> bool:
	for building: CompletedBuilding in get_completed_buildings_of_type(definition_id):
		if world_to_resonance_grid(building.global_position) == grid_position:
			return true
	return false


func serialize_completed_buildings() -> Array:
	var result: Array = []
	for building: Node3D in _completed_buildings:
		if not is_instance_valid(building):
			continue
		var definition := building.get("building_definition") as BuildingDefinition
		if definition == null:
			continue
		var progress := 0.0
		if building is CompletedBuilding:
			progress = (building as CompletedBuilding).production_elapsed_seconds
		result.append({
			"definition_id": str(definition.id),
			"transform": _serialize_transform(building.transform),
			"production_elapsed_seconds": progress,
			"durability": (building as CompletedBuilding).durability if building is CompletedBuilding else 100.0,
		})
	return result


func restore_completed_buildings(data: Array) -> void:
	for building: Node3D in _completed_buildings:
		if is_instance_valid(building):
			building.queue_free()
	_completed_buildings.clear()
	_influence_sources.clear()

	var container := get_tree().get_first_node_in_group("completed_building_container") as Node3D
	if container == null:
		container = get_tree().current_scene
	if container == null:
		push_warning("Cannot restore Phase 2 buildings without a scene container.")
		return
	for raw: Variant in data:
		if not raw is Dictionary:
			continue
		var entry := raw as Dictionary
		var definition := get_building_definition(StringName(str(entry.get("definition_id", ""))))
		if definition == null or definition.completed_scene == null:
			continue
		var building := definition.completed_scene.instantiate() as CompletedBuilding
		building.building_definition = definition
		container.add_child(building)
		building.transform = _deserialize_transform(entry.get("transform", {}))
		building.restore_production_progress(float(entry.get("production_elapsed_seconds", 0.0)))
		building.restore_durability(float(entry.get("durability", definition.max_durability)))
		register_completed_building(building, definition)
	influence_changed.emit()


func get_building_definition(definition_id: StringName) -> BuildingDefinition:
	for file_name: String in DirAccess.get_files_at(BUILDING_DEFINITION_DIRECTORY):
		if not file_name.ends_with(".tres"):
			continue
		var definition := load(BUILDING_DEFINITION_DIRECTORY.path_join(file_name)) as BuildingDefinition
		if definition != null and definition.id == definition_id:
			return definition
	return null


func _serialize_transform(value: Transform3D) -> Dictionary:
	return {
		"origin": [value.origin.x, value.origin.y, value.origin.z],
		"basis_x": [value.basis.x.x, value.basis.x.y, value.basis.x.z],
		"basis_y": [value.basis.y.x, value.basis.y.y, value.basis.y.z],
		"basis_z": [value.basis.z.x, value.basis.z.y, value.basis.z.z],
	}


func _deserialize_transform(data: Dictionary) -> Transform3D:
	return Transform3D(
		Basis(
			_to_vector3(data.get("basis_x", [1.0, 0.0, 0.0])),
			_to_vector3(data.get("basis_y", [0.0, 1.0, 0.0])),
			_to_vector3(data.get("basis_z", [0.0, 0.0, 1.0]))
		),
		_to_vector3(data.get("origin", [0.0, 0.0, 0.0]))
	)


func _to_vector3(data: Variant) -> Vector3:
	if not data is Array or data.size() < 3:
		return Vector3.ZERO
	return Vector3(float(data[0]), float(data[1]), float(data[2]))
