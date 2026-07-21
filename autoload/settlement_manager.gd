class_name Phase2SettlementManager
extends Node

signal influence_changed
signal building_registered(building: Node3D)

const INITIAL_RADIUS: float = 10.0
const SETTLEMENT_ORIGIN := Vector3.ZERO

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
