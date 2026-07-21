extends Node
## Autoload "TownStorage". Same slot-based item model as the player's
## personal Inventory (deliberately duplicated rather than shared -- the two
## are conceptually different pools: what the cat is carrying vs. what the
## town has stockpiled), but this is where finished buildings' automatic
## production lands (BuildingManager) and, later, what construction/upkeep
## costs draw from once those move off the player's personal inventory.

signal slot_changed(index: int)
signal inventory_changed()

const _InvSerializer := preload("res://core/inventory_serializer.gd")

@export var slot_count: int = 40

var slots: Array = []

func _ready() -> void:
	slots.resize(slot_count)
	for i in slot_count:
		slots[i] = null

func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= slots.size():
		return {}
	return slots[index] if slots[index] != null else {}

func get_item_count(id: String) -> int:
	var total := 0
	for slot in slots:
		if slot != null and slot.item.id == id:
			total += slot.quantity
	return total

func add_item(item: InventoryItem, amount: int = 1) -> int:
	var remaining := amount

	for i in slots.size():
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot.item.id == item.id and slot.quantity < item.max_stack:
			var space: int = item.max_stack - slot.quantity
			var add_amt: int = min(space, remaining)
			slot.quantity += add_amt
			remaining -= add_amt
			slot_changed.emit(i)

	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i] == null:
			var add_amt: int = min(item.max_stack, remaining)
			slots[i] = {"item": item, "quantity": add_amt}
			remaining -= add_amt
			slot_changed.emit(i)

	inventory_changed.emit()
	return remaining

func remove_item(id: String, amount: int) -> bool:
	if get_item_count(id) < amount:
		return false

	var remaining := amount
	for i in slots.size():
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot.item.id == id:
			var take: int = min(slot.quantity, remaining)
			slot.quantity -= take
			remaining -= take
			if slot.quantity <= 0:
				slots[i] = null
			slot_changed.emit(i)

	inventory_changed.emit()
	return true

## Step 9: save/load robustness, via the same slot shape Inventory uses.
func serialize() -> Array:
	return _InvSerializer.serialize_slots(slots)

func restore(data: Array) -> void:
	slots = _InvSerializer.restore_slots(data, slot_count)
	inventory_changed.emit()
