class_name MousePersonalityData
extends Resource

## Data format version for future migrations of community-created resources.
@export_range(1, 100, 1) var schema_version: int = 1
## Stable unique identifier used for saves, content registries, and mod interoperability.
@export var internal_id: StringName
## Selects a supported animation/behavior presentation without coupling it to the unique ID.
@export var behavior_profile: StringName = &"builder"
## Open-ended semantic tags that other systems or mods can query.
@export var traits: Array[StringName] = []
## Open-ended named modifiers. Values are additive unless the consuming system documents otherwise.
@export var effects: Dictionary[StringName, float] = {}
## Free-form extension data reserved for content-specific configuration.
@export var extension_data: Dictionary = {}

@export_range(0, 20, 1) var recruitment_cost: int = 1
@export_range(0.25, 2.0, 0.05) var move_speed_multiplier: float = 1.0
@export_range(0.25, 3.0, 0.05) var pause_duration_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.05) var inspection_frequency: float = 0.2
@export_range(0.5, 4.0, 0.1) var notice_delay_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var wander_radius_multiplier: float = 1.0
@export var debug_color: Color = Color.WHITE
@export_multiline var picnic_dialogue: Array[String] = []
@export_multiline var recruitment_dialogue: Array[String] = []


## Returns whether the personality advertises the requested semantic trait.
func has_trait(trait_id: StringName) -> bool:
	return traits.has(trait_id)


## Returns a named modifier without requiring callers to inspect the backing dictionary.
func get_effect(effect_id: StringName, default_value: float = 0.0) -> float:
	return effects.get(effect_id, default_value)


## Returns extension data while keeping missing keys safe for optional mod content.
func get_extension_value(key: StringName, default_value: Variant = null) -> Variant:
	return extension_data.get(key, default_value)
