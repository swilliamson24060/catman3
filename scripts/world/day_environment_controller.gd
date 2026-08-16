class_name DayEnvironmentController
extends Node

const PERIOD_PRESENTATION := {
	&"morning": {"sky": Color(0.72, 0.86, 0.92), "ambient": Color(0.9, 0.86, 0.7), "ambient_energy": 0.9, "energy": 1.12, "light": Color(1.0, 0.84, 0.61)},
	&"afternoon": {"sky": Color(0.58, 0.8, 0.94), "ambient": Color(0.82, 0.9, 0.78), "ambient_energy": 0.84, "energy": 1.32, "light": Color(1.0, 0.96, 0.78)},
	&"evening": {"sky": Color(0.55, 0.34, 0.48), "ambient": Color(0.7, 0.45, 0.46), "ambient_energy": 0.72, "energy": 0.78, "light": Color(1.0, 0.57, 0.34)},
	&"night": {"sky": Color(0.055, 0.075, 0.16), "ambient": Color(0.18, 0.24, 0.42), "ambient_energy": 0.52, "energy": 0.28, "light": Color(0.48, 0.58, 0.86)},
}

@onready var world_environment: WorldEnvironment = get_parent().get_node("WorldEnvironment")
@onready var sunlight: DirectionalLight3D = get_parent().get_node("DirectionalLight3D")
@onready var rain: GPUParticles3D = get_parent().get_node("WeatherPresentation/Rain")
@onready var sun_disc: MeshInstance3D = get_parent().get_node("WeatherPresentation/SunDisc")
@onready var moon_disc: MeshInstance3D = get_parent().get_node("WeatherPresentation/MoonDisc")
@onready var period_label: Label = get_parent().get_node("Interface/CalendarHUD/Margin/VBox/Period")
@onready var weather_label: Label = get_parent().get_node("Interface/CalendarHUD/Margin/VBox/Weather")
@onready var forecast_label: Label = get_parent().get_node("Interface/CalendarHUD/Margin/VBox/Forecast")

func _ready() -> void:
	var calendar := get_node("/root/CalendarService")
	var weather := get_node("/root/WeatherService")
	calendar.period_changed.connect(_on_period_changed)
	weather.forecast_changed.connect(_on_forecast_changed)
	get_node("/root/EventBus").weather_changed.connect(_on_weather_changed)
	call_deferred("_apply_initial_state")

func _apply_initial_state() -> void:
	var calendar := get_node("/root/CalendarService")
	var weather := get_node("/root/WeatherService")
	_on_period_changed(calendar.current_day, calendar.period_id())
	_on_weather_changed(weather.weather_id())
	_on_forecast_changed(weather.get_forecast())

func _on_period_changed(day: int, period_id: StringName) -> void:
	var state: Dictionary = PERIOD_PRESENTATION.get(period_id, PERIOD_PRESENTATION[&"morning"])
	var environment := world_environment.environment
	environment.background_color = state.sky
	environment.ambient_light_color = state.ambient
	environment.ambient_light_energy = float(state.ambient_energy)
	sunlight.light_color = state.light
	sunlight.light_energy = float(state.energy) * (0.72 if get_node("/root/WeatherService").is_raining() else 1.0)
	period_label.text = "Day %d — %s" % [day, String(period_id).capitalize()]
	sun_disc.visible = period_id != &"night"
	moon_disc.visible = period_id == &"night"
	for node: Node in get_tree().get_nodes_in_group("ambience_zones"):
		if node.has_method("set_period_mix"):
			node.call("set_period_mix", period_id)

func _on_weather_changed(weather_id: String) -> void:
	rain.emitting = weather_id == "rain"
	weather_label.text = "Weather: %s" % weather_id.capitalize()
	var state: Dictionary = PERIOD_PRESENTATION.get(get_node("/root/CalendarService").period_id(), PERIOD_PRESENTATION[&"morning"])
	sunlight.light_energy = float(state.energy) * (0.72 if weather_id == "rain" else 1.0)

func _on_forecast_changed(forecast: Array[String]) -> void:
	var display: Array[String] = []
	for id: String in forecast:
		display.append(id.capitalize())
	forecast_label.text = "Forecast: %s" % " → ".join(display)
