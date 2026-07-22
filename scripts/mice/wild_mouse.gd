class_name Phase1WildMouse
extends CharacterBody3D

enum MouseState {
	WAIT_FOR_NAVIGATION,
	IDLE,
	WANDER,
	NOTICE_PICNIC,
	MOVE_TO_PICNIC,
	PICNIC_IDLE,
	NEGOTIATE,
	RECRUITED,
	FOLLOW_PLAYER,
	EVALUATE_WORK,
	MOVE_TO_WORKSITE,
	WAIT_FOR_WORK_SLOT,
	WORK,
	TAKE_BREAK,
	SEEK_CHEESE,
	DISCONTENTED_IDLE,
	CELEBRATE_COMPLETION,
}

const ARRIVAL_DISTANCE: float = 0.45
const TARGET_RETRY_DELAY: float = 0.6
const PICNIC_ARRIVAL_DISTANCE: float = 0.65
const FOLLOW_REPATH_INTERVAL: float = 0.4
const FOLLOW_STOP_DISTANCE: float = 1.15
const FOLLOW_RESUME_DISTANCE: float = 1.85
const FOLLOW_TELEPORT_DISTANCE: float = 24.0
const STUCK_CHECK_INTERVAL: float = 1.0
const STUCK_RECOVERY_TIME: float = 3.0
const WORK_EVALUATION_INTERVAL: float = 2.0
const WORK_REPATH_INTERVAL: float = 0.5
const WORK_ARRIVAL_DISTANCE: float = 0.7
const WORK_JOIN_THRESHOLD: float = 20.0
const GIVEN_NAMES: Array[String] = ["Pip", "Mallow", "Nib", "Tansy", "Button", "Cricket", "Pebble", "Mochi", "Thimble", "Clover", "Biscuit", "Juniper"]
const FAMILY_NAMES: Array[String] = ["Whisker", "Quickpaw", "Softstep", "Cheesenose", "Brambletail", "Dewdrop", "Nettle", "Acorn"]
const DEFAULT_PERSONALITY: MousePersonalityData = preload("res://resources/personalities/builder.tres")

@export var personality: MousePersonalityData
@export var show_personality_debug: bool = false
@export var show_work_debug: bool = false
@export var move_speed: float = 2.2
@export var wander_radius: float = 8.0
@export var minimum_pause: float = 0.8
@export var maximum_pause: float = 2.8
@export var rotation_speed: float = 8.0
@export_range(0.1, 2.0, 0.1) var minimum_notice_delay: float = 0.25
@export_range(0.1, 2.0, 0.1) var maximum_notice_delay: float = 0.8

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual_root: Node3D = $VisualRoot
@onready var personality_debug: Label3D = $PersonalityDebug
@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var interaction_area: Area3D = $InteractionArea
@onready var contentment: Node = $MouseContentment
@onready var work_debug: Label3D = $WorkDebug
@onready var recruitment_badge: Label3D = $RecruitmentBadge
@onready var stats_service: Node = get_node("/root/StatsService")
@onready var catnip_drift_service: Node = get_node("/root/CatnipDriftService")
@onready var settlement_manager: Phase2SettlementManager = get_node("/root/SettlementManager") as Phase2SettlementManager

var _state: MouseState = MouseState.WAIT_FOR_NAVIGATION
var _spawn_position: Vector3
var _pause_remaining: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _random := RandomNumberGenerator.new()
var _picnic: Phase1Picnic
var _gathering_position: Vector3
var _inspection_target: Node3D
var _picnic_behavior_remaining: float = 0.0
var generated_name: String = "Wild Mouse"
var is_recruited: bool = false
var current_recruitment_cost: int = 1
var personal_cheese: int = 0
var _state_before_negotiation: MouseState = MouseState.PICNIC_IDLE
var _follow_target: Node3D
var _follow_offset: Vector3 = Vector3.ZERO
var _follow_repath_remaining: float = 0.0
var _follow_is_stopped: bool = false
var _stuck_check_remaining: float = STUCK_CHECK_INTERVAL
var _stuck_time: float = 0.0
var _last_stuck_position: Vector3
var _work_evaluation_remaining: float = WORK_EVALUATION_INTERVAL
var _work_repath_remaining: float = 0.0
var _worksite: ConstructionSite
var _work_slot: Marker3D
var _break_remaining: float = 0.0
var _last_work_score: float = 0.0
var _cheese_target: Node3D


