extends Node
## Autoload "WeatherService". A global weather timer (Step 6, mechanic 3:
## Cardboard Tier & Rain Events) that alternates CLEAR/RAIN on a randomized
## schedule and emits EventBus.weather_changed -- the signal was already
## declared in event_bus.gd from day one but nothing fired it until now.
## BuildingManager listens for is_raining() to damage non-waterproof
## buildings; anything else (a future Catnip Drift wind system, a rain
## particle effect) can react to the same signal without this service
## knowing or caring who's listening.

enum Weather { CLEAR, RAIN }

@export var min_clear_seconds: float = 25.0
@export var max_clear_seconds: float = 45.0
@export var min_rain_seconds: float = 10.0
@export var max_rain_seconds: float = 18.0

var current_weather: int = Weather.CLEAR

var _timer: float = 0.0
var _phase_duration: float = 0.0

## Catnip Drift Dynamics (Step 6, mechanic 5): a prevailing wind direction,
## independent of the rain/clear cycle above. CatnipDriftService reads this
## each time it needs to compute downwind scent -- nothing here knows what
## catnip is, it just tracks "which way the wind is blowing right now."
const WIND_DIRECTIONS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
@export var min_wind_seconds: float = 20.0
@export var max_wind_seconds: float = 40.0

var _wind_direction: Vector2i = Vector2i(1, 0)
var _wind_timer: float = 0.0
var _wind_phase_duration: float = 0.0

func _ready() -> void:
	randomize()
	_phase_duration = randf_range(min_clear_seconds, max_clear_seconds)
	_wind_direction = WIND_DIRECTIONS[randi() % WIND_DIRECTIONS.size()]
	_wind_phase_duration = randf_range(min_wind_seconds, max_wind_seconds)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _phase_duration:
		_timer = 0.0
		_toggle()

	_wind_timer += delta
	if _wind_timer >= _wind_phase_duration:
		_wind_timer = 0.0
		_wind_phase_duration = randf_range(min_wind_seconds, max_wind_seconds)
		_pick_new_wind()

func _pick_new_wind() -> void:
	var choices: Array = WIND_DIRECTIONS.filter(func(d): return d != _wind_direction)
	_wind_direction = choices[randi() % choices.size()]
	EventBus.wind_changed.emit(_wind_direction)
	print("[WeatherService] Wind shifted to %s" % [_wind_direction])

func wind_direction() -> Vector2i:
	return _wind_direction

## Testing/debug hook -- forces the wind to a specific cardinal direction
## without waiting out the random timer.
func force_wind(direction: Vector2i) -> void:
	_wind_direction = direction
	_wind_timer = 0.0
	EventBus.wind_changed.emit(_wind_direction)
	print("[WeatherService] Wind forced to %s" % [_wind_direction])

func _toggle() -> void:
	if current_weather == Weather.CLEAR:
		current_weather = Weather.RAIN
		_phase_duration = randf_range(min_rain_seconds, max_rain_seconds)
	else:
		current_weather = Weather.CLEAR
		_phase_duration = randf_range(min_clear_seconds, max_clear_seconds)
	EventBus.weather_changed.emit(weather_id())
	print("[WeatherService] Weather changed to '%s' (lasting ~%.0fs)" % [weather_id(), _phase_duration])

func is_raining() -> bool:
	return current_weather == Weather.RAIN

func weather_id() -> String:
	return "rain" if current_weather == Weather.RAIN else "clear"

## Testing/debug hook -- forces an immediate weather change without waiting
## out the random timer.
func force_weather(id: String) -> void:
	current_weather = Weather.RAIN if id == "rain" else Weather.CLEAR
	_timer = 0.0
	_phase_duration = randf_range(min_rain_seconds, max_rain_seconds) if is_raining() else randf_range(min_clear_seconds, max_clear_seconds)
	EventBus.weather_changed.emit(weather_id())
	print("[WeatherService] Weather forced to '%s'" % weather_id())
