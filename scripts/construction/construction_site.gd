class_name ConstructionSite
extends Node3D

signal work_progress_changed(completed_work: float, required_work: float)
signal site_completed(site: ConstructionSite, building: Node3D)
signal site_cancelled(site: ConstructionSite)
signal bribe_cheese_changed(new_amount: int)

enum SiteState { WAITING_FOR_WORKERS, UNDER_CONSTRUCTION, PAUSED, COMPLETED, CANCELLED }

@export var building_definition: BuildingDefinition
@export var worker_slot_count: int = 8

@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var settlement_manager: Phase2SettlementManager = get_node("/root/SettlementManager") as Phase2SettlementManager
@onready var progress_fill: MeshInstance3D = $ProgressFill
@onready var frame: MeshInstance3D = $PlaceholderFrame
@onready var world_status: Label3D = $WorldStatus

var completed_work: float = 0.0
var bribe_cheese: int = 0
var state: SiteState = SiteState.WAITING_FOR_WORKERS
var _reserved_workers: Dictionary = {}
var _active_workers: Dictionary = {}


func _ready() -> void:
	add_to_group("construction_sites")
	var simulation_clock := get_node_or_null("/root/SimulationClock") as Phase2SimulationClock
	if simulation_clock != null:
		simulation_clock.simulation_advanced.connect(_on_simulation_advanced)
	_update_visuals()


func configure(definition: BuildingDefinition) -> void:
	building_definition = definition
	_update_visuals()


func interact(_interactor: Node3D) -> void:
	if state in [SiteState.COMPLETED, SiteState.CANCELLED]:
		return
	game_state.open_construction_site(self)


func get_interaction_prompt() -> String:
	return "Press E to manage %s construction" % (building_definition.display_name if building_definition != null else "site")


func get_interaction_priority() -> int:
	return 20


func get_display_name() -> String:
	return building_definition.display_name if building_definition != null else "Construction Site"


func get_progress_ratio() -> float:
	if building_definition == null or building_definition.work_required <= 0.0:
		return 0.0
	return clampf(completed_work / building_definition.work_required, 0.0, 1.0)


func get_available_worker_slots() -> int:
	return maxi(worker_slot_count - _reserved_workers.size(), 0)


func get_worker_count() -> int:
	return _reserved_workers.size()


func get_active_worker_count() -> int:
	return _active_workers.size()


func set_worker_active(worker: Node3D, is_active: bool) -> void:
	if worker == null or not _reserved_workers.has(worker):
		return
	if is_active:
		_active_workers[worker] = true
	else:
		_active_workers.erase(worker)
	_update_visuals()


func is_accepting_workers() -> bool:
	return state in [SiteState.WAITING_FOR_WORKERS, SiteState.UNDER_CONSTRUCTION] and get_available_worker_slots() > 0


func reserve_worker(worker: Node3D) -> Marker3D:
	if worker == null or _reserved_workers.has(worker):
		return null
	for child: Node in $WorkerSlots.get_children():
		var slot := child as Marker3D
		if slot != null and not slot in _reserved_workers.values():
			_reserved_workers[worker] = slot
			var completed_callable := Callable(worker, "_on_worksite_completed")
			var cancelled_callable := Callable(worker, "_on_worksite_cancelled")
			if not site_completed.is_connected(completed_callable):
				site_completed.connect(completed_callable)
			if not site_cancelled.is_connected(cancelled_callable):
				site_cancelled.connect(cancelled_callable)
			_update_visuals()
			return slot
	return null


func release_worker(worker: Node3D) -> void:
	_active_workers.erase(worker)
	_reserved_workers.erase(worker)
	_update_visuals()


func get_bribe_willingness_value() -> float:
	return float(bribe_cheese) * 8.0


func add_bribe_cheese(amount: int) -> bool:
	if amount <= 0 or state in [SiteState.COMPLETED, SiteState.CANCELLED]:
		return false
	if not game_state.spend_cheese(amount):
		game_state.request_feedback("Not enough cheese.")
		return false
	bribe_cheese += amount
	bribe_cheese_changed.emit(bribe_cheese)
	_update_visuals()
	return true


func return_bribe_cheese() -> int:
	var returned := bribe_cheese
	bribe_cheese = 0
	if returned > 0:
		game_state.add_cheese(returned)
	bribe_cheese_changed.emit(bribe_cheese)
	_update_visuals()
	return returned


## Development contribution used until voluntary mouse labor arrives in Milestone 3.
func debug_contribute_work(amount: float = 20.0) -> void:
	contribute_work(amount)


