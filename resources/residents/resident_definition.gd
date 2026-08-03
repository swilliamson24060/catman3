class_name ResidentDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var specialty: StringName
@export var personality_tags: Array[String] = []
@export var likes: Array[String] = []
@export var dislikes: Array[String] = []
@export var home_id: StringName
@export var aspiration_id: StringName
@export var aspiration_steps: Array[String] = []
@export var routines: Dictionary = {}
