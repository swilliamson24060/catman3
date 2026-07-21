extends Node
# Autoload singleton "Inventory". Holds the player's item slots and exposes
# signals the UI listens to. Slots are stored as either null (empty) or a
# Dictionary: { "item": InventoryItem, "quantity": int }.

signal slot_changed(index: int)
signal inventory_changed()

const _InvSerializer := preload("res://core/inventory_serializer.gd")

@export var slot_count: int = 20

var slots: Array = []

func _ready() -> void:
	slots.resize(slot_count)
	for i in slot_count:
		slots[i] = null

## Cheese-Standard Salary (Step 6, mechanic 6): generic timer-based
## degradation for any item whose items.json entry sets
## properties.perishable = true and properties.spoil_time -- not
## cheese-specific, so a future perishable (fresh milk, cut yarn) gets
## this for free. A spoiled stack is removed outright and
## EventBus.item_spoiled fires so something else (AnimalManager's "pests"
## morale penalty) can react without Inventory needing to know why aging
## matters to anyone.
func _process(delta: float) -> void:
	for i in slots.size():
		var slot = slots[i]
		if slot == null:
			continue
		var props: Dictionary = slot.item.properties
		if not props.get("perishable", false):
			continue
		slot.age = slot.get("age", 0.0) + delta
		var spoil_time: float = props.get("spoil_time", INF)
		if slot.age >= spoil_time:
			var item_id: String = slot.item.id
			var amount: int = slot.quantity
			slots[i] = null
			slot_changed.emit(i)
			inventory_changed.emit()
			EventBus.item_spoiled.emit(item_id, amount)

## Returns the slot data at index, or an empty Dictionary if the slot is empty
## or out of range.
func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= slots.size():
		return {}
	return slots[index] if slots[index] != null else {}

## Adds `amount` of `item` to the inventory, stacking onto existing slots
## first, then filling empty slots. Returns the amount that didn't fit.
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
			slots[i] = {"item": item, "quantity": add_amt, "age": 0.0}
			remaining -= add_amt
			slot_changed.emit(i)

	inventory_changed.emit()
	return remaining

## Removes `amount` of whatever is in `index`, clearing the slot if it drops
## to zero or below.
func remove_item_at(index: int, amount: int = 1) -> void:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return
	slots[index].quantity -= amount
	if slots[index].quantity <= 0:
		slots[index] = null
	slot_changed.emit(index)
	inventory_changed.emit()

## Total quantity of item `id` currently held, across all slots.
func get_item_count(id: String) -> int:
	var total := 0
	for slot in slots:
		if slot != null and slot.item.id == id:
			total += slot.quantity
	return total

## Removes `amount` total of item `id`, spread across however many slots it
## occupies. All-or-nothing: if the inventory doesn't hold enough, nothing
## is removed and this returns false. Used to spend recruitment/upkeep
## costs without callers needing to know which slot index holds what.
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

## Moves (or stacks/swaps) the contents of `from_index` into `to_index`.
## Used by drag-and-drop in the UI.
func move_item(from_index: int, to_index: int) -> void:
	if from_index == to_index:
		return
	if from_index < 0 or from_index >= slots.size():
		return
	if to_index < 0 or to_index >= slots.size():
		return

	var from_slot = slots[from_index]
	var to_slot = slots[to_index]
	if from_slot == null:
		return

	if to_slot != null and to_slot.item.id == from_slot.item.id:
		var space: int = from_slot.item.max_stack - to_slot.quantity
		if space > 0:
			var move_amt: int = min(space, from_slot.quantity)
			to_slot.quantity += move_amt
			from_slot.quantity -= move_amt
			if from_slot.quantity <= 0:
				slots[from_index] = null
			slot_changed.emit(from_index)
			slot_changed.emit(to_index)
			inventory_changed.emit()
			return

	# No stacking possible (different item, or target full) -> swap.
	slots[from_index] = to_slot
	slots[to_index] = from_slot
	slot_changed.emit(from_index)
	slot_changed.emit(to_index)
	inventory_changed.emit()

## Changes the number of slots at runtime (e.g. inventory upgrades).
func set_slot_count(count: int) -> void:
	slot_count = count
	slots.resize(count)
	inventory_changed.emit()

## Step 9: save/load robustness, via the same slot shape TownStorage uses.
func serialize() -> Array:
	return _InvSerializer.serialize_slots(slots)

func restore(data: Array) -> void:
	slots = _InvSerializer.restore_slots(data, slot_count)
	inventory_changed.emit()
