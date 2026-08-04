class_name RebootCelebrationService
extends Node

signal state_changed(state_id: StringName, summary: String)
signal contribution_completed(resident_id: StringName, contribution_id: StringName)
signal choice_requested(choices: Array[Dictionary])
signal choice_made(choice_id: StringName)
signal closing_line_requested(line: Dictionary, line_index: int, line_count: int)
signal celebration_completed
signal demo_acknowledgement_requested

const EVENT_ID := &"event_first_bloom_celebration"
const STATES: Array[StringName] = [&"dormant", &"preparing", &"awaiting_choice", &"gathering", &"closing", &"complete"]

var definition: Dictionary = {}
var state: StringName = &"dormant"
var completed_contributions: Array[StringName] = []
var active_contribution_index: int = -1
var contribution_remaining: float = 0.0
var player_choice: StringName = &""
var gathering_session_id: StringName = &""
var closing_index: int = 0
var activation_day: int = 0
var completion_day: int = 0
var distant_rumors: Array[String] = []
var contribution_duration: float = 1.1
var _scene: Node

func _ready() -> void:
	definition = get_node("/root/DataRegistry").get_village_event(String(EVENT_ID))
	if definition.is_empty(): push_error("[CelebrationService] Missing First Bloom celebration definition")
	get_node("/root/SeasonalResonanceService").activation_completed.connect(_on_resonance_activated)
	get_node("/root/ResidentManager").social_activity_completed.connect(_on_social_activity_completed)
	get_node("/root/ResidentManager").residents_spawned.connect(_on_residents_spawned)

func _process(delta: float) -> void:
	if state != &"preparing" or active_contribution_index < 0: return
	var contribution := _active_contribution()
	var resident_id := StringName(str(contribution.get("resident_id", "")))
	var manager := get_node("/root/ResidentManager")
	var resident: ResidentAgent = manager.get_agent(resident_id)
	var at_authored_slot := false
	if resident != null and _scene != null:
		var offset: Vector3 = resident.global_position - _scene.contribution_slot_position(int(contribution.get("slot", active_contribution_index)))
		offset.y = 0.0
		at_authored_slot = offset.length() <= resident.arrival_distance
	if not manager.celebration_contribution_ready(resident_id) and not at_authored_slot: return
	contribution_remaining = maxf(contribution_remaining - delta, 0.0)
	if is_zero_approx(contribution_remaining): _finish_active_contribution()

func reset() -> void:
	get_node("/root/ResidentManager").release_celebration_residents()
	state = &"dormant"
	completed_contributions.clear()
	active_contribution_index = -1
	contribution_remaining = 0.0
	player_choice = &""
	gathering_session_id = &""
	closing_index = 0
	activation_day = 0
	completion_day = 0
	distant_rumors.clear()
	_refresh_scene()

func bind_scene(scene: Node) -> void:
	_scene = scene
	_refresh_scene()
	_resume_state()

func unbind_scene(scene: Node) -> void:
	if _scene == scene: _scene = null

func start_celebration() -> bool:
	if state != &"dormant": return false
	activation_day = int(get_node("/root/CalendarService").current_day)
	_set_state(&"preparing", "The village begins preparing a First Bloom gathering.")
	_start_next_contribution()
	return true

func choose_decoration(choice_id: StringName) -> bool:
	if state != &"awaiting_choice" or not _valid_choice(choice_id): return false
	player_choice = choice_id
	choice_made.emit(player_choice)
	_refresh_scene()
	_begin_gathering()
	return true

func advance_closing_conversation() -> bool:
	if state != &"closing": return false
	closing_index += 1
	var lines: Array = definition.get("closing_lines", [])
	if closing_index < lines.size():
		_emit_closing_line()
	else:
		_complete_celebration()
	return true

func serialize_state() -> Dictionary:
	return {"state":String(state), "completed_contributions":_strings(completed_contributions), "active_contribution_index":active_contribution_index, "contribution_remaining":contribution_remaining, "player_choice":String(player_choice), "gathering_session_id":String(gathering_session_id), "closing_index":closing_index, "activation_day":activation_day, "completion_day":completion_day, "distant_rumors":distant_rumors.duplicate()}

func restore_state(data: Dictionary) -> void:
	state = StringName(str(data.get("state", "dormant")))
	if state not in STATES: state = &"dormant"
	completed_contributions.clear()
	for value: Variant in data.get("completed_contributions", []): completed_contributions.append(StringName(str(value)))
	active_contribution_index = int(data.get("active_contribution_index", -1))
	contribution_remaining = maxf(float(data.get("contribution_remaining", contribution_duration)), 0.0)
	player_choice = StringName(str(data.get("player_choice", "")))
	gathering_session_id = StringName(str(data.get("gathering_session_id", "")))
	closing_index = maxi(int(data.get("closing_index", 0)), 0)
	activation_day = maxi(int(data.get("activation_day", 0)), 0)
	completion_day = maxi(int(data.get("completion_day", 0)), 0)
	distant_rumors.assign(_string_array(data.get("distant_rumors", [])))
	_refresh_scene()
	_resume_state()

func status_summary() -> String:
	match state:
		&"dormant": return "The First Bloom celebration has not begun."
		&"preparing": return "Celebration preparations: %d/3 resident contributions complete." % completed_contributions.size()
		&"awaiting_choice": return "The gathering is ready. Choose its finishing touch."
		&"gathering": return "The village is gathering among the First Bloom flowers."
		&"closing": return "The residents are sharing what the First Bloom might mean."
		&"complete": return "The First Bloom celebration is remembered; ordinary village days continue."
		_: return String(state)

