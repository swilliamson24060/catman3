extends Node
## Autoload "AudioService" (Step 9 polish: audio hooks). A small pool of
## AudioStreamPlayers plays one-shot SFX by cue id, read from
## audio_cues.json -- exactly the same "data names an asset path, code
## checks ResourceLoader.exists before using it" idiom items.json already
## uses for icons. No actual .ogg files ship with the project yet, so cues
## use short generated tone fallbacks configured in data. Dropping a real
## asset at the path a cue names automatically replaces the fallback.

const POOL_SIZE := 6

var _players: Array[AudioStreamPlayer] = []
var _next_player_index := 0

func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

	EventBus.building_constructed.connect(func(_id, _pos): play_cue("building_constructed"))
	EventBus.animal_recruited.connect(func(_id, _species): play_cue("animal_recruited"))
	EventBus.achievement_unlocked.connect(func(_id): play_cue("achievement_unlocked"))
	EventBus.pattern_discovered.connect(func(_id): play_cue("pattern_discovered"))

## Plays the named cue through the next pooled player (round-robin, so
## several cues firing in the same frame don't cut each other off). Missing
## cue ids or missing asset files both degrade to a quiet log line rather
## than an error -- audio is polish, never a hard dependency.
func play_cue(cue_id: String) -> bool:
	var cue := DataRegistry.get_audio_cue(cue_id)
	if cue.is_empty():
		return false

	var stream_path: String = cue.get("stream_path", "")
	var stream: AudioStream = load(stream_path) if stream_path != "" and ResourceLoader.exists(stream_path) else _make_tone(cue)
	if stream == null:
		return false

	var player := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	player.stream = stream
	player.volume_db = float(cue.get("volume_db", -8.0))
	player.play()
	return true

func _make_tone(cue: Dictionary) -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := clampf(float(cue.get("fallback_duration", 0.12)), 0.03, 0.5)
	var frequency := clampf(float(cue.get("fallback_frequency", 440.0)), 80.0, 2400.0)
	var sample_count := maxi(int(duration * mix_rate), 1)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in sample_count:
		var progress := float(i) / sample_count
		var envelope := sin(PI * progress)
		var sample := int(sin(TAU * frequency * float(i) / mix_rate) * envelope * 10000.0)
		bytes.encode_s16(i * 2, sample)
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = mix_rate
	wave.stereo = false
	wave.data = bytes
	return wave

func get_pool_diagnostics() -> Dictionary:
	var configured := 0
	for player: AudioStreamPlayer in _players:
		if player.stream != null:
			configured += 1
	return {"pool_size": _players.size(), "configured_players": configured}