func _ready() -> void:
	add_to_group("wild_mice")
	if personality == null:
		personality = DEFAULT_PERSONALITY
	_spawn_position = global_position
	_random.randomize()
	current_recruitment_cost = maxi(personality.recruitment_cost, 1)
	generated_name = "%s %s" % [GIVEN_NAMES[_random.randi_range(0, GIVEN_NAMES.size() - 1)], FAMILY_NAMES[_random.randi_range(0, FAMILY_NAMES.size() - 1)]]
	navigation_agent.path_desired_distance = 0.25
	navigation_agent.target_desired_distance = ARRIVAL_DISTANCE
	navigation_agent.avoidance_enabled = false
	navigation_agent.radius = 0.35
	navigation_agent.height = 0.7
	personality_debug.text = str(personality.behavior_profile).capitalize()
	personality_debug.modulate = personality.debug_color
	personality_debug.visible = show_personality_debug
	work_debug.visible = show_work_debug and OS.is_debug_build()
	contentment.contentment_changed.connect(_on_contentment_changed)
	interaction_area.input_event.connect(_on_interaction_area_input_event)
	game_state.construction_site_placed.connect(_on_construction_site_placed)
	call_deferred("_wait_for_navigation")


func _wait_for_navigation() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_begin_idle(_random.randf_range(0.2, 1.2))


func _physics_process(delta: float) -> void:
	var position_before_motion := global_position
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	match _state:
		MouseState.IDLE:
			_update_idle(delta)
		MouseState.WANDER:
			_update_navigation(delta, false)
		MouseState.NOTICE_PICNIC:
			_update_notice(delta)
		MouseState.MOVE_TO_PICNIC:
			_update_navigation(delta, true)
		MouseState.PICNIC_IDLE:
			_update_picnic_idle(delta)
		MouseState.NEGOTIATE, MouseState.RECRUITED:
			_stop_planar_motion(delta)
		MouseState.FOLLOW_PLAYER:
			_update_follow_player(delta)
		MouseState.EVALUATE_WORK:
			_evaluate_work_opportunities()
		MouseState.MOVE_TO_WORKSITE:
			_update_move_to_worksite(delta)
		MouseState.WAIT_FOR_WORK_SLOT:
			_update_wait_for_work_slot(delta)
		MouseState.WORK:
			_update_work(delta)
		MouseState.TAKE_BREAK:
			_update_work_break(delta)
		MouseState.SEEK_CHEESE:
			_update_seek_cheese(delta)
		MouseState.DISCONTENTED_IDLE:
			_update_discontented_idle(delta)
		MouseState.CELEBRATE_COMPLETION:
			_update_completion_celebration(delta)
		MouseState.WAIT_FOR_NAVIGATION:
			_stop_planar_motion(delta)

	move_and_slide()
	var constrained_position := settlement_manager.constrain_position_to_settlement(position_before_motion, global_position)
	if not constrained_position.is_equal_approx(global_position):
		global_position = constrained_position
		velocity.x = 0.0
		velocity.z = 0.0
	_update_contentment_presentation(delta)


## Returns the player-facing contentment score.
func get_contentment_score() -> int:
	return contentment.score


func is_unhappy() -> bool:
	return contentment.is_unhappy()


## Returns the readable behavioral band without exposing a hidden personality.
func get_contentment_band() -> String:
	var score := get_contentment_score()
	if score >= 14:
		return "Cheerful"
	if score >= 7:
		return "Settled"
	if score >= 4:
		return "Uneasy"
	return "Miserable"


func set_work_debug_visible(enabled: bool) -> void:
	show_work_debug = enabled and OS.is_debug_build()
	work_debug.visible = show_work_debug


## Applies a signed contentment change for future needs, work, and event systems.
func adjust_contentment(amount: int) -> int:
	return contentment.adjust(amount)


func get_personal_cheese() -> int:
	return personal_cheese


func receive_personal_cheese(amount: int) -> int:
	if amount <= 0:
		return personal_cheese
	personal_cheese += amount
	_eat_personal_cheese_for_contentment()
	return personal_cheese


## Computes future work-group decay, including unhappy coworker influence.
func get_work_contentment_decay(base_decay: float, coworkers: Array[Phase1WildMouse]) -> float:
	var coworker_contentment: Array[Node] = []
	for coworker: Phase1WildMouse in coworkers:
		if coworker != null:
			coworker_contentment.append(coworker.contentment)
	return contentment.get_coworker_adjusted_decay(base_decay, coworker_contentment)


func _on_interaction_area_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	game_state.mouse_inspected.emit(self)


