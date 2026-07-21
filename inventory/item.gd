extends Resource
class_name InventoryItem

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99
@export var description: String = ""
## Open-ended, mechanic-specific data (cheese variety/age, wool's source
## animal, etc.) so new attributes never require editing this script.
@export var properties: Dictionary = {}
