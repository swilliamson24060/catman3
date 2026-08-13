class_name RebootFounderCat
extends CharacterBody3D

@export_category("Movement feel")
@export var maximum_speed: float = 5.25
@export var acceleration: float = 24.0
@export var deceleration: float = 32.0
@export var turn_speed: float = 12.0
@export var interaction_radius: float = 2.4

## The world is several separate hand-authored/generated grounded areas
## (the clearing, the woodland route, the ruin, exploration areas) rather
## than one continuous floor, with real gaps between them. Rather than
## trying to wall off every edge of an evolving, organically-shaped
## playspace, catch the fall instead: track the last position that had solid
## ground underfoot, and snap back there if we ever drop below the world.
const FALL_RECOVERY_Y := -8.0

var input_enabled: bool = true
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _active_anchor: InteractionAnchor
var _last_grounded_position: Vector3
var _cat_animation_player: AnimationPlayer
var _current_cat_animation := ""

@onready var prompt_label: Label = get_tree().get_first_node_in_group("reboot_interaction_prompt") as Label
@onready var carried_material_visual: MeshInstance3D = $CarriedItemSocket/CarriedMaterial

func _ready() -> void:
	add_to_group("reboot_player")
	add_to_group("player_cat")
	_last_grounded_position = global_position
	get_node("/root/CommunityProjectService").carried_material_changed.connect(_on_carried_material_changed)
	_on_carried_material_changed(&"")

## There is only one physical carry socket on the model, but the founder can
## now carry several material kinds at once (see CommunityProjectService.
## carried_materials) -- this shows whichever material the just-changed
## signal refers to if still carried, falling back to any other carried
## material so the visual doesn't go empty just because a different item
## in the same load was the one that changed.
func _on_carried_material_changed(material_id: StringName) -> void:
	var service := get_node("/root/CommunityProjectService")
	var display_id: StringName = material_id if service.carried_count(material_id) > 0 else _any_carried_material(service)
	carried_material_visual.visible = not display_id.is_empty()
	if display_id.is_empty(): return
	var material := StandardMaterial3D.new()
	match display_id:
		&"reclaimed_wood": material.albedo_color = Color(0.72, 0.42, 0.18)
		&"smooth_stone": material.albedo_color = Color(0.52, 0.58, 0.62)
		_: material.albedo_color = Color(0.76, 0.68, 0.22)
	carried_material_visual.material_override = material

func _any_carried_material(service: Node) -> StringName:
	for id: Variant in service.carried_materials.keys():
		var mid := StringName(str(id))
		if service.carried_count(mid) > 0: return mid
	return &""

func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed("interact") and _active_anchor != null:
		_active_anchor.interact(self)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_update_interaction_anchor()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
		_last_grounded_position = global_position
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_enabled else Vector2.ZERO
	var camera := get_viewport().get_camera_3d()
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if camera != null:
		forward = -camera.global_basis.z
		right = camera.global_basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
	var desired_direction := (right * input_vector.x + forward * -input_vector.y).normalized()
	var desired_velocity := desired_direction * maximum_speed
	var rate := acceleration if not desired_direction.is_zero_approx() else deceleration
	velocity.x = move_toward(velocity.x, desired_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, rate * delta)
	if not desired_direction.is_zero_approx():
		var target_yaw := atan2(-desired_direction.x, -desired_direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, turn_speed * delta))
	move_and_slide()
	_check_boundary_contact()
	if global_position.y < FALL_RECOVERY_Y:
		global_position = _last_grounded_position
		velocity = Vector3.ZERO
	get_node("/root/ExpeditionService").notify_founder_moved(global_position)
	_update_cat_animation()

## The model (and its AnimationPlayer) doesn't exist until CatAppearance.
## apply_to_player() runs -- looked up lazily rather than at _ready(), and
## re-checked each time since is_instance_valid() catches the old one being
## freed when the founder's model is (re)applied.
func _update_cat_animation() -> void:
	if _cat_animation_player == null or not is_instance_valid(_cat_animation_player):
		_cat_animation_player = CatAppearance.find_animation_player(self)
	if _cat_animation_player == null:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var target := "run" if horizontal_speed > maximum_speed * 0.65 else ("walk" if horizontal_speed > 0.15 else "idle")
	if target == _current_cat_animation:
		return
	if _cat_animation_player.has_animation(target):
		_cat_animation_player.play(target)
		_current_cat_animation = target

## Walls tagged "world_boundary" (see village_clearing.gd's
## _create_boundary_wall) are otherwise invisible collision -- this is the
## only thing that tells the player *why* they stopped, rather than leaving
## them pushing uselessly against nothing.
func _check_boundary_contact() -> void:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is Node and (collider as Node).is_in_group("world_boundary"):
			var shell := get_tree().get_first_node_in_group("reboot_ui_shell")
			if shell != null and shell.has_method("show_boundary_notice"):
				shell.show_boundary_notice("You're at the edge of the village.")
			return

## Called by ExpeditionService right after teleporting the founder (visiting
## or leaving an exploration area) so the fall-recovery reference point
## updates to the new position immediately, instead of possibly snapping
## back to wherever the founder stood before the teleport.
func reset_fall_recovery() -> void:
	_last_grounded_position = global_position

func _update_interaction_anchor() -> void:
	var nearest: InteractionAnchor
	var nearest_distance := interaction_radius
	for candidate: Node in get_tree().get_nodes_in_group("interaction_anchors"):
		var anchor := candidate as InteractionAnchor
		if anchor == null or not anchor.enabled:
			continue
		var distance := global_position.distance_to(anchor.global_position)
		if distance <= nearest_distance:
			nearest = anchor
			nearest_distance = distance
	if nearest == _active_anchor:
		return
	if _active_anchor != null:
		_active_anchor.set_focused(false)
	_active_anchor = nearest
	if _active_anchor != null:
		_active_anchor.set_focused(true)
	if prompt_label != null:
		prompt_label.text = "[E] %s" % _active_anchor.prompt if _active_anchor != null else ""
		prompt_label.visible = _active_anchor != null
		prompt_label.get_parent().visible = _active_anchor != null

func get_active_anchor() -> InteractionAnchor:
	return _active_anchor
