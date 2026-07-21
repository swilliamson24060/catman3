extends MultiMeshInstance3D
## Renders one dark, flat quad per grid tile and hides (scales to zero) each
## one as GridService reports it revealed. Purely a visual layer over
## GridService's data -- no gameplay logic lives here.

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(GridService.cell_size * 0.98, GridService.cell_size * 0.98)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.04, 0.05, 0.94)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.surface_set_material(0, mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = GridService.grid_width * GridService.grid_height
	multimesh = mm

	var flat_basis := Basis(Vector3.RIGHT, -PI / 2.0)
	var i := 0
	for x in GridService.grid_width:
		for y in GridService.grid_height:
			var pos := Vector2i(x, y)
			var world := GridService.grid_to_world(pos)
			multimesh.set_instance_transform(i, Transform3D(flat_basis, world + Vector3(0, 0.05, 0)))
			if GridService.is_revealed(pos):
				_hide_instance(i)
			i += 1

	GridService.tile_revealed.connect(_on_tile_revealed)

func _on_tile_revealed(grid_pos: Vector2i) -> void:
	var index := grid_pos.x * GridService.grid_height + grid_pos.y
	_hide_instance(index)

func _hide_instance(index: int) -> void:
	var t := multimesh.get_instance_transform(index)
	t.basis = t.basis.scaled(Vector3.ZERO)
	multimesh.set_instance_transform(index, t)
