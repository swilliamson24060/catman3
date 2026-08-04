class_name FirstBloomResonanceSite
extends Node3D

@onready var plinths: Array[Node] = [$Plinths/WaterPlinth, $Plinths/MotionPlinth, $Plinths/LifePlinth]
@onready var feedback_lines: Node3D = $FeedbackLines
@onready var center_pulse: MeshInstance3D = $CenterPulse
@onready var status_label: Label3D = $StatusLabel
@onready var bloom_flowers: Node3D = $FirstBloomFlowers

func _ready() -> void:
	set_meta("development_placeholder", true)
	_build_lines()
	get_node("/root/SeasonalResonanceService").feedback_changed.connect(_on_feedback_changed)
	get_node("/root/SeasonalResonanceService").bind_site(self)

func _exit_tree() -> void:
	var service := get_node_or_null("/root/SeasonalResonanceService")
	if service != null: service.unbind_site(self)

func candidate_data(components: Array[StringName]) -> Dictionary:
	var positions: Array[Vector3] = []
	for plinth: Node3D in plinths: positions.append(plinth.global_position)
	return {"positions":positions, "components":components.duplicate(), "center":global_position, "landmark_ready":get_node("/root/CommunityProjectService").completed}

func apply_state(components: Array[StringName], result: Dictionary, activated: bool, palette_unlocked: bool) -> void:
	for index in range(mini(plinths.size(), components.size())): plinths[index].refresh_component(components[index])
	_apply_feedback(int(result.get("tier", 0)))
	bloom_flowers.visible = palette_unlocked
	if activated: status_label.text = "THE FIRST BLOOM"

func play_activation_sequence() -> void:
	center_pulse.visible = true
	center_pulse.scale = Vector3.ONE * (1.25 if bool(get_node("/root/UserExperienceService").get_preference(&"reduced_flash", false)) else 1.8)
	_play_tones(4)

func _on_feedback_changed(result: Dictionary) -> void:
	_apply_feedback(int(result.get("tier", 0)))
	_play_tones(int(result.get("tier", 0)))

func _apply_feedback(tier: int) -> void:
	var cue: Dictionary = get_node("/root/UserExperienceService").tier_accessible_cue(tier)
	status_label.text = "%s %s — %s" % [cue.symbol, str(cue.name).to_upper(), str(cue.motion).to_upper()]
	for plinth: Node in plinths: plinth.set_feedback(tier)
	feedback_lines.visible = tier >= 2
	center_pulse.visible = tier >= 3
	var color: Color = [Color(0.4,0.43,0.42), Color(0.3,0.75,0.9), Color(0.55,0.45,0.95), Color(0.95,0.75,0.25), Color(1.0,0.45,0.75)][clampi(tier,0,4)]
	var material := center_pulse.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = color
		material.emission = color
	for line: MeshInstance3D in feedback_lines.get_children():
		(line.material_override as StandardMaterial3D).albedo_color = color

func _build_lines() -> void:
	for pair: Array in [[0,1],[1,2],[2,0]]:
		var line := MeshInstance3D.new()
		var start: Vector3 = (plinths[pair[0]] as Node3D).position + Vector3.UP * 0.14
		var finish: Vector3 = (plinths[pair[1]] as Node3D).position + Vector3.UP * 0.14
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.06, 0.04, start.distance_to(finish))
		line.mesh = mesh
		line.position = (start + finish) * 0.5
		line.look_at_from_position(line.position, finish, Vector3.UP)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.55, 0.45, 0.95)
		line.material_override = material
		feedback_lines.add_child(line)
	feedback_lines.visible = false

func _play_tones(tier: int) -> void:
	if tier <= 0: return
	var frequencies := [330.0, 440.0, 554.0]
	for index in range(mini(tier, 3)):
		var player := AudioStreamPlayer3D.new()
		player.stream = _tone(frequencies[index], 0.12)
		player.volume_db = -18.0
		add_child(player)
		player.finished.connect(player.queue_free)
		player.play()

func _tone(frequency: float, duration: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count)
	for index in count:
		var envelope := 1.0 - float(index) / float(count)
		bytes[index] = clampi(int(128.0 + sin(TAU * frequency * float(index) / rate) * 42.0 * envelope), 0, 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
