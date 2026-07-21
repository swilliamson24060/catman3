class_name CompletedBuilding
extends StaticBody3D

signal production_status_changed(status: String)

@export var building_definition: BuildingDefinition

@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var simulation_clock: Phase2SimulationClock = get_node("/root/SimulationClock") as Phase2SimulationClock

var production_elapsed_seconds: float = 0.0
var _production_status: String = "Inactive"


func _ready() -> void:
	add_to_group("completed_buildings")
	if is_producer():
		simulation_clock.simulation_advanced.connect(_on_simulation_advanced)
		_set_production_status("Producing")


func is_producer() -> bool:
	return building_definition != null \
		and not building_definition.production_resource.is_empty() \
		and building_definition.production_amount > 0 \
		and building_definition.production_interval_seconds > 0.0


func get_production_progress_ratio() -> float:
	if not is_producer():
		return 0.0
	return clampf(production_elapsed_seconds / building_definition.production_interval_seconds, 0.0, 1.0)


func get_production_status() -> String:
	return _production_status


func get_pause_reason() -> String:
	if not is_producer():
		return "This building does not produce resources."
	var missing: Array[String] = []
	for raw_id: Variant in building_definition.production_inputs:
		var resource_id := StringName(str(raw_id))
		var required := int(building_definition.production_inputs[raw_id])
		var available := game_state.get_resource_amount(resource_id)
		if available < required:
			missing.append("%s %d/%d" % [str(resource_id).capitalize(), available, required])
	return "Missing " + ", ".join(missing) if not missing.is_empty() else ""


func interact(_interactor: Node3D) -> void:
	if not is_producer():
		game_state.request_feedback("%s is a non-producing structure." % building_definition.display_name)
		return
	game_state.request_feedback("%s: %s (%.0f%%)." % [
		building_definition.display_name,
		get_production_status(),
		get_production_progress_ratio() * 100.0,
	])


func get_interaction_prompt() -> String:
	return "Press E to inspect %s production" % building_definition.display_name if building_definition != null else ""


func get_interaction_priority() -> int:
	return 8


func _on_simulation_advanced(simulation_delta: float) -> void:
	if not is_producer() or simulation_delta <= 0.0:
		return
	production_elapsed_seconds += simulation_delta
	while production_elapsed_seconds >= building_definition.production_interval_seconds:
		if not game_state.spend_resources(building_definition.production_inputs):
			production_elapsed_seconds = building_definition.production_interval_seconds
			_set_production_status(get_pause_reason())
			return
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
	_set_production_status("Producing")


func restore_production_progress(elapsed_seconds: float) -> void:
	if not is_producer():
		production_elapsed_seconds = 0.0
		return
	production_elapsed_seconds = clampf(elapsed_seconds, 0.0, building_definition.production_interval_seconds)
	_set_production_status(get_pause_reason() if is_equal_approx(production_elapsed_seconds, building_definition.production_interval_seconds) else "Producing")


func _set_production_status(status: String) -> void:
	if _production_status == status:
		return
	_production_status = status
	production_status_changed.emit(status)