## Common interaction entry point. Only settled picnic attendees will negotiate.
func interact(_interactor: Node3D) -> void:
	if is_recruited:
		game_state.request_feedback("%s has already joined your settlement." % generated_name)
		return
	if _picnic != null and _picnic.has_completed_conversation(self):
		game_state.request_feedback("You have already spoken with %s at this picnic." % generated_name)
		return
	if _state != MouseState.PICNIC_IDLE:
		game_state.request_feedback("This mouse is too busy to talk right now.")
		return
	begin_picnic_negotiation()


## Opens this attendee's offer from either the world interaction or picnic
## picker. The picker may be used while the mouse is still walking to its mat.
func begin_picnic_negotiation() -> bool:
	if is_recruited or _picnic == null or _picnic.has_completed_conversation(self):
		return false
	_state_before_negotiation = _state
	_state = MouseState.NEGOTIATE
	if not game_state.open_mouse_dialogue(self):
		_state = _state_before_negotiation
		return false
	return true


func get_interaction_priority() -> int:
	return 10 if _state == MouseState.PICNIC_IDLE and not is_recruited and (_picnic == null or not _picnic.has_completed_conversation(self)) else 0


func get_interaction_prompt() -> String:
	if is_recruited:
		return ""
	if _state == MouseState.PICNIC_IDLE and (_picnic == null or not _picnic.has_completed_conversation(self)):
		return "Press E to talk to %s" % generated_name
	return ""


func get_display_name() -> String:
	return generated_name


func get_dialogue_text() -> String:
	var lines := personality.picnic_dialogue
	if lines.is_empty():
		return "The mouse watches you cautiously."
	return lines[_random.randi_range(0, lines.size() - 1)]


## Attempts the cheese transaction exactly once and enters the recruited state on success.
func try_recruit() -> bool:
	if is_recruited:
		return false
	var cost := get_recruitment_cost()
	if not game_state.spend_cheese(cost):
		game_state.request_feedback("%s wants %d cheese, but you do not have enough." % [generated_name, cost])
		revise_price_after_decline()
		return false
	is_recruited = true
	_state = MouseState.RECRUITED
	navigation_agent.target_position = global_position
	remove_from_group("wild_mice")
	add_to_group("recruited_mice")
	recruitment_badge.text = "✓ RECRUITED\n%s • waiting patiently" % generated_name
	recruitment_badge.show()
	_work_evaluation_remaining = 0.15
	# A picnic attendee stays at the gathering until the host ends or packs it.
	# Direct/scripted recruitment outside a picnic can begin following immediately.
	if _picnic == null:
		_begin_following()
	game_state.mouse_recruited.emit(self)
	game_state.recruited_mouse_count_changed.emit(game_state.get_recruited_mouse_count())
	game_state.request_feedback("%s joined and will wait patiently. Talk to every mouse at the picnic, or pack it, before choosing a building." % generated_name)
	return true


func _on_construction_site_placed(_site: ConstructionSite) -> void:
	if is_recruited:
		_work_evaluation_remaining = 0.1


## Assigns a stable formation slot and starts navigation toward the founder.
func _begin_following() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_state = MouseState.RECRUITED
		return
	_follow_target = players[0] as Node3D
	var recruits := get_tree().get_nodes_in_group("recruited_mice")
	var slot_index := maxi(recruits.find(self), 0)
	var row := slot_index / 2
	var side: float = -1.0 if slot_index % 2 == 0 else 1.0
	_follow_offset = Vector3(side * (1.15 + float(row) * 0.35), 0.0, 1.8 + float(row) * 1.05)
	_follow_repath_remaining = 0.0
	_follow_is_stopped = false
	_stuck_check_remaining = STUCK_CHECK_INTERVAL
	_stuck_time = 0.0
	_last_stuck_position = global_position
	navigation_agent.target_desired_distance = FOLLOW_STOP_DISTANCE
	_state = MouseState.FOLLOW_PLAYER


