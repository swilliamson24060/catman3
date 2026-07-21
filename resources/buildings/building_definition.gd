class_name BuildingDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var completed_scene: PackedScene
@export var footprint_radius: float = 1.25
@export var work_required: float = 100.0
@export var minimum_workers: int = 1
@export var preferred_worker_count: int = 2
@export var base_construction_turns: float = 5.0
@export var settlement_influence_radius: float = 0.0
@export var tags: Array[StringName] = []
@export var tier: StringName = &"cardboard"
@export var waterproof: bool = false
@export var max_durability: float = 100.0
@export var locked_by_default: bool = false
@export var unlock_content_id: StringName
@export var production_resource: StringName
@export var production_amount: int = 0
@export var production_interval_seconds: float = 0.0
## Resource id -> amount consumed atomically when one production cycle completes.
@export var production_inputs: Dictionary = {}
