class_name RebootCalendarService
extends Node

signal simulation_advanced(simulation_delta: float)
signal need_cycle(cycle_index: int)
signal time_multiplier_changed(new_multiplier: float)
signal period_changed(day: int, period_id: StringName)
signal resident_schedule_changed(period_id: StringName)
signal day_started(day: int)
signal day_ended(summary: Dictionary)
signal rain_followed_by_sunrise(day: int)
signal pause_changed(paused: bool)

enum DayPeriod { MORNING, AFTERNOON, EVENING, NIGHT }

const PERIOD_IDS: Array[StringName] = [&"morning", &"afternoon", &"evening", &"night"]
const DEFAULT_PERIOD_DURATION_SECONDS := 90.0
const LEGACY_NEED_CYCLE_SECONDS := 90.0
const DEBUG_MULTIPLIERS: Array[float] = [1.0, 4.0, 10.0, 20.0]

@export var period_duration_seconds: float = DEFAULT_PERIOD_DURATION_SECONDS

var current_day: int = 1
var current_period: DayPeriod = DayPeriod.MORNING
var period_elapsed_seconds: float = 0.0
var debug_time_multiplier: float = 1.0
var _manual_pause: bool = false
var _modal_pause_count: int = 0
var _legacy_need_accumulator: float = 0.0
var _legacy_need_cycle_index: int = 0
var _summary_events: Dictionary = {
	"discoveries": [],
	"project_progress": [],
	"relationship_moments": [],
}

func _ready() -> void:
	if not _is_reboot_mode():
		_bind_legacy_clock()
		return
	call_deferred("_emit_initial_state")

func _process(delta: float) -> void:
	if not _is_reboot_mode() or is_paused():
		return
	var simulation_delta := delta * debug_time_multiplier
	if simulation_delta <= 0.0:
		return
	period_elapsed_seconds += simulation_delta
	_legacy_need_accumulator += simulation_delta
	simulation_advanced.emit(simulation_delta)
	while _legacy_need_accumulator >= LEGACY_NEED_CYCLE_SECONDS:
		_legacy_need_accumulator -= LEGACY_NEED_CYCLE_SECONDS
		_legacy_need_cycle_index += 1
		need_cycle.emit(_legacy_need_cycle_index)
	while period_elapsed_seconds >= period_duration_seconds:
		period_elapsed_seconds -= period_duration_seconds
		advance_period()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_reboot_mode():
		return
	if event.is_action_pressed("debug_next_period"):
		advance_period()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_rain_sunrise"):
		WeatherService.debug_force_transition(&"rain_to_sunrise", current_day)
		get_viewport().set_input_as_handled()

func advance_period() -> void:
	if current_period == DayPeriod.NIGHT:
		_end_current_day()
		return
	current_period = (int(current_period) + 1) as DayPeriod
	period_elapsed_seconds = 0.0
	_emit_period_state()

func end_day() -> Dictionary:
	return _end_current_day()

func _end_current_day() -> Dictionary:
	var finished_day := current_day
	var next_day := current_day + 1
	var previous_weather := WeatherService.complete_day_and_advance(next_day)
	var summary := _build_day_summary(finished_day)
	day_ended.emit(summary)
	current_day = next_day
	current_period = DayPeriod.MORNING
	period_elapsed_seconds = 0.0
	_clear_summary_events()
	day_started.emit(current_day)
	_emit_period_state()
	if WeatherService.notify_sunrise(current_day, previous_weather):
		rain_followed_by_sunrise.emit(current_day)
	return summary

func debug_jump_to_period(period_id: StringName) -> bool:
	var index := PERIOD_IDS.find(period_id)
	if index < 0:
		return false
	current_period = index as DayPeriod
	period_elapsed_seconds = 0.0
	_emit_period_state()
	return true

func set_simulation_paused(paused: bool) -> void:
	var was_paused := is_paused()
	_manual_pause = paused
	if was_paused != is_paused():
		pause_changed.emit(is_paused())

func push_modal_pause() -> void:
	var was_paused := is_paused()
	_modal_pause_count += 1
	if was_paused != is_paused():
		pause_changed.emit(is_paused())

