class_name WoodlandRouteGreybox
extends Node3D

func _ready() -> void:
	_create_path("MainRoute", Vector3(5.5, 0.2, 28.0), Vector3(0.0, -0.1, -14.0))
	_create_path("WestBranch", Vector3(12.0, 0.2, 4.5), Vector3(-6.0, -0.1, -12.0))
	_create_path("EastBranch", Vector3(13.0, 0.2, 4.5), Vector3(6.5, -0.1, -19.0))
	_create_path("RuinBranch", Vector3(7.0, 0.2, 8.0), Vector3(0.0, 0.0, -30.0))
	for data: Array in [
		[Vector3(-4.0, 0.0, -4.0), 1.0], [Vector3(4.0, 0.0, -7.0), 1.1],
		[Vector3(-4.5, 0.0, -16.0), 1.2], [Vector3(4.5, 0.0, -14.0), 0.9],
		[Vector3(-4.0, 0.0, -25.0), 1.0], [Vector3(4.0, 0.0, -26.0), 1.15],
		[Vector3(-11.0, 0.0, -12.0), 0.85], [Vector3(12.0, 0.0, -19.0), 0.9],
	]:
		_create_tree(data[0], data[1])

func _create_path(node_name: String, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.set_meta("development_placeholder", true)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(Color(0.42, 0.34, 0.23))
	body.add_child(mesh_instance)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)

func _create_tree(position: Vector3, scale_factor: float) -> void:
	var body := StaticBody3D.new()
	body.name = "RouteTree"
	body.position = position
	body.collision_layer = 5
	body.set_meta("development_placeholder", true)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.25 * scale_factor
	trunk_mesh.bottom_radius = 0.38 * scale_factor
	trunk_mesh.height = 3.4 * scale_factor
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.7 * scale_factor
	trunk.material_override = _material(Color(0.27, 0.15, 0.07))
	body.add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.25 * scale_factor
	crown_mesh.height = 2.5 * scale_factor
	crown.mesh = crown_mesh
	crown.position.y = 3.7 * scale_factor
	crown.material_override = _material(Color(0.12, 0.33, 0.16))
	body.add_child(crown)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.42 * scale_factor
	shape.height = 3.4 * scale_factor
	collision.shape = shape
	collision.position.y = 1.7 * scale_factor
	body.add_child(collision)
	add_child(body)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
