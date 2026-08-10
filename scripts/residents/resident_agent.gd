class_name ResidentAgent
extends CharacterBody3D

signal conversation_requested(resident: ResidentAgent)
signal activity_changed(resident_id: StringName, activity_id: StringName, state_name: StringName)

enum State { ROUTINE_TRAVEL, ROUTINE_ACTIVITY, CONSIDERING, CONTRIBUTION_TRAVEL, CONTRIBUTING, SOCIAL_TRAVEL, SOCIALIZING, TALKING, GOING_HOME, SLEEPING, AWAY }

@export var move_speed: float = 2.6
@export var arrival_distance: float = 0.35
@export var show_debug_scores: bool = false

var definition: Dictionary = {}
var resident_id: StringName
var current_period: StringName = &"morning"
var current_activity: Dictionary = {}
var current_state: State = State.ROUTINE_ACTIVITY
var energy: float = 0.85
var mood: float = 0.75
var social_openness: float = 0.65
var aspiration_step: int = 0
var carried_item_id: StringName
var social_session_id: StringName
var project_phase_id: StringName
var garden_routine_unlocked: bool = false
var _score_breakdown: Array[String] = []
var _stuck_seconds: float = 0.0
var _last_distance: float = INF

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var model_root: Node3D = $ModelRoot
@onready var interaction_anchor: InteractionAnchor = $InteractionAnchor
@onready var speech_bubble_anchor: Marker3D = $SpeechBubbleAnchor
@onready var carried_item_socket: Marker3D = $CarriedItemSocket
@onready var debug_label: Label3D = $DebugActivity
@onready var activity_bubble: Label3D = $ActivityBubble

func _ready() -> void:
	add_to_group("reboot_residents")
	interaction_anchor.activated.connect(_on_interaction)
	show_debug_scores = bool(ProjectSettings.get_setting("feature/show_resident_debug", show_debug_scores))
	debug_label.visible = show_debug_scores
	set_meta("development_placeholder", true)

func configure(data: Dictionary, saved_state: Dictionary = {}) -> void:
	definition = data.duplicate(true)
	resident_id = StringName(str(definition.get("id", "resident")))
	name = str(definition.get("display_name", resident_id))
	interaction_anchor.anchor_id = resident_id
	interaction_anchor.prompt = "Talk with %s" % display_name()
	global_position = _vector3(definition.get("home_position", [0.0, 0.2, 0.0]))
	_apply_color(Color(str(definition.get("color", "ffffff"))))
	restore_state(saved_state)
	set_period(StringName(str(saved_state.get("routine_period", current_period))))

func set_period(period_id: StringName) -> void:
	current_period = period_id
	_select_routine_activity()

func _select_routine_activity() -> void:
	var routines: Dictionary = definition.get("routines", {})
	var candidates: Array = routines.get(String(current_period), []).duplicate(true)
	if garden_routine_unlocked and current_period in [&"afternoon", &"evening"]:
		candidates.append({"id":"tend_restored_garden", "label":"Enjoys the restored garden", "location":"community garden", "position":[-7.0,0.2,14.0], "specialty":str(definition.get("specialty", "")), "aspiration":str(definition.get("specialty", "")) == "gardening"})
	if candidates.is_empty():
		current_activity = {"id":"wait", "label":"Takes a quiet pause", "location":"village center", "position":[0.0,0.2,0.0]}
	else:
		var best_score := -INF
		var best: Dictionary = {}
		_score_breakdown.clear()
		for candidate_value: Variant in candidates:
			if not candidate_value is Dictionary:
				continue
			var candidate: Dictionary = candidate_value
			var score_data := score_activity(candidate)
			var score := float(score_data.score)
			_score_breakdown.append("%s %.1f" % [candidate.get("id", "?"), score])
			if score > best_score:
				best_score = score
				best = candidate
		current_activity = best.duplicate(true)
	_begin_travel()