func _update_follow_player(delta: float) -> void:
	_work_evaluation_remaining -= delta
	if _work_evaluation_remaining <= 0.0:
		_state = MouseState.EVALUATE_WORK
		return
	if not is_instance_valid(_follow_target):
		_begin_following()
		_stop_planar_motion(delta)
		return
	var desired_position := _get_follow_position()
	var distance_to_slot := global_position.distance_to(desired_position)
	if global_position.distance_to(_follow_target.global_position) >= FOLLOW_TELEPORT_DISTANCE:
		_recover_follow_position(desired_position, true)
		return
	if _follow_is_stopped:
		if distance_to_slot <= FOLLOW_RESUME_DISTANCE:
			_stop_planar_motion(delta)
			return
		_follow_is_stopped = false
	if distance_to_slot <= FOLLOW_STOP_DISTANCE:
		_follow_is_stopped = true
		navigation_agent.target_position = global_position
		_stop_planar_motion(delta)
		return

	_follow_repath_remaining -= delta
	if _follow_repath_remaining <= 0.0:
		_follow_repath_remaining = FOLLOW_REPATH_INTERVAL
		var map_rid := navigation_agent.get_navigation_map()
		if _navigation_is_ready(map_rid):
			navigation_agent.target_position = NavigationServer3D.map_get_closest_point(map_rid, desired_position)

	if navigation_agent.is_navigation_finished() or not navigation_agent.is_target_reachable():
		_stop_planar_motion(delta)
		_update_stuck_recovery(delta, desired_position)
		return
	var next_position := navigation_agent.get_next_path_position()
	var flat_direction := next_position - global_position
	flat_direction.y = 0.0
	if flat_direction.length() <= ARRIVAL_DISTANCE:
		_stop_planar_motion(delta)
		return
	var direction := flat_direction.normalized()
	var active_speed := move_speed * personality.move_speed_multiplier * _get_contentment_move_multiplier() * _get_resonance_move_multiplier()
	velocity.x = direction.x * active_speed
	velocity.z = direction.z * active_speed
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
	_update_stuck_recovery(delta, desired_position)


func _get_follow_position() -> Vector3:
	return _follow_target.global_position 		+ _follow_target.global_basis.x * _follow_offset.x 		+ _follow_target.global_basis.z * _follow_offset.z


func _update_stuck_recovery(delta: float, desired_position: Vector3) -> void:
	_stuck_check_remaining -= delta
	if _stuck_check_remaining > 0.0:
		return
	var moved_distance := global_position.distance_to(_last_stuck_position)
	_stuck_time = _stuck_time + STUCK_CHECK_INTERVAL if moved_distance < 0.12 else 0.0
	_last_stuck_position = global_position
	_stuck_check_remaining = STUCK_CHECK_INTERVAL
	if _stuck_time >= STUCK_RECOVERY_TIME:
		_recover_follow_position(desired_position, false)


func _recover_follow_position(desired_position: Vector3, allow_teleport: bool) -> void:
	var map_rid := navigation_agent.get_navigation_map()
	if not _navigation_is_ready(map_rid):
		return
	var safe_position := NavigationServer3D.map_get_closest_point(map_rid, desired_position)
	if allow_teleport:
		global_position = safe_position + Vector3.UP * 0.05
	navigation_agent.target_position = safe_position
	_follow_repath_remaining = FOLLOW_REPATH_INTERVAL
	_follow_is_stopped = false
	_stuck_time = 0.0
	_last_stuck_position = global_position


## Restores picnic behavior after a declined or closed offer.
## Randomly raises or lowers the next asking price after a declined negotiation.
func revise_price_after_decline() -> int:
	if is_recruited:
		return current_recruitment_cost
	var change: int = -1 if _random.randi_range(0, 1) == 0 else 1
	current_recruitment_cost = maxi(current_recruitment_cost + change, 1)
	return current_recruitment_cost


func close_negotiation() -> void:
	var attended_picnic := _picnic
	if _state == MouseState.NEGOTIATE:
		_state = MouseState.PICNIC_IDLE if attended_picnic != null else MouseState.IDLE
	elif not is_recruited or attended_picnic == null:
		return
	attended_picnic.complete_conversation(self)


## Returns whether this wild mouse can respond to a new picnic event.
func is_eligible_for_picnic() -> bool:
	return _picnic == null and _state not in [
		MouseState.NOTICE_PICNIC,
		MouseState.MOVE_TO_PICNIC,
		MouseState.PICNIC_IDLE,
	]


## Chooses a marker that reinforces this mouse's hidden behavior.
func choose_gathering_marker(markers: Array[Node], picnic: Phase1Picnic) -> Marker3D:
	if markers.is_empty() or picnic == null:
		return null
	var chosen := markers[0] as Marker3D
	if personality.behavior_profile == &"hoarder":
		var food_position := picnic.get_food_position()
		for node: Node in markers:
			var marker := node as Marker3D
			if marker != null and marker.global_position.distance_squared_to(food_position) < chosen.global_position.distance_squared_to(food_position):
				chosen = marker
	elif personality.behavior_profile == &"curious":
		for node: Node in markers:
			var marker := node as Marker3D
			if marker != null and marker.global_position.distance_squared_to(picnic.global_position) > chosen.global_position.distance_squared_to(picnic.global_position):
				chosen = marker
	return chosen


