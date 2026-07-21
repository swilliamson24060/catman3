extends Node
## Populates the inventory with a few sample items so the UI has something
## to show right away. Safe to delete once you're adding real items yourself
## (e.g. via Inventory.add_item(my_item, amount) from pickup/loot code).

func _ready() -> void:
	var sword := InventoryItem.new()
	sword.id = "sword"
	sword.display_name = "Sword"
	sword.description = "A sharp blade."
	sword.icon = load("res://inventory/icons/sword.png")
	sword.max_stack = 1

	var potion := InventoryItem.new()
	potion.id = "potion"
	potion.display_name = "Health Potion"
	potion.description = "Restores health."
	potion.icon = load("res://inventory/icons/potion.png")
	potion.max_stack = 99

	var coin := InventoryItem.new()
	coin.id = "coin"
	coin.display_name = "Gold Coin"
	coin.description = "Shiny currency."
	coin.icon = load("res://inventory/icons/coin.png")
	coin.max_stack = 999

	Inventory.add_item(sword, 1)
	Inventory.add_item(potion, 5)
	Inventory.add_item(coin, 42)
