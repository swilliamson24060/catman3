class_name OcclusionFader
extends Node

@export var collision_mask: int = 4
@export_range(0.05, 1.0, 0.05) var faded_alpha: float = 0.28
@export var fade_speed: float = 8.0

var _faded: Dictionary = {}

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("reboot_player") as Node3D
	if camera == null or player == null:
		return
	var desired: Dictionary = {}
	var origin := camera.global_position
	var target := player.global_position + Vector3.UP * 0.65
	var exclusions: Array[RID] = []
	for _index in range(12):
		var query := PhysicsRayQueryParameters3D.create(origin, target, collision_mask, exclusions)
		var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var collider := hit.get("collider") as CollisionObject3D
		if collider == null:
			break
		desired[collider] = true
		exclusions.append(collider.get_rid())
	for body: CollisionObject3D in desired:
		_faded[body] = true
	for body: CollisionObject3D in _faded.keys():
		if not is_instance_valid(body):
			_faded.erase(body)
			continue
		var target_alpha := faded_alpha if desired.has(body) else 1.0
		var finished := _set_body_alpha(body, target_alpha, delta)
		if finished and target_alpha >= 1.0:
			_faded.erase(body)

func _set_body_alpha(body: CollisionObject3D, target_alpha: float, delta: float) -> bool:
	var finished := true
	for child: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var current := mesh.transparency
		mesh.transparency = move_toward(current, 1.0 - target_alpha, fade_speed * delta)
		finished = finished and is_equal_approx(mesh.transparency, 1.0 - target_alpha)
	return finished
