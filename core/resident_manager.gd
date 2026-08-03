class_name RebootResidentManager
extends Node

signal residents_spawned(count: int)
signal dialogue_requested(resident: ResidentAgent, text: String)
signal dialogue_closed(resident_id: StringName)
signal priority_changed(priority_id: StringName)
signal locator_changed(entries: Array[Dictionary])
signal board_requested

const RESIDENT_SCENE := preload("res://scenes/residents/resident_agent.tscn")
const RESTORE_GARDEN_PRIORITY := &"project_restore_garden"

var current_priority: StringName
var recent_discoveries: Array[String] = []
var _agents: Dictionary = {}
var _world_root: Node3D
var _pending_state: Dictionary = {}
var _active_dialogue_resident: ResidentAgent

var legacy_animal_manager: Node:
	get: return get_node_or_null("/root/AnimalManager")

func _ready() -> void:
	if bool(ProjectSettings.get_setting("feature/reboot_mode", true)):
		get_node("/root/CalendarService").resident_schedule_changed.connect(_on_period_changed)
		get_node("/root/WeatherService").forecast_changed.connect(_on_forecast_changed)

func bind_world(world_root: Node3D) -> void:
	if not bool(ProjectSettings.get_setting("feature/reboot_mode", true)):
		return
	_world_root = world_root
	_spawn_residents()

func _spawn_residents() -> void:
	for agent: ResidentAgent in _agents.values():
		if is_instance_valid(agent):
			agent.queue_free()
	_agents.clear()
	var saved_residents: Dictionary = _pending_state.get("residents", {})
	for definition_value: Variant in get_node("/root/DataRegistry").get_all_residents():
		if not definition_value is Dictionary:
			continue
		var definition: Dictionary = definition_value
		var resident_id := StringName(str(definition.get("id", "")))
		var agent := RESIDENT_SCENE.instantiate() as ResidentAgent
		_world_root.get_node("Residents").add_child(agent)
		agent.conversation_requested.connect(_on_conversation_requested)
		agent.activity_changed.connect(_on_agent_activity_changed)
		agent.configure(definition, saved_residents.get(String(resident_id), {}))
		_agents[resident_id] = agent
	current_priority = StringName(str(_pending_state.get("current_priority", current_priority)))
	_pending_state.clear()
	residents_spawned.emit(_agents.size())
	_emit_locator()

func new_game() -> void:
	current_priority = &""
	recent_discoveries.clear()
	_pending_state.clear()
	if _world_root != null:
		_spawn_residents()

func propose_priority(priority_id: StringName) -> bool:
	if priority_id != RESTORE_GARDEN_PRIORITY:
		return false
	current_priority = priority_id
	priority_changed.emit(current_priority)
	get_node("/root/CalendarService").record_project_progress("The community proposed restoring the abandoned garden.")
	return true

func request_board() -> void:
	board_requested.emit()

func priority_display_name() -> String:
	return "Restore the abandoned garden" if current_priority == RESTORE_GARDEN_PRIORITY else "No priority proposed"

func record_discovery_context(display_name: String) -> void:
	if not display_name.is_empty() and display_name not in recent_discoveries:
		recent_discoveries.append(display_name)
	while recent_discoveries.size() > 3:
		recent_discoveries.pop_front()

func get_agent(resident_id: StringName) -> ResidentAgent:
	return _agents.get(resident_id) as ResidentAgent

func get_agents() -> Array[ResidentAgent]:
	var result: Array[ResidentAgent] = []
	for agent: ResidentAgent in _agents.values():
		result.append(agent)
	return result

func set_debug_visualization(enabled: bool) -> void:
	for agent: ResidentAgent in get_agents():
		agent.show_debug_scores = enabled
		agent.debug_label.visible = enabled

func locator_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for agent: ResidentAgent in get_agents():
		entries.append({"resident_id":agent.resident_id, "display_name":agent.display_name(), "location":agent.location_name(), "activity":str(agent.current_activity.get("label", "Taking a quiet pause")), "state":agent.state_name()})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.display_name) < str(b.display_name))
	return entries

func serialize_state() -> Dictionary:
	var resident_states: Dictionary = {}
	for resident_id: StringName in _agents:
		resident_states[String(resident_id)] = (_agents[resident_id] as ResidentAgent).serialize_state()
	return {"current_priority":String(current_priority), "recent_discoveries":recent_discoveries.duplicate(), "residents":resident_states}

func restore_state(data: Dictionary) -> void:
	_pending_state = data.duplicate(true)
	current_priority = StringName(str(data.get("current_priority", "")))
	recent_discoveries.assign(_string_array(data.get("recent_discoveries", [])))
	if _world_root != null:
		_spawn_residents()

func close_dialogue() -> void:
	if _active_dialogue_resident == null:
		return
	var resident_id := _active_dialogue_resident.resident_id
	_active_dialogue_resident.end_talking()
	_active_dialogue_resident = null
	get_node("/root/CalendarService").pop_modal_pause()
	dialogue_closed.emit(resident_id)

func _on_conversation_requested(resident: ResidentAgent) -> void:
	if _active_dialogue_resident != null:
		return
	_active_dialogue_resident = resident
	resident.begin_talking()
	get_node("/root/CalendarService").push_modal_pause()
	dialogue_requested.emit(resident, resident.conversation_text())

func _on_period_changed(period_id: StringName) -> void:
	if _active_dialogue_resident != null:
		close_dialogue()
	for agent: ResidentAgent in get_agents():
		agent.set_period(period_id)
	_emit_locator()

func _on_forecast_changed(_forecast: Array[String]) -> void:
	# Weather preference is part of scoring, so a changed day may alter the
	# resident's choice without adding a separate hidden need system.
	for agent: ResidentAgent in get_agents():
		agent.set_period(agent.current_period)

func _on_agent_activity_changed(_resident_id: StringName, _activity_id: StringName, _state: StringName) -> void:
	_emit_locator()

func _emit_locator() -> void:
	locator_changed.emit(locator_entries())

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			if entry is String:
				result.append(entry)
	return result

func serialize_legacy_roster() -> Array:
	return legacy_animal_manager.serialize_roster() if legacy_animal_manager != null else []

func restore_legacy_roster(data: Array) -> void:
	if legacy_animal_manager != null:
		legacy_animal_manager.restore_roster(data)

func legacy_recruited_count(species_id: String) -> int:
	return legacy_animal_manager.recruited_count(species_id) if legacy_animal_manager != null else 0
