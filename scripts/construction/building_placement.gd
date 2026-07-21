class_name BuildingPlacementController
extends Node

const SITE_SCENE: PackedScene = preload("res://scenes/construction/construction_site.tscn")
const TEST_STRUCTURE: BuildingDefinition = preload("res://resources/buildings/test_structure.tres")
const CATNIP_GARDEN: BuildingDefinition = preload("res://resources/buildings/catnip_garden.tres")
const MOUSE_HUT: BuildingDefinition = preload("res://resources/buildings/mouse_hut.tres")
const CHEESE_VAULT: BuildingDefinition = preload("res://resources/buildings/cheese_vault.tres")
const VALID_COLOR := Color(0.2, 0.95, 0.4, 0.5)
const INVALID_COLOR := Color(0.95, 0.2, 0.16, 0.5)

@export_range(1.5, 6.0, 0.25) var placement_distance: float = 3.0
@export_range(0.0, 60.0, 1.0) var maximum_slope_degrees: float = 25.0

@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState
@onready var settlement_manager: Phase2SettlementManager = get_node("/root/SettlementManager") as Phase2SettlementManager
@onready var achievement_service: Node = get_node("/root/AchievementService")

var _preview: MeshInstance3D
var _preview_label: Label3D
var _preview_material := StandardMaterial3D.new()
var _selected_definition: BuildingDefinition
var _is_valid: bool = false
var _validation_message: String = ""


func _ready() -> void:
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _process(_delta: float) -> void:
	if _preview != null:
		_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not game_state.has_founder() or game_state.is_dialogue_open() or game_state.is_construction_site_open():
		return
	if event.is_action_pressed("toggle_build_menu"):
		if _preview != null:
			cancel_placement()
		else:
			game_state.toggle_build_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("select_building_1"):
		begin_placement(TEST_STRUCTURE)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("select_building_2"):
		begin_placement(CATNIP_GARDEN)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("select_building_3"):
		begin_placement(MOUSE_HUT)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("select_building_4"):
		if not is_definition_unlocked(CHEESE_VAULT):
			game_state.request_feedback("Cheese Vault unlocks after recruiting five mice.")
		else:
			begin_placement(CHEESE_VAULT)
		get_viewport().set_input_as_handled()
		return
	if _preview == null:
		return
	if event.is_action_pressed("interact"):
		confirm_placement()
		get_viewport().set_input_as_handled()


func is_placing() -> bool:
	return _preview != null


func begin_placement(definition: BuildingDefinition) -> void:
	if definition == null:
		return
	if not is_definition_unlocked(definition):
		game_state.request_feedback("%s is still locked." % definition.display_name)
		return
	cancel_placement(false)
	game_state.set_build_menu_open(false)
	_selected_definition = definition
	var mesh := CylinderMesh.new()
	mesh.top_radius = definition.footprint_radius
	mesh.bottom_radius = definition.footprint_radius
	mesh.height = 0.08
	_preview = MeshInstance3D.new()
	_preview.mesh = mesh
	_preview.material_override = _preview_material
	get_tree().current_scene.add_child(_preview)
	_preview_label = Label3D.new()
	_preview_label.position = Vector3(0.0, 0.75, 0.0)
	_preview_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_preview_label.no_depth_test = true
	_preview_label.font_size = 28
	_preview_label.outline_size = 9
	_preview.add_child(_preview_label)
	game_state.set_placement_mode(true)
	game_state.set_build_selection(definition.display_name)
	_set_boundary_visible(true)


func is_definition_unlocked(definition: BuildingDefinition) -> bool:
	if definition == null or not definition.locked_by_default:
		return true
	return bool(achievement_service.call("is_unlocked", str(definition.unlock_content_id)))


func cancel_placement(show_feedback: bool = true) -> void:
	if _preview == null:
		return
	_preview.queue_free()
	_preview = null
	_preview_label = null
	_selected_definition = null
	_is_valid = false
	game_state.set_placement_mode(false)
	game_state.set_build_selection("")
	_set_boundary_visible(false)
	if show_feedback:
		game_state.request_feedback("Building placement cancelled.")


func confirm_placement() -> void:
	if _preview == null:
		return
	if not _is_valid:
		game_state.request_feedback(_validation_message)
		return
	var container := get_tree().get_first_node_in_group("construction_site_container") as Node3D
	if container == null:
		game_state.request_feedback("Construction container unavailable.")
		return
	var site := SITE_SCENE.instantiate() as ConstructionSite
	container.add_child(site)
	site.global_transform = _preview.global_transform
	site.configure(_selected_definition)
	game_state.construction_site_placed.emit(site)
	game_state.request_feedback("%s site placed. It needs %d mice for 5 turns; extra mice can reduce that to 3." % [_selected_definition.display_name, _selected_definition.minimum_workers])
	cancel_placement(false)


func _update_preview() -> void:
	var forward := -player.global_basis.z
	forward.y = 0.0
	var target := player.global_position + forward.normalized() * placement_distance
	var query := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 6.0, target + Vector3.DOWN * 8.0, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	_is_valid = false
	_validation_message = "No valid ground detected."
	_preview.visible = not hit.is_empty()
	if not hit.is_empty():
		var position: Vector3 = settlement_manager.snap_to_resonance_grid(hit["position"])
		var normal: Vector3 = hit["normal"]
		_preview.global_position = position + normal * 0.04
		var slope_ok := normal.dot(Vector3.UP) >= cos(deg_to_rad(maximum_slope_degrees))
		var territory_ok := settlement_manager.is_position_inside_settlement(position)
		var clear := not _is_blocked(position)
		_is_valid = slope_ok and territory_ok and clear
		if not slope_ok:
			_validation_message = "Ground is too steep."
		elif not territory_ok:
			_validation_message = "Outside controlled settlement territory."
		elif not clear:
			_validation_message = "The footprint overlaps blocked geometry or another site."
		else:
			_validation_message = "Valid placement — press E to place construction marker."
	_preview_material.albedo_color = VALID_COLOR if _is_valid else INVALID_COLOR
	if _preview_label != null:
		_preview_label.modulate = Color(0.55, 1.0, 0.62) if _is_valid else Color(1.0, 0.48, 0.42)
		_preview_label.text = "%s\n%s" % [
			"%s • %d MICE • +%.0fM TERRITORY" % [_selected_definition.display_name, _selected_definition.minimum_workers, _selected_definition.settlement_influence_radius],
			"PRESS E TO BUILD HERE" if _is_valid else _validation_message.to_upper(),
		]
	game_state.set_placement_validity(_validation_message, _is_valid)


func _is_blocked(position: Vector3) -> bool:
	var shape := CylinderShape3D.new()
	shape.radius = _selected_definition.footprint_radius
	shape.height = 0.3
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.3)
	query.collision_mask = 1 | 4
	query.exclude = [player.get_rid()]
	query.collide_with_areas = true
	return not player.get_world_3d().direct_space_state.intersect_shape(query, 4).is_empty()


func _set_boundary_visible(_is_visible: bool) -> void:
	var boundary := get_tree().get_first_node_in_group("settlement_boundary") as Node3D
	if boundary != null:
		# Territory is now a permanent movement limit, so its initial outline
		# remains visible alongside the influence rings added by new buildings.
		boundary.visible = true
