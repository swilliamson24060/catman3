extends Node3D
class_name Mouse
## Movement-only visual/agent for a single recruited animal instance.
## Deliberately dumb: AnimalManager owns all job-assignment/state logic and
## just tells this node where to walk along a GridService.find_path result.
## Nothing species-specific lives here, so a future cow (or any other
## animal) reuses this exact script -- only the spawning code and
## animal_types.json entry differ per species.

signal path_finished(mouse: Node3D)

## Kenney cube-pets koala model, used as the default recruited-animal visual
## when a species doesn't name its own art. Scaled well down from its
## native (cat-sized) scale so it reads as a small creature scurrying
## between resource nodes and its hut.
const VISUAL_SCENE := preload("res://kenney_cube-pets_1/Models/GLB format/animal-koala.glb")
const VISUAL_SCALE := 0.45
const _VisualResolver := preload("res://world/visual_resolver.gd")

@export var movement_speed: float = 3.5
## Step 9 polish: which animal_types.json entry this instance represents,
## purely so _build_visual() can look up a species-specific
## mesh_scene_path/sprite_path via VisualResolver. Everything else about
## this script stays fully species-agnostic -- AnimalManager still owns all
## job/state logic regardless of what species_id says.
@export var species_id: String = ""
## {body_color, eye_color, decoration} from AppearanceService.assign_appearance()
## -- see _apply_appearance() for how each piece is rendered.
@export var appearance: Dictionary = {}

var grid_pos: Vector2i = Vector2i.ZERO

var _path: Array = []
var _path_index: int = 0

func _ready() -> void:
	_build_visual()
	position = GridService.grid_to_world(grid_pos)
	set_physics_process(false)

func _build_visual() -> void:
	var animal_type := DataRegistry.get_animal_type(species_id) if species_id != "" else {}
	var visual := _VisualResolver.resolve(animal_type, _build_default_koala)
	visual.scale = Vector3.ONE * VISUAL_SCALE
	add_child(visual)
	_apply_appearance(visual)

func _build_default_koala() -> Node3D:
	return VISUAL_SCENE.instantiate()

## Renders this instance's {body_color, eye_color, decoration} combo.
##
## Scoping note: these Kenney cube-pets models (like the founder cats' own
## model -- see cat_appearance.gd's header comment) bake fur AND eyes into
## one shared colormap.png atlas with unknown/unverified UV layout. That
## codebase already had to reverse-engineer the cat model and pre-bake a
## whole texture per founder just to recolor it correctly; doing the same
## per-instance for a potentially large recruited population isn't a
## reasonable scope here. Instead: body_color is a non-destructive material
## tint (preserves whatever texture detail exists, same principle as
## cat_appearance.gd's "mat.albedo_color = white so it doesn't wash out the
## texture" -- here we intentionally DO tint, since there's no baked art to
## protect on the placeholder models), and eye_color/decoration render as
## small distinctly-colored marker shapes rather than literal fur
## patterns/eye pigment. This still makes every animal visually
## distinguishable at a glance, which is the actual requirement -- proper
## per-species baked art can replace these markers later with zero changes
## to AppearanceService or the data driving it.
func _apply_appearance(visual: Node3D) -> void:
	if appearance.is_empty():
		return

	var body: Dictionary = appearance.get("body_color", {})
	if not body.is_empty():
		_tint_recursive(visual, Color(body.get("hex", "#FFFFFF")))

	var eye: Dictionary = appearance.get("eye_color", {})
	if not eye.is_empty():
		var marker := _make_marker(SphereMesh.new(), Color(eye.get("hex", "#FFFFFF")))
		marker.mesh.radius = 0.12
		marker.mesh.height = 0.24
		marker.position = Vector3(0, 0.95, 0.35)
		add_child(marker)

	var decoration: Dictionary = appearance.get("decoration", {})
	if decoration.get("pattern", "none") != "none":
		var ring := _make_marker(TorusMesh.new(), Color(decoration.get("hex", "#FFFFFF")))
		ring.mesh.inner_radius = 0.35
		ring.mesh.outer_radius = 0.45
		ring.position = Vector3(0, 0.15, 0)
		add_child(ring)

func _tint_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		if mesh:
			for i in mesh.get_surface_count():
				var mat := StandardMaterial3D.new()
				var existing: Material = node.get_active_material(i)
				if existing is BaseMaterial3D:
					mat.albedo_texture = existing.albedo_texture
				mat.albedo_color = color
				node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_tint_recursive(child, color)

func _make_marker(mesh: Mesh, color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	marker.set_surface_override_material(0, mat)
	return marker

## The remaining un-walked cells of the current path, from wherever this
## mouse is right now to its destination. Used by Cat-Nap Fast-Forward's
## ghost-path gizmos -- since movement is already fully deterministic A*,
## "predicting" the future is just reading the rest of the path that's
## already been computed.
func get_remaining_path() -> Array:
	if _path_index >= _path.size():
		return []
	return _path.slice(_path_index)

## Starts walking along `cells` (a list of Vector2i grid coordinates, as
## returned by GridService.find_path). Emits path_finished once the last
## cell is reached; does nothing (and doesn't emit) if `cells` is empty.
func walk_path(cells: Array) -> void:
	_path = cells
	_path_index = 0
	set_physics_process(not _path.is_empty())

func _physics_process(delta: float) -> void:
	if _path_index >= _path.size():
		set_physics_process(false)
		return

	var target_cell: Vector2i = _path[_path_index]
	var target_world := GridService.grid_to_world(target_cell)
	target_world.y = position.y
	var to_target := target_world - position
	var step := movement_speed * delta

	if to_target.length() <= step:
		position = target_world
		grid_pos = target_cell
		_path_index += 1
		if _path_index >= _path.size():
			set_physics_process(false)
			path_finished.emit(self)
	else:
		position += to_target.normalized() * step
		look_at(position + to_target.normalized(), Vector3.UP)
