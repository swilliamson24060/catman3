extends Node3D
## Placeholder marker for a placed blueprint -- a flat, tier-tinted box sized
## to the building's footprint. Purely a stand-in for real building art
## (step 9 polish). While unbuilt it's translucent; once a mouse finishes
## constructing it (BuildingManager.complete_construction ->
## EventBus.building_constructed) it swaps to an opaque "built" tint so
## there's a visible signal the automated construction loop actually ran.

const _VisualResolver := preload("res://world/visual_resolver.gd")

@export var building_id: String = ""
@export var grid_pos: Vector2i = Vector2i.ZERO

var _mat: StandardMaterial3D
var _built_color := Color(0.45, 0.32, 0.18, 1.0)

func _ready() -> void:
	var building := DataRegistry.get_building(building_id)

	# Step 9 polish: a real mesh_scene_path/sprite_path in buildings.json
	# takes over automatically; only the procedural tinted-box fallback (and
	# the damage/collapse tinting below) needs _mat, so it's left null when
	# real art is present -- that's a deliberate scoping simplification, not
	# a bug, since real art presumably brings its own damage feedback later.
	var visual := _VisualResolver.resolve(building, _build_procedural_box)
	add_child(visual)

	EventBus.building_constructed.connect(_on_building_constructed)
	EventBus.building_damaged.connect(_on_building_damaged)
	EventBus.building_collapsed.connect(_on_building_collapsed)

func _build_procedural_box() -> Node3D:
	var building := DataRegistry.get_building(building_id)
	var footprint: Dictionary = building.get("footprint", {"width": 1, "height": 1})
	var w: int = footprint.get("width", 1)
	var h: int = footprint.get("height", 1)
	var cell := GridService.cell_size

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w * cell * 0.9, 0.5, h * cell * 0.9)
	mesh_instance.mesh = box
	mesh_instance.position.y = 0.25

	_mat = StandardMaterial3D.new()
	var tier: String = building.get("tier", "cardboard")
	_mat.albedo_color = Color(0.82, 0.7, 0.5, 0.85) if tier == "cardboard" else Color(0.6, 0.6, 0.65, 0.9)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.set_surface_override_material(0, _mat)
	return mesh_instance

func _on_building_constructed(finished_building_id: String, finished_grid_pos: Vector2i) -> void:
	if finished_building_id != building_id or finished_grid_pos != grid_pos:
		return
	if _mat == null:
		return
	_mat.albedo_color = _built_color
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

## Cardboard Tier & Rain Events (Step 6, mechanic 3): darken and desaturate
## toward a sodden grey-brown as durability drops, so a building visibly
## looks worse for wear before it collapses -- purely cosmetic, all the
## real state lives in BuildingManager.
func _on_building_damaged(damaged_building_id: String, damaged_grid_pos: Vector2i, durability: float) -> void:
	if damaged_building_id != building_id or damaged_grid_pos != grid_pos:
		return
	if _mat == null:
		return
	var ratio := clampf(durability / 100.0, 0.0, 1.0)
	var soaked := Color(0.25, 0.25, 0.28, 1.0)
	_mat.albedo_color = _built_color.lerp(soaked, 1.0 - ratio)

func _on_building_collapsed(collapsed_building_id: String, collapsed_grid_pos: Vector2i) -> void:
	if collapsed_building_id != building_id or collapsed_grid_pos != grid_pos:
		return
	queue_free()