func _on_resonance_activated(pattern_id: StringName) -> void:
	if str(definition.get("trigger_pattern_id", "")) == String(pattern_id): start_celebration()

func _on_residents_spawned(_count: int) -> void:
	_resume_state()

func _start_next_contribution() -> void:
	if state != &"preparing" or _scene == null: return
	var contributions: Array = definition.get("contributions", [])
	for index in range(contributions.size()):
		var candidate: Dictionary = contributions[index]
		if StringName(str(candidate.get("id", ""))) in completed_contributions: continue
		active_contribution_index = index
		contribution_remaining = contribution_duration
		var resident_id := StringName(str(candidate.get("resident_id", "")))
		if not get_node("/root/ResidentManager").begin_celebration_contribution(resident_id, StringName(str(candidate.get("id", ""))), str(candidate.get("label", "Prepares for the gathering")), _scene.contribution_slot_position(int(candidate.get("slot", index))), StringName(str(candidate.get("action", "inspect")))):
			active_contribution_index = -1
			call_deferred("_start_next_contribution")
		return
	active_contribution_index = -1
	_set_state(&"awaiting_choice", "Everyone contributed. The founder can choose the gathering's finishing touch.")
	choice_requested.emit(_choices())

func _finish_active_contribution() -> void:
	var contribution := _active_contribution()
	if contribution.is_empty(): return
	var resident_id := StringName(str(contribution.get("resident_id", "")))
	var contribution_id := StringName(str(contribution.get("id", "")))
	get_node("/root/ResidentManager").finish_celebration_contribution(resident_id)
	if contribution_id not in completed_contributions: completed_contributions.append(contribution_id)
	if _scene != null: _scene.reveal_contribution(contribution_id)
	contribution_completed.emit(resident_id, contribution_id)
	active_contribution_index = -1
	get_node("/root/CalendarService").record_project_progress(str(contribution.get("label", "A resident prepared for the First Bloom gathering.")) + ".")
	_start_next_contribution()

func _begin_gathering() -> void:
	_set_state(&"gathering", "The First Bloom gathering begins in the restored garden.")
	var manager := get_node("/root/ResidentManager")
	var existing: StringName = manager.find_social_session(&"garden_gathering", &"garden_table")
	if existing != &"":
		gathering_session_id = existing
		return
	var participants: Array[StringName] = [&"resident_mara", &"resident_pip", &"resident_elowen"]
	gathering_session_id = manager.plan_social_activity(&"garden_gathering", participants, &"garden_table", 4.0)
	if gathering_session_id == &"": call_deferred("_begin_gathering")

func _on_social_activity_completed(session: Dictionary) -> void:
	if state != &"gathering" or str(session.get("activity_id", "")) != "garden_gathering": return
	gathering_session_id = &""
	state = &"closing"
	closing_index = 0
	get_node("/root/ResidentManager").release_celebration_residents()
	_set_state(&"closing", "The gathering settles into one last conversation.")
	_emit_closing_line()

func _emit_closing_line() -> void:
	var lines: Array = definition.get("closing_lines", [])
	if closing_index >= 0 and closing_index < lines.size(): closing_line_requested.emit((lines[closing_index] as Dictionary).duplicate(true), closing_index, lines.size())

func _complete_celebration() -> void:
	state = &"complete"
	completion_day = int(get_node("/root/CalendarService").current_day)
	distant_rumors = ["Wind-marked stones may stand beyond the north ridge.", "Other seasonal patterns can wait until the village chooses to explore again."]
	get_node("/root/ResidentManager").release_celebration_residents()
	get_node("/root/CalendarService").record_project_progress("The village celebrated The First Bloom and returned to its everyday rhythms.")
	_set_state(&"complete", status_summary())
	celebration_completed.emit()
	if bool(ProjectSettings.get_setting("feature/demo_build", false)): demo_acknowledgement_requested.emit()
	get_node("/root/SaveService").save_game()

func _resume_state() -> void:
	if state == &"dormant" and get_node("/root/SeasonalResonanceService").activated:
		start_celebration()
		return
	if _scene == null: return
	_refresh_scene()
	match state:
		&"preparing":
			var contribution := _active_contribution()
			var resident: ResidentAgent = (get_node("/root/ResidentManager").get_agent(StringName(str(contribution.get("resident_id", "")))) as ResidentAgent) if not contribution.is_empty() else null
			if resident == null or StringName(str(resident.activity_id())) != StringName(str(contribution.get("id", ""))) or not bool(resident.current_activity.get("event", false)):
				get_node("/root/ResidentManager").release_celebration_residents()
				active_contribution_index = -1
				_start_next_contribution()
		&"awaiting_choice": choice_requested.emit(_choices())
		&"gathering": _begin_gathering()
		&"closing": _emit_closing_line()
		&"complete": get_node("/root/ResidentManager").release_celebration_residents()

func _refresh_scene() -> void:
	if _scene == null or not is_instance_valid(_scene): return
	_scene.apply_event_state(state, completed_contributions, player_choice)

func _set_state(value: StringName, summary: String) -> void:
	state = value
	_refresh_scene()
	state_changed.emit(state, summary)

func _active_contribution() -> Dictionary:
	var contributions: Array = definition.get("contributions", [])
	return contributions[active_contribution_index] if active_contribution_index >= 0 and active_contribution_index < contributions.size() else {}

func _valid_choice(choice_id: StringName) -> bool:
	for choice: Dictionary in _choices():
		if str(choice.get("id", "")) == String(choice_id): return true
	return false

func _choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in definition.get("choices", []):
		if value is Dictionary: result.append(value.duplicate(true))
	return result

func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values: result.append(String(value))
	return result

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value: result.append(str(entry))
	return result
