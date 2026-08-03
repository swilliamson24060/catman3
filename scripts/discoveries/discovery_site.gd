class_name DiscoverySite
extends Node3D

@export var discovery_id: StringName
@export var rumor_id: StringName
@export var prompt: String = "Inspect an unusual find"
@export var placeholder_color: Color = Color(0.2, 0.85, 0.95)

var anchor: InteractionAnchor
var marker: MeshInstance3D

func _ready() -> void:
	set_meta("development_placeholder", true)
	marker = MeshInstance3D.new()
	marker.name = "DiscoveryPlaceholder"
	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.64
	marker.mesh = mesh
	marker.position.y = 0.36
	var material := StandardMaterial3D.new()
	material.albedo_color = placeholder_color
	material.emission_enabled = true
	material.emission = placeholder_color * 0.35
	marker.material_override = material
	add_child(marker)
	anchor = preload("res://scenes/world/interaction_anchor.tscn").instantiate() as InteractionAnchor
	anchor.anchor_id = StringName("find_%s" % discovery_id)
	anchor.prompt = prompt
	anchor.activated.connect(_on_activated)
	add_child(anchor)
	get_node("/root/DiscoveryService").discovery_changed.connect(_on_discovery_changed)
	get_node("/root/RumorService").rumor_help_changed.connect(_on_help_changed)
	_refresh()

func _on_activated(_anchor_id: StringName) -> void:
	var service := get_node("/root/DiscoveryService")
	if service.find(discovery_id):
		get_node("/root/RumorService").acquire(rumor_id)
	else:
		get_node("/root/RumorService").observe_or_revisit(rumor_id)

func _on_discovery_changed(changed_id: StringName, _state: StringName) -> void:
	if changed_id == discovery_id: _refresh()

func _on_help_changed(changed_id: StringName, _enabled: bool) -> void:
	if changed_id == rumor_id: _refresh()

func _refresh() -> void:
	if marker == null or anchor == null: return
	var found: bool = get_node("/root/DiscoveryService").state(discovery_id) in [&"found", &"unidentified", &"investigation_available", &"investigated", &"interpreted"]
	marker.visible = not found
	anchor.prompt = "Revisit the place %s was found" % get_node("/root/DiscoveryService").unidentified_name(discovery_id) if found else prompt
	# Help markers are deliberately absent until requested/revisited.
	var help_enabled := false
	for rumor: Dictionary in get_node("/root/RumorService").known_rumors():
		if StringName(str(rumor.id)) == rumor_id: help_enabled = bool(rumor.marker_enabled)
	anchor.icon.visible = help_enabled or not found
