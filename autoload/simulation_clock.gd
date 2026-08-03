class_name Phase2SimulationClock
extends Node

signal simulation_advanced(simulation_delta: float)
signal need_cycle(cycle_index: int)
signal time_multiplier_changed(new_multiplier: float)

const NEED_CYCLE_SECONDS: float = 90.0
const MINIMUM_TIME_MULTIPLIER: float = 0.0
const MAXIMUM_TIME_MULTIPLIER: float = 20.0

@export_range(MINIMUM_TIME_MULTIPLIER, MAXIMUM_TIME_MULTIPLIER, 0.25) var debug_time_multiplier: float = 1.0

var simulation_time_seconds: float = 0.0
var _need_accumulator: float = 0.0
var _need_cycle_index: int = 0
var _manually_paused: bool = false
var _calendar_adapter_bound: bool = false


func _process(delta: float) -> void:
	if _is_reboot_mode():
		# The engine disables this adapter's processing in reboot mode, but an
		# explicit legacy `_process()` call still advances the authoritative clock.
		# This retains the old debug/test seam without double-ticking at runtime.
		var calendar := get_node_or_null("/root/CalendarService")
		if calendar != null:
			calendar._process(delta)
			if not _calendar_adapter_bound and not calendar.is_paused():
				var simulation_delta: float = delta * float(calendar.debug_time_multiplier)
				simulation_time_seconds += simulation_delta
				simulation_advanced.emit(simulation_delta)
		return
	if _manually_paused or _should_pause_for_ui():
		return
	var simulation_delta := delta * debug_time_multiplier
	if simulation_delta <= 0.0:
		return
	simulation_time_seconds += simulation_delta
	_need_accumulator += simulation_delta
	simulation_advanced.emit(simulation_delta)
	while _need_accumulator >= NEED_CYCLE_SECONDS:
		_need_accumulator -= NEED_CYCLE_SECONDS
		_need_cycle_index += 1
		need_cycle.emit(_need_cycle_index)


func set_simulation_paused(is_paused: bool) -> void:
	if _is_reboot_mode() and get_node_or_null("/root/CalendarService") != null:
		get_node("/root/CalendarService").set_simulation_paused(is_paused)
		return
	_manually_paused = is_paused


func set_debug_time_multiplier(multiplier: float) -> void:
	if _is_reboot_mode() and get_node_or_null("/root/CalendarService") != null:
		get_node("/root/CalendarService").set_debug_time_multiplier(multiplier)
		return
	debug_time_multiplier = clampf(multiplier, MINIMUM_TIME_MULTIPLIER, MAXIMUM_TIME_MULTIPLIER)
	time_multiplier_changed.emit(debug_time_multiplier)


func cycle_debug_time_multiplier() -> float:
	if _is_reboot_mode() and get_node_or_null("/root/CalendarService") != null:
		return float(get_node("/root/CalendarService").cycle_debug_time_multiplier())
	var choices: Array[float] = [1.0, 4.0, 10.0]
	var current_index := choices.find(debug_time_multiplier)
	var next_index := 0 if current_index < 0 else (current_index + 1) % choices.size()
	set_debug_time_multiplier(choices[next_index])
	return debug_time_multiplier


func _should_pause_for_ui() -> bool:
	var state := get_node_or_null("/root/GameState") as Phase1GameState
	return state != null and state.is_dialogue_open()

func _ready() -> void:
	if _is_reboot_mode():
		set_process(false)
		call_deferred("_bind_calendar_adapter")

func _bind_calendar_adapter() -> void:
	var calendar := get_node_or_null("/root/CalendarService")
	if calendar == null:
		push_warning("[SimulationClock] CalendarService unavailable for reboot compatibility.")
		return
	calendar.simulation_advanced.connect(func(delta: float) -> void:
		simulation_time_seconds += delta
		simulation_advanced.emit(delta)
	)
	calendar.need_cycle.connect(func(index: int) -> void:
		_need_cycle_index = index
		need_cycle.emit(index)
	)
	calendar.time_multiplier_changed.connect(func(multiplier: float) -> void:
		debug_time_multiplier = multiplier
		time_multiplier_changed.emit(multiplier)
	)
	_calendar_adapter_bound = true

func _is_reboot_mode() -> bool:
	return bool(ProjectSettings.get_setting("feature/reboot_mode", true))
