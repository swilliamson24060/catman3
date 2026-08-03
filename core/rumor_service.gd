class_name RebootRumorService
extends Node

signal rumor_acquired(rumor_id: StringName, text: String)
signal rumor_help_changed(rumor_id: StringName, marker_enabled: bool)

var _definitions: Dictionary = {}
var _known: Dictionary = {}
var _revisits: Dictionary = {}
var _help_markers: Dictionary = {}

func _ready() -> void:
	_load_definitions()
	var project_service := get_node_or_null("/root/CommunityProjectService")
	if project_service != null:
		project_service.phase_changed.connect(_on_project_phase_changed)

func reset() -> void:
	_known.clear()
	_revisits.clear()
	_help_markers.clear()

func acquire(rumor_id: StringName) -> bool:
	if not _definitions.has(rumor_id) or _known.has(rumor_id): return false
	_known[rumor_id] = true
	var definition: Dictionary = _definitions[rumor_id]
	rumor_acquired.emit(rumor_id, str(definition.get("text", "")))
	get_node("/root/EventBus").rumor_acquired.emit(rumor_id)
	get_node("/root/CalendarService").record_discovery("Rumor: %s" % str(definition.get("text", "")))
	return true

func observe_or_revisit(rumor_id: StringName) -> void:
	if not _known.has(rumor_id):
		acquire(rumor_id)
		return
	_revisits[rumor_id] = int(_revisits.get(rumor_id, 0)) + 1
	if int(_revisits[rumor_id]) >= 1: request_help(rumor_id)

func request_help(rumor_id: StringName) -> bool:
	if not _known.has(rumor_id) or _help_markers.has(rumor_id): return false
	_help_markers[rumor_id] = true
	rumor_help_changed.emit(rumor_id, true)
	return true

func known_rumors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rumor_id: StringName in _known:
		var item: Dictionary = _definitions[rumor_id].duplicate(true)
		item["marker_enabled"] = _help_markers.has(rumor_id)
		result.append(item)
	return result

func rumor_for_discovery(discovery_id: StringName) -> StringName:
	for rumor_id: StringName in _definitions:
		if StringName(str((_definitions[rumor_id] as Dictionary).get("discovery_id", ""))) == discovery_id: return rumor_id
	return &""

func serialize_state() -> Dictionary:
	return {"known":_known.keys().map(func(value: Variant) -> String: return str(value)), "revisits":_revisits.duplicate(true), "help_markers":_help_markers.keys().map(func(value: Variant) -> String: return str(value))}

func restore_state(data: Dictionary) -> void:
	reset()
	for value: Variant in data.get("known", []):
		var rumor_id := StringName(str(value))
		_known[rumor_id] = true
		if _definitions.has(rumor_id): rumor_acquired.emit(rumor_id, str((_definitions[rumor_id] as Dictionary).get("text", "")))
	_revisits = (data.get("revisits", {}) as Dictionary).duplicate(true)
	for value: Variant in data.get("help_markers", []): _help_markers[StringName(str(value))] = true

func _load_definitions() -> void:
	var file := FileAccess.open("res://data/rumors.json", FileAccess.READ)
	if file == null: return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		for value: Variant in parsed:
			if value is Dictionary: _definitions[StringName(str(value.get("id", "")))] = value

func _on_project_phase_changed(_project_id: StringName, phase_id: StringName, _phase_index: int) -> void:
	if phase_id in [&"repair_beds", &"restore_irrigation", &"plant", &"celebrate"]:
		acquire(&"rumor_plaque")
		get_node("/root/DiscoveryService").reveal_rumor(&"discovery_old_plaque")
