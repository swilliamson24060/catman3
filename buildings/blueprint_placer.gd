extends Node3D
## Lets the player pick a building type via hotkey, previews a footprint-
## sized ghost that follows the mouse (green = valid, red = invalid), and
## places a blueprint marker on left-click. Reads footprint/cost purely from
## DataRegistry -- adding a building type here never needs a code change.

const BLUEPRINT_MARKER_SCRIPT := preload("res://buildings/blueprint_marker.gd")

const BUILDING_HOTKEYS := {
	KEY_1: "building_mouse_hut",
	KEY_2: "building_catnip_garden",
	KEY_3: "building_cheese_vault",
}

@export var camera_path: NodePath

@onready var camera: Camera3D = get_node(camera_path)

var selected_building_id: String = ""
var _ghost: MeshInstance3D
var _blueprints_container: Node3D

func _ready() -> void:
	_blueprints_container = Node3D.new()
	_blueprints_container.name = "Blueprints"
	add_child(_blueprints_container)
	EventBus.building_placed_as_blueprint.connect(_spawn_marker)

	_ghost = MeshInstance3D.new()
	_ghost.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost.set_surface_override_material(0, mat)
	_ghost.visible = false
	add_child(_ghost)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if BUILDING_HOTKEYS.has(event.keycode):
			var candidate: String = BUILDING_HOTKEYS[event.keycode]
			if not _is_available(candidate):
				print("[BlueprintPlacer] '%s' isn't unlocked yet." % candidate)
			else:
				selected_building_id = candidate
				print("[BlueprintPlacer] Selected building: ", selected_building_id)

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and selected_building_id != "":
		_try_place_blueprint()

func _process(_delta: float) -> void:
	if selected_building_id == "":
		_ghost.visible = false
		return

	var grid_pos = _mouse_grid_pos()
	if grid_pos == null:
		_ghost.visible = false
		return

	_update_ghost(grid_pos)

func _mouse_grid_pos():
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	var world_pos := from + dir * t
	return GridService.world_to_grid(world_pos)

## Step 7 gating hook: buildings.json's `locked_by_default` is a generic
## flag any building can set, unrelated to what actually unlocks it -- that
## mapping lives entirely in achievements.json's `unlocks` lists, so this
## check never needs to know which achievement (if any) is responsible.
func _is_available(building_id: String) -> bool:
	var building := DataRegistry.get_building(building_id)
	if not building.get("locked_by_default", false):
		return true
	return AchievementService.is_unlocked(building_id)

func _footprint_of(building: Dictionary) -> Vector2i:
	var footprint: Dictionary = building.get("footprint", {"width": 1, "height": 1})
	return Vector2i(footprint.get("width", 1), footprint.get("height", 1))

func _update_ghost(grid_pos: Vector2i) -> void:
	var building := DataRegistry.get_building(selected_building_id)
	if building.is_empty():
		_ghost.visible = false
		return

	var fp := _footprint_of(building)
	var cell := GridService.cell_size
	_ghost.mesh.size = Vector3(fp.x * cell, 0.15, fp.y * cell)

	var origin := GridService.grid_to_world(grid_pos)
	_ghost.position = origin + Vector3((fp.x - 1) * cell * 0.5, 0.12, (fp.y - 1) * cell * 0.5)
	_ghost.visible = true

	var valid := _is_valid_placement(grid_pos, fp)
	var mat: StandardMaterial3D = _ghost.get_surface_override_material(0)
	mat.albedo_color = Color(0.2, 0.9, 0.3, 0.5) if valid else Color(0.9, 0.2, 0.2, 0.5)

func _is_valid_placement(grid_pos: Vector2i, fp: Vector2i) -> bool:
	for x in range(grid_pos.x, grid_pos.x + fp.x):
		for y in range(grid_pos.y, grid_pos.y + fp.y):
			var pos := Vector2i(x, y)
			if not GridService.in_bounds(pos):
				return false
			if not GridService.is_revealed(pos):
				return false
			if GridService.get_tile_state(pos) != GridService.TileState.EMPTY:
				return false
			if GridService.is_resource_occupied(pos):
				return false
	return true

func _try_place_blueprint() -> void:
	var grid_pos = _mouse_grid_pos()
	if grid_pos == null:
		return

	var building := DataRegistry.get_building(selected_building_id)
	if building.is_empty():
		return

	var fp := _footprint_of(building)
	if not _is_valid_placement(grid_pos, fp):
		print("[BlueprintPlacer] Invalid placement at ", grid_pos)
		return

	# Tile-state occupancy is BuildingManager's bookkeeping (it's the single
	# owner of _placed/durability/footprint state), so it's set inside its
	# own building_placed_as_blueprint handler rather than here -- this
	# just emits the signal. Marker creation below is purely signal-driven
	# too (Step 9: the exact same path a restored save uses to respawn
	# visuals for buildings it didn't place through this UI at all).
	EventBus.building_placed_as_blueprint.emit(selected_building_id, grid_pos)
	print("[BlueprintPlacer] Placed blueprint '%s' at %s" % [selected_building_id, grid_pos])

	selected_building_id = ""
	_ghost.visible = false

func _spawn_marker(spawned_building_id: String, grid_pos: Vector2i) -> void:
	var marker := Node3D.new()
	marker.set_script(BLUEPRINT_MARKER_SCRIPT)
	marker.building_id = spawned_building_id
	marker.grid_pos = grid_pos
	marker.position = GridService.grid_to_world(grid_pos)
	_blueprints_container.add_child(marker)
