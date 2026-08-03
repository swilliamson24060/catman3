extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const CAPTURES := {
	&"morning": "/tmp/catmando_milestone2_morning.png",
	&"evening": "/tmp/catmando_milestone2_evening.png",
	&"night": "/tmp/catmando_milestone2_night.png",
	&"rain": "/tmp/catmando_milestone2_rain.png",
}

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var calendar := root.get_node("CalendarService")
	var weather := root.get_node("WeatherService")
	var scene := CLEARING.instantiate()
	root.add_child(scene)
	for _frame in range(45):
		await process_frame

	for period_id: StringName in [&"morning", &"evening", &"night"]:
		calendar.debug_jump_to_period(period_id)
		weather.force_weather("clear")
		await process_frame
		await process_frame
		assert(root.get_texture().get_image().save_png(CAPTURES[period_id]) == OK)

	calendar.debug_jump_to_period(&"morning")
	weather.force_weather("rain")
	for _frame in range(20):
		await process_frame
	assert(root.get_texture().get_image().save_png(CAPTURES[&"rain"]) == OK)
	print("MILESTONE_2_VISUAL_CAPTURE_PASS")
	scene.queue_free()
	quit(0)
