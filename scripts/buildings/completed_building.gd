class_name CompletedBuilding
extends StaticBody3D

signal production_status_changed(status: String)
signal durability_changed(current: float, maximum: float)

@export var building_definition: BuildingDefinition

@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var simulation_clock: Phase2SimulationClock = get_node("/root/SimulationClock") as Phase2SimulationClock
@onready var stats_service: Node = get_node("/root/StatsService")
@onready var weather_service: Node = get_node("/root/WeatherService")
@onready var settlement_manager: Phase2SettlementManager = get_node("/root/SettlementManager") as Phase2SettlementManager

var production_elapsed_seconds: float = 0.0
var durability: float = 100.0
var _production_status: String = "Inactive"
var _builder_mice: Array[Phase1WildMouse] = []
var _reward_turns_elapsed: int = 0
var _completion_rewards_granted: bool = false


func _ready() -> void:
	add_to_group("completed_buildings")
	durability = building_definition.max_durability if building_definition != null else 100.0
	simulation_clock.simulation_advanced.connect(_on_simulation_advanced)
	simulation_clock.need_cycle.connect(_on_need_cycle)
	if is_producer():
		_set_production_status("Producing")


func configure_builders(builders: Array[Phase1WildMouse]) -> void:
	_builder_mice.clear()
	for mouse in builders:
		if is_instance_valid(mouse) and mouse not in _builder_mice:
			_builder_mice.append(mouse)


func get_builder_count() -> int:
	var count := 0
	for mouse in _builder_mice:
		if is_instance_valid(mouse):
			count += 1
	return count


func grant_completion_rewards() -> void:
	if _completion_rewards_granted or building_definition == null:
		return
	_completion_rewards_granted = true
	var rewarded_workers := 0
	for mouse in _builder_mice:
		if not is_instance_valid(mouse):
			continue
		mouse.receive_personal_cheese(1)
		rewarded_workers += 1
	match building_definition.id:
		&"test_structure":
			game_state.add_cheese(1)
		&"catnip_garden":
			game_state.deposit_resource(&"catnip", 1, self)
		&"mouse_hut":
			game_state.add_cheese(2)
			for mouse in _builder_mice:
				if is_instance_valid(mouse):
					mouse.adjust_contentment(3)
		&"cheese_vault":
			game_state.add_cheese(3)
	game_state.request_feedback("%s rewarded %d builders with personal cheese." % [building_definition.display_name, rewarded_workers])


func _on_need_cycle(_cycle_index: int) -> void:
	_reward_turns_elapsed += 1
	if _reward_turns_elapsed < 5:
		return
	_reward_turns_elapsed = 0
	var rewarded_workers := 0
	for mouse in _builder_mice:
		if is_instance_valid(mouse) and mouse.is_recruited:
			mouse.receive_personal_cheese(1)
			rewarded_workers += 1
	if rewarded_workers > 0:
		game_state.request_feedback("%s paid 1 personal cheese to each of its %d builders." % [building_definition.display_name, rewarded_workers])


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
	var production_rate := float(stats_service.call("get_effective", str(building_definition.id), "production_rate", 1.0))
	if production_rate <= 0.0:
		return "Production rate is zero."
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
	if simulation_delta <= 0.0:
		return
	_tick_weather_damage(simulation_delta)
	if durability <= 0.0 or not is_producer():
		return
	var production_rate := float(stats_service.call("get_effective", str(building_definition.id), "production_rate", 1.0))
	if production_rate <= 0.0:
		_set_production_status("Production rate is zero.")
		return
	if not game_state.can_store_resource(building_definition.production_resource, building_definition.production_amount):
		_set_production_status("Invalid production output.")
		return
	production_elapsed_seconds += simulation_delta * production_rate
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


func restore_durability(value: float) -> void:
	var maximum := building_definition.max_durability if building_definition != null else 100.0
	durability = clampf(value, 0.0, maximum)
	durability_changed.emit(durability, maximum)


func _tick_weather_damage(simulation_delta: float) -> void:
	if building_definition == null or building_definition.waterproof or not bool(weather_service.call("is_raining")):
		return
	durability = maxf(durability - 2.0 * simulation_delta, 0.0)
	durability_changed.emit(durability, building_definition.max_durability)
	if durability <= 0.0:
		settlement_manager.unregister_completed_building(self)
		game_state.request_feedback("%s collapsed in the rain." % building_definition.display_name)
		queue_free()


func _set_production_status(status: String) -> void:
	if _production_status == status:
		return
	_production_status = status
	production_status_changed.emit(status)
