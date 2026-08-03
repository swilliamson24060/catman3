class_name VillageClearingBootstrap
extends Node3D

const LEGACY_SCENE_PATH := "res://scenes/world/main.tscn"
const INTERACTION_ANCHOR := preload("res://scenes/world/interaction_anchor.tscn")

const DESTINATIONS := {
	&"village_center": Vector3(0.0, 0.0, 0.0),
	&"home_edge": Vector3(-17.0, 0.0, -6.0),
	&"workshop_edge": Vector3(14.0, 0.0, -1.5),
	&"abandoned_garden": Vector3(-7.0, 0.0, 11.5),
	&"woodland_gate": Vector3(0.0, 0.0, -19.0),
	&"ruin_overlook": Vector3(0.0, 0.0, -47.0),
}

const ZONE_COLORS := {
	&"clearing": Color(0.29, 0.48, 0.25),
	&"village": Color(0.56, 0.49, 0.35),
	&"homes": Color(0.38, 0.57, 0.31),
	&"workshop": Color(0.57, 0.43, 0.25),
	&"garden": Color(0.38, 0.32, 0.2),
	&"path": Color(0.48, 0.4, 0.29),
}

func _ready() -> void:
	if not bool(ProjectSettings.get_setting("feature/reboot_mode", true)):
		push_warning("[Reboot] village_clearing.tscn was opened while reboot mode is disabled.")
	_build_clearing()
	_spawn_authored_anchors()
	print("[Reboot] Milestone 1 clearing booted. Legacy prototype remains at %s" % LEGACY_SCENE_PATH)

func get_authored_destinations() -> Dictionary:
	return DESTINATIONS.duplicate()

func _build_clearing() -> void:
	_create_ground("ClearingBase", Vector3(45.0, 0.25, 45.0), Vector3(0.0, -0.125, 0.0), ZONE_COLORS.clearing, true)
	_create_ground("VillageCenter", Vector3(13.0, 0.12, 11.0), Vector3(0.0, 0.03, 0.0), ZONE_COLORS.village)
	_create_ground("HomeEdge", Vector3(12.0, 0.1, 16.0), Vector3(-15.5, 0.025, -5.5), ZONE_COLORS.homes)
	_create_ground("WorkshopEdge", Vector3(11.0, 0.14, 13.0), Vector3(15.5, 0.045, -4.0), ZONE_COLORS.workshop)
	_create_ground("AbandonedGarden", Vector3(15.0, 0.08, 11.0), Vector3(-7.0, 0.015, 15.0), ZONE_COLORS.garden)
	_create_ground("WoodlandGatePath", Vector3(6.0, 0.06, 13.0), Vector3(0.0, 0.01, -17.0), ZONE_COLORS.path)

	_create_block("HomeMaraPlaceholder", Vector3(4.2, 3.2, 4.2), Vector3(-17.0, 1.6, -10.0), Color(0.78, 0.51, 0.45))
	_create_block("HomePipPlaceholder", Vector3(4.2, 3.7, 4.2), Vector3(-12.0, 1.85, -4.5), Color(0.45, 0.64, 0.78))
	_create_block("WorkshopPlaceholder", Vector3(6.0, 4.2, 5.0), Vector3(15.0, 2.1, -5.5), Color(0.88, 0.5, 0.2))

	for row in range(3):
		_create_block("GardenBed%d" % row, Vector3(4.8, 0.45, 1.25), Vector3(-9.0 + float(row) * 3.8, 0.23, 15.0), Color(0.3, 0.2, 0.12), false)
	_create_tree("OldGardenTree", Vector3(-7.0, 0.0, 19.0), 1.35)
	_create_tree("CenterTree", Vector3(4.5, 0.0, 4.5), 1.0)
	for tree_data: Array in [
		[Vector3(-21.0, 0.0, -18.0), 1.15], [Vector3(-18.0, 0.0, 19.5), 1.0],
		[Vector3(20.5, 0.0, 17.0), 1.2], [Vector3(20.0, 0.0, -17.0), 1.0],
		[Vector3(-7.0, 0.0, -20.5), 0.95], [Vector3(7.0, 0.0, -20.5), 1.05],
	]:
		_create_tree("BoundaryTree", tree_data[0], tree_data[1])
	_create_block("GatePostLeft", Vector3(0.7, 3.2, 0.7), Vector3(-3.2, 1.6, -21.0), Color(0.28, 0.16, 0.08))
	_create_block("GatePostRight", Vector3(0.7, 3.2, 0.7), Vector3(3.2, 1.6, -21.0), Color(0.28, 0.16, 0.08))

func _spawn_authored_anchors() -> void:
	var prompts := {
		&"village_center": "Look around the village center",
		&"home_edge": "Inspect the future homes",
		&"workshop_edge": "Inspect the workshop plot",
		&"abandoned_garden": "Inspect the abandoned garden",
		&"woodland_gate": "Listen at the woodland gate",
		&"ruin_overlook": "Study the ancient ruin",
	}
	for anchor_id: StringName in DESTINATIONS:
		var anchor := INTERACTION_ANCHOR.instantiate() as InteractionAnchor
		anchor.name = String(anchor_id).to_pascal_case() + "Anchor"
		anchor.anchor_id = anchor_id
		anchor.prompt = prompts[anchor_id]
		anchor.position = DESTINATIONS[anchor_id] + Vector3.UP * 0.05
		anchor.activated.connect(_on_anchor_activated)
		$AuthoredInteractionAnchors.add_child(anchor)

func _on_anchor_activated(anchor_id: StringName) -> void:
	if anchor_id == &"home_edge":
		get_node("/root/CalendarService").end_day()

func _create_ground(node_name: String, size: Vector3, position: Vector3, color: Color, collision: bool = false) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.set_meta("development_placeholder", true)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)
	if collision:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
	$TerrainZones.add_child(body)

func _create_block(node_name: String, size: Vector3, position: Vector3, color: Color, collision: bool = true) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 5 if collision else 0
	body.set_meta("development_placeholder", true)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)
	if collision:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
	$PlaceholderProps.add_child(body)

func _create_tree(node_name: String, position: Vector3, scale_factor: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 5
	body.set_meta("development_placeholder", true)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.28 * scale_factor
	trunk_mesh.bottom_radius = 0.42 * scale_factor
	trunk_mesh.height = 3.0 * scale_factor
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.5 * scale_factor
	trunk.material_override = _material(Color(0.3, 0.17, 0.08))
	body.add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.35 * scale_factor
	crown_mesh.height = 2.5 * scale_factor
	crown.mesh = crown_mesh
	crown.position.y = 3.4 * scale_factor
	crown.material_override = _material(Color(0.17, 0.43, 0.2))
	body.add_child(crown)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45 * scale_factor
	shape.height = 3.0 * scale_factor
	collision.shape = shape
	collision.position.y = 1.5 * scale_factor
	body.add_child(collision)
	$PlaceholderProps.add_child(body)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
