class_name RebootCommunityProjectService
extends Node

signal project_started(project_id: StringName)
signal phase_changed(project_id: StringName, phase_id: StringName, phase_index: int)
signal project_progress_changed(project_id: StringName, summary: String)
signal project_completed(project_id: StringName)
## Emitted whenever a single material's carried count changes (gather,
## return, or deposit of that material) -- not a full-snapshot signal.
## Listeners that care about the whole carried set (UI, the player's visual)
## should read carried_materials themselves rather than relying solely on
## the value passed here.
signal carried_material_changed(material_id: StringName)

const PROJECT_ID := &"project_restore_garden"
const PROJECTS_PATH := "res://data/projects.json"
const MATERIAL_SOURCE_CAPACITY := {&"reclaimed_wood": 3, &"smooth_stone": 3, &"garden_seed": 3}

var definition: Dictionary = {}
var active: bool = false
var completed: bool = false
var phase_index: int = 0
var phase_contributors: Array[StringName] = []
var player_participated: bool = false
var resident_participated: bool = false
## material_id (StringName) -> count currently carried. Previously a single
## StringName ("carrying at most one thing"), which meant a player who
## gathered a material the current phase didn't need yet had no way to also
## pick up one it did need until they walked back and returned the first --
## a real reported UX dead end. Gathering is now bounded only by each
## source's own remaining stock (source_remaining below), not by whatever
## else is already carried.
var carried_materials: Dictionary = {}
var deposited_materials: Dictionary = {}
var source_remaining: Dictionary = {}
var _project_scene: Node

func _ready() -> void:
	_load_definition()
	reset()

