class_name SocialPlace
extends Node3D

signal reservation_changed(place_id: StringName)

@export var place_id: StringName
@export var display_name: String = "Social place"
@export var activity_ids: Array[StringName] = [&"conversation"]
@export_range(2, 4, 1) var capacity: int = 2
@export_enum("bench", "table", "porch", "stoop") var placeholder_style: String = "bench"

var _slot_owners: Dictionary = {}
var _resident_slots: Dictionary = {}

func _ready() -> void:
	add_to_group("social_places")
	set_meta("development_placeholder", true)
	_build_placeholder()
	_build_slots()
	get_node("/root/RelationshipService").register_social_place(self)

func _exit_tree() -> void:
	var service := get_node_or_null("/root/RelationshipService")
	if service != null:
		service.unregister_social_place(place_id, self)

func supports_activity(activity_id: StringName) -> bool:
	return activity_id in activity_ids and get_node("/root/RelationshipService").is_social_activity_enabled(activity_id)

func reserve_group(resident_ids: Array[StringName]) -> bool:
	if resident_ids.is_empty() or resident_ids.size() > capacity:
		return false
	var unique: Dictionary = {}
	for resident_id: StringName in resident_ids:
		if resident_id == &"" or unique.has(resident_id):
			return false
		unique[resident_id] = true
		if _resident_slots.has(resident_id):
			return false
	var free_slots: Array[int] = []
	for slot_index in range(capacity):
		if not _slot_owners.has(slot_index):
			free_slots.append(slot_index)
	if free_slots.size() < resident_ids.size():
		return false
	for index in range(resident_ids.size()):
		var resident_id := resident_ids[index]
		var slot_index := free_slots[index]
		_slot_owners[slot_index] = resident_id
		_resident_slots[resident_id] = slot_index
	reservation_changed.emit(place_id)
	return true

func release_group(resident_ids: Array[StringName]) -> void:
	for resident_id: StringName in resident_ids:
		if not _resident_slots.has(resident_id):
			continue
		var slot_index: int = int(_resident_slots[resident_id])
		_resident_slots.erase(resident_id)
		_slot_owners.erase(slot_index)
	reservation_changed.emit(place_id)

func release_all() -> void:
	_slot_owners.clear()
	_resident_slots.clear()
	reservation_changed.emit(place_id)

func slot_position_for(resident_id: StringName) -> Vector3:
	if not _resident_slots.has(resident_id):
		return global_position
	var marker := get_node("Slots/Slot%d" % int(_resident_slots[resident_id])) as Marker3D
	return marker.global_position

func reserved_count() -> int:
	return _resident_slots.size()

func _build_slots() -> void:
	for index in range(capacity):
		var marker := Marker3D.new()
		marker.name = "Slot%d" % index
		var angle := TAU * float(index) / float(capacity)
		marker.position = Vector3(cos(angle) * 1.05, 0.2, sin(angle) * 1.05)
		$Slots.add_child(marker)

func _build_placeholder() -> void:
	match placeholder_style:
		"table":
			_add_box("Table", Vector3(1.8, 0.12, 1.15), Vector3(0, 0.72, 0), Color(0.45, 0.26, 0.13))
			for x in [-0.55, 0.55]:
				_add_cylinder("Mug", 0.12, 0.24, Vector3(x, 0.88, 0), Color(0.86, 0.72, 0.42))
		"porch":
			_add_box("Porch", Vector3(3.2, 0.18, 1.7), Vector3(0, 0.1, 0), Color(0.58, 0.36, 0.2))
			_add_box("ToolBox", Vector3(0.8, 0.45, 0.45), Vector3(0.75, 0.32, 0), Color(0.82, 0.48, 0.18))
		"stoop":
			_add_box("Step", Vector3(2.0, 0.3, 0.85), Vector3(0, 0.15, 0), Color(0.62, 0.48, 0.32))
			_add_cylinder("Mug", 0.12, 0.24, Vector3(0.55, 0.42, 0), Color(0.66, 0.79, 0.88))
		_:
			_add_box("BenchSeat", Vector3(2.4, 0.18, 0.55), Vector3(0, 0.55, 0), Color(0.48, 0.3, 0.14))
			_add_box("BenchBack", Vector3(2.4, 0.75, 0.15), Vector3(0, 0.9, 0.25), Color(0.48, 0.3, 0.14))

func _add_box(node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color)
	instance.set_meta("development_placeholder", true)
	$Presentation.add_child(instance)

func _add_cylinder(node_name: String, radius: float, height: float, position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color)
	instance.set_meta("development_placeholder", true)
	$Presentation.add_child(instance)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material
