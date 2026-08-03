class_name RebootFounderCat
extends CharacterBody3D

@export_category("Movement feel")
@export var maximum_speed: float = 5.25
@export var acceleration: float = 24.0
@export var deceleration: float = 32.0
@export var turn_speed: float = 12.0
@export var interaction_radius: float = 2.4

var input_enabled: bool = true
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _active_anchor: InteractionAnchor

@onready var prompt_label: Label = get_tree().get_first_node_in_group("reboot_interaction_prompt") as Label

func _ready() -> void:
	add_to_group("reboot_player")

func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed("interact") and _active_anchor != null:
		_active_anchor.interact(self)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_update_interaction_anchor()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_enabled else Vector2.ZERO
	var camera := get_viewport().get_camera_3d()
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if camera != null:
		forward = -camera.global_basis.z
		right = camera.global_basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
	var desired_direction := (right * input_vector.x + forward * -input_vector.y).normalized()
	var desired_velocity := desired_direction * maximum_speed
	var rate := acceleration if not desired_direction.is_zero_approx() else deceleration
	velocity.x = move_toward(velocity.x, desired_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, rate * delta)
	if not desired_direction.is_zero_approx():
		var target_yaw := atan2(-desired_direction.x, -desired_direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, turn_speed * delta))
	move_and_slide()

func _update_interaction_anchor() -> void:
	var nearest: InteractionAnchor
	var nearest_distance := interaction_radius
	for candidate: Node in get_tree().get_nodes_in_group("interaction_anchors"):
		var anchor := candidate as InteractionAnchor
		if anchor == null or not anchor.enabled:
			continue
		var distance := global_position.distance_to(anchor.global_position)
		if distance <= nearest_distance:
			nearest = anchor
			nearest_distance = distance
	if nearest == _active_anchor:
		return
	if _active_anchor != null:
		_active_anchor.set_focused(false)
	_active_anchor = nearest
	if _active_anchor != null:
		_active_anchor.set_focused(true)
	if prompt_label != null:
		prompt_label.text = "[E] %s" % _active_anchor.prompt if _active_anchor != null else ""
		prompt_label.visible = _active_anchor != null
		prompt_label.get_parent().visible = _active_anchor != null

func get_active_anchor() -> InteractionAnchor:
	return _active_anchor
