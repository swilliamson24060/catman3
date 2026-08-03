class_name RebootCommunityMachineService
extends Node

signal machine_state_changed(state_id: StringName, summary: String)
signal craft_family_unlocked(family_id: StringName)
signal craft_completed(craft_id: StringName, display_name: String)

const MACHINE_ID := &"machine_garden_irrigation"
const CRAFT_FAMILY_ID := &"craft_family_natural_dyes"

var definition: Dictionary = {}
var craft_family: Dictionary = {}
var installed: bool = false
var broken: bool = false
var resonant: bool = false
var craft_unlocked: bool = false
var completed_crafts: Array[String] = []
var current_state: StringName = &"incomplete"
var operation_count: int = 0
var unlock_count: int = 0
var _machine_scene: Node
var _cycle_running: bool = false

func _ready() -> void:
	definition = get_node("/root/DataRegistry").get_community_machine(String(MACHINE_ID))
	craft_family = get_node("/root/DataRegistry").get_craft_family(String(CRAFT_FAMILY_ID))
	if definition.is_empty() or craft_family.is_empty(): push_error("[CommunityMachineService] Missing Milestone 8 definitions")
	get_node("/root/CommunityProjectService").phase_changed.connect(_on_project_phase_changed)
	get_node("/root/CommunityProjectService").project_completed.connect(_on_project_completed)
	get_node("/root/SeasonalResonanceService").activation_completed.connect(_on_first_bloom)
	_reconcile_dependencies()

func reset() -> void:
	installed = false
	broken = false
	resonant = false
	craft_unlocked = false
	completed_crafts.clear()
	current_state = &"incomplete"
	operation_count = 0
	unlock_count = 0
	_cycle_running = false
	_refresh_scene()

func bind_machine_scene(scene: Node) -> void:
	_machine_scene = scene
	_refresh_scene()

func unbind_machine_scene(scene: Node) -> void:
	if _machine_scene == scene: _machine_scene = null

func set_broken(value: bool) -> void:
	if not installed: return
	broken = value
	_set_state(&"maintenance" if broken else (&"resonant" if resonant else &"installed_idle"))
	_request_pip_routine()

func request_player_operation() -> bool:
	if not installed or broken or not craft_unlocked or _cycle_running: return false
	_run_visible_cycle.call_deferred()
	return true

func interaction_summary() -> String:
	if not installed: return "The workshop slot is waiting for the recovered irrigation assembly."
	if broken: return "The irrigation assembly needs Pip's maintenance."
	if not craft_unlocked: return "Water turns the gear, but the garden has not revealed a new color yet."
	if _cycle_running: return "Flowers soak, the gear turns, and color gathers in the cloth."
	var output := "No cloth dyed yet." if completed_crafts.is_empty() else "Newest output: %s." % craft_display_name(StringName(completed_crafts.back()))
	return "First Bloom Natural Dyes are available. %s" % output

func craft_display_name(craft_id: StringName) -> String:
	for craft: Variant in craft_family.get("crafts", []):
		if craft is Dictionary and str(craft.get("id", "")) == String(craft_id): return str(craft.get("display_name", craft_id))
	return String(craft_id).replace("craft_", "").replace("_", " ").capitalize()

func serialize_state() -> Dictionary:
	return {"installed":installed, "broken":broken, "resonant":resonant, "craft_unlocked":craft_unlocked, "completed_crafts":completed_crafts.duplicate(), "current_state":String(current_state), "operation_count":operation_count}

func restore_state(data: Dictionary) -> void:
	installed = bool(data.get("installed", false))
	broken = bool(data.get("broken", false))
	resonant = bool(data.get("resonant", false))
	craft_unlocked = bool(data.get("craft_unlocked", false))
	completed_crafts.assign(_strings(data.get("completed_crafts", [])))
	operation_count = maxi(int(data.get("operation_count", 0)), 0)
	current_state = StringName(str(data.get("current_state", "incomplete")))
	_cycle_running = false
	_reconcile_dependencies()

func _on_project_phase_changed(_project_id: StringName, phase_id: StringName, _index: int) -> void:
	if phase_id == &"plant": _install_once()

func _on_project_completed(_project_id: StringName) -> void:
	_install_once()

func _on_first_bloom(pattern_id: StringName) -> void:
	if pattern_id != &"resonance_first_bloom": return
	resonant = true
	if not craft_unlocked:
		craft_unlocked = true
		unlock_count += 1
		craft_family_unlocked.emit(CRAFT_FAMILY_ID)
	_set_state(&"maintenance" if broken else &"resonant")
	_request_pip_routine()

func _install_once() -> void:
	if installed: return
	installed = true
	_set_state(&"installed_idle")
	_request_pip_routine()

func _run_visible_cycle() -> void:
	_cycle_running = true
	_set_state(&"operating")
	_request_pip_routine()
	if _machine_scene != null: await _machine_scene.play_input_stage()
	if _machine_scene != null: await _machine_scene.play_work_stage()
	var crafts: Array = craft_family.get("crafts", [])
	if not crafts.is_empty():
		var craft: Dictionary = crafts[operation_count % crafts.size()]
		var craft_id := StringName(str(craft.get("id", "")))
		completed_crafts.append(String(craft_id))
		operation_count += 1
		if _machine_scene != null: await _machine_scene.play_output_stage(craft)
		craft_completed.emit(craft_id, str(craft.get("display_name", craft_id)))
	_cycle_running = false
	_set_state(&"resonant")

func _set_state(value: StringName) -> void:
	current_state = value
	_refresh_scene()
	machine_state_changed.emit(current_state, interaction_summary())

func _refresh_scene() -> void:
	if _machine_scene != null and is_instance_valid(_machine_scene): _machine_scene.apply_machine_state(current_state, completed_crafts)

func _request_pip_routine() -> void:
	var manager := get_node_or_null("/root/ResidentManager")
	if manager != null: manager.react_to_machine_state(current_state)

func _reconcile_dependencies() -> void:
	var project := get_node_or_null("/root/CommunityProjectService")
	if project != null and (project.completed or project.phase_index >= 3): installed = true
	var resonance := get_node_or_null("/root/SeasonalResonanceService")
	if resonance != null and resonance.activated:
		resonant = true
		craft_unlocked = true
	current_state = &"incomplete" if not installed else (&"maintenance" if broken else (&"resonant" if resonant else &"installed_idle"))
	_refresh_scene()
	_request_pip_routine()

func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value: result.append(str(entry))
	return result