func pop_modal_pause() -> void:
	var was_paused := is_paused()
	_modal_pause_count = maxi(_modal_pause_count - 1, 0)
	if was_paused != is_paused():
		pause_changed.emit(is_paused())

func is_paused() -> bool:
	return _manual_pause or _modal_pause_count > 0 or _legacy_dialogue_is_open()

func set_debug_time_multiplier(multiplier: float) -> void:
	debug_time_multiplier = clampf(multiplier, 0.0, 20.0)
	time_multiplier_changed.emit(debug_time_multiplier)

func cycle_debug_time_multiplier() -> float:
	var current_index := DEBUG_MULTIPLIERS.find(debug_time_multiplier)
	var next_index := 0 if current_index < 0 else (current_index + 1) % DEBUG_MULTIPLIERS.size()
	set_debug_time_multiplier(DEBUG_MULTIPLIERS[next_index])
	return debug_time_multiplier

func period_id() -> StringName:
	return PERIOD_IDS[int(current_period)]

func period_progress() -> float:
	return clampf(period_elapsed_seconds / maxf(period_duration_seconds, 0.001), 0.0, 1.0)

func record_discovery(display_name: String) -> void:
	_append_unique_summary("discoveries", display_name)

func record_project_progress(description: String) -> void:
	_append_unique_summary("project_progress", description)

func record_relationship_moment(description: String) -> void:
	_append_unique_summary("relationship_moments", description)

func serialize_state() -> Dictionary:
	return {
		"day": current_day,
		"period": String(period_id()),
		"period_elapsed_seconds": period_elapsed_seconds,
		"debug_time_multiplier": debug_time_multiplier,
		"summary_events": _summary_events.duplicate(true),
	}

func restore_state(data: Dictionary) -> void:
	current_day = maxi(int(data.get("day", 1)), 1)
	var restored_period := StringName(str(data.get("period", "morning")))
	var index := PERIOD_IDS.find(restored_period)
	current_period = index if index >= 0 else 0
	period_elapsed_seconds = clampf(float(data.get("period_elapsed_seconds", 0.0)), 0.0, period_duration_seconds)
	debug_time_multiplier = clampf(float(data.get("debug_time_multiplier", 1.0)), 0.0, 20.0)
	var restored_summary: Variant = data.get("summary_events", {})
	if restored_summary is Dictionary:
		for key: String in _summary_events:
			var values: Variant = restored_summary.get(key, [])
			_summary_events[key] = values.duplicate() if values is Array else []
	WeatherService.ensure_day(current_day)
	call_deferred("_emit_initial_state")

func _build_day_summary(finished_day: int) -> Dictionary:
	return {
		"day": finished_day,
		"discoveries": _summary_events.discoveries.duplicate(),
		"project_progress": _summary_events.project_progress.duplicate(),
		"relationship_moments": _summary_events.relationship_moments.duplicate(),
		"tomorrow_forecast": WeatherService.forecast_for_offset(0),
	}

func _append_unique_summary(key: String, description: String) -> void:
	if description.is_empty():
		return
	var entries: Array = _summary_events[key]
	if description not in entries:
		entries.append(description)

func _clear_summary_events() -> void:
	for key: String in _summary_events:
		_summary_events[key] = []

func _emit_initial_state() -> void:
	if not _is_reboot_mode():
		return
	WeatherService.ensure_day(current_day)
	day_started.emit(current_day)
	_emit_period_state()

func _emit_period_state() -> void:
	period_changed.emit(current_day, period_id())
	resident_schedule_changed.emit(period_id())
	EventBus.day_period_changed.emit(current_day, period_id())

func _bind_legacy_clock() -> void:
	var clock := get_node_or_null("/root/SimulationClock")
	if clock == null:
		return
	clock.simulation_advanced.connect(func(delta: float) -> void: simulation_advanced.emit(delta))
	clock.need_cycle.connect(func(index: int) -> void: need_cycle.emit(index))
	clock.time_multiplier_changed.connect(func(multiplier: float) -> void: time_multiplier_changed.emit(multiplier))

func _legacy_dialogue_is_open() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state != null and state.has_method("is_dialogue_open") and bool(state.call("is_dialogue_open"))

func _is_reboot_mode() -> bool:
	return bool(ProjectSettings.get_setting("feature/reboot_mode", true))
