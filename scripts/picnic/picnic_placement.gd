class_name PicnicPlacementController
extends Node

signal placement_validity_changed(is_valid: bool)

const PICNIC_SCENE: PackedScene = preload("res://scenes/picnic/picnic.tscn")
const PREVIEW_VALID_COLOR := Color(0.25, 0.95, 0.38, 0.48)
const PREVIEW_INVALID_COLOR := Color(0.95, 0.22, 0.18, 0.48)
const PLACEMENT_HALF_EXTENTS := Vector3(1.35, 0.035, 1.05)

@export_range(1.5, 5.0, 0.25) var placement_distance: float = 2.5
@export_range(0.0, 60.0, 1.0) var maximum_slope_degrees: float = 25.0

@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState

var _preview: Phase1Picnic
var _is_valid: bool = false
var _last_validity: bool = false
var _preview_material: StandardMaterial3D


func _process(_delta: float) -> void:
	if _preview != null:
		_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not game_state.has_founder():
		return
	if event.is_action_pressed("place_picnic"):
		if game_state.is_build_decision_pending():
			game_state.request_feedback("Place the selected construction site before moving the picnic.")
		elif _preview == null and not game_state.has_picnic():
			begin_placement()
		elif game_state.has_picnic():
			pack_current_picnic()
		get_viewport().set_input_as_handled()
		return
	if _preview == null:
		return
	if event.is_action_pressed("interact"):
		confirm_placement()
		get_viewport().set_input_as_handled()


func is_placing() -> bool:
	return _preview != null


func begin_placement() -> void:
	if game_state.is_build_decision_pending():
		game_state.request_feedback("Place the selected construction site before moving the picnic.")
		return
	if _preview != null or game_state.has_picnic():
		return
	_preview = PICNIC_SCENE.instantiate() as Phase1Picnic
	_preview.name = "PicnicPreview"
	get_tree().current_scene.add_child(_preview)
	_preview.set_preview_mode(true)
	_set_preview_color(PREVIEW_INVALID_COLOR)
	game_state.set_placement_mode(true)


func pack_current_picnic() -> void:
	if game_state.is_build_decision_pending():
		game_state.request_feedback("Place the selected construction site before moving the picnic.")
		return
	var picnic := game_state.placed_picnic as Phase1Picnic
	if picnic == null:
		return
	picnic.pack_up()


func cancel_placement() -> void:
	if _preview == null:
		return
	_preview.queue_free()
	_preview = null
	_is_valid = false
	game_state.set_placement_mode(false)
	game_state.request_feedback("Picnic placement cancelled.")


func confirm_placement() -> void:
	if _preview == null:
		return
	if not _is_valid:
		game_state.request_feedback("Choose clear, reasonably flat ground.")
		return
	var container := get_tree().get_first_node_in_group("picnic_container") as Node3D
	if container == null:
		game_state.request_feedback("Picnic container is unavailable.")
		return
	var picnic := PICNIC_SCENE.instantiate() as Phase1Picnic
	picnic.global_transform = _preview.global_transform
	container.add_child(picnic)
	game_state.register_picnic(picnic)
	_preview.queue_free()
	_preview = null
	_is_valid = false
	game_state.set_placement_mode(false)
	game_state.request_feedback("Picnic placed. Walk close and press E to ring the bell.")


func _update_preview() -> void:
	var founder_forward := -player.global_basis.z
	founder_forward.y = 0.0
	founder_forward = founder_forward.normalized()
	var target_position := player.global_position + founder_forward * placement_distance
	var ray_origin := target_position + Vector3.UP * 6.0
	var ray_end := target_position + Vector3.DOWN * 8.0
	var ray_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1, [player.get_rid()])
	ray_query.collide_with_areas = false
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray_query)
	var next_valid := false
	if not hit.is_empty():
		var hit_position: Vector3 = hit["position"]
		var hit_normal: Vector3 = hit["normal"]
		_preview.global_position = hit_position + hit_normal * 0.025
		_preview.global_rotation = Vector3.ZERO
		var slope_ok := hit_normal.dot(Vector3.UP) >= cos(deg_to_rad(maximum_slope_degrees))
		next_valid = slope_ok and not _is_blocked(hit_position)
	_is_valid = next_valid
	_preview.visible = not hit.is_empty()
	if _is_valid != _last_validity:
		_last_validity = _is_valid
		_set_preview_color(PREVIEW_VALID_COLOR if _is_valid else PREVIEW_INVALID_COLOR)
		placement_validity_changed.emit(_is_valid)


func _is_blocked(position: Vector3) -> bool:
	var shape := BoxShape3D.new()
	shape.size = PLACEMENT_HALF_EXTENTS * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.09)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	return not player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _set_preview_color(color: Color) -> void:
	if _preview == null:
		return
	_preview_material = StandardMaterial3D.new()
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.albedo_color = color
	for child: Node in _preview.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		mesh_instance.material_override = _preview_material
