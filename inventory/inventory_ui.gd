extends CanvasLayer
class_name InventoryUI
## Toggleable inventory panel. Press the "toggle_inventory" action (default: I)
## to show/hide it. Rebuilds its grid of InventorySlot instances whenever the
## Inventory singleton's slot count changes.

const SLOT_SCENE := preload("res://inventory/inventory_slot.tscn")

@onready var root_control: Control = $Control
@onready var grid: GridContainer = $Control/Panel/Margin/VBox/Grid
@onready var inventory: Node = get_node("/root/Inventory")

func _ready() -> void:
	root_control.visible = false
	inventory.inventory_changed.connect(_rebuild)
	_rebuild()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	root_control.visible = not root_control.visible

func _rebuild() -> void:
	var slots: Array = inventory.get("slots")
	if grid.get_child_count() == slots.size():
		return
	for child in grid.get_children():
		child.queue_free()
	for i in slots.size():
		var slot: InventorySlot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		grid.add_child(slot)
