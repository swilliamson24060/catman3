extends Node3D
## Scatters ResourceNode pickups across GridService's grid at run start.
## Avoids the spawn area right around the player start and never doubles up
## on a tile.

const RESOURCE_NODE_SCRIPT := preload("res://world/resource_node.gd")

@export var wood_count: int = 18
@export var twigs_count: int = 14
@export var yarn_count: int = 10
@export var cheese_count: int = 6
@export var moonstone_count: int = 3
@export var min_distance_from_center: int = 3
@export var rng_seed: int = 0
@onready var grid_service: Node = get_node("/root/GridService")

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	var used_positions: Dictionary = {}
	_spawn_batch(rng, "wood", wood_count, used_positions)
	_spawn_batch(rng, "twigs", twigs_count, used_positions)
	_spawn_batch(rng, "yarn", yarn_count, used_positions)
	# Cheese is a stand-in resource node until a real production chain
	# (creamery, etc.) exists -- it's what mice cost to recruit per
	# animal_types.json's upkeep field, so it needs to be obtainable now.
	_spawn_batch(rng, "cheese_mild", cheese_count, used_positions)
	# Moonstone is rare and flagged is_rare -- it's what the Whisker-Radar
	# Hot/Cold UI (mechanic 2) homes in on while still fogged.
	_spawn_batch(rng, "moonstone", moonstone_count, used_positions, true)

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