## Reserves a destination and begins the mouse's response sequence.
func respond_to_picnic(picnic: Phase1Picnic, gathering_position: Vector3) -> bool:
	if not is_eligible_for_picnic() or picnic == null:
		return false
	_picnic = picnic
	_gathering_position = gathering_position
	_state = MouseState.NOTICE_PICNIC
	var notice_delay := _random.randf_range(minimum_notice_delay, maximum_notice_delay)
	_pause_remaining = notice_delay * personality.notice_delay_multiplier
	_picnic_behavior_remaining = _random.randf_range(1.2, 2.2)
	navigation_agent.target_position = global_position
	return true


## Releases this mouse from the supplied picnic and resumes wandering.
func release_from_picnic(picnic: Phase1Picnic) -> void:
	if picnic != _picnic:
		return
	_picnic = null
	visual_root.position.y = 0.0
	if is_recruited:
		recruitment_badge.text = "✓ RECRUITED\n%s • ready to build" % generated_name
		_work_evaluation_remaining = 0.15
		_begin_following()
	else:
		_begin_idle(_random.randf_range(minimum_pause, maximum_pause))


func get_state_name() -> String:
	return MouseState.keys()[_state]


func get_picnic_dialogue() -> Array[String]:
	return personality.picnic_dialogue


func get_recruitment_dialogue() -> Array[String]:
	return personality.recruitment_dialogue


func get_recruitment_cost() -> int:
	return current_recruitment_cost


func collect_random_cheese(amount: int) -> void:
	if amount <= 0 or is_recruited:
		return
	current_recruitment_cost += amount
	game_state.request_feedback("%s found %d cheese. Their recruitment price is now %d." % [generated_name, amount, current_recruitment_cost])
	_cheese_target = null
	_begin_idle(_random.randf_range(minimum_pause, maximum_pause))


func _update_idle(delta: float) -> void:
	_pause_remaining -= delta
	_stop_planar_motion(delta)
	if is_instance_valid(_inspection_target):
		_face_position(_inspection_target.global_position, delta)
	if _pause_remaining <= 0.0:
		if _try_seek_settlement_cheese():
			return
		_choose_wander_target()


func _try_seek_settlement_cheese() -> bool:
	if is_recruited or _picnic != null:
		return false
	var nearest: Node3D
	var nearest_distance := INF
	for node: Node in get_tree().get_nodes_in_group("settlement_cheese_pickups"):
		var pickup := node as Node3D
		if pickup == null or pickup.is_queued_for_deletion():
			continue
		var distance := global_position.distance_to(pickup.global_position)
		if distance < nearest_distance:
			nearest = pickup
			nearest_distance = distance
	if nearest == null:
		return false
	_cheese_target = nearest
	navigation_agent.target_desired_distance = ARRIVAL_DISTANCE
	navigation_agent.target_position = nearest.global_position
	_state = MouseState.SEEK_CHEESE
	return true


func _update_seek_cheese(delta: float) -> void:
	if is_recruited or not is_instance_valid(_cheese_target) or _cheese_target.is_queued_for_deletion():
		_cheese_target = null
		_begin_idle(_random.randf_range(minimum_pause, maximum_pause))
		return
	if global_position.distance_to(_cheese_target.global_position) <= ARRIVAL_DISTANCE + 0.25:
		_cheese_target.call("collect", self)
		return
	navigation_agent.target_position = _cheese_target.global_position
	_update_navigation(delta, false)


func _update_notice(delta: float) -> void:
	_pause_remaining -= delta
	_stop_planar_motion(delta)
	if _picnic != null:
		_face_position(_picnic.global_position, delta)
	if _pause_remaining <= 0.0:
		_begin_picnic_navigation()


func _update_picnic_idle(delta: float) -> void:
	_stop_planar_motion(delta)
	if _picnic == null:
		visual_root.position.y = 0.0
		_begin_idle(TARGET_RETRY_DELAY)
		return
	_picnic_behavior_remaining -= delta
	match personality.behavior_profile:
		&"builder":
			_face_position(_picnic.get_bell_position(), delta)
		&"curious":
			var focus := _picnic.get_food_position() if int(_picnic_behavior_remaining * 2.0) % 2 == 0 else _picnic.get_bell_position()
			_face_position(focus, delta)
		&"lazy":
			visual_root.position.y = lerpf(visual_root.position.y, -0.09, delta * 4.0)
			if _picnic_behavior_remaining <= 0.0:
				_picnic_behavior_remaining = _random.randf_range(2.5, 4.0)
		&"hoarder":
			_face_position(_picnic.get_food_position(), delta)
			if _picnic_behavior_remaining <= 0.0:
				_begin_hoarder_circle()


