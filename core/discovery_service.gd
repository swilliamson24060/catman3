class_name RebootDiscoveryService
extends Node

signal discovery_changed(discovery_id: StringName, state: StringName)

const STATES := [&"hidden", &"rumored", &"found", &"unidentified", &"investigation_available", &"investigated", &"interpreted"]
var _definitions: Dictionary = {}
var _states: Dictionary = {}
var _resident_observations: Dictionary = {}

func _ready() -> void:
	_load_definitions()
	reset()

func reset() -> void:
	_states.clear()
	_resident_observations.clear()
	for discovery_id: StringName in _definitions: _states[discovery_id] = &"hidden"

func reveal_rumor(discovery_id: StringName) -> bool:
	return _advance(discovery_id, &"rumored")

func resident_observed(discovery_id: StringName, resident_id: StringName) -> void:
	_resident_observations[discovery_id] = resident_id
	reveal_rumor(discovery_id)
	var rumor_id: StringName = get_node("/root/RumorService").rumor_for_discovery(discovery_id)
	if not rumor_id.is_empty(): get_node("/root/RumorService").acquire(rumor_id)

func find(discovery_id: StringName) -> bool:
	if not _definitions.has(discovery_id): return false
	var current := state(discovery_id)
	if current in [&"found", &"unidentified", &"investigation_available", &"investigated", &"interpreted"]: return false
	_states[discovery_id] = &"found"
	_emit_change(discovery_id)
	_states[discovery_id] = &"unidentified"
	_emit_change(discovery_id)
	_states[discovery_id] = &"investigation_available"
	_emit_change(discovery_id)
	get_node("/root/ResidentManager").record_discovery_context(unidentified_name(discovery_id))
	return true

func investigate(discovery_id: StringName, resident_specialty: StringName = &"") -> Dictionary:
	if state(discovery_id) not in [&"investigation_available", &"investigated"]: return {}
	_states[discovery_id] = &"investigated"
	_emit_change(discovery_id)
	_states[discovery_id] = &"interpreted"
	_emit_change(discovery_id)
	var definition: Dictionary = _definitions[discovery_id]
	var specialist := StringName(str(definition.get("resident_specialty", ""))) == resident_specialty
	var result := {"discovery_id":String(discovery_id), "display_name":display_name(discovery_id), "interpretation":str(definition.get("interpretation", "")), "specialist_context":specialist}
	get_node("/root/ResidentManager").record_discovery_context(display_name(discovery_id))
	get_node("/root/CalendarService").record_discovery("Interpreted: %s" % display_name(discovery_id))
	return result

func state(discovery_id: StringName) -> StringName: return StringName(str(_states.get(discovery_id, "hidden")))
func definition(discovery_id: StringName) -> Dictionary: return (_definitions.get(discovery_id, {}) as Dictionary).duplicate(true)
func display_name(discovery_id: StringName) -> String: return str((_definitions.get(discovery_id, {}) as Dictionary).get("display_name", discovery_id))
func unidentified_name(discovery_id: StringName) -> String: return str((_definitions.get(discovery_id, {}) as Dictionary).get("unidentified_name", "Unidentified find"))

func entries_for_state(states: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for discovery_id: StringName in _definitions:
		if state(discovery_id) in states:
			var item := definition(discovery_id)
			item["state"] = String(state(discovery_id))
			item["label"] = display_name(discovery_id) if state(discovery_id) == &"interpreted" else unidentified_name(discovery_id)
			result.append(item)
	return result

func pending_investigations() -> Array[StringName]:
	var result: Array[StringName] = []
	for discovery_id: StringName in _states:
		if state(discovery_id) == &"investigation_available": result.append(discovery_id)
	return result

func serialize_state() -> Dictionary:
	var states: Dictionary = {}
	for discovery_id: StringName in _states: states[String(discovery_id)] = String(_states[discovery_id])
	var observations: Dictionary = {}
	for discovery_id: StringName in _resident_observations: observations[String(discovery_id)] = String(_resident_observations[discovery_id])
	return {"states":states, "resident_observations":observations}

func restore_state(data: Dictionary) -> void:
	reset()
	for discovery_id: Variant in (data.get("states", {}) as Dictionary):
		var saved_state := StringName(str(data.states[discovery_id]))
		if saved_state in STATES and _definitions.has(StringName(str(discovery_id))): _states[StringName(str(discovery_id))] = saved_state
	for discovery_id: Variant in (data.get("resident_observations", {}) as Dictionary): _resident_observations[StringName(str(discovery_id))] = StringName(str(data.resident_observations[discovery_id]))
	for discovery_id: StringName in _states: discovery_changed.emit(discovery_id, state(discovery_id))

func _advance(discovery_id: StringName, next_state: StringName) -> bool:
	if not _definitions.has(discovery_id) or STATES.find(next_state) <= STATES.find(state(discovery_id)): return false
	_states[discovery_id] = next_state
	_emit_change(discovery_id)
	return true

func _emit_change(discovery_id: StringName) -> void:
	discovery_changed.emit(discovery_id, state(discovery_id))
	get_node("/root/EventBus").discovery_state_changed.emit(discovery_id, state(discovery_id))

func _load_definitions() -> void:
	var file := FileAccess.open("res://data/discoveries.json", FileAccess.READ)
	if file == null: return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		for value: Variant in parsed:
			if value is Dictionary: _definitions[StringName(str(value.get("id", "")))] = value
