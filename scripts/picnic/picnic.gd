class_name Phase1Picnic
extends Node3D

signal bell_rung(picnic: Phase1Picnic)
signal picnic_started(picnic: Phase1Picnic)
signal picnic_ended(picnic: Phase1Picnic)

@export_range(2.0, 30.0, 0.5) var attraction_radius: float = 13.0
@export var show_attraction_radius: bool = false

@onready var interaction_area: Area3D = $InteractionArea
@onready var bell_visual: MeshInstance3D = $Bell
@onready var food_visual: MeshInstance3D = $Basket
@onready var gathering_positions: Node3D = $GatheringPositions
@onready var attraction_debug: MeshInstance3D = $AttractionRadiusDebug
@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState

var _bell_tween: Tween
var _event_active: bool = false
var _reservations: Dictionary = {}
var _completed_conversations: Dictionary = {}


func _ready() -> void:
	attraction_debug.visible = show_attraction_radius
	attraction_debug.scale = Vector3(attraction_radius, 1.0, attraction_radius)


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


## Releases every attendee and removes this picnic so it can be placed elsewhere.
func pack_up() -> void:
	if _event_active:
		_complete_conversation_cycle(true)
	else:
		_release_attendees()
	if game_state.unregister_picnic(self) and not game_state.is_build_menu_open:
		game_state.request_feedback("Picnic packed up. Press P to place it near other wild mice.")
	queue_free()


func get_food_position() -> Vector3:
	return food_visual.global_position


func get_bell_position() -> Vector3:
	return bell_visual.global_position


## Frees a reservation when a mouse cannot reach its assigned position.
func release_mouse(mouse: Phase1WildMouse) -> void:
	if not _reservations.has(mouse):
		return
	_reservations.erase(mouse)
	_completed_conversations.erase(mouse)
	_check_conversation_cycle_complete()


## Records one completed founder conversation, whether its offer was accepted or declined.
func complete_conversation(mouse: Phase1WildMouse) -> void:
	if not _event_active or not _reservations.has(mouse):
		return
	_completed_conversations[mouse] = true
	_check_conversation_cycle_complete()
	var remaining := get_remaining_conversation_count()
	if _event_active and remaining > 0:
		game_state.request_feedback("Conversation complete. %d mice still await their turn." % remaining)


func has_completed_conversation(mouse: Phase1WildMouse) -> bool:
	return _completed_conversations.has(mouse)


func get_remaining_conversation_count() -> int:
	var remaining := 0
	for mouse: Phase1WildMouse in _reservations:
		if is_instance_valid(mouse) and not _completed_conversations.has(mouse):
			remaining += 1
	return remaining


## Ends the current gathering and returns attendees to wandering.
func end_picnic_event(show_feedback: bool = true) -> void:
	if not _event_active:
		return
	_event_active = false
	_release_attendees()
	_completed_conversations.clear()
	picnic_ended.emit(self)
	if show_feedback:
		game_state.request_feedback("The picnic winds down. Ring the bell to gather mice again.")


func _release_attendees() -> void:
	for mouse: Phase1WildMouse in _reservations.keys():
		if is_instance_valid(mouse):
			mouse.release_from_picnic(self)
	_reservations.clear()


func _start_picnic_event() -> void:
	_event_active = true
	_reservations.clear()
	_completed_conversations.clear()
	game_state.set_build_menu_open(false)

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
		game_state.request_feedback("%d wild mice arrived. Talk to each mouse, or press P to pack the picnic." % _reservations.size())


func _check_conversation_cycle_complete() -> void:
	if not _event_active or _reservations.is_empty():
		return
	if get_remaining_conversation_count() == 0:
		_complete_conversation_cycle(false)


func _complete_conversation_cycle(was_packed: bool) -> void:
	if not _event_active:
		return
	var recruited_count := 0
	for mouse: Phase1WildMouse in _reservations:
		if is_instance_valid(mouse) and mouse.is_recruited:
			recruited_count += 1
	end_picnic_event(false)
	if recruited_count > 0:
		game_state.set_build_menu_open(true)
		var reason := "Picnic packed" if was_packed else "Everyone has had a turn"
		game_state.request_feedback("%s. Choose what your %d new mice should build (1–4)." % [reason, recruited_count])
	elif was_packed:
		game_state.request_feedback("Picnic packed. No mice were recruited; press P to place it elsewhere.")
	else:
		game_state.request_feedback("Everyone has had a turn, but no mice joined this time.")


func _animate_bell() -> void:
	if _bell_tween != null and _bell_tween.is_running():
		_bell_tween.kill()
	_bell_tween = create_tween()
	_bell_tween.tween_property(bell_visual, "rotation_degrees:z", 18.0, 0.08)
	_bell_tween.tween_property(bell_visual, "rotation_degrees:z", -18.0, 0.12)
	_bell_tween.tween_property(bell_visual, "rotation_degrees:z", 0.0, 0.08)
