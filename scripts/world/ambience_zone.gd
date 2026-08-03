class_name AmbienceZone
extends Area3D

@export var zone_id: StringName
@export var radius: float = 8.0
@export var tone_hz: float = 110.0
@export_range(-60.0, 0.0, 1.0) var volume_db: float = -38.0

var _phase: float = 0.0
var _player: AudioStreamGeneratorPlayback
var _period_gain: float = 1.0

func _ready() -> void:
	add_to_group("ambience_zones")
	var shape := SphereShape3D.new()
	shape.radius = radius
	$CollisionShape3D.shape = shape
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.25
	$AudioStreamPlayer3D.stream = generator
	$AudioStreamPlayer3D.volume_db = volume_db
	$AudioStreamPlayer3D.max_distance = radius * 1.5
	$AudioStreamPlayer3D.play()
	_player = $AudioStreamPlayer3D.get_stream_playback() as AudioStreamGeneratorPlayback

func _process(_delta: float) -> void:
	if _player == null:
		return
	var frames := _player.get_frames_available()
	for _index in range(frames):
		_phase = fmod(_phase + tone_hz / 22050.0, 1.0)
		var sample := sin(_phase * TAU) * 0.018 * _period_gain
		_player.push_frame(Vector2(sample, sample))

func set_period_mix(period_id: StringName) -> void:
	match period_id:
		&"morning":
			_period_gain = 0.75
		&"afternoon":
			_period_gain = 1.0
		&"evening":
			_period_gain = 0.65
		&"night":
			_period_gain = 0.38
		_:
			_period_gain = 1.0

func period_gain() -> float:
	return _period_gain