func _load_definition() -> void:
	var file := FileAccess.open(PROJECTS_PATH, FileAccess.READ)
	if file == null:
		push_error("[CommunityProjectService] Missing projects.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for entry: Variant in parsed.get("projects", []):
			if entry is Dictionary and str(entry.get("id", "")) == String(PROJECT_ID):
				definition = entry.duplicate(true)
				return

func reset() -> void:
	active = false
	completed = false
	phase_index = 0
	phase_contributors.clear()
	player_participated = false
	resident_participated = false
	carried_materials.clear()
	deposited_materials.clear()
	source_remaining = MATERIAL_SOURCE_CAPACITY.duplicate()
	_refresh_scene()

func bind_project_scene(scene: Node) -> void:
	_project_scene = scene
	_refresh_scene()
	if active and not completed:
		get_node("/root/ResidentManager").call_deferred("consider_project_contributions")

func unbind_project_scene(scene: Node) -> void:
	if _project_scene == scene:
		_project_scene = null

func start_project(project_id: StringName) -> bool:
	if project_id != PROJECT_ID or active or completed or definition.is_empty():
		return false
	active = true
	project_started.emit(PROJECT_ID)
	_enter_phase(0)
	return true

func current_phase() -> Dictionary:
	var phases: Array = definition.get("phases", [])
	return phases[phase_index] if phase_index >= 0 and phase_index < phases.size() else {}

func current_phase_id() -> StringName:
	return StringName(str(current_phase().get("id", "complete")))

func current_phase_label() -> String:
	return str(current_phase().get("label", "Garden restored"))

func work_action() -> StringName:
	return StringName(str(current_phase().get("work_action", "work")))

func required_specialties() -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in current_phase().get("resident_specialties", []):
		result.append(StringName(str(value)))
	return result

func carried_count(material_id: StringName) -> int:
	return int(carried_materials.get(material_id, 0))

func is_carrying_anything() -> bool:
	for count: Variant in carried_materials.values():
		if int(count) > 0: return true
	return false

## Human-readable list of everything currently carried, for messages that
## need to name it (e.g. "the garden doesn't need what you're carrying").
func carried_summary() -> String:
	var parts: Array[String] = []
	for material_id: Variant in carried_materials.keys():
		var mid := StringName(str(material_id))
		if carried_count(mid) > 0:
			parts.append(material_display_name(mid))
	return ", ".join(parts) if not parts.is_empty() else "nothing"

func gather_material(material_id: StringName) -> bool:
	if int(source_remaining.get(material_id, 0)) <= 0:
		return false
	source_remaining[material_id] = int(source_remaining.get(material_id, 0)) - 1
	carried_materials[material_id] = carried_count(material_id) + 1
	carried_material_changed.emit(material_id)
	_refresh_scene()
	return true

func return_carried_material(material_id: StringName) -> bool:
	if carried_count(material_id) <= 0:
		return false
	source_remaining[material_id] = int(source_remaining.get(material_id, 0)) + 1
	carried_materials[material_id] = carried_count(material_id) - 1
	if carried_materials[material_id] <= 0:
		carried_materials.erase(material_id)
	carried_material_changed.emit(material_id)
	_refresh_scene()
	return true

## Delivers one unit of whichever carried material the current phase still
## needs (the player may be carrying several kinds at once now). Returns the
## material_id actually deposited, or an empty StringName if nothing carried
## matches what this phase wants right now.
func deposit_carried_material() -> StringName:
	if not active or completed:
		return &""
	for material_id: Variant in carried_materials.keys():
		var mid := StringName(str(material_id))
		if carried_count(mid) > 0 and _phase_needs_more(mid):
			deposited_materials[mid] = int(deposited_materials.get(mid, 0)) + 1
			carried_materials[mid] = carried_count(mid) - 1
			if carried_materials[mid] <= 0:
				carried_materials.erase(mid)
			carried_material_changed.emit(mid)
			_emit_progress()
			if materials_ready(): get_node("/root/ResidentManager").consider_project_contributions()
			return mid
	return &""

func materials_ready() -> bool:
	for material_id: Variant in current_phase().get("material_needs", {}):
		if int(deposited_materials.get(material_id, 0)) < int(current_phase().material_needs[material_id]):
			return false
	return true

func _phase_needs_more(material_id: StringName) -> bool:
	var needs: Dictionary = current_phase().get("material_needs", {})
	return int(needs.get(material_id, 0)) > int(deposited_materials.get(material_id, 0))

## Public wrapper for _phase_needs_more(), for callers outside this service
## (e.g. ProjectMaterialSource's pickup guidance) that need to know whether
## delivering a material right now would actually be accepted, before
## telling the player to carry it to the garden.
func phase_wants_material(material_id: StringName) -> bool:
	return active and not completed and _phase_needs_more(material_id)

func contribute(contributor_id: StringName, is_player: bool) -> bool:
	if not active or completed or not materials_ready() or contributor_id in phase_contributors:
		return false
	phase_contributors.append(contributor_id)
	player_participated = player_participated or is_player
	resident_participated = resident_participated or not is_player
	_emit_progress()
	if phase_contributors.size() >= 2 and (&"founder" in phase_contributors) and _phase_has_resident():
		_advance_phase()
	return true

func can_player_contribute() -> bool:
	return active and not completed and materials_ready() and &"founder" not in phase_contributors

func can_resident_contribute(resident_id: StringName) -> bool:
	return active and not completed and materials_ready() and resident_id not in phase_contributors and not _phase_has_resident()

func interaction_prompt() -> String:
	if completed:
		return "Admire the restored community garden"
	if not active:
		return "Propose this project at the Community Board"
	var deliverable := _carried_and_needed_material()
	if not deliverable.is_empty():
		return "Deliver %s to the garden" % material_display_name(deliverable)
	if not materials_ready():
		return "Gather materials: %s" % material_need_summary()
	if can_player_contribute():
		return "%s alongside the community" % current_phase_label()
	if is_carrying_anything():
		return "This phase doesn't need %s -- try direct work instead" % carried_summary()
	return "Check garden progress"

## The first carried material (if any) the current phase would actually
## accept a delivery of right now -- used both for the prompt and to decide
## whether an interaction at the garden has anything to deposit.
func _carried_and_needed_material() -> StringName:
	for material_id: Variant in carried_materials.keys():
		var mid := StringName(str(material_id))
		if carried_count(mid) > 0 and _phase_needs_more(mid):
			return mid
	return &""

func material_need_summary() -> String:
	var parts: Array[String] = []
	for material_id: Variant in current_phase().get("material_needs", {}):
		parts.append("%s %d/%d" % [material_display_name(StringName(str(material_id))), int(deposited_materials.get(material_id, 0)), int(current_phase().material_needs[material_id])])
	return ", ".join(parts) if not parts.is_empty() else "Ready for shared work"

func progress_summary() -> String:
	if completed:
		return "Garden restored — ordinary flowers and new routines have returned."
	if not active:
		return "Waiting for the village to propose restoration."
	return "%s — %s — %d/2 neighbors contributed" % [current_phase_label(), material_need_summary(), phase_contributors.size()]

func material_display_name(material_id: StringName) -> String:
	match material_id:
		&"reclaimed_wood": return "reclaimed wood"
		&"smooth_stone": return "smooth stone"
		&"garden_seed": return "common seeds"
		_: return String(material_id).replace("_", " ")

func serialize_state() -> Dictionary:
	return {"active":active, "completed":completed, "phase_index":phase_index, "phase_contributors":_strings(phase_contributors), "player_participated":player_participated, "resident_participated":resident_participated, "carried_materials":carried_materials.duplicate(true), "deposited_materials":deposited_materials.duplicate(true), "source_remaining":source_remaining.duplicate(true)}

func restore_state(state: Dictionary) -> void:
	active = bool(state.get("active", false))
	completed = bool(state.get("completed", false))
	phase_index = clampi(int(state.get("phase_index", 0)), 0, maxi(definition.get("phases", []).size() - 1, 0))
	phase_contributors.clear()
	for value: Variant in state.get("phase_contributors", []): phase_contributors.append(StringName(str(value)))
	player_participated = bool(state.get("player_participated", false))
	resident_participated = bool(state.get("resident_participated", false))
	# Older saves only ever had a single "carried_material" string -- migrate
	# that into the new count-per-material shape instead of dropping it.
	if state.has("carried_materials") and state.get("carried_materials", {}) is Dictionary:
		carried_materials = state.get("carried_materials", {}).duplicate(true)
	else:
		carried_materials = {}
		var legacy := str(state.get("carried_material", ""))
		if not legacy.is_empty(): carried_materials[StringName(legacy)] = 1
	deposited_materials = state.get("deposited_materials", {}).duplicate(true) if state.get("deposited_materials", {}) is Dictionary else {}
	source_remaining = state.get("source_remaining", MATERIAL_SOURCE_CAPACITY).duplicate(true) if state.get("source_remaining", {}) is Dictionary else MATERIAL_SOURCE_CAPACITY.duplicate()
	_refresh_scene()
	if carried_materials.is_empty():
		carried_material_changed.emit(&"")  # nothing carried after restore -- nudge listeners to clear any stale visual
	else:
		for material_id: Variant in carried_materials.keys(): carried_material_changed.emit(StringName(str(material_id)))

func _enter_phase(index: int) -> void:
	phase_index = index
	phase_contributors.clear()
	deposited_materials.clear()
	_refresh_scene()
	phase_changed.emit(PROJECT_ID, current_phase_id(), phase_index)
	get_node("/root/CalendarService").record_project_progress("Garden: %s." % current_phase_label())
	get_node("/root/EventBus").community_project_phase_changed.emit(PROJECT_ID, current_phase_id())
	get_node("/root/ResidentManager").consider_project_contributions()

func _advance_phase() -> void:
	var phases: Array = definition.get("phases", [])
	if phase_index + 1 < phases.size():
		_enter_phase(phase_index + 1)
		return
	if not player_participated or not resident_participated:
		return
	completed = true
	active = false
	_refresh_scene()
	project_completed.emit(PROJECT_ID)
	get_node("/root/EventBus").community_project_completed.emit(PROJECT_ID)
	get_node("/root/CalendarService").record_project_progress("The community garden was restored together.")
	get_node("/root/ResidentManager").on_community_project_completed(PROJECT_ID)

func _phase_has_resident() -> bool:
	for contributor: StringName in phase_contributors:
		if contributor != &"founder": return true
	return false

func _emit_progress() -> void:
	var summary := progress_summary()
	project_progress_changed.emit(PROJECT_ID, summary)
	if _project_scene != null: _project_scene.apply_project_state(phase_index, completed)

func _refresh_scene() -> void:
	if _project_scene != null: _project_scene.apply_project_state(phase_index, completed)

func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values: result.append(String(value))
	return result
