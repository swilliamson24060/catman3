class_name IsometricCameraRig
extends Node3D

signal angle_changed(angle_index: int)

const SNAP_DEGREES: float = 90.0

@export var follow_smoothing: float = 10.0
@export var pitch_degrees: float = -38.0
@export var distance: float = 22.0
@export var view_size: float = 19.0
@export var initial_angle_index: int = 0

var angle_index: int = 0
var target: Node3D

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D

func _ready() -> void:
	target = get_tree().get_first_node_in_group("reboot_player") as Node3D
	angle_index = posmod(initial_angle_index, 4)
	pitch_pivot.rotation_degrees.x = pitch_degrees
	camera.position.z = distance
	camera.size = view_size
	_apply_angle()
	if target != null:
		global_position = target.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_snap_left"):
		snap_left()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_snap_right"):
		snap_right()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if target == null:
		target = get_tree().get_first_node_in_group("reboot_player") as Node3D
	if target != null:
		global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_smoothing * delta))

func snap_left() -> void:
	set_angle_index(angle_index - 1)

func snap_right() -> void:
	set_angle_index(angle_index + 1)

func set_angle_index(value: int) -> void:
	angle_index = posmod(value, 4)
	_apply_angle()
	angle_changed.emit(angle_index)

func _apply_angle() -> void:
	yaw_pivot.rotation_degrees.y = float(angle_index) * SNAP_DEGREES + 45.0
