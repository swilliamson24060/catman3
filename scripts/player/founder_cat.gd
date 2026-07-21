extends CharacterBody3D

const CAT_SCENE: PackedScene = preload("res://kenney_cube-pets_1/Models/GLB format/animal-cat.glb")
const TABBY_SHADER: Shader = preload("res://founder/tabby_stripes.gdshader")
const WHISPER_FACE_SHADER: Shader = preload("res://founder/whisper_face.gdshader")
const MODEL_SCALE: Vector3 = Vector3(1.08, 1.08, 1.08)

@export_category("Movement")
@export var move_speed: float = 5.5
@export var acceleration: float = 22.0
@export var rotation_speed: float = 10.0
@export_category("Camera")
@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity: float = 0.003
@export_range(-80.0, -5.0, 1.0) var minimum_pitch_degrees: float = -55.0
@export_range(5.0, 80.0, 1.0) var maximum_pitch_degrees: float = 35.0

@onready var visual_root: Node3D = $VisualRoot
@onready var camera_rig: Node3D = $CameraRig
@onready var yaw_pivot: Node3D = $CameraRig/YawPivot
@onready var pitch_pivot: Node3D = $CameraRig/YawPivot/PitchPivot
@onready var camera: Camera3D = $CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D
@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var placement_controller: PicnicPlacementController = $PicnicPlacementController
@onready var building_placement_controller: BuildingPlacementController = $BuildingPlacementController

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _interaction_target: Node


func _ready() -> void:
	add_to_group("player")
	game_state.founder_selected.connect(_on_founder_selected)
	if game_state.has_founder():
		_on_founder_selected(game_state.selected_founder)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not game_state.has_founder():
		return
	if game_state.is_dialogue_open() or game_state.is_construction_site_open():
		return
	if placement_controller.is_placing():
		if event.is_action_pressed("release_mouse"):
			placement_controller.cancel_placement()
			get_viewport().set_input_as_handled()
		return
	if building_placement_controller.is_placing():
		if event.is_action_pressed("release_mouse"):
			building_placement_controller.cancel_placement()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and _interaction_target != null:
		_interaction_target.call("interact", self)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw_pivot.rotate_y(-motion.relative.x * mouse_sensitivity)
		pitch_pivot.rotation.x = clampf(
			pitch_pivot.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(minimum_pitch_degrees),
			deg_to_rad(maximum_pitch_degrees)
		)
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	camera_rig.global_position = global_position
	_update_interaction_target()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var input_vector := Vector2.ZERO
	if game_state.has_founder() and not game_state.is_dialogue_open():
		input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_forward := -camera.global_basis.z
	var camera_right := camera.global_basis.x
	camera_forward.y = 0.0
	camera_right.y = 0.0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	var desired_direction := (camera_right * input_vector.x + camera_forward * -input_vector.y).normalized()
	var desired_velocity := desired_direction * move_speed

	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)

	if not desired_direction.is_zero_approx():
		var target_yaw := atan2(-desired_direction.x, -desired_direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)

	move_and_slide()


func _update_interaction_target() -> void:
	if placement_controller.is_placing() or building_placement_controller.is_placing() or not game_state.has_founder() or game_state.is_dialogue_open() or game_state.is_construction_site_open():
		_set_interaction_target(null)
		return
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	var ray_origin := camera.project_ray_origin(viewport_center)
	var ray_end := ray_origin + camera.project_ray_normal(viewport_center) * 4.5
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 2, [get_rid()])
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var space_state := get_world_3d().direct_space_state
	var hit := space_state.intersect_ray(query)
	var target: Node = null
	if not hit.is_empty():
		var collider := hit["collider"] as Node
		if collider != null and collider.get_parent().has_method("interact"):
			target = collider.get_parent()
	if target == null:
		var nearby_shape := SphereShape3D.new()
		nearby_shape.radius = 6.0
		var nearby_query := PhysicsShapeQueryParameters3D.new()
		nearby_query.shape = nearby_shape
		nearby_query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.6)
		nearby_query.collision_mask = 2
		nearby_query.collide_with_areas = true
		nearby_query.collide_with_bodies = false
		var best_score: float = -INF
		for result: Dictionary in space_state.intersect_shape(nearby_query, 16):
			var nearby_collider := result["collider"] as Node
			if nearby_collider == null:
				continue
			var candidate := nearby_collider.get_parent()
			if not candidate.has_method("interact"):
				continue
			var priority: int = int(candidate.call("get_interaction_priority")) if candidate.has_method("get_interaction_priority") else 0
			var candidate_3d := candidate as Node3D
			var distance: float = global_position.distance_to(candidate_3d.global_position) if candidate_3d != null else 6.0
			var score := float(priority) * 100.0 - distance
			if score > best_score:
				best_score = score
				target = candidate
	_set_interaction_target(target)


