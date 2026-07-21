class_name CompletedBuilding
extends StaticBody3D

@export var building_definition: BuildingDefinition

@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var simulation_clock: Phase2SimulationClock = get_node("/root/SimulationClock") as Phase2SimulationClock

var production_elapsed_seconds: float = 0.0


func _ready() -> void:
	add_to_group("completed_buildings")
	if is_producer():
		simulation_clock.simulation_advanced.connect(_on_simulation_advanced)


func is_producer() -> bool:
	return building_definition != null \
		and not building_definition.production_resource.is_empty() \
		and building_definition.production_amount > 0 \
		and building_definition.production_interval_seconds > 0.0


func get_production_progress_ratio() -> float:
	if not is_producer():
		return 0.0
	return clampf(production_elapsed_seconds / building_definition.production_interval_seconds, 0.0, 1.0)


func _on_simulation_advanced(simulation_delta: float) -> void:
	if not is_producer() or simulation_delta <= 0.0:
		return
	production_elapsed_seconds += simulation_delta
	while production_elapsed_seconds >= building_definition.production_interval_seconds:
		production_elapsed_seconds -= building_definition.production_interval_seconds
		if game_state.deposit_resource(
			building_definition.production_resource,
			building_definition.production_amount,
			self
		):
			game_state.request_feedback("%s produced %d %s." % [
				building_definition.display_name,
				building_definition.production_amount,
				str(building_definition.production_resource).capitalize(),
			])
