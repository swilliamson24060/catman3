extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const SAVE_PATH := "/tmp/catmando_milestone2_save.json"

var _sunrise_events: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	ProjectSettings.set_setting("feature/reboot_mode", true)
	var calendar := root.get_node("CalendarService")
	var weather := root.get_node("WeatherService")
	var save_service := root.get_node("SaveService")
	var completed_buildings := Node3D.new()
	completed_buildings.add_to_group("completed_building_container")
	root.add_child(completed_buildings)

	# A save seed and day always yield the same rolling three-day forecast.
	weather.configure_seed(24681357, 4)
	var expected_forecast: Array[String] = weather.get_forecast()
	assert(expected_forecast.size() == 3)
	weather.configure_seed(24681357, 4)
	assert(weather.get_forecast() == expected_forecast)

	# Every period is directly reachable for debug and presentation validation.
	for expected_period: StringName in calendar.PERIOD_IDS:
		assert(calendar.debug_jump_to_period(expected_period))
		assert(calendar.period_id() == expected_period)
	assert(not calendar.debug_jump_to_period(&"invalid"))

	# Modal pauses freeze calendar time without advancing the weather day.
	calendar.restore_state({"day": 4, "period": "afternoon", "period_elapsed_seconds": 12.0})
	weather.ensure_day(4)
	var paused_forecast: Array[String] = weather.get_forecast()
	calendar.push_modal_pause()
	calendar._process(15.0)
	assert(is_equal_approx(calendar.period_elapsed_seconds, 12.0))
	assert(weather.current_day == 4 and weather.get_forecast() == paused_forecast)
	calendar.pop_modal_pause()
	calendar._process(1.0)
	assert(calendar.period_elapsed_seconds > 12.0)

	# Calendar and forecast round-trip through the real save boundary.
	save_service.new_game("milestone2_founder")
	save_service.current.world_seed = 24681357
	weather.configure_seed(24681357, 7)
	calendar.restore_state({"day": 7, "period": "evening", "period_elapsed_seconds": 23.5})
	await process_frame
	var saved_forecast: Array[String] = weather.get_forecast()
	var saved_elapsed: float = calendar.period_elapsed_seconds
	assert(save_service.save_game(SAVE_PATH))
	calendar.restore_state({"day": 1, "period": "morning"})
	weather.configure_seed(999, 1)
	assert(save_service.load_game(SAVE_PATH))
	assert(calendar.current_day == 7)
	assert(calendar.period_id() == &"evening")
	assert(is_equal_approx(calendar.period_elapsed_seconds, saved_elapsed))
	assert(weather.world_seed == 24681357)
	assert(weather.get_forecast() == saved_forecast)

	# A rainy completed day activates the sunrise seam once, even if notified twice.
	weather.weather_transition.connect(_on_weather_transition)
	weather.force_weather("rain")
	calendar.restore_state({"day": 7, "period": "night"})
	await process_frame
	calendar.advance_period()
	assert(_sunrise_events == 1)
	assert(not weather.notify_sunrise(8, "rain"))
	assert(_sunrise_events == 1)

	# Summaries retain all important categories and tomorrow's forecast.
	calendar.record_discovery("Moonlit ruin marks")
	calendar.record_project_progress("Garden survey completed")
	calendar.record_relationship_moment("Shared tea at home")
	var summary: Dictionary = calendar.end_day()
	assert("Moonlit ruin marks" in summary.discoveries)
	assert("Garden survey completed" in summary.project_progress)
	assert("Shared tea at home" in summary.relationship_moments)
	assert(summary.tomorrow_forecast in ["clear", "rain"])

	# The reboot scene exposes the complete placeholder presentation contract.
	var scene := CLEARING.instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.has_node("DayEnvironmentController"))
	assert(scene.has_node("WeatherPresentation/Rain"))
	assert(scene.has_node("WeatherPresentation/SunDisc"))
	assert(scene.has_node("WeatherPresentation/MoonDisc"))
	assert(scene.has_node("Interface/CalendarHUD/Margin/VBox/Period"))
	assert(scene.has_node("DaySummary"))
	assert(scene.get_node("Ambience").get_child_count() == 3)

	scene.queue_free()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".bak")
	completed_buildings.queue_free()
	await process_frame
	print("MILESTONE_2_CALENDAR_WEATHER_SMOKE_TEST_PASS")
	quit(0)

func _on_weather_transition(transition_id: StringName, _day: int) -> void:
	if transition_id == &"rain_to_sunrise":
		_sunrise_events += 1