func _set_interaction_target(target: Node) -> void:
	if target == _interaction_target:
		return
	_interaction_target = target
	var prompt := ""
	if _interaction_target != null and _interaction_target.has_method("get_interaction_prompt"):
		prompt = str(_interaction_target.call("get_interaction_prompt"))
	game_state.set_interaction_prompt(prompt)


func _on_founder_selected(founder: FounderData) -> void:
	_apply_founder_visual(founder)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_founder_visual(founder: FounderData) -> void:
	for child: Node in visual_root.get_children():
		child.queue_free()

	var model := CAT_SCENE.instantiate() as Node3D
	model.name = "FounderModel"
	model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	model.scale = MODEL_SCALE
	visual_root.add_child(model)
	_apply_founder_materials(model, founder)


func _apply_founder_materials(model: Node3D, founder: FounderData) -> void:
	var face_decoration := _find_mesh(model, &"Group")
	if face_decoration != null and founder.internal_id == &"whisper":
		var nose_material := StandardMaterial3D.new()
		nose_material.albedo_color = Color.BLACK
		nose_material.roughness = 0.9
		face_decoration.set_surface_override_material(0, nose_material)

	var body := _find_mesh(model, &"body")
	if body != null:
		var albedo_path := "res://founder/textures/cat_%s_albedo.png" % founder.internal_id
		if founder.internal_id == &"whisper":
			var whisper_material := ShaderMaterial.new()
			whisper_material.shader = WHISPER_FACE_SHADER
			whisper_material.set_shader_parameter("albedo_tex", load(albedo_path))
			body.set_surface_override_material(0, whisper_material)
		elif founder.internal_id == &"turbo":
			var striped_material := ShaderMaterial.new()
			striped_material.shader = TABBY_SHADER
			striped_material.set_shader_parameter("albedo_tex", load(albedo_path))
			striped_material.set_shader_parameter("fur_mask_tex", load("res://founder/textures/cat_turbo_furmask.png"))
			striped_material.set_shader_parameter("body_color", Color(1.0, 0.42, 0.08, 1.0))
			striped_material.set_shader_parameter("secondary_color", Color(0.25, 0.07, 0.025, 1.0))
			striped_material.set_shader_parameter("stripe_width", 0.15)
			body.set_surface_override_material(0, striped_material)
		else:
			var body_material := StandardMaterial3D.new()
			body_material.albedo_color = Color.WHITE
			body_material.albedo_texture = load(albedo_path)
			body_material.roughness = 0.85
			body.set_surface_override_material(0, body_material)

	var accent_material := StandardMaterial3D.new()
	accent_material.albedo_color = founder.tint
	accent_material.roughness = 0.85
	for part_name: StringName in [
		&"tail",
		&"leg-back-left",
		&"leg-back-right",
		&"leg-front-left",
		&"leg-front-right",
	]:
		var part := _find_mesh(model, part_name)
		if part != null:
			part.set_surface_override_material(0, accent_material)


func _find_mesh(root: Node, mesh_name: StringName) -> MeshInstance3D:
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		if child.name == mesh_name:
			return child as MeshInstance3D
	return null
