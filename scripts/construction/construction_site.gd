class_name ConstructionSite
extends Node3D

signal work_progress_changed(completed_work: float, required_work: float)
signal site_completed(site: ConstructionSite, building: Node3D)
signal site_cancelled(site: ConstructionSite)
signal bribe_cheese_changed(new_amount: int)

enum SiteState { WAITING_FOR_WORKERS, UNDER_CONSTRUCTION, PAUSED, COMPLETED, CANCELLED }

@export var building_definition: BuildingDefinition
@export var worker_slot_count: int = 3

@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var settlement_manager: Phase2SettlementManager = get_node("/root/SettlementManager") as Phase2SettlementManager
@onready var progress_fill: MeshInstance3D = $ProgressFill
@onready var frame: MeshInstance3D = $PlaceholderFrame

var completed_work: float = 0.0
var bribe_cheese: int = 0
var state: SiteState = SiteState.WAITING_FOR_WORKERS
var _reserved_workers: Dictionary = {}


func _ready() -> void:
	add_to_group("construction_sites")
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
			return slot
	return null


func release_worker(worker: Node3D) -> void:
	_reserved_workers.erase(worker)


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
	var container := get_tree().get_first_node_in_group("completed_building_container") as Node3D
	if container == null:
		container = get_tree().current_scene
	container.add_child(building)
	building.global_transform = global_transform
	settlement_manager.register_completed_building(building, building_definition)
	site_completed.emit(self, building)
	game_state.close_construction_site()
	game_state.request_feedback("%s completed.%s" % [get_display_name(), " %d bowl cheese returned." % remainder if remainder > 0 else ""])
	queue_free()


func _update_visuals() -> void:
	if not is_inside_tree():
		return
	var ratio := get_progress_ratio()
	frame.position.y = 0.15 + ratio * 0.75
	progress_fill.scale.x = maxf(ratio, 0.02)
	progress_fill.position.x = -0.6 + 0.6 * ratio
	var bowl_ratio := clampf(float(bribe_cheese) / 6.0, 0.0, 1.0)
	$BribeBowl/CheeseFill.scale.y = maxf(bowl_ratio, 0.03)
