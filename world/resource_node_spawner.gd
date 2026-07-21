extends Node3D
## Scatters ResourceNode pickups across GridService's grid at run start.
## Avoids the spawn area right around the player start and never doubles up
## on a tile.

const RESOURCE_NODE_SCRIPT := preload("res://world/resource_node.gd")
const SETTLEMENT_CHEESE_SCRIPT := preload("res://world/settlement_cheese_pickup.gd")

@export var wood_count: int = 18
@export var twigs_count: int = 14
@export var yarn_count: int = 10
@export var cheese_count: int = 6
@export var moonstone_count: int = 3
@export var min_distance_from_center: int = 3
@export var rng_seed: int = 0
@onready var grid_service: Node = get_node("/root/GridService")
@onready var settlement_manager: Phase2SettlementManager = get_node("/root/SettlementManager") as Phase2SettlementManager
@onready var simulation_clock: Phase2SimulationClock = get_node("/root/SimulationClock") as Phase2SimulationClock

const SETTLEMENT_CHEESE_REPLENISH_TURNS: int = 3

var _rng := RandomNumberGenerator.new()
var _active_settlement_cheese: Node3D

func _ready() -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	var used_positions: Dictionary = {}
	_spawn_batch(_rng, "wood", wood_count, used_positions)
	_spawn_batch(_rng, "twigs", twigs_count, used_positions)
	_spawn_batch(_rng, "yarn", yarn_count, used_positions)
	# Cheese is a stand-in resource node until a real production chain
	# (creamery, etc.) exists -- it's what mice cost to recruit per
	# animal_types.json's upkeep field, so it needs to be obtainable now.
	_spawn_batch(_rng, "cheese_mild", cheese_count, used_positions)
	# Moonstone is rare and flagged is_rare -- it's what the Whisker-Radar
	# Hot/Cold UI (mechanic 2) homes in on while still fogged.
	_spawn_batch(_rng, "moonstone", moonstone_count, used_positions, true)
	simulation_clock.need_cycle.connect(_on_need_cycle)
	call_deferred("_spawn_settlement_cheese")


func _on_need_cycle(cycle_index: int) -> void:
	if cycle_index > 0 and cycle_index % SETTLEMENT_CHEESE_REPLENISH_TURNS == 0:
		_spawn_settlement_cheese()


func _spawn_settlement_cheese() -> Node3D:
	if is_instance_valid(_active_settlement_cheese) and not _active_settlement_cheese.is_queued_for_deletion():
		return _active_settlement_cheese
	var pickup := Area3D.new()
	pickup.set_script(SETTLEMENT_CHEESE_SCRIPT)
	_active_settlement_cheese = pickup
	add_child(_active_settlement_cheese)
	_active_settlement_cheese.global_position = settlement_manager.get_random_position_inside_settlement(_rng, 1.25)
	_active_settlement_cheese.collected.connect(_on_settlement_cheese_collected)
	return _active_settlement_cheese


func _on_settlement_cheese_collected(pickup: Node3D, _collector: Node3D) -> void:
	if pickup == _active_settlement_cheese:
		_active_settlement_cheese = null

func _spawn_batch(rng: RandomNumberGenerator, item_id: String, count: int, used_positions: Dictionary, is_rare: bool = false) -> void:
	var placed := 0
	var attempts := 0
	var max_attempts := count * 40

	while placed < count and attempts < max_attempts:
		attempts += 1
		var pos := Vector2i(
			rng.randi_range(0, int(grid_service.get("grid_width")) - 1),
			rng.randi_range(0, int(grid_service.get("grid_height")) - 1)
		)
		@warning_ignore("integer_division")
		var half_w: int = int(grid_service.get("grid_width")) / 2
		@warning_ignore("integer_division")
		var half_h: int = int(grid_service.get("grid_height")) / 2
		var center := Vector2i(half_w, half_h)
		if Vector2(pos).distance_to(Vector2(center)) < min_distance_from_center:
			continue
		if used_positions.has(pos) or bool(grid_service.call("is_resource_occupied", pos)):
			continue

		used_positions[pos] = true
		_spawn_node(item_id, pos, is_rare)
		placed += 1

func _spawn_node(item_id: String, grid_pos: Vector2i, is_rare: bool = false) -> void:
	var node := Area3D.new()
	node.set_script(RESOURCE_NODE_SCRIPT)
	node.item_id = item_id
	node.grid_pos = grid_pos
	node.is_rare = is_rare
	node.position = grid_service.call("grid_to_world", grid_pos)
	add_child(node)
