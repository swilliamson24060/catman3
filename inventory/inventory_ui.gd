extends CanvasLayer
class_name InventoryUI
## Toggleable inventory panel. Press the "toggle_inventory" action (default: I)
## to show/hide it. Rebuilds its grid of InventorySlot instances whenever the
## Inventory singleton's slot count changes.

const SLOT_SCENE := preload("res://inventory/inventory_slot.tscn")

@onready var root_control: Control = $Control
@onready var grid: GridContainer = $Control/Panel/Margin/VBox/Grid
@onready var inventory: Node = get_node("/root/Inventory")
@onready var item_name: Label = $Control/Panel/Margin/VBox/Details/ItemName
@onready var item_description: Label = $Control/Panel/Margin/VBox/Details/ItemDescription
@onready var item_usage: Label = $Control/Panel/Margin/VBox/Details/ItemUsage
@onready var use_button: Button = $Control/Panel/Margin/VBox/Details/UseButton

var _selected_slot: int = -1

func _ready() -> void:
	root_control.visible = false
	inventory.inventory_changed.connect(_rebuild)
	inventory.inventory_changed.connect(_refresh_details)
	use_button.pressed.connect(_use_selected_item)
	_rebuild()
	_refresh_details()

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
		slot.selected.connect(_select_slot)
		grid.add_child(slot)


func _select_slot(index: int) -> void:
	_selected_slot = index
	_refresh_details()


func _refresh_details() -> void:
	var data: Dictionary = inventory.call("get_slot", _selected_slot)
	if data.is_empty():
		item_name.text = "Select an item"
		item_description.text = "Click an inventory object to identify it."
		item_usage.text = ""
		use_button.hide()
		return
	var item: InventoryItem = data.item
	item_name.text = "%s  ×%d" % [item.display_name, data.quantity]
	item_description.text = item.description
	item_usage.text = "Use: %s" % str(inventory.call("get_item_usage", item))
	use_button.text = str(item.properties.get("use_label", "Use Item"))
	use_button.visible = not str(item.properties.get("use_action", "")).is_empty()


func _use_selected_item() -> void:
	var result: Dictionary = inventory.call("use_item_at", _selected_slot)
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.call("request_feedback", str(result.get("message", "")))
	_refresh_details()