func _choose_wander_target() -> void:
	var map_rid := navigation_agent.get_navigation_map()
	if not _navigation_is_ready(map_rid):
		_begin_idle(TARGET_RETRY_DELAY)
		return

	var active_wander_radius := wander_radius * personality.wander_radius_multiplier
	var random_offset := Vector3(
		_random.randf_range(-active_wander_radius, active_wander_radius),
		0.0,
		_random.randf_range(-active_wander_radius, active_wander_radius)
	)
	var requested_target := _spawn_position + random_offset
	var safe_target := NavigationServer3D.map_get_closest_point(map_rid, requested_target)
	safe_target = settlement_manager.constrain_position_to_settlement(global_position, safe_target)
	if safe_target.distance_to(global_position) < 1.0:
		_begin_idle(TARGET_RETRY_DELAY)
		return

	_inspection_target = null
	navigation_agent.target_position = safe_target
	_state = MouseState.WANDER


func _begin_picnic_navigation() -> void:
	if _picnic == null:
		_begin_idle(TARGET_RETRY_DELAY)
		return
	var map_rid := navigation_agent.get_navigation_map()
	if not _navigation_is_ready(map_rid):
		_pause_remaining = TARGET_RETRY_DELAY
		return
	var safe_target := NavigationServer3D.map_get_closest_point(map_rid, _gathering_position)
	if safe_target.distance_to(_gathering_position) > 1.5:
		_fail_picnic_response()
		return
	_gathering_position = safe_target
	navigation_agent.target_desired_distance = PICNIC_ARRIVAL_DISTANCE
	navigation_agent.target_position = _gathering_position
	_state = MouseState.MOVE_TO_PICNIC


func _begin_hoarder_circle() -> void:
	if _picnic == null:
		return
	var angle := _random.randf_range(0.0, TAU)
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * _random.randf_range(0.75, 1.1)
	var map_rid := navigation_agent.get_navigation_map()
	_gathering_position = NavigationServer3D.map_get_closest_point(map_rid, _picnic.get_food_position() + offset)
	navigation_agent.target_position = _gathering_position
	_state = MouseState.MOVE_TO_PICNIC
	_picnic_behavior_remaining = _random.randf_range(1.1, 2.0)


func _update_navigation(delta: float, moving_to_picnic: bool) -> void:
	var distance_to_target := global_position.distance_to(
		_gathering_position if moving_to_picnic else navigation_agent.target_position
	)
	if navigation_agent.is_navigation_finished() or (
		moving_to_picnic and distance_to_target <= PICNIC_ARRIVAL_DISTANCE
	):
		if moving_to_picnic:
			_state = MouseState.PICNIC_IDLE
			navigation_agent.target_position = global_position
			_stop_planar_motion(delta)
		else:
			_begin_idle(_random.randf_range(minimum_pause, maximum_pause))
		return
	if not navigation_agent.is_target_reachable():
		if moving_to_picnic:
			_fail_picnic_response()
		else:
			_begin_idle(TARGET_RETRY_DELAY)
		return

	var next_position := navigation_agent.get_next_path_position()
	var flat_direction := next_position - global_position
	flat_direction.y = 0.0
	if flat_direction.length() <= ARRIVAL_DISTANCE:
		return

	var direction := flat_direction.normalized()
	var active_speed := move_speed * personality.move_speed_multiplier * _get_contentment_move_multiplier() * _get_resonance_move_multiplier()
	velocity.x = direction.x * active_speed
	velocity.z = direction.z * active_speed
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)


func _fail_picnic_response() -> void:
	var failed_picnic := _picnic
	_picnic = null
	visual_root.position.y = 0.0
	if failed_picnic != null:
		failed_picnic.release_mouse(self)
	_begin_idle(TARGET_RETRY_DELAY)


func _begin_idle(duration: float) -> void:
	_state = MouseState.IDLE
	_pause_remaining = duration * personality.pause_duration_multiplier
	navigation_agent.target_desired_distance = ARRIVAL_DISTANCE
	navigation_agent.target_position = global_position
	_inspection_target = null
	if _random.randf() <= personality.inspection_frequency:
		_inspection_target = _find_nearest_interest_point()
		_pause_remaining *= 1.35


