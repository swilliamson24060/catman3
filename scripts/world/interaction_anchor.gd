class_name InteractionAnchor
extends Node3D

signal activated(anchor_id: StringName)

@export var anchor_id: StringName
@export var prompt: String = "Inspect"
@export var enabled: bool = true
## Optional first-visit explanation. When set, the first interact() shows
## this instead of firing -- the underlying action only runs once the player
## dismisses it, so it can't fire silently alongside a place they've never
## seen before. Leave intro_title empty to skip this entirely.
@export var intro_title: String = ""
@export var intro_body: String = ""
## Overrides anchor_id as the "have I introduced this before" tracking key.
## Leave empty to track by anchor_id (the default, right for a one-of-a-kind
## anchor). Set this when several anchor instances -- e.g. the three
## resonance plinths -- should share a single first-visit explanation
## instead of each showing its own the first time it's touched.
@export var intro_key: StringName = &""

@onready var icon: Sprite3D = $Icon

func _ready() -> void:
	add_to_group("interaction_anchors")
	set_meta("development_placeholder", true)

func interact(_player: Node3D) -> void:
	if not intro_title.is_empty():
		var shell := get_tree().get_first_node_in_group("reboot_ui_shell")
		var key := intro_key if not intro_key.is_empty() else anchor_id
		if shell != null and shell.maybe_show_intro(key, intro_title, intro_body, _fire):
			return
	_fire()

func _fire() -> void:
	activated.emit(anchor_id)
	print("[Interaction] %s" % anchor_id)

func set_focused(focused: bool) -> void:
	if icon != null:
		icon.modulate = Color(1.0, 0.92, 0.45, 1.0) if focused else Color.WHITE
		icon.scale = Vector3.ONE * (1.18 if focused else 1.0)
