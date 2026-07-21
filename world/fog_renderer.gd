class_name SettlementFogRenderer
extends MultiMeshInstance3D

## A dense overhead fog blanket. Tiles inside controlled settlement territory
## are removed; completed buildings update SettlementManager influence and
## immediately clear the newly expanded area.

@export var world_half_extent: float = 35.0
@export var fog_cell_size: float = 1.0
@export var fog_height: float = 1.55

@onready var settlement_manager: Phase2SettlementManager = get_node("/root/SettlementManager") as Phase2SettlementManager

var _grid_size: int = 0


func _ready() -> void:
	_build_fog_grid()
	settlement_manager.influence_changed.connect(_refresh_fog)
	_refresh_fog()


func _build_fog_grid() -> void:
	_grid_size = ceili(world_half_extent * 2.0 / fog_cell_size)
	var quad := QuadMesh.new()
	quad.size = Vector2(fog_cell_size * 1.04, fog_cell_size * 1.04)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.035, 0.055, 0.07, 0.96)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.surface_set_material(0, material)
	var fog_multimesh := MultiMesh.new()
	fog_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	fog_multimesh.mesh = quad
	fog_multimesh.instance_count = _grid_size * _grid_size
	multimesh = fog_multimesh


func _refresh_fog() -> void:
	if multimesh == null:
		return
	var flat_basis := Basis(Vector3.RIGHT, -PI / 2.0)
	var hidden_basis := flat_basis.scaled(Vector3.ZERO)
	var start := -world_half_extent + fog_cell_size * 0.5
	var index := 0
	for x: int in range(_grid_size):
		for z: int in range(_grid_size):
			var world_position := Vector3(start + x * fog_cell_size, fog_height, start + z * fog_cell_size)
			var is_settled := settlement_manager.is_position_inside_settlement(world_position)
			multimesh.set_instance_transform(index, Transform3D(hidden_basis if is_settled else flat_basis, world_position))
			index += 1


func is_position_fogged(world_position: Vector3) -> bool:
	return not settlement_manager.is_position_inside_settlement(world_position)
