class_name MouseNeeds
extends Node

signal hunger_changed(new_value: float)
signal fatigue_changed(new_value: float)
signal meal_resolved(was_fed: bool)

const CHEESE_PER_NEED_CYCLE: int = 1
const MINIMUM_NEED: float = 0.0
const MAXIMUM_NEED: float = 1.0

@export_range(0.0, 1.0, 0.01) var hunger: float = 0.0
@export_range(0.0, 1.0, 0.01) var fatigue: float = 0.0
@export_range(0.0, 1.0, 0.01) var hunger_increase_per_cycle: float = 0.35
@export_range(0.0, 1.0, 0.01) var fed_hunger_reduction: float = 0.55
@export_range(0.0, 1.0, 0.01) var unfed_hunger_penalty: float = 0.25
@export_range(0.0, 1.0, 0.001) var passive_fatigue_recovery_per_second: float = 0.01
@export var fed_contentment_gain: int = 1
@export var unfed_contentment_loss: int = 2

@onready var mouse: Phase1WildMouse = get_parent() as Phase1WildMouse
@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var simulation_clock: Phase2SimulationClock = get_node("/root/SimulationClock") as Phase2SimulationClock


func _ready() -> void:
	simulation_clock.need_cycle.connect(_on_need_cycle)
	simulation_clock.simulation_advanced.connect(_on_simulation_advanced)


## Adds work fatigue while keeping the normalized value in range.
func add_fatigue(amount: float) -> float:
	fatigue = clampf(fatigue + maxf(amount, 0.0), MINIMUM_NEED, MAXIMUM_NEED)
	fatigue_changed.emit(fatigue)
	return fatigue


## Recovers fatigue without allowing it to become negative.
func recover_fatigue(amount: float) -> float:
	fatigue = clampf(fatigue - maxf(amount, 0.0), MINIMUM_NEED, MAXIMUM_NEED)
	fatigue_changed.emit(fatigue)
	return fatigue


func get_hunger_description() -> String:
	if hunger >= 0.85:
		return "Starving"
	if hunger >= 0.6:
		return "Hungry"
	if hunger >= 0.25:
		return "Peckish"
	return "Fed"


func get_fatigue_description() -> String:
	if fatigue >= 0.85:
		return "Exhausted"
	if fatigue >= 0.6:
		return "Tired"
	if fatigue >= 0.25:
		return "Weary"
	return "Rested"


func _on_need_cycle(_cycle_index: int) -> void:
	if mouse == null or not mouse.is_recruited:
		return
	_set_hunger(hunger + hunger_increase_per_cycle)
	if game_state.spend_cheese(CHEESE_PER_NEED_CYCLE):
		_set_hunger(hunger - fed_hunger_reduction)
		mouse.adjust_contentment(fed_contentment_gain)
		meal_resolved.emit(true)
	else:
		_set_hunger(hunger + unfed_hunger_penalty)
		mouse.adjust_contentment(-unfed_contentment_loss)
		game_state.request_feedback("%s went hungry because the settlement has no cheese." % mouse.get_display_name())
		meal_resolved.emit(false)


func _on_simulation_advanced(simulation_delta: float) -> void:
	if mouse == null or not mouse.is_recruited or fatigue <= MINIMUM_NEED:
		return
	recover_fatigue(passive_fatigue_recovery_per_second * simulation_delta)


func _set_hunger(value: float) -> void:
	hunger = clampf(value, MINIMUM_NEED, MAXIMUM_NEED)
	hunger_changed.emit(hunger)
