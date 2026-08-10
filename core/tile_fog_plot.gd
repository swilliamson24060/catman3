class_name TileFogPlot
extends RefCounted
## An instantiable per-place tile grid + fog-of-war, modeled on GridService's
## API shape (grid_to_world/world_to_grid/is_revealed/reveal_around) but
## parameterized instead of a global singleton -- one instance per place
## (the home growth plot, each exploration area), not one shared grid for
## the whole game. Deliberately small: no build-occupancy state, no
## pathfinding -- just "which terrain tile occupies this cell" plus fog.

const CELL_SIZE := 1.0

var plot_id: StringName
var width: int = 8
var height: int = 8
var origin: Vector3 = Vector3.ZERO

var _tile_ids: Dictionary = {}   # Vector2i -> String (terrain_tile id); absent = ungenerated
var _revealed: Dictionary = {}   # Vector2i -> bool

func all_cells() -> Array:
	var cells: Array = []
	for x in width:
		for y in height:
			cells.append(Vector2i(x, y))
	return cells

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func grid_to_world(cell: Vector2i) -> Vector3:
	return origin + Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	var local := world_pos - origin
	return Vector2i(round(local.x / CELL_SIZE), round(local.z / CELL_SIZE))

func get_tile_id(cell: Vector2i) -> String:
	return _tile_ids.get(cell, "")

func set_tile_id(cell: Vector2i, id: String) -> void:
	_tile_ids[cell] = id
	_revealed[cell] = true   # a generated cell is, by definition, no longer hidden

func is_generated(cell: Vector2i) -> bool:
	return _tile_ids.has(cell)

func is_revealed(cell: Vector2i) -> bool:
	return _revealed.get(cell, false)

## Same flood-fill shape as GridService.reveal_around -- used when the
## founder is physically present near this plot, on top of (not instead of)
## generation-driven reveal from set_tile_id().
func reveal_around(cell: Vector2i, radius: int) -> void:
	for x in range(cell.x - radius, cell.x + radius + 1):
		for y in range(cell.y - radius, cell.y + radius + 1):
			var pos := Vector2i(x, y)
			if not in_bounds(pos):
				continue
			if Vector2(pos).distance_to(Vector2(cell)) <= radius:
				_revealed[pos] = true

func revealed_fraction() -> float:
	var total := width * height
	if total == 0:
		return 0.0
	var revealed_count := 0
	for cell in all_cells():
		if is_revealed(cell):
			revealed_count += 1
	return float(revealed_count) / float(total)

func ungenerated_cells() -> Array:
	var cells: Array = []
	for cell in all_cells():
		if not is_generated(cell):
			cells.append(cell)
	return cells

func serialize() -> Dictionary:
	var tiles := {}
	for cell in _tile_ids:
		tiles[_encode_cell(cell)] = _tile_ids[cell]
	var revealed: Array = []
	for cell in _revealed:
		if _revealed[cell]:
			revealed.append(_encode_cell(cell))
	return {
		"plot_id": String(plot_id),
		"width": width,
		"height": height,
		"origin": [origin.x, origin.y, origin.z],
		"tiles": tiles,
		"revealed": revealed,
	}

static func from_data(data: Dictionary) -> TileFogPlot:
	var plot := TileFogPlot.new()
	plot.plot_id = StringName(str(data.get("plot_id", "")))
	plot.width = int(data.get("width", 8))
	plot.height = int(data.get("height", 8))
	var o: Array = data.get("origin", [0.0, 0.0, 0.0])
	if o.size() >= 3:
		plot.origin = Vector3(float(o[0]), float(o[1]), float(o[2]))
	var tiles: Dictionary = data.get("tiles", {})
	for key: String in tiles:
		plot._tile_ids[_decode_cell(key)] = str(tiles[key])
	for key: Variant in (data.get("revealed", []) as Array):
		plot._revealed[_decode_cell(str(key))] = true
	return plot

## Vector2i isn't a valid JSON dictionary key -- encode as "x,y", matching
## how the rest of the codebase flattens Godot vector types for save data.
static func _encode_cell(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func _decode_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