func _find_nearest_interest_point() -> Node3D:
	var nearest: Node3D
	var nearest_distance := INF
	for node: Node in get_tree().get_nodes_in_group("points_of_interest"):
		var point := node as Node3D
		if point == null:
			continue
		var distance := global_position.distance_squared_to(point.global_position)
		if distance < nearest_distance and distance <= 49.0:
			nearest = point
			nearest_distance = distance
	return nearest


func _stop_planar_motion(delta: float) -> void:
	var active_speed := move_speed * personality.move_speed_multiplier * _get_contentment_move_multiplier() * _get_resonance_move_multiplier()
	velocity.x = move_toward(velocity.x, 0.0, active_speed * 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, active_speed * 5.0 * delta)


func _face_position(position: Vector3, delta: float) -> void:
	var direction := position - global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)


func _navigation_is_ready(map_rid: RID) -> bool:
	return map_rid.is_valid() and NavigationServer3D.map_get_iteration_id(map_rid) > 0


func _evaluate_work_opportunities() -> void:
	_work_evaluation_remaining = WORK_EVALUATION_INTERVAL + _random.randf_range(-0.35, 0.35)
	if not is_recruited or get_contentment_score() <= 3:
		_last_work_score = -100.0
		work_debug.text = "Work refused: discontented"
		_state = MouseState.DISCONTENTED_IDLE
		_break_remaining = 2.5
		return
	var best_site: ConstructionSite
	var best_score := -INF
	for node: Node in get_tree().get_nodes_in_group("construction_sites"):
		var site := node as ConstructionSite
		if site == null or not site.is_accepting_workers():
			continue
		var score := _score_worksite(site)
		if score > best_score:
			best_score = score
			best_site = site
	_last_work_score = best_score if best_site != null else 0.0
	work_debug.text = "Work %.1f / %.0f" % [_last_work_score, WORK_JOIN_THRESHOLD]
	if best_site != null and best_score >= WORK_JOIN_THRESHOLD:
		_commit_to_worksite(best_site)
	else:
		_state = MouseState.FOLLOW_PLAYER


func _score_worksite(site: ConstructionSite) -> float:
	var distance_penalty := global_position.distance_to(site.global_position) * 1.5
	var bribe_multiplier := personality.get_effect(&"bribe_willingness_multiplier", 1.0)
	var bribe_bonus := site.get_bribe_willingness_value() * bribe_multiplier
	var contentment_bonus := float(get_contentment_score() - 10) * 1.5
	var crowding_penalty := float(site.get_worker_count()) * 6.0
	return 50.0 + personality.get_effect(&"construction_willingness", 0.0) + bribe_bonus + contentment_bonus - distance_penalty - crowding_penalty + _random.randf_range(-8.0, 8.0)


func _commit_to_worksite(site: ConstructionSite) -> void:
	var slot := site.reserve_worker(self)
	if slot == null:
		_state = MouseState.WAIT_FOR_WORK_SLOT
		_worksite = site
		_break_remaining = 1.0
		return
	_worksite = site
	_work_slot = slot
	_work_repath_remaining = 0.0
	navigation_agent.target_desired_distance = WORK_ARRIVAL_DISTANCE
	_state = MouseState.MOVE_TO_WORKSITE


func _update_move_to_worksite(delta: float) -> void:
	if not is_instance_valid(_worksite) or not is_instance_valid(_work_slot):
		_abandon_worksite()
		return
	var target := _work_slot.global_position
	if global_position.distance_to(target) <= WORK_ARRIVAL_DISTANCE:
		navigation_agent.target_position = global_position
		_worksite.set_worker_active(self, true)
		_state = MouseState.WORK
		_stop_planar_motion(delta)
		return
	_work_repath_remaining -= delta
	if _work_repath_remaining <= 0.0:
		_work_repath_remaining = WORK_REPATH_INTERVAL
		navigation_agent.target_position = target
	if navigation_agent.is_navigation_finished() or not navigation_agent.is_target_reachable():
		_abandon_worksite()
		return
	var direction := navigation_agent.get_next_path_position() - global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	direction = direction.normalized()
	var active_speed := move_speed * personality.move_speed_multiplier * _get_contentment_move_multiplier() * _get_resonance_move_multiplier()
	velocity.x = direction.x * active_speed
	velocity.z = direction.z * active_speed
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), rotation_speed * delta)


