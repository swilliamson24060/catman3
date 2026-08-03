extends Node

signal forecast_changed(forecast: Array[String])
signal weather_transition(transition_id: StringName, day: int)

enum Weather { CLEAR, RAIN }

const WEATHER_IDS: Array[String] = ["clear", "rain", "clear", "clear", "rain"]
const WIND_DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const FORECAST_DAYS := 3

@export var min_clear_seconds: float = 25.0
@export var max_clear_seconds: float = 45.0
@export var min_rain_seconds: float = 10.0
@export var max_rain_seconds: float = 18.0
@export var min_wind_seconds: float = 20.0
@export var max_wind_seconds: float = 40.0

var current_weather: int = Weather.CLEAR
var world_seed: int = 1337
var current_day: int = 1
var recent_weather: Array[String] = []

var _forecast: Array[String] = []
var _wind_direction: Vector2i = Vector2i.RIGHT
var _timer: float = 0.0
var _phase_duration: float = 30.0
var _wind_timer: float = 0.0
var _wind_phase_duration: float = 30.0
var _last_sunrise_transition_day: int = -1

func _ready() -> void:
	configure_seed(world_seed, current_day)

func _process(delta: float) -> void:
	if _is_reboot_mode():
		return
	_timer += delta
	if _timer >= _phase_duration:
		_timer = 0.0
		_toggle()
	_wind_timer += delta
	if _wind_timer >= _wind_phase_duration:
		_wind_timer = 0.0
		_pick_new_wind()

func configure_seed(seed_value: int, day: int = 1) -> void:
	world_seed = seed_value if seed_value != 0 else 1337
	current_day = maxi(day, 1)
	_rebuild_forecast()
	_apply_forecast_today()
	_pick_deterministic_wind(current_day)

func ensure_day(day: int) -> void:
	if current_day != day or _forecast.is_empty():
		current_day = maxi(day, 1)
		_rebuild_forecast()
		_apply_forecast_today()

func complete_day_and_advance(next_day: int) -> String:
	var finished_weather := weather_id()
	recent_weather.append(finished_weather)
	while recent_weather.size() > 7:
		recent_weather.pop_front()
	current_day = maxi(next_day, 1)
	_rebuild_forecast()
	_apply_forecast_today()
	_pick_deterministic_wind(current_day)
	return finished_weather

func notify_sunrise(day: int, previous_weather: String = "") -> bool:
	var prior: String = previous_weather if not previous_weather.is_empty() else (str(recent_weather.back()) if not recent_weather.is_empty() else "")
	if prior != "rain" or _last_sunrise_transition_day == day:
		return false
	_last_sunrise_transition_day = day
	weather_transition.emit(&"rain_to_sunrise", day)
	EventBus.weather_transition.emit(&"rain_to_sunrise", day)
	return true

func debug_force_transition(transition_id: StringName, day: int) -> bool:
	if transition_id != &"rain_to_sunrise":
		return false
	_last_sunrise_transition_day = -1
	if recent_weather.is_empty():
		recent_weather.append("rain")
	else:
		recent_weather[recent_weather.size() - 1] = "rain"
	return notify_sunrise(day, "rain")

func get_forecast() -> Array[String]:
	return _forecast.duplicate()

func forecast_for_offset(offset: int) -> String:
	return _forecast[clampi(offset, 0, _forecast.size() - 1)] if not _forecast.is_empty() else "clear"

func wind_direction() -> Vector2i:
	return _wind_direction

func force_wind(direction: Vector2i) -> void:
	_wind_direction = direction
	_wind_timer = 0.0
	EventBus.wind_changed.emit(_wind_direction)
	print("[WeatherService] Wind forced to %s" % [_wind_direction])

func is_raining() -> bool:
	return current_weather == Weather.RAIN

func weather_id() -> String:
	return "rain" if current_weather == Weather.RAIN else "clear"

func force_weather(id: String) -> void:
	_set_weather("rain" if id == "rain" else "clear")
	print("[WeatherService] Weather forced to '%s'" % weather_id())

func serialize_state() -> Dictionary:
	return {
		"world_seed": world_seed,
		"current_day": current_day,
		"current_weather": weather_id(),
		"forecast": _forecast.duplicate(),
		"recent_weather": recent_weather.duplicate(),
		"wind_x": _wind_direction.x,
		"wind_y": _wind_direction.y,
		"last_sunrise_transition_day": _last_sunrise_transition_day,
	}

func restore_state(data: Dictionary) -> void:
	world_seed = int(data.get("world_seed", 1337))
	current_day = maxi(int(data.get("current_day", 1)), 1)
	recent_weather.assign(_string_array(data.get("recent_weather", [])))
	_last_sunrise_transition_day = int(data.get("last_sunrise_transition_day", -1))
	_rebuild_forecast()
	var saved_forecast := _string_array(data.get("forecast", []))
	if saved_forecast.size() == FORECAST_DAYS:
		_forecast = saved_forecast
	_set_weather(str(data.get("current_weather", forecast_for_offset(0))))
	_wind_direction = Vector2i(int(data.get("wind_x", 1)), int(data.get("wind_y", 0)))
	forecast_changed.emit(get_forecast())

func _rebuild_forecast() -> void:
	_forecast.clear()
	for offset in range(FORECAST_DAYS):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%d" % [world_seed, current_day + offset])
		_forecast.append(WEATHER_IDS[rng.randi_range(0, WEATHER_IDS.size() - 1)])
	forecast_changed.emit(get_forecast())

func _apply_forecast_today() -> void:
	_set_weather(forecast_for_offset(0))

func _set_weather(id: String) -> void:
	current_weather = Weather.RAIN if id == "rain" else Weather.CLEAR
	EventBus.weather_changed.emit(weather_id())

func _toggle() -> void:
	_set_weather("clear" if is_raining() else "rain")
	_phase_duration = randf_range(min_rain_seconds, max_rain_seconds) if is_raining() else randf_range(min_clear_seconds, max_clear_seconds)

func _pick_new_wind() -> void:
	var choices := WIND_DIRECTIONS.filter(func(direction: Vector2i) -> bool: return direction != _wind_direction)
	_wind_direction = choices[randi() % choices.size()]
	_wind_phase_duration = randf_range(min_wind_seconds, max_wind_seconds)
	EventBus.wind_changed.emit(_wind_direction)

func _pick_deterministic_wind(day: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wind:%d:%d" % [world_seed, day])
	_wind_direction = WIND_DIRECTIONS[rng.randi_range(0, WIND_DIRECTIONS.size() - 1)]
	EventBus.wind_changed.emit(_wind_direction)

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			if entry is String:
				result.append(entry)
	return result

func _is_reboot_mode() -> bool:
	return bool(ProjectSettings.get_setting("feature/reboot_mode", true))
