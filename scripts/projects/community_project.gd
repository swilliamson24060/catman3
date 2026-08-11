class_name CommunityProject
extends Node3D

signal interaction_requested

@export var project_id: StringName = &"project_restore_garden"

@onready var phase_presentations: Node3D = $PhasePresentations
@onready var contribution_slots: Node3D = $ContributionSlots
@onready var interaction_anchor: InteractionAnchor = $InteractionAnchor
@onready var status_label: Label3D = $StatusLabel

func _ready() -> void:
	add_to_group("community_projects")
	set_meta("development_placeholder", true)
	interaction_anchor.intro_title = "Garden Restoration"
	interaction_anchor.intro_body = "An abandoned garden the village can restore together. Propose it at the Community Board first, then gather materials nearby and bring them here -- residents will pitch in once enough is delivered."
	interaction_anchor.activated.connect(_on_interaction)
	get_node("/root/CommunityProjectService").bind_project_scene(self)
	_refresh_prompt()

func _exit_tree() -> void:
	var service := get_node_or_null("/root/CommunityProjectService")
	if service != null: service.unbind_project_scene(self)

func apply_project_state(phase_index: int, completed: bool) -> void:
	for index in range(phase_presentations.get_child_count()):
		phase_presentations.get_child(index).visible = index == (4 if completed else phase_index)
	status_label.text = "RESTORED" if completed else "PHASE %d/5" % (phase_index + 1)
	_refresh_prompt()

func contribution_slot_position(index: int) -> Vector3:
	if contribution_slots.get_child_count() == 0: return global_position
	return (contribution_slots.get_child(index % contribution_slots.get_child_count()) as Node3D).global_position

func _on_interaction(_anchor_id: StringName) -> void:
	interaction_requested.emit()
	var service := get_node("/root/CommunityProjectService")
	var shell := get_tree().get_first_node_in_group("reboot_ui_shell")
	if not service.active and not service.completed:
		if shell != null: shell.show_event_toast("Propose this project at the Community Board first.")
	elif not service.carried_material.is_empty():
		var material_name: String = service.material_display_name(service.carried_material)
		if service.deposit_carried_material():
			if shell != null: shell.show_event_toast("Delivered %s." % material_name)
		elif shell != null:
			shell.show_event_toast("The garden doesn't need more %s right now." % material_name)
	elif service.can_player_contribute():
		service.contribute(&"founder", true)
	_refresh_prompt()

func _refresh_prompt() -> void:
	var service := get_node_or_null("/root/CommunityProjectService")
	if service != null: interaction_anchor.prompt = service.interaction_prompt()
