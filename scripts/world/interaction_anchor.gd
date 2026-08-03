class_name InteractionAnchor
extends Node3D

signal activated(anchor_id: StringName)

@export var anchor_id: StringName
@export var prompt: String = "Inspect"
@export var enabled: bool = true

@onready var icon: Sprite3D = $Icon

func _ready() -> void:
	add_to_group("interaction_anchors")
	set_meta("development_placeholder", true)

func interact(_player: Node3D) -> void:
	activated.emit(anchor_id)
	print("[Interaction] %s" % anchor_id)

func set_focused(focused: bool) -> void:
	if icon != null:
		icon.modulate = Color(1.0, 0.92, 0.45, 1.0) if focused else Color.WHITE
		icon.scale = Vector3.ONE * (1.18 if focused else 1.0)
