class_name ResonancePlinth
extends Node3D

@export var plinth_index: int = 0
@onready var interaction_anchor: InteractionAnchor = $InteractionAnchor
@onready var component_visual: Node3D = $ComponentSlot/ComponentVisual
@onready var motes: GPUParticles3D = $FeedbackMotes

func _ready() -> void:
	set_meta("development_placeholder", true)
	interaction_anchor.anchor_id = StringName("resonance_plinth_%d" % plinth_index)
	interaction_anchor.activated.connect(func(_id: StringName) -> void: get_node("/root/SeasonalResonanceService").handle_plinth_interaction(plinth_index))
	get_node("/root/SeasonalResonanceService").component_changed.connect(_on_component_changed)
	refresh_component(get_node("/root/SeasonalResonanceService").plinth_components[plinth_index])

func _on_component_changed(index: int, component_id: StringName) -> void:
	if index == plinth_index: refresh_component(component_id)

func refresh_component(component_id: StringName) -> void:
	for child: Node in component_visual.get_children(): child.queue_free()
	interaction_anchor.prompt = "Place an interpreted component" if component_id.is_empty() else "Retrieve the installed component"
	if component_id.is_empty(): return
	var visual := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	match component_id:
		&"component_rain_lens":
			var lens := CylinderMesh.new(); lens.top_radius = 0.42; lens.bottom_radius = 0.42; lens.height = 0.12; visual.mesh = lens; material.albedo_color = Color(0.2, 0.75, 1.0, 0.85); material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		&"component_copper_gear":
			var gear := CylinderMesh.new(); gear.top_radius = 0.36; gear.bottom_radius = 0.36; gear.height = 0.22; visual.mesh = gear; visual.rotation_degrees.x = 90.0; material.albedo_color = Color(0.9, 0.38, 0.08)
		_:
			var seeds := PrismMesh.new(); seeds.size = Vector3(0.55, 0.28, 0.4); visual.mesh = seeds; material.albedo_color = Color(0.86, 0.72, 0.16)
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.3
	visual.material_override = material
	component_visual.add_child(visual)

func set_feedback(tier: int) -> void:
	motes.emitting = tier >= 1
	motes.amount = 4 if tier == 1 else 12