func _update_wait_for_work_slot(delta: float) -> void:
	_stop_planar_motion(delta)
	_break_remaining -= delta
	if _break_remaining <= 0.0:
		if is_instance_valid(_worksite):
			_commit_to_worksite(_worksite)
		else:
			_abandon_worksite()


func _update_work(delta: float) -> void:
	if not is_instance_valid(_worksite):
		_abandon_worksite()
		return
	_stop_planar_motion(delta)
	_face_position(_worksite.global_position, delta)


func _start_work_break() -> void:
	if is_instance_valid(_worksite):
		_worksite.release_worker(self)
	_work_slot = null
	_break_remaining = _random.randf_range(3.0, 5.0) * (1.35 if personality.behavior_profile == &"lazy" else 1.0)
	_state = MouseState.TAKE_BREAK


func _update_work_break(delta: float) -> void:
	_stop_planar_motion(delta)
	visual_root.position.y = lerpf(visual_root.position.y, -0.07, delta * 4.0)
	_break_remaining -= delta
	if _break_remaining <= 0.0:
		visual_root.position.y = 0.0
		_worksite = null
		_begin_following()
		_work_evaluation_remaining = 0.8


func _update_discontented_idle(delta: float) -> void:
	_stop_planar_motion(delta)
	_break_remaining -= delta
	if is_instance_valid(game_state.placed_picnic):
		_face_position(game_state.placed_picnic.global_position, delta)
	if _break_remaining <= 0.0:
		_begin_following()
		_work_evaluation_remaining = WORK_EVALUATION_INTERVAL


func _update_completion_celebration(delta: float) -> void:
	_stop_planar_motion(delta)
	_break_remaining -= delta
	visual_root.rotation.y += delta * 3.5
	if _break_remaining <= 0.0:
		visual_root.rotation.y = 0.0
		_begin_following()
		_work_evaluation_remaining = 1.0


func _abandon_worksite() -> void:
	if is_instance_valid(_worksite):
		_worksite.release_worker(self)
	_worksite = null
	_work_slot = null
	_begin_following()
	_work_evaluation_remaining = WORK_EVALUATION_INTERVAL


func _on_worksite_completed(site: ConstructionSite, _building: Node3D) -> void:
	if site != _worksite:
		return
	site.release_worker(self)
	_worksite = null
	_work_slot = null
	_break_remaining = 2.0
	_state = MouseState.CELEBRATE_COMPLETION


func _on_worksite_cancelled(site: ConstructionSite) -> void:
	if site == _worksite:
		_abandon_worksite()


func receive_work_bribe(cheese_share: int) -> void:
	if cheese_share <= 0:
		return
	receive_personal_cheese(cheese_share)
	adjust_contentment(2 if personality.behavior_profile in [&"lazy", &"hoarder"] else 1)


func _get_contentment_move_multiplier() -> float:
	match get_contentment_band():
		"Cheerful":
			return 1.08
		"Uneasy":
			return 0.9
		"Miserable":
			return 0.72
		_:
			return 1.0


func _get_resonance_move_multiplier() -> float:
	return maxf(float(stats_service.call("get_effective", "global_mice", "movement_speed", 1.0)), 0.0)


func get_catnip_drift_work_multiplier() -> float:
	var grid_position := settlement_manager.world_to_resonance_grid(global_position)
	var scent := float(catnip_drift_service.call("get_scent_at", grid_position))
	if scent >= 0.85:
		return 0.75
	return 1.0 + scent * 0.4


func _update_contentment_presentation(delta: float) -> void:
	var target_scale := Vector3.ONE
	match get_contentment_band():
		"Cheerful":
			target_scale = Vector3.ONE * 1.03
		"Uneasy":
			target_scale = Vector3(0.98, 0.96, 0.98)
		"Miserable":
			target_scale = Vector3(1.0, 0.88, 1.0)
	visual_root.scale = visual_root.scale.lerp(target_scale, minf(delta * 4.0, 1.0))


func _on_contentment_changed(_new_score: int) -> void:
	_eat_personal_cheese_for_contentment()


func _eat_personal_cheese_for_contentment() -> int:
	var score := get_contentment_score()
	if score > 6 or personal_cheese <= 0:
		return 0
	var eaten := mini(10 - score, personal_cheese)
	if eaten <= 0:
		return 0
	personal_cheese -= eaten
	contentment.adjust(eaten)
	game_state.request_feedback("%s ate %d personal cheese and recovered to %d contentment." % [generated_name, eaten, get_contentment_score()])
	return eaten
