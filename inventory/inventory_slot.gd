extends PanelContainer
class_name InventorySlot
## A single inventory grid cell. Displays an item icon + stack count and
## supports drag-and-drop to reorder/stack/swap items via Inventory.move_item.

@export var slot_index: int = 0

@onready var icon_rect: TextureRect = $Margin/Icon
@onready var count_label: Label = $Margin/Count

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Inventory.slot_changed.connect(_on_slot_changed)
	refresh()

func _on_slot_changed(index: int) -> void:
	if index == slot_index:
		refresh()

func refresh() -> void:
	var data := Inventory.get_slot(slot_index)
	if data.is_empty():
		icon_rect.texture = null
		count_label.text = ""
		tooltip_text = ""
	else:
		icon_rect.texture = data.item.icon
		count_label.text = str(data.quantity) if data.quantity > 1 else ""
		tooltip_text = data.item.display_name if data.item.description == "" else "%s\n%s" % [data.item.display_name, data.item.description]

func _get_drag_data(_at_position: Vector2) -> Variant:
	var data := Inventory.get_slot(slot_index)
	if data.is_empty():
		return null

	var preview := TextureRect.new()
	preview.texture = data.item.icon
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)

	return {"from_index": slot_index}

func _can_drop_data(_at_position: Vector2, drag_data: Variant) -> bool:
	return typeof(drag_data) == TYPE_DICTIONARY and drag_data.has("from_index")

func _drop_data(_at_position: Vector2, drag_data: Variant) -> void:
	Inventory.move_item(drag_data.from_index, slot_index)
