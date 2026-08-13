class_name ProjectMaterialSource
extends Node3D

@export var material_id: StringName
@export var display_name: String = "material"
@export var placeholder_color: Color = Color.WHITE

var _anchor: InteractionAnchor

func _ready() -> void:
	set_meta("development_placeholder", true)
	_build_placeholder()
	_anchor = preload("res://scenes/world/interaction_anchor.tscn").instantiate() as InteractionAnchor
	_anchor.anchor_id = StringName("source_%s" % material_id)
	_anchor.activated.connect(_on_interaction)
	add_child(_anchor)
	_refresh()
	get_node("/root/CommunityProjectService").carried_material_changed.connect(_on_carried_changed)

func _build_placeholder() -> void:
	var visual := MeshInstance3D.new()
	visual.name = "Presentation"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.75, 0.55, 0.75)
	visual.mesh = mesh
	visual.position.y = 0.28
	var material := StandardMaterial3D.new()
	material.albedo_color = placeholder_color
	material.roughness = 0.9
	visual.material_override = material
	add_child(visual)

func _on_interaction(_anchor_id: StringName) -> void:
	var service := get_node("/root/CommunityProjectService")
	if service.carried_count(material_id) > 0:
		service.return_carried_material(material_id)
	elif service.gather_material(material_id):
		_show_pickup_guidance()
	_refresh()

## The founder can gather several materials at once (see
## CommunityProjectService.carried_materials) and nothing previously told
## the player where any of it goes -- picking something up looked identical
## to every other interaction. The very first-ever pickup, of any material,
## gets a full explanation of the general carry/deliver mechanic as a modal
## (impossible to miss, matches how first-visit anchor intros teach a
## mechanic once) -- that fires unconditionally, since it's teaching how the
## system works in general, not directing the player anywhere specific right
## now. Every later pickup gets a short reminder toast instead, and THAT one
## does check phase_wants_material(): sources stay gatherable across every
## phase (a player can stockpile ahead), but the garden only accepts the one
## material the current phase needs, so a repeat toast that unconditionally
## says "bring it to the garden" would routinely send a player on a trip
## just to be turned away with a "doesn't need this" message -- the original
## reported bug.
func _show_pickup_guidance() -> void:
	var shell := get_tree().get_first_node_in_group("reboot_ui_shell")
	if shell == null:
		return
	var experience := get_node("/root/UserExperienceService")
	if experience.introduce_anchor(&"gather_material"):
		shell.show_dialog("Carrying %s" % display_name, "You picked up %s. It only sits in your paws until you deliver it -- bring it to the abandoned garden and interact there when you arrive; the prompt will change to \"Deliver\" once you're close enough." % display_name)
		return
	var service := get_node("/root/CommunityProjectService")
	if service.phase_wants_material(material_id):
		shell.show_event_toast("Carrying %s -- bring it to the abandoned garden." % display_name)
	else:
		shell.show_event_toast("Carrying %s -- the garden doesn't need this yet; hold onto it for a later phase." % display_name)

func _on_carried_changed(_material_id: StringName) -> void:
	_refresh()

func _refresh() -> void:
	if _anchor == null: return
	var service := get_node("/root/CommunityProjectService")
	var remaining := int(service.source_remaining.get(material_id, 0))
	var carrying: int = service.carried_count(material_id)
	_anchor.enabled = remaining > 0 or carrying > 0
	_anchor.prompt = "Return %s" % display_name if carrying > 0 else "Gather %s (%d nearby)" % [display_name, remaining]