func score_activity(candidate: Dictionary) -> Dictionary:
	var target := _vector3(candidate.get("position", [0.0, 0.2, 0.0]))
	var schedule_score := 40.0
	var specialty_score := 18.0 if str(candidate.get("specialty", "")) == str(definition.get("specialty", "")) else 0.0
	var aspiration_score := 14.0 if bool(candidate.get("aspiration", false)) else 0.0
	var distance_score := maxf(0.0, 12.0 - global_position.distance_to(target) * 0.35)
	var weather_score := 0.0
	var weather := get_node_or_null("/root/WeatherService")
	if weather != null:
		var likes: Array = definition.get("likes", [])
		weather_score = 8.0 if weather.is_raining() and "rain" in likes else (4.0 if not weather.is_raining() and "clear_weather" in likes else 0.0)
	var comfort_score := (energy + mood + social_openness) * 3.0
	var manager := get_node_or_null("/root/ResidentManager")
	var priority_score := 8.0 if manager != null and manager.current_priority == &"project_restore_garden" and bool(candidate.get("aspiration", false)) else 0.0
	var relationship_score := 0.0
	var relationship_service := get_node_or_null("/root/RelationshipService")
	if relationship_service != null:
		var partner_ids: Array = candidate.get("partner_ids", [])
		for partner_id: Variant in partner_ids:
			relationship_score += float(relationship_service.bond(resident_id, StringName(str(partner_id)))) * 0.08 + relationship_service.compatibility_score(resident_id, StringName(str(partner_id)))
	return {"score": schedule_score + specialty_score + aspiration_score + distance_score + weather_score + comfort_score + priority_score + relationship_score, "schedule":schedule_score, "specialty":specialty_score, "aspiration":aspiration_score, "distance":distance_score, "weather":weather_score, "comfort":comfort_score, "priority":priority_score, "relationship":relationship_score}

func _begin_travel() -> void:
	var target := activity_position()
	navigation_agent.target_position = target
	current_state = State.GOING_HOME if bool(current_activity.get("home", false)) else State.ROUTINE_TRAVEL
	_stuck_seconds = 0.0
	_last_distance = global_position.distance_to(target)
	_update_debug_label()
	activity_changed.emit(resident_id, activity_id(), state_name())

func _physics_process(delta: float) -> void:
	var calendar := get_node_or_null("/root/CalendarService")
	if calendar != null and calendar.is_paused() and current_state != State.TALKING:
		velocity = Vector3.ZERO
		return
	if current_state not in [State.ROUTINE_TRAVEL, State.CONTRIBUTION_TRAVEL, State.SOCIAL_TRAVEL, State.GOING_HOME]:
		velocity = Vector3.ZERO
		_animate_activity()
		return
	var target := activity_position()
	var offset := target - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= arrival_distance:
		global_position = Vector3(target.x, global_position.y, target.z)
		velocity = Vector3.ZERO
		current_state = State.CONTRIBUTING if bool(current_activity.get("project", false)) else (State.SOCIALIZING if bool(current_activity.get("social", false)) else (State.SLEEPING if current_period == &"night" else State.ROUTINE_ACTIVITY))
		activity_bubble.visible = current_state in [State.SOCIALIZING, State.CONTRIBUTING]
		_update_debug_label()
		activity_changed.emit(resident_id, activity_id(), state_name())
		return
	var direction := offset.normalized()
	velocity = direction * move_speed
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 9.0))
	move_and_slide()
	model_root.position.y = 0.06 + absf(sin(Time.get_ticks_msec() * 0.012)) * 0.08
	_stuck_seconds = _stuck_seconds + delta if distance >= _last_distance - 0.01 else 0.0
	_last_distance = distance
	if _stuck_seconds >= 5.0:
		global_position = Vector3(target.x, global_position.y, target.z)
		_stuck_seconds = 0.0

func _animate_activity() -> void:
	if current_state == State.SLEEPING:
		model_root.rotation.z = lerpf(model_root.rotation.z, -0.18, 0.08)
		return
	model_root.rotation.z = lerpf(model_root.rotation.z, sin(Time.get_ticks_msec() * 0.004) * 0.035, 0.12)
	model_root.position.y = 0.06 + sin(Time.get_ticks_msec() * 0.006) * 0.035
	if current_state == State.CONTRIBUTING:
		var action := StringName(str(current_activity.get("work_action", "work")))
		if action == &"build": model_root.rotation.x = sin(Time.get_ticks_msec() * 0.01) * 0.14
		elif action == &"plant": model_root.position.y = 0.02 + absf(sin(Time.get_ticks_msec() * 0.007)) * 0.12
		elif action == &"celebrate": model_root.position.y = 0.08 + absf(sin(Time.get_ticks_msec() * 0.012)) * 0.22
		elif action in [&"operate", &"maintain"]: model_root.rotation.x = sin(Time.get_ticks_msec() * 0.009) * 0.11
		else: model_root.rotation.y += 0.008

func request_contribution(specialty: StringName) -> Dictionary:
	if current_period == &"night" or energy < 0.25:
		return {"accepted":false, "reason":"%s needs to rest first and can help tomorrow." % display_name()}
	if specialty != StringName(str(definition.get("specialty", ""))):
		return {"accepted":false, "reason":"%s says this needs a %s's eye, but will check back later." % [display_name(), specialty]}
	return {"accepted":true, "reason":"%s would like to help when the community project opens." % display_name()}

