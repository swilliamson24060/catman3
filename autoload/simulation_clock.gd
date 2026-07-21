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


func _process(delta: float) -> void:
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
	_manually_paused = is_paused


func set_debug_time_multiplier(multiplier: float) -> void:
	debug_time_multiplier = clampf(multiplier, MINIMUM_TIME_MULTIPLIER, MAXIMUM_TIME_MULTIPLIER)
	time_multiplier_changed.emit(debug_time_multiplier)


func cycle_debug_time_multiplier() -> float:
	var choices: Array[float] = [1.0, 4.0, 10.0]
	var current_index := choices.find(debug_time_multiplier)
	var next_index := 0 if current_index < 0 else (current_index + 1) % choices.size()
	set_debug_time_multiplier(choices[next_index])
	return debug_time_multiplier


func _should_pause_for_ui() -> bool:
	var state := get_node_or_null("/root/GameState") as Phase1GameState
	return state != null and state.is_dialogue_open()
