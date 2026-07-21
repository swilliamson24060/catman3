extends Node3D
## Grooming & Dust Bunnies (Step 6, mechanic 1): a random spawner that pops
## dust bunnies near active (unbuilt) construction sites -- reads those from
## BuildingManager.get_unbuilt_anchors(), never hardcodes which building
## types count. Left-click near a dust bunny swats it: Lint goes to the
## player's Inventory and a small permanent bump lands on the generic
## global_town/morale stat via the same StatsService pipeline everything
## else uses.

const DUST_BUNNY_SCRIPT := preload("res://world/dust_bunny.gd")

@export var spawn_interval: float = 8.0
@export var spawn_chance: float = 0.6
@export var max_active: int = 5
@export var swat_radius: float = 0.6
@export var lint_reward: int = 1
@export var morale_reward: float = 1.0

var _active: Array = [] # Node3D (DustBunny) instances currently alive
var _timer: float = 0.0
@onready var building_manager: Node = get_node("/root/BuildingManager")
@onready var grid_service: Node = get_node("/root/GridService")
@onready var data_registry: Node = get_node("/root/DataRegistry")
@onready var inventory: Node = get_node("/root/Inventory")
@onready var stats_service: Node = get_node("/root/StatsService")

func _ready() -> void:
	randomize()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_maybe_spawn()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var click_pos = _mouse_ground_pos()
	if click_pos == null:
		return

	var nearest: Node3D = null
	var nearest_dist := INF
	for bunny in _active:
		if not is_instance_valid(bunny):
			continue
		var d: float = Vector2(bunny.global_position.x, bunny.global_position.z).distance_to(Vector2(click_pos.x, click_pos.z))
		if d < nearest_dist:
			nearest_dist = d
			nearest = bunny

	if nearest != null and nearest_dist <= swat_radius:
		_swat(nearest)
		get_viewport().set_input_as_handled()

func _mouse_ground_pos():
	var cam := get_tree().root.find_child("Camera3D", true, false)
	if cam == null:
		return null
	var mouse_pos := get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var dir: Vector3 = cam.project_ray_normal(mouse_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t

func _maybe_spawn() -> void:
	if _active.size() >= max_active:
		return
	if randf() > spawn_chance:
		return

	var world_sites: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group("construction_sites"):
		if node is Node3D:
			world_sites.append((node as Node3D).global_position)
	if world_sites.is_empty():
		for anchor: Vector2i in building_manager.call("get_unbuilt_anchors"):
			world_sites.append(grid_service.call("grid_to_world", anchor))
	if world_sites.is_empty():
		return
	var position := world_sites[randi() % world_sites.size()] + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))

	var bunny := Node3D.new()
	bunny.set_script(DUST_BUNNY_SCRIPT)
	bunny.position = position
	add_child(bunny)
	bunny.expired.connect(_on_bunny_gone)
	_active.append(bunny)

func _swat(bunny: Node3D) -> void:
	if not bunny.swat():
		return
	_active.erase(bunny)

	var item: InventoryItem = data_registry.call("make_inventory_item", "lint")
	if item:
		inventory.call("add_item", item, lint_reward)
	stats_service.call("add_modifiers", [
		{"target": "global_town", "stat": "morale", "modifier_type": "additive", "value": morale_reward},
	])
	print("[DustBunnySpawner] Swatted! +%d lint, +%.1f morale (total %.1f)" % [
		lint_reward, morale_reward, float(stats_service.call("get_effective", "global_town", "morale", 0.0))
	])

func _on_bunny_gone(bunny: Node3D) -> void:
	_active.erase(bunny)