func contribute_work(amount: float) -> void:
	if amount <= 0.0 or state in [SiteState.COMPLETED, SiteState.CANCELLED] or building_definition == null:
		return
	state = SiteState.UNDER_CONSTRUCTION
	completed_work = minf(completed_work + game_state.get_building_speed(amount), building_definition.work_required)
	work_progress_changed.emit(completed_work, building_definition.work_required)
	_update_visuals()
	if completed_work >= building_definition.work_required:
		_complete_site()


func _on_simulation_advanced(simulation_delta: float) -> void:
	if simulation_delta <= 0.0 or building_definition == null or state in [SiteState.COMPLETED, SiteState.CANCELLED]:
		return
	var active_count := get_active_worker_count()
	var required_count := maxi(building_definition.minimum_workers, 1)
	if active_count < required_count:
		state = SiteState.WAITING_FOR_WORKERS
		_update_visuals()
		return
	state = SiteState.UNDER_CONSTRUCTION
	var effective_turns := maxf(
		3.0,
		building_definition.base_construction_turns * float(required_count) / float(active_count)
	)
	var duration_seconds := effective_turns * Phase2SimulationClock.NEED_CYCLE_SECONDS
	var progress_amount := building_definition.work_required * simulation_delta / duration_seconds
	completed_work = minf(completed_work + progress_amount, building_definition.work_required)
	work_progress_changed.emit(completed_work, building_definition.work_required)
	_update_visuals()
	if completed_work >= building_definition.work_required:
		_complete_site()


func cancel_site() -> void:
	if state in [SiteState.COMPLETED, SiteState.CANCELLED]:
		return
	return_bribe_cheese()
	state = SiteState.CANCELLED
	site_cancelled.emit(self)
	game_state.close_construction_site()
	game_state.request_feedback("%s site cancelled; bribe cheese returned." % get_display_name())
	queue_free()


func _complete_site() -> void:
	state = SiteState.COMPLETED
	var participant_count := _reserved_workers.size()
	var share := bribe_cheese / participant_count if participant_count > 0 else 0
	var distributed := share * participant_count
	for worker: Node3D in _reserved_workers:
		if share > 0 and worker.has_method("receive_work_bribe"):
			worker.call("receive_work_bribe", share)
	bribe_cheese -= distributed
	var remainder := return_bribe_cheese()
	var building := building_definition.completed_scene.instantiate() as Node3D
	building.set("building_definition", building_definition)
	var builders: Array[Phase1WildMouse] = []
	for worker: Node3D in _reserved_workers:
		var mouse := worker as Phase1WildMouse
		if mouse != null and is_instance_valid(mouse):
			builders.append(mouse)
	if building.has_method("configure_builders"):
		building.call("configure_builders", builders)
	var container := get_tree().get_first_node_in_group("completed_building_container") as Node3D
	if container == null:
		container = get_tree().current_scene
	container.add_child(building)
	building.global_transform = global_transform
	if building.has_method("grant_completion_rewards"):
		building.call("grant_completion_rewards")
	_add_completion_marker(building)
	settlement_manager.register_completed_building(building, building_definition)
	site_completed.emit(self, building)
	game_state.close_construction_site()
	var expansion_text := " Settlement expanded by %.0f meters." % building_definition.settlement_influence_radius if building_definition.settlement_influence_radius > 0.0 else ""
	game_state.request_feedback("%s completed.%s%s" % [get_display_name(), expansion_text, " %d bowl cheese returned." % remainder if remainder > 0 else ""])
	queue_free()


func _add_completion_marker(building: Node3D) -> void:
	var marker := Label3D.new()
	marker.name = "CompletionMarker"
	marker.position = Vector3(0.0, 2.0, 0.0)
	marker.text = "✓ %s COMPLETE" % get_display_name().to_upper()
	marker.modulate = Color(0.55, 1.0, 0.62)
	marker.font_size = 32
	marker.outline_size = 10
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	building.add_child(marker)


func _update_visuals() -> void:
	if not is_inside_tree():
		return
	var ratio := get_progress_ratio()
	frame.position.y = 0.15 + ratio * 0.75
	progress_fill.scale.x = maxf(ratio, 0.02)
	progress_fill.position.x = -0.6 + 0.6 * ratio
	var bowl_ratio := clampf(float(bribe_cheese) / 6.0, 0.0, 1.0)
	$BribeBowl/CheeseFill.scale.y = maxf(bowl_ratio, 0.03)
	if world_status != null:
		var required_count := maxi(building_definition.minimum_workers, 1) if building_definition != null else 1
		var active_count := get_active_worker_count()
		var status := "%d/%d MICE READY" % [active_count, required_count] if active_count < required_count else "%d MICE BUILDING" % active_count
		world_status.text = "%s\n%s • %d%%" % [get_display_name(), status, roundi(ratio * 100.0)]