func begin_project_contribution(phase_id: StringName, label: String, work_action: StringName, target: Vector3) -> void:
	project_phase_id = phase_id
	current_activity = {"id":"garden_%s" % phase_id, "label":label, "location":"community garden", "position":[target.x,target.y,target.z], "project":true, "work_action":String(work_action)}
	activity_bubble.text = _project_icon(work_action)
	activity_bubble.visible = false
	_begin_travel()
	current_state = State.CONTRIBUTION_TRAVEL

func is_project_ready() -> bool:
	return not project_phase_id.is_empty() and current_state == State.CONTRIBUTING

func finish_project_contribution() -> void:
	project_phase_id = &""
	activity_bubble.visible = false
	_select_routine_activity()

func unlock_garden_routine() -> void:
	garden_routine_unlocked = true

func begin_social_activity(session_id: StringName, activity_id_value: StringName, label: String, location: String, target: Vector3, participant_ids: Array[StringName]) -> void:
	social_session_id = session_id
	current_activity = {"id":String(activity_id_value), "label":label, "location":location, "position":[target.x,target.y,target.z], "social":true, "partner_ids":participant_ids}
	current_state = State.SOCIAL_TRAVEL
	activity_bubble.text = _activity_icon(activity_id_value)
	activity_bubble.visible = false
	_begin_social_travel()

func _begin_social_travel() -> void:
	navigation_agent.target_position = activity_position()
	current_state = State.SOCIAL_TRAVEL
	_stuck_seconds = 0.0
	_last_distance = global_position.distance_to(activity_position())
	_update_debug_label()
	activity_changed.emit(resident_id, activity_id(), state_name())

func finish_social_activity() -> void:
	social_session_id = &""
	activity_bubble.visible = false
	_select_routine_activity()

func begin_investigation_meet(target: Vector3) -> void:
	current_activity = {"id":"investigation_meet", "label":"Meets the founder to study a find", "location":"workshop investigation table", "position":[target.x,target.y,target.z]}
	_begin_travel()

func begin_resonance_reaction(tier: int, activation: bool) -> void:
	current_activity = {"id":"first_bloom_reaction" if activation else "resonance_reaction", "label":"Celebrates The First Bloom" if activation else "Listens to the answering stones", "location":"community garden", "position":[global_position.x,global_position.y,global_position.z], "work_action":"celebrate" if activation else "inspect", "project":true}
	current_state = State.CONTRIBUTING
	activity_bubble.text = "✦" if activation else "△"
	activity_bubble.visible = true
	_update_debug_label()

func begin_machine_activity(activity_id_value: StringName, label: String, target: Vector3, action: StringName) -> void:
	current_activity = {"id":String(activity_id_value), "label":label, "location":"workshop machine slot", "position":[target.x,target.y,target.z], "work_action":String(action), "project":true, "machine":true}
	activity_bubble.text = "⚙"
	activity_bubble.visible = false
	_begin_travel()
	current_state = State.CONTRIBUTION_TRAVEL

func begin_event_activity(activity_id_value: StringName, label: String, target: Vector3, action: StringName) -> void:
	current_activity = {"id":String(activity_id_value), "label":label, "location":"First Bloom celebration", "position":[target.x,target.y,target.z], "work_action":String(action), "project":true, "event":true}
	activity_bubble.text = "✦"
	activity_bubble.visible = false
	_begin_travel()
	current_state = State.CONTRIBUTION_TRAVEL

func is_event_ready() -> bool:
	if not bool(current_activity.get("event", false)):
		return false
	# Event staging owns an exact authored slot. Treat arrival at that slot as
	# ready even while a modal pause prevents the normal physics-state handoff;
	# this keeps save restoration and accessible menus from trapping residents.
	var flat_offset := activity_position() - global_position
	flat_offset.y = 0.0
	return current_state == State.CONTRIBUTING or flat_offset.length() <= arrival_distance

func finish_event_activity() -> void:
	activity_bubble.visible = false
	_select_routine_activity()

func is_social_ready(session_id: StringName) -> bool:
	return social_session_id == session_id and current_state == State.SOCIALIZING

