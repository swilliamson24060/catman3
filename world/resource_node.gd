extends Area3D
class_name ResourceNode
## A harvestable resource node sitting on one grid tile. Builds its own
## placeholder visual procedurally (no external art needed) and stays
## invisible/non-collidable until GridService reports its tile revealed,
## which is what makes fog-of-war actually gate resource discovery per the
## GDD's "uncovers resource nodes" loop.

@export var item_id: String = "wood"
@export var amount: int = 1
@export var grid_pos: Vector2i = Vector2i.ZERO
## Rare nodes (moonstone) are what the Whisker-Radar Hot/Cold UI homes in
## on while their tile is still fogged -- see GridService.register_resource_node.
@export var is_rare: bool = false
@onready var grid_service: Node = get_node("/root/GridService")
@onready var data_registry: Node = get_node("/root/DataRegistry")
@onready var inventory: Node = get_node("/root/Inventory")

func _ready() -> void:
	_build_visual()
	_build_collision()

	monitoring = bool(grid_service.call("is_revealed", grid_pos))
	visible = monitoring
	grid_service.call("set_resource_occupied", grid_pos, true)
	grid_service.call("register_resource_node", grid_pos, self)

	body_entered.connect(_on_body_entered)
	grid_service.tile_revealed.connect(_on_tile_revealed)
	tree_exiting.connect(_on_tree_exiting)

func _on_tile_revealed(pos: Vector2i) -> void:
	if pos == grid_pos:
		visible = true
		monitoring = true

func _on_tree_exiting() -> void:
	grid_service.call("set_resource_occupied", grid_pos, false)
	grid_service.call("unregister_resource_node", grid_pos)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player_cat"):
		return
	var result := harvest()
	if result.is_empty():
		return
	var item: InventoryItem = data_registry.call("make_inventory_item", result.item_id)
	if item == null:
		return
	inventory.call("add_item", item, result.amount)

## Generic harvest entry point -- usable by the player's collision-based
## pickup above, or explicitly by AnimalManager on behalf of a mouse (which
## has no physics body to trigger body_entered). Returns {item_id, amount}
## and frees this node, or an empty Dictionary if it's already been claimed.
func harvest() -> Dictionary:
	if not is_inside_tree():
		return {}
	var result := {"item_id": item_id, "amount": amount}
	queue_free()
	return result

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	var mesh: Mesh

	match item_id:
		"wood":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.16
			cyl.bottom_radius = 0.16
			cyl.height = 0.6
			mesh = cyl
			mat.albedo_color = Color(0.42, 0.28, 0.15)
		"twigs":
			var box := BoxMesh.new()
			box.size = Vector3(0.55, 0.08, 0.08)
			mesh = box
			mat.albedo_color = Color(0.55, 0.4, 0.2)
		"yarn":
			var sphere := SphereMesh.new()
			sphere.radius = 0.26
			sphere.height = 0.52
			mesh = sphere
			mat.albedo_color = Color(0.8, 0.3, 0.5)
		"cheese_mild":
			var wedge := BoxMesh.new()
			wedge.size = Vector3(0.32, 0.2, 0.32)
			mesh = wedge
			mat.albedo_color = Color(0.95, 0.85, 0.35)
		"moonstone":
			var gem := PrismMesh.new()
			gem.size = Vector3(0.28, 0.3, 0.28)
			mesh = gem
			mat.albedo_color = Color(0.55, 0.75, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(0.5, 0.8, 1.0)
			mat.emission_energy_multiplier = 1.5
		_:
			var box2 := BoxMesh.new()
			box2.size = Vector3(0.3, 0.3, 0.3)
			mesh = box2
			mat.albedo_color = Color(0.7, 0.7, 0.7)

	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, mat)
	mesh_instance.position.y = 0.3
	add_child(mesh_instance)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.5
	shape.shape = sphere_shape
	shape.position.y = 0.3
	add_child(shape)
