class_name Phase1Picnic
extends Node3D

signal bell_rung(picnic: Phase1Picnic)
signal picnic_started(picnic: Phase1Picnic)
signal picnic_ended(picnic: Phase1Picnic)

@export_range(2.0, 30.0, 0.5) var attraction_radius: float = 13.0
@export_range(5.0, 120.0, 1.0) var event_duration: float = 30.0
@export var show_attraction_radius: bool = false

@onready var interaction_area: Area3D = $InteractionArea
@onready var bell_visual: MeshInstance3D = $Bell
@onready var food_visual: MeshInstance3D = $Basket
@onready var gathering_positions: Node3D = $GatheringPositions
@onready var attraction_debug: MeshInstance3D = $AttractionRadiusDebug
@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState

var _bell_tween: Tween
var _event_active: bool = false
var _event_time_remaining: float = 0.0
var _reservations: Dictionary = {}


func _ready() -> void:
	attraction_debug.visible = show_attraction_radius
	attraction_debug.scale = Vector3(attraction_radius, 1.0, attraction_radius)


func _process(delta: float) -> void:
	if not _event_active:
		return
	_event_time_remaining -= delta
	if _event_time_remaining <= 0.0:
		end_picnic_event()


## Enables or disables preview-only behavior.
func set_preview_mode(enabled: bool) -> void:
	interaction_area.monitoring = not enabled
	interaction_area.monitorable = not enabled
	interaction_area.collision_layer = 0 if enabled else 2
	set_process(not enabled)


## Common interaction entry point used by the player.
func interact(_interactor: Node3D) -> void:
	if _event_active:
		game_state.request_feedback("The picnic is already underway.")
		return
	_animate_bell()
	_start_picnic_event()


func get_interaction_priority() -> int:
	return 1


func get_interaction_prompt() -> String:
	return "Press E to ring the picnic bell"


func is_event_active() -> bool:
	return _event_active


func get_attendee_count() -> int:
	return _reservations.size()


func get_food_position() -> Vector3:
	return food_visual.global_position


func get_bell_position() -> Vector3:
	return bell_visual.global_position


## Frees a reservation when a mouse cannot reach its assigned position.
func release_mouse(mouse: Phase1WildMouse) -> void:
	if not _reservations.has(mouse):
		return
	_reservations.erase(mouse)


## Ends the current gathering and returns attendees to wandering.
func end_picnic_event() -> void:
	if not _event_active:
		return
	_event_active = false
	_event_time_remaining = 0.0
	for mouse: Phase1WildMouse in _reservations.keys():
		if is_instance_valid(mouse):
			mouse.release_from_picnic(self)
	_reservations.clear()
	picnic_ended.emit(self)
	game_state.request_feedback("The picnic winds down. Ring the bell to gather mice again.")


func _start_picnic_event() -> void:
	_event_active = true
	_event_time_remaining = event_duration
	_reservations.clear()

	var eligible_mice: Array[Phase1WildMouse] = []
	for node: Node in get_tree().get_nodes_in_group("wild_mice"):
		var mouse := node as Phase1WildMouse
		if mouse != null and mouse.is_eligible_for_picnic():
			if mouse.global_position.distance_to(global_position) <= attraction_radius:
				eligible_mice.append(mouse)
	eligible_mice.sort_custom(
		func(a: Phase1WildMouse, b: Phase1WildMouse) -> bool:
			return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position)
	)

	var available_markers: Array[Node] = gathering_positions.get_children()
	var response_count := mini(eligible_mice.size(), available_markers.size())
	for index: int in response_count:
		var mouse := eligible_mice[index]
		var marker := mouse.choose_gathering_marker(available_markers, self)
		if marker != null and mouse.respond_to_picnic(self, marker.global_position):
			_reservations[mouse] = marker
			available_markers.erase(marker)

	bell_rung.emit(self)
	picnic_started.emit(self)
	game_state.picnic_started.emit(self)
	if response_count == 0:
		game_state.request_feedback("The bell rings, but no wild mice are close enough.")
	else:
		game_state.request_feedback("%d wild mice heard the picnic bell." % _reservations.size())


func _animate_bell() -> void:
	if _bell_tween != null and _bell_tween.is_running():
		_bell_tween.kill()
	_bell_tween = create_tween()
	_bell_tween.tween_property(bell_visual, "rotation_degrees:z", 18.0, 0.08)
	_bell_tween.tween_property(bell_visual, "rotation_degrees:z", -18.0, 0.12)
	_bell_tween.tween_property(bell_visual, "rotation_degrees:z", 0.0, 0.08)