func conversation_text() -> String:
	var weather := get_node_or_null("/root/WeatherService")
	var weather_line := "The clearing feels settled today."
	if weather != null and weather.is_raining():
		weather_line = "The rain changes what is worth noticing today."
	var manager := get_node_or_null("/root/ResidentManager")
	var priority_line := "We can choose our first shared priority at the Community Board."
	if manager != null and not String(manager.current_priority).is_empty():
		priority_line = "I am keeping the community priority in mind: %s." % manager.priority_display_name()
	var discovery_line := ""
	if manager != null and not manager.recent_discoveries.is_empty():
		discovery_line = "\nI have been thinking about our recent discovery: %s." % manager.recent_discoveries.back()
	var relationship_line := ""
	var relationship_service := get_node_or_null("/root/RelationshipService")
	if relationship_service != null:
		var memories: Array[Dictionary] = relationship_service.memories_for(resident_id, 1)
		if not memories.is_empty():
			relationship_line = "\nI still smile about this: %s" % str(memories[0].description)
	var steps: Array = definition.get("aspiration_steps", [])
	var aspiration := str(steps[clampi(aspiration_step, 0, steps.size() - 1)]) if not steps.is_empty() else "Find a place in the community."
	return "%s\n\n%s\n%s%s%s\n\nI hope to: %s" % [current_activity.get("label", "Taking a quiet pause."), weather_line, priority_line, discovery_line, relationship_line, aspiration]

## Sent off on (or returned from) a solo expedition -- ExpeditionService owns
## the decision, this just applies it. Hidden and unreachable while away
## rather than idling in place: v1 keeps the trip entirely off-screen at
## home ("just around the bend"), narratively resolved by ExpeditionService.
func set_away(value: bool) -> void:
	if value:
		current_state = State.AWAY
		velocity = Vector3.ZERO
		visible = false
		interaction_anchor.enabled = false
		_update_debug_label()
		activity_changed.emit(resident_id, activity_id(), state_name())
	else:
		visible = true
		interaction_anchor.enabled = true
		_select_routine_activity()

func is_away() -> bool:
	return current_state == State.AWAY

func begin_talking() -> void:
	current_state = State.TALKING
	velocity = Vector3.ZERO
	_update_debug_label()

func end_talking() -> void:
	_select_routine_activity()

func serialize_state() -> Dictionary:
	return {"resident_id":String(resident_id), "position":[global_position.x,global_position.y,global_position.z], "home_id":str(definition.get("home_id", "")), "routine_period":String(current_period), "activity_id":String(activity_id()), "state":state_name(), "energy":energy, "mood":mood, "social_openness":social_openness, "aspiration_step":aspiration_step, "carried_item_id":String(carried_item_id), "garden_routine_unlocked":garden_routine_unlocked}

func restore_state(data: Dictionary) -> void:
	if data.has("position"):
		global_position = _vector3(data.position)
	energy = clampf(float(data.get("energy", 0.85)), 0.0, 1.0)
	mood = clampf(float(data.get("mood", 0.75)), 0.0, 1.0)
	social_openness = clampf(float(data.get("social_openness", 0.65)), 0.0, 1.0)
	aspiration_step = maxi(int(data.get("aspiration_step", 0)), 0)
	carried_item_id = StringName(str(data.get("carried_item_id", "")))
	garden_routine_unlocked = bool(data.get("garden_routine_unlocked", false))

func display_name() -> String:
	return str(definition.get("display_name", resident_id))

func activity_id() -> StringName:
	return StringName(str(current_activity.get("id", "wait")))

func activity_position() -> Vector3:
	return _vector3(current_activity.get("position", definition.get("home_position", [0.0,0.2,0.0])))

func location_name() -> String:
	return str(current_activity.get("location", "village clearing"))

func state_name() -> StringName:
	return StringName(str(State.keys()[current_state]).to_snake_case())

func _on_interaction(_anchor_id: StringName) -> void:
	conversation_requested.emit(self)

func _update_debug_label() -> void:
	debug_label.text = "%s — %s\n%s\n%s" % [display_name(), state_name(), current_activity.get("label", "Waiting"), " | ".join(_score_breakdown)]

func _apply_color(color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	for descendant: Node in model_root.find_children("*", "MeshInstance3D", true, false):
		(descendant as MeshInstance3D).material_override = material

func _vector3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func _activity_icon(activity_id_value: StringName) -> String:
	match activity_id_value:
		&"shared_meal": return "☕"
		&"collaboration": return "✦"
		&"visit": return "⌂"
		&"celebration": return "★"
		&"garden_gathering": return "❀"
		_: return "…"

func _project_icon(work_action: StringName) -> String:
	match work_action:
		&"clear": return "⌁"
		&"build": return "▣"
		&"inspect": return "◉"
		&"plant": return "♣"
		&"celebrate": return "★"
		_: return "✦"
