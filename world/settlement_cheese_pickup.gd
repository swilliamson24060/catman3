class_name SettlementCheesePickup
extends Area3D

signal collected(pickup: Node3D, collector: Node3D)

@export var amount: int = 1

@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var inventory: Node = get_node("/root/Inventory")
@onready var data_registry: Node = get_node("/root/DataRegistry")

var _was_collected: bool = false


func _ready() -> void:
	add_to_group("settlement_cheese_pickups")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	_build_visual()
	_build_collision()
	body_entered.connect(_on_body_entered)


func collect(collector: Node3D) -> bool:
	if _was_collected or collector == null:
		return false
	if collector.is_in_group("player_cat"):
		var cheese: InventoryItem = data_registry.call("make_inventory_item", "cheese_mild")
		if cheese == null:
			return false
		if int(inventory.call("get_available_capacity", cheese)) < amount:
			game_state.request_feedback("Inventory full — make room before collecting Mild Cheese.")
			return false
		inventory.call("add_item", cheese, amount)
		game_state.request_feedback("Found %d Mild Cheese. Open Inventory (I) to identify or use it." % amount)
	elif collector.is_in_group("wild_mice") and collector.has_method("collect_random_cheese"):
		collector.call("collect_random_cheese", amount)
	else:
		return false
	_was_collected = true
	collected.emit(self, collector)
	queue_free()
	return true


func _on_body_entered(body: Node3D) -> void:
	collect(body)


func _build_visual() -> void:
	var wedge := PrismMesh.new()
	wedge.size = Vector3(0.48, 0.32, 0.44)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.78, 0.16)
	material.emission_enabled = true
	material.emission = Color(0.45, 0.2, 0.02)
	material.emission_energy_multiplier = 0.65
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "CheeseVisual"
	mesh_instance.position.y = 0.3
	mesh_instance.mesh = wedge
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var label := Label3D.new()
	label.name = "PickupLabel"
	label.position = Vector3(0.0, 0.85, 0.0)
	label.text = "+1 CHEESE"
	label.modulate = Color(1.0, 0.9, 0.35)
	label.font_size = 24
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "PickupCollision"
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	collision.position.y = 0.35
	collision.shape = shape
	add_child(collision)
