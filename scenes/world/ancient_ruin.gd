class_name AncientRuinGreybox
extends Node3D

func _ready() -> void:
	for data: Array in [
		[Vector3(-3.4, 1.7, 0.8), Vector3(1.1, 3.4, 0.9), -12.0],
		[Vector3(3.4, 1.9, 0.8), Vector3(1.0, 3.8, 0.9), 11.0],
		[Vector3(0.0, 2.1, -3.3), Vector3(1.15, 4.2, 0.95), 3.0],
	]:
		_create_stone(data[0], data[1], data[2])
	_create_stone(Vector3(0.0, 3.5, 0.8), Vector3(7.2, 0.85, 0.9), 0.0)
	var clue: Node3D = preload("res://scenes/discoveries/discovery_site.tscn").instantiate() as Node3D
	clue.name = "TriangleClueSite"
	clue.discovery_id = &"clue_ruin_triangle"
	clue.rumor_id = &"rumor_triangle"
	clue.prompt = "Study the low three-point carving"
	clue.placeholder_color = Color(0.72, 0.38, 0.9)
	clue.position = Vector3(0.0, 0.25, -4.3)
	add_child(clue)

func _create_stone(position: Vector3, size: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = "RuinStone"
	body.position = position
	body.rotation_degrees.y = yaw
	body.collision_layer = 5
	body.set_meta("development_placeholder", true)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.45, 0.43)
	material.roughness = 1.0
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
