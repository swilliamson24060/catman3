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

	var sites := BuildingManager.get_unbuilt_anchors()
	if sites.is_empty():
		return

	var anchor: Vector2i = sites[randi() % sites.size()]
	var offset := Vector2i(randi_range(-1, 1), randi_range(-1, 1))
	var grid_pos := anchor + offset

	var bunny := Node3D.new()
	bunny.set_script(DUST_BUNNY_SCRIPT)
	bunny.position = GridService.grid_to_world(grid_pos)
	add_child(bunny)
	bunny.expired.connect(_on_bunny_gone)
	_active.append(bunny)

func _swat(bunny: Node3D) -> void:
	if not bunny.swat():
		return
	_active.erase(bunny)

	var item := DataRegistry.make_inventory_item("lint")
	if item:
		Inventory.add_item(item, lint_reward)
	StatsService.add_modifiers([
		{"target": "global_town", "stat": "morale", "modifier_type": "additive", "value": morale_reward},
	])
	print("[DustBunnySpawner] Swatted! +%d lint, +%.1f morale (total %.1f)" % [
		lint_reward, morale_reward, StatsService.get_effective("global_town", "morale", 0.0)
	])

func _on_bunny_gone(bunny: Node3D) -> void:
	_active.erase(bunny)
