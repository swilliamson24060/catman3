extends Node
## Autoload "AudioService" (Step 9 polish: audio hooks). A small pool of
## AudioStreamPlayers plays one-shot SFX by cue id, read from
## audio_cues.json -- exactly the same "data names an asset path, code
## checks ResourceLoader.exists before using it" idiom items.json already
## uses for icons. No actual .ogg files ship with the project yet, so every
## cue currently no-ops with a log line instead of playing anything; drop a
## real asset at the path a cue names and it starts playing with zero code
## changes here.

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
func play_cue(cue_id: String) -> void:
	var cue := DataRegistry.get_audio_cue(cue_id)
	if cue.is_empty():
		return

	var stream_path: String = cue.get("stream_path", "")
	if stream_path == "" or not ResourceLoader.exists(stream_path):
		print("[AudioService] Cue '%s' has no audio asset yet (%s) -- skipping playback." % [cue_id, stream_path])
		return

	var stream: AudioStream = load(stream_path)
	if stream == null:
		return

	var player := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	player.stream = stream
	player.play()
