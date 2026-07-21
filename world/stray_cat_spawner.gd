extends Node3D
## Stray Cat Visitors (Step 6, mechanic 9): a random event controller that
## periodically rolls to spawn a wandering stray cat at a map edge tile.
## Attraction odds are entirely data-driven -- each recruited animal type
## contributes whatever weight its animal_types.json entry lists under
## `attracts.stray_cat` (currently just Mouse, at 0.15; a future Cow with a
## higher weight per the GDD needs zero changes here). Left-clicking near the
## cat "greets" it and resolves a weighted random outcome: a rare trade, a
## free gift, or the cat deciding to stick around (a permanent town morale
## bump, standing in for "town membership" since there's no general resident
## roster beyond recruited job-holding animals yet).

const STRAY_CAT_SCRIPT := preload("res://world/stray_cat.gd")

@export var min_visit_interval: float = 40.0
@export var max_visit_interval: float = 90.0
@export var base_chance: float = 0.15
@export var greet_radius: float = 0.8

var _timer: float = 0.0
var _next_check: float = 0.0
var _current: Node3D = null
@onready var data_registry: Node = get_node("/root/DataRegistry")
@onready var animal_manager: Node = get_node("/root/AnimalManager")
@onready var grid_service: Node = get_node("/root/GridService")
@onready var event_bus: Node = get_node("/root/EventBus")
@onready var inventory: Node = get_node("/root/Inventory")
@onready var stats_service: Node = get_node("/root/StatsService")
@onready var game_state: Phase1GameState = get_node("/root/GameState") as Phase1GameState

func _ready() -> void:
	randomize()
	_next_check = randf_range(min_visit_interval, max_visit_interval)

func _process(delta: float) -> void:
	if _current != null:
		return
	_timer += delta
	if _timer >= _next_check:
		_timer = 0.0
		_next_check = randf_range(min_visit_interval, max_visit_interval)
		_maybe_spawn()

func _unhandled_input(event: InputEvent) -> void:
	if _current == null:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var click_pos = _mouse_ground_pos()
	if click_pos == null:
		return
	var d: float = Vector2(_current.global_position.x, _current.global_position.z).distance_to(Vector2(click_pos.x, click_pos.z))
	if d <= greet_radius:
		_greet(_current)
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

## Sum of `attracts.stray_cat` weight across every recruited animal, plus a
## flat base_chance -- the same generic "sum a data-driven field across the
## roster" shape the plan calls for, ready to pick up any future species
## without code changes.
func attraction_chance() -> float:
	var chance := base_chance
	for animal_type: Dictionary in data_registry.call("get_all_animal_types"):
		var species_id: String = animal_type.get("id", "")
		var weight: float = animal_type.get("attracts", {}).get("stray_cat", 0.0)
		if weight <= 0.0:
			continue
		var count := int(animal_manager.call("recruited_count", species_id))
		if species_id == "mouse":
			count += game_state.get_recruited_mouse_count()
		chance += count * weight
	return clampf(chance, 0.0, 1.0)

func _maybe_spawn() -> void:
	if randf() > attraction_chance():
		return
	var grid_pos := _pick_edge_tile()
	if grid_pos == Vector2i(-1, -1):
		return

	var cat := Node3D.new()
	cat.set_script(STRAY_CAT_SCRIPT)
	cat.position = grid_service.call("grid_to_world", grid_pos)
	add_child(cat)
	cat.departed.connect(_on_departed)
	_current = cat
	event_bus.stray_cat_appeared.emit(grid_pos)
	print("[StrayCatSpawner] A stray cat appeared at %s! Click it to greet." % [grid_pos])

## Picks a random empty, in-bounds tile along one of the four map edges.
## Returns Vector2i(-1, -1) if a handful of attempts all land on occupied
## tiles (small edge case, not worth a full free-tile scan).
func _pick_edge_tile() -> Vector2i:
	for attempt in 6:
		var side := randi() % 4
		var pos: Vector2i
		match side:
			0: pos = Vector2i(randi() % int(grid_service.get("grid_width")), 0)
			1: pos = Vector2i(randi() % int(grid_service.get("grid_width")), int(grid_service.get("grid_height")) - 1)
			2: pos = Vector2i(0, randi() % int(grid_service.get("grid_height")))
			_: pos = Vector2i(int(grid_service.get("grid_width")) - 1, randi() % int(grid_service.get("grid_height")))
		if int(grid_service.call("get_tile_state", pos)) == 0 and not bool(grid_service.call("is_resource_occupied", pos)):
			return pos
	return Vector2i(-1, -1)

func _on_departed(_cat: Node3D) -> void:
	var pos: Vector2i = grid_service.call("world_to_grid", _current.global_position) if is_instance_valid(_current) else Vector2i.ZERO
	_current = null
	event_bus.stray_cat_departed.emit(pos)
	print("[StrayCatSpawner] The stray cat wandered off, unresolved.")

func _greet(cat: Node3D) -> void:
	if not cat.greet():
		return
	var grid_pos: Vector2i = grid_service.call("world_to_grid", cat.global_position)
	_current = null

	var outcome := _resolve_visit()
	event_bus.stray_cat_visit_resolved.emit(outcome)
	event_bus.stray_cat_departed.emit(grid_pos)

## Weighted random outcome table: 40% rare trade (if the player can afford
## it), 35% free gift, 25% the cat sticks around and joins the town.
func _resolve_visit() -> String:
	var roll := randf()
	if roll < 0.40:
		if bool(inventory.call("remove_item", "catnip", 2)):
			var moonstone: InventoryItem = data_registry.call("make_inventory_item", "moonstone")
			if moonstone:
				inventory.call("add_item", moonstone, 1)
			print("[StrayCatSpawner] The stray cat traded 1 moonstone for 2 catnip!")
			return "trade_moonstone"
		print("[StrayCatSpawner] The stray cat wanted to trade for catnip, but you had none. It leaves empty-pawed.")
		return "trade_declined"
	elif roll < 0.75:
		var gift_item_id := "wood" if randf() < 0.5 else "twigs"
		var amount := randi_range(2, 4)
		var item: InventoryItem = data_registry.call("make_inventory_item", gift_item_id)
		if item:
			inventory.call("add_item", item, amount)
		print("[StrayCatSpawner] The stray cat left a gift: %d x %s!" % [amount, gift_item_id])
		return "gift"
	else:
		stats_service.call("add_modifiers", [
			{"target": "global_town", "stat": "morale", "modifier_type": "additive", "value": 2.0},
		])
		print("[StrayCatSpawner] The stray cat decided to stick around -- town morale permanently +2 (now %.1f)." % float(stats_service.call("get_effective", "global_town", "morale", 0.0)))
		return "joins_town"
