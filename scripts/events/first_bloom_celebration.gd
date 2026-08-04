class_name FirstBloomCelebration
extends Node3D

@onready var contribution_props: Node3D = $ContributionProps
@onready var sunrise_bunting: Node3D = $PlayerChoices/SunriseBunting
@onready var firefly_lanterns: Node3D = $PlayerChoices/FireflyLanterns
@onready var gathering_lights: Node3D = $GatheringLights
@onready var status_label: Label3D = $StatusLabel
var _last_state: StringName = &"dormant"

func _ready() -> void:
	set_meta("development_placeholder", true)
	get_node("/root/CelebrationService").bind_scene(self)

func _exit_tree() -> void:
	var service := get_node_or_null("/root/CelebrationService")
	if service != null: service.unbind_scene(self)

func contribution_slot_position(index: int) -> Vector3:
	var slots := $ContributionSlots
	if slots.get_child_count() == 0: return global_position
	return (slots.get_child(clampi(index, 0, slots.get_child_count() - 1)) as Node3D).global_position

func reveal_contribution(contribution_id: StringName) -> void:
	var node := contribution_props.get_node_or_null(String(contribution_id).to_pascal_case()) as Node3D
	if node != null: node.visible = true

func apply_event_state(state_id: StringName, completed: Array[StringName], choice_id: StringName) -> void:
	for child: Node in contribution_props.get_children(): child.visible = StringName(child.name.to_snake_case()) in completed
	sunrise_bunting.visible = choice_id == &"sunrise_bunting"
	firefly_lanterns.visible = choice_id == &"firefly_lanterns"
	gathering_lights.visible = state_id in [&"gathering", &"closing", &"complete"]
	visible = state_id != &"dormant"
	status_label.text = _state_label(state_id)
	if state_id == &"gathering" and _last_state != &"gathering": _play_gathering_motif()
	_last_state = state_id

func _process(_delta: float) -> void:
	if not gathering_lights.visible: return
	var time := Time.get_ticks_msec() * 0.002
	for index in range(gathering_lights.get_child_count()):
		var light := gathering_lights.get_child(index) as Node3D
		light.position.y = 2.2 + sin(time + index * 0.9) * 0.18

func _state_label(state_id: StringName) -> String:
	match state_id:
		&"preparing": return "FIRST BLOOM GATHERING\nNeighbors are preparing together"
		&"awaiting_choice": return "ONE FINISHING TOUCH\nChoose without risking the celebration"
		&"gathering": return "THE FIRST BLOOM CELEBRATION"
		&"closing": return "A QUIET MOMENT AFTER THE GATHERING"
		&"complete": return "A GARDEN FOR ORDINARY DAYS\nGatherings can happen here again"
		_: return ""

func _play_gathering_motif() -> void:
	for note: Array in [[392.0,0.0],[494.0,0.12],[587.0,0.24],[784.0,0.38]]:
		_play_note_later(float(note[0]), float(note[1]))

func _play_note_later(frequency: float, delay: float) -> void:
	if delay > 0.0: await get_tree().create_timer(delay).timeout
	var player := AudioStreamPlayer3D.new()
	player.stream = _tone(frequency, 0.34)
	player.volume_db = -20.0
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
		bytes[index] = clampi(int(128.0 + sin(TAU * frequency * float(index) / rate) * 32.0 * envelope), 0, 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
