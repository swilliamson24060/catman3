class_name IrrigationMachine
extends Node3D

@onready var incomplete_visual: Node3D = $States/Incomplete
@onready var installed_visual: Node3D = $States/Installed
@onready var gear: MeshInstance3D = $States/Installed/Gear
@onready var water: GPUParticles3D = $States/Installed/Water
@onready var input_tray: MeshInstance3D = $States/Installed/InputTray
@onready var output_swatches: Node3D = $States/Installed/OutputSwatches
@onready var status_label: Label3D = $StatusLabel

func _ready() -> void:
	set_meta("development_placeholder", true)
	$InteractionAnchor.activated.connect(_on_interact)
	get_node("/root/CommunityMachineService").bind_machine_scene(self)

func _exit_tree() -> void:
	var service := get_node_or_null("/root/CommunityMachineService")
	if service != null: service.unbind_machine_scene(self)

func apply_machine_state(state_id: StringName, outputs: Array[String]) -> void:
	incomplete_visual.visible = state_id == &"incomplete"
	installed_visual.visible = state_id != &"incomplete"
	water.emitting = state_id in [&"operating", &"resonant"]
	status_label.text = _state_label(state_id)
	for index in range(output_swatches.get_child_count()):
		var swatch := output_swatches.get_child(index) as MeshInstance3D
		swatch.visible = index < mini(outputs.size(), output_swatches.get_child_count())
		if swatch.visible: _apply_craft_color(swatch, StringName(outputs[index]))

func play_input_stage() -> void:
	input_tray.scale = Vector3(1.35, 1.35, 1.35)
	await get_tree().create_timer(0.35).timeout
	input_tray.scale = Vector3.ONE

func play_work_stage() -> void:
	water.emitting = true
	for _step in range(12):
		gear.rotation.z += TAU / 12.0
		await get_tree().create_timer(0.055).timeout

func play_output_stage(craft: Dictionary) -> void:
	var index := mini(get_node("/root/CommunityMachineService").completed_crafts.size(), output_swatches.get_child_count()) - 1
	if index >= 0:
		var swatch := output_swatches.get_child(index) as MeshInstance3D
		swatch.visible = true
		_apply_color(swatch, str(craft.get("output_color", "ffffff")))
	await get_tree().create_timer(0.35).timeout

func _on_interact(_anchor_id: StringName) -> void:
	var service := get_node("/root/CommunityMachineService")
	if not service.request_player_operation(): service.machine_state_changed.emit(service.current_state, service.interaction_summary())

func _state_label(state_id: StringName) -> String:
	match state_id:
		&"incomplete": return "WORKSHOP MACHINE SLOT\nAssembly incomplete"
		&"installed_idle": return "IRRIGATION ASSEMBLY\nWater route restored"
		&"operating": return "FLOWERS → WATER + GEAR → DYED CLOTH"
		&"resonant": return "FIRST BLOOM DYES AVAILABLE\nInteract to dye cloth"
		&"maintenance": return "MAINTENANCE NEEDED\nPip is checking the gear"
		_: return String(state_id)

func _apply_craft_color(swatch: MeshInstance3D, craft_id: StringName) -> void:
	var family: Dictionary = get_node("/root/CommunityMachineService").craft_family
	for craft: Variant in family.get("crafts", []):
		if craft is Dictionary and str(craft.get("id", "")) == String(craft_id):
			_apply_color(swatch, str(craft.get("output_color", "ffffff")))
			return

func _apply_color(swatch: MeshInstance3D, hex: String) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	swatch.material_override = material
