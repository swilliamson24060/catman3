class_name InventorySerializer
extends RefCounted
## Shared save/load helper for Inventory and TownStorage. They're
## deliberately separate autoloads (player-carried vs. town-stockpiled --
## see town_storage.gd's own comment) but use the exact same slot shape, so
## the (de)serialization logic only needs to exist once.

static func serialize_slots(slots: Array) -> Array:
	var out: Array = []
	for slot in slots:
		if slot == null:
			out.append(null)
			continue
		var entry := {"item_id": slot.item.id, "quantity": slot.quantity}
		if slot.has("age"):
			entry["age"] = slot.age
		out.append(entry)
	return out

## Rebuilds a slots array from serialized data. Any item id that no longer
## resolves (a removed expansion, a save from an older content version) is
## dropped silently rather than crashing the load -- a save/load robustness
## requirement, not a modding nicety.
static func restore_slots(data: Array, slot_count: int) -> Array:
	var slots: Array = []
	slots.resize(slot_count)
	for i in slot_count:
		slots[i] = null

	for i in mini(data.size(), slot_count):
		var entry = data[i]
		if entry == null or not (entry is Dictionary):
			continue
		var item := DataRegistry.make_inventory_item(str(entry.get("item_id", "")))
		if item == null:
			continue
		var quantity := clampi(int(entry.get("quantity", 0)), 0, item.max_stack)
		if quantity <= 0:
			continue
		var restored := {"item": item, "quantity": quantity}
		if entry.has("age"):
			restored["age"] = maxf(float(entry.get("age", 0.0)), 0.0)
		slots[i] = restored
	return slots
