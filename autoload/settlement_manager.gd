class_name Phase2SettlementManager
extends Node

signal influence_changed
signal building_registered(building: Node3D)

const INITIAL_RADIUS: float = 10.0
const SETTLEMENT_ORIGIN := Vector3.ZERO
const BUILDING_DEFINITION_DIRECTORY := "res://resources/buildings"

var _influence_sources: Dictionary = {}
var _completed_buildings: Array[Node3D] = []


func is_position_inside_settlement(world_position: Vector3) -> bool:
	var flat := world_position
	flat.y = 0.0
	if flat.distance_to(SETTLEMENT_ORIGIN) <= INITIAL_RADIUS:
		return true
	for source: Node3D in _influence_sources:
		if is_instance_valid(source) and flat.distance_to(Vector3(source.global_position.x, 0.0, source.global_position.z)) <= float(_influence_sources[source]):
			return true
	return false


func get_nearest_settlement_edge(world_position: Vector3) -> Vector3:
	var direction := Vector3(world_position.x, 0.0, world_position.z) - SETTLEMENT_ORIGIN
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	return SETTLEMENT_ORIGIN + direction.normalized() * INITIAL_RADIUS


func register_influence_source(source: Node3D, radius: float) -> void:
	if source == null or radius <= 0.0:
		return
	_influence_sources[source] = radius
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


func get_completed_buildings() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for building: Node3D in _completed_buildings:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			result.append(building)
	return result


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
