class_name ProjectMaterialSource
extends Node3D

@export var material_id: StringName
@export var display_name: String = "material"
@export var placeholder_color: Color = Color.WHITE

var _anchor: InteractionAnchor

func _ready() -> void:
	set_meta("development_placeholder", true)
	_build_placeholder()
	_anchor = preload("res://scenes/world/interaction_anchor.tscn").instantiate() as InteractionAnchor
	_anchor.anchor_id = StringName("source_%s" % material_id)
	_anchor.activated.connect(_on_interaction)
	add_child(_anchor)
	_refresh()
	get_node("/root/CommunityProjectService").carried_material_changed.connect(_on_carried_changed)

func _build_placeholder() -> void:
	var visual := MeshInstance3D.new()
	visual.name = "Presentation"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.75, 0.55, 0.75)
	visual.mesh = mesh
	visual.position.y = 0.28
	var material := StandardMaterial3D.new()
	material.albedo_color = placeholder_color
	material.roughness = 0.9
	visual.material_override = material
	add_child(visual)

func _on_interaction(_anchor_id: StringName) -> void:
	var service := get_node("/root/CommunityProjectService")
	if service.carried_material.is_empty(): service.gather_material(material_id)
	elif service.carried_material == material_id: service.return_carried_material()
	_refresh()

func _on_carried_changed(_material_id: StringName) -> void:
	_refresh()

func _refresh() -> void:
	if _anchor == null: return
	var service := get_node("/root/CommunityProjectService")
	var remaining := int(service.source_remaining.get(material_id, 0))
	_anchor.enabled = remaining > 0 or service.carried_material == material_id
	_anchor.prompt = "Return %s" % display_name if service.carried_material == material_id else "Gather %s (%d nearby)" % [display_name, remaining]
