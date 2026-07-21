class_name FounderData
extends Resource

@export var internal_id: StringName
@export var display_name: String
@export_multiline var title: String
@export_multiline var description: String
@export var appearance_id: StringName = &"cat"
@export var tint: Color = Color.WHITE

@export_category("Gameplay Modifiers")
@export var recruitment_rate_multiplier: float = 1.0
@export var building_speed_multiplier: float = 1.0
@export var cheese_yield_multiplier: float = 1.0
@export var worker_pay_multiplier: float = 1.0
@export var resource_discovery_multiplier: float = 1.0
@export var stray_recruitment_multiplier: float = 1.0
