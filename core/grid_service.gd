extends Node
## Autoload "GridService". Bidirectional mapping between logical grid
## coordinates and 3D world transforms, plus per-tile state. Visuals (2D
## billboards or 3D meshes) only ever need the transform this returns for a
## given cell -- that's what lets them swap with zero code changes per the
## GDD's 2.5D fallback requirement.

## Build-occupancy state for a tile. Deliberately separate from fog-of-war
## (_revealed below) -- a tile's construction state and whether the player
## has seen it yet are two different questions.
enum TileState { EMPTY, BLUEPRINT, BUILT }

signal tile_revealed(grid_pos: Vector2i)

## World-space size of one cell, and how many cells make up the grid. The
## grid is centered on world-space (0,0) so it lines up with the existing
## playable ground plane (a 20x20 CSGBox3D with walls at +/-10) rather than
## starting at the world origin corner.
@export var cell_size: float = 1.0
@export var grid_width: int = 20
@export var grid_height: int = 20

var _tile_state: Dictionary = {}        # Vector2i -> TileState
var _revealed: Dictionary = {}          # Vector2i -> bool
var _resource_occupied: Dictionary = {} # Vector2i -> bool
var _resource_nodes: Dictionary = {}    # Vector2i -> Node (the ResourceNode occupying that tile, if any)
var _rare_positions: Dictionary = {}    # Vector2i -> true, for nearest_hidden_rare_distance()

var _astar: AStarGrid2D
var _astar_dirty: bool = true
var _astar_rebuild_count: int = 0
var _path_query_count: int = 0

func _ready() -> void:
	for x in grid_width:
		for y in grid_height:
			var pos := Vector2i(x, y)
			_tile_state[pos] = TileState.EMPTY
			_revealed[pos] = false

func _origin() -> Vector2:
	return Vector2(-grid_width * cell_size / 2.0, -grid_height * cell_size / 2.0)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return grid_to_world_f(Vector2(grid_pos))

## Float-coordinate version of grid_to_world -- for anything that needs to
## move smoothly across the grid rather than snapping cell to cell (e.g.
## ThermalService's sunbeam).
func grid_to_world_f(grid_pos: Vector2) -> Vector3:
	var origin := _origin()
	return Vector3(grid_pos.x * cell_size + origin.x, 0.0, grid_pos.y * cell_size + origin.y)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	var origin := _origin()
	return Vector2i(round((world_pos.x - origin.x) / cell_size), round((world_pos.z - origin.y) / cell_size))

func get_tile_state(grid_pos: Vector2i) -> TileState:
	return _tile_state.get(grid_pos, TileState.EMPTY)

func set_tile_state(grid_pos: Vector2i, state: TileState) -> void:
	_tile_state[grid_pos] = state
	_astar_dirty = true

func is_revealed(grid_pos: Vector2i) -> bool:
	return _revealed.get(grid_pos, false)

func reveal_around(grid_pos: Vector2i, radius: int) -> void:
	for x in range(grid_pos.x - radius, grid_pos.x + radius + 1):
		for y in range(grid_pos.y - radius, grid_pos.y + radius + 1):
			var pos := Vector2i(x, y)
			if not in_bounds(pos) or _revealed.get(pos, false):
				continue
			if Vector2(pos).distance_to(Vector2(grid_pos)) <= radius:
				_revealed[pos] = true
				tile_revealed.emit(pos)

func in_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height

func is_resource_occupied(grid_pos: Vector2i) -> bool:
	return _resource_occupied.get(grid_pos, false)

func set_resource_occupied(grid_pos: Vector2i, occupied: bool) -> void:
	_resource_occupied[grid_pos] = occupied

## Lets a ResourceNode register itself so animals (and anything else) can
## look up "what's harvestable at this tile" without needing a scene-tree
## reference to the spawner. Registered by ResourceNode itself in _ready/
## _on_tree_exiting.
func register_resource_node(grid_pos: Vector2i, node: Node) -> void:
	_resource_nodes[grid_pos] = node
	if node.get("is_rare"):
		_rare_positions[grid_pos] = true

func unregister_resource_node(grid_pos: Vector2i) -> void:
	_resource_nodes.erase(grid_pos)
	_rare_positions.erase(grid_pos)

func get_resource_node(grid_pos: Vector2i) -> Node:
	return _resource_nodes.get(grid_pos, null)

## World-space distance from `from_pos` to the nearest rare resource node
## whose tile is still fogged (INF if none exist, or every rare node found
## so far has already been revealed). Drives the Whisker-Radar Hot/Cold UI
## -- once a rare node's tile is revealed it stops counting as "hidden",
## matching the GDD's "hidden rare resources in the fog of war" framing.
func nearest_hidden_rare_distance(from_pos: Vector3) -> float:
	var nearest := INF
	for pos in _rare_positions:
		if is_revealed(pos):
			continue
		var d: float = from_pos.distance_to(grid_to_world(pos))
		if d < nearest:
			nearest = d
	return nearest

## Lazily (re)builds the pathfinding grid whenever tile state has changed
## since the last path request. Tiles that aren't EMPTY (BLUEPRINT/BUILT)
## are solid obstacles; resource-occupied tiles stay walkable so an animal
## can path onto the tile it's about to harvest.
func _ensure_astar() -> void:
	if _astar == null:
		_astar = AStarGrid2D.new()
		_astar.region = Rect2i(0, 0, grid_width, grid_height)
		_astar.cell_size = Vector2.ONE
		_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		_astar.update()
	if _astar_dirty:
		for x in grid_width:
			for y in grid_height:
				var pos := Vector2i(x, y)
				var solid: bool = _tile_state.get(pos, TileState.EMPTY) != TileState.EMPTY
				_astar.set_point_solid(pos, solid)
		_astar_dirty = false
		_astar_rebuild_count += 1

## Returns a path of grid cells from `from` to `to` (inclusive of `to`), or
## an empty array if no path exists. Both endpoints are treated as walkable
## even if something (a hut, a resource node's tile) marked them solid --
## an animal always needs to be able to reach its destination and leave its
## own tile.
func find_path(from: Vector2i, to: Vector2i) -> Array:
	if not in_bounds(from) or not in_bounds(to):
		return []
	_ensure_astar()
	_path_query_count += 1

	var was_solid_to := _astar.is_point_solid(to)
	var was_solid_from := _astar.is_point_solid(from)
	_astar.set_point_solid(to, false)
	_astar.set_point_solid(from, false)

	var raw_path: PackedVector2Array = _astar.get_point_path(from, to)

	_astar.set_point_solid(to, was_solid_to)
	_astar.set_point_solid(from, was_solid_from)

	var result: Array = []
	for p in raw_path:
		result.append(Vector2i(round(p.x), round(p.y)))
	return result

func get_pathfinding_diagnostics() -> Dictionary:
	return {
		"queries": _path_query_count,
		"grid_rebuilds": _astar_rebuild_count,
		"grid_instance_id": _astar.get_instance_id() if _astar != null else 0,
	}

func reset_pathfinding_diagnostics() -> void:
	_path_query_count = 0
	_astar_rebuild_count = 0
