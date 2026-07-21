extends Node
## Autoload "ThermalService". Thermal Warmth Grid (Step 6, mechanic 4): a
## slow-wandering "sunbeam" heat source sweeps across the grid, warming
## nearby tiles; heat decays everywhere else over time. Exposes get_heat()
## so anything can read the heat-map without knowing how it's generated --
## today that's player.gd's temporary movement-speed buff, but a future
## napping/stamina system or mice preferring warm tiles could read the
## exact same function.
##
## "Warm appliances" from the GDD's description aren't implemented -- no
## heater-type building exists in buildings.json yet -- so this is scoped
## to the sunbeam only, which is the part the deliverable actually needs.
## Adding an appliance heat source later is just another _apply_heat-style
## call reading a building's position, no changes needed here.

const HEAT_RADIUS := 2.5
const HEAT_GAIN_PER_SEC := 0.6
const HEAT_DECAY_PER_SEC := 0.15
const MAX_HEAT := 1.0
const SWEEP_SPEED := 0.5 # radians/sec of the Lissajous path below

var _heat: Dictionary = {} # Vector2i -> float
var _sunbeam_grid_pos: Vector2 = Vector2.ZERO
var _sweep_t: float = 0.0
var _visual: MeshInstance3D

func _ready() -> void:
	_update_sunbeam_pos()
	_build_visual()

func _process(delta: float) -> void:
	_sweep_t += delta * SWEEP_SPEED
	_update_sunbeam_pos()
	_decay_heat(delta)
	_apply_heat(delta)
	if _visual:
		_visual.position = GridService.grid_to_world_f(_sunbeam_grid_pos) + Vector3(0, 0.05, 0)

func get_heat(grid_pos: Vector2i) -> float:
	return _heat.get(grid_pos, 0.0)

func sunbeam_grid_pos() -> Vector2:
	return _sunbeam_grid_pos

func _update_sunbeam_pos() -> void:
	var half_w := GridService.grid_width / 2.0
	var half_h := GridService.grid_height / 2.0
	var x := half_w + sin(_sweep_t) * (half_w - 2.0)
	var y := half_h + cos(_sweep_t * 0.6) * (half_h - 2.0) * 0.6
	_sunbeam_grid_pos = Vector2(x, y)

func _apply_heat(delta: float) -> void:
	var center := _sunbeam_grid_pos
	var r := int(ceil(HEAT_RADIUS))
	var cx := int(round(center.x))
	var cy := int(round(center.y))
	for x in range(cx - r, cx + r + 1):
		for y in range(cy - r, cy + r + 1):
			var pos := Vector2i(x, y)
			if not GridService.in_bounds(pos):
				continue
			var d := Vector2(pos).distance_to(center)
			if d > HEAT_RADIUS:
				continue
			var falloff := 1.0 - (d / HEAT_RADIUS)
			var current: float = _heat.get(pos, 0.0)
			_heat[pos] = minf(MAX_HEAT, current + HEAT_GAIN_PER_SEC * falloff * delta)

func _decay_heat(delta: float) -> void:
	for pos in _heat.keys():
		var current: float = _heat[pos]
		if current > 0.0:
			_heat[pos] = maxf(0.0, current - HEAT_DECAY_PER_SEC * delta)

func _build_visual() -> void:
	_visual = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = HEAT_RADIUS * GridService.cell_size
	disc.bottom_radius = HEAT_RADIUS * GridService.cell_size
	disc.height = 0.02
	_visual.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.5, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_visual.set_surface_override_material(0, mat)
	add_child(_visual)
