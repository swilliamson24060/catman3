extends Node
## Autoload "AnimalManager". Species-agnostic recruitment + job framework:
## one roster of animal instances regardless of species (mice today, cows
## later), all driven by data/animal_types.json. Nothing here hardcodes
## "mouse" in any behavioral sense -- a new species needs only a new
## animal_types.json entry, a housing building, and its own resource-node
## item types; the recruit/path/work/return loop below is unchanged. See
## docs/implementation_plan.md Section 3.
##
## Housing: a species' housing_building_type just needs to have been placed
## as a blueprint (BUILDING_PLACED_AS_BLUEPRINT) -- counts as available
## housing even before it's actually built, since a hut still shelters mice
## while they're the ones building it.
##
## Recruitment trigger: RECRUIT_HOTKEYS stands in for the "Recruitment
## Board" UI the plan describes. recruit() itself has no idea how it was
## triggered, so swapping in real UI later only touches this one hotkey
## handler.
##
## Delegation ("Laser Pointer Prioritization"): right-click a revealed tile
## to send the nearest idle animal there. Three things can be there:
##   - a resource node matching one of the animal's species' job_roles ->
##     gather it, deposit into Inventory, walk home.
##   - an unbuilt blueprint (any building, not species-specific) -> spend
##     its build_cost from Inventory and construct it (BuildingManager),
##     walk home.
##   - anything else -> just walk there and go idle.

const MOUSE_SCRIPT := preload("res://animals/mouse.gd")

const RECRUIT_HOTKEYS := {
	KEY_3: "mouse",
}

## Mouse Guilds & Tiny Tools (Step 6, mechanic 7): stands in for a proper
## crafting UI. craft_tool() itself just reads an item's properties.craft_cost
## generically, so any future tool item works via these same two hotkeys'
## pattern without new code -- only the item id changes.
const CRAFT_HOTKEYS := {
	KEY_4: "thimble_helmet",
	KEY_5: "button_shield",
}

enum AnimalState { IDLE, QUEUED_FOR_PATH, MOVING_TO_JOB, WORKING, RETURNING }

const GHOST_REFRESH_INTERVAL := 1.0
const UPKEEP_RETRY_INTERVAL := 10.0
const STRIKE_MORALE_PENALTY := -3.0
const PEST_MORALE_PENALTY := -1.0

## Step 9 polish: caps how many new AStarGrid2D pathfind + dispatch
## resolutions happen in a single frame. A single priority-target click
## only ever queues one animal, so this is invisible in normal play; it
## exists so a future "dispatch everyone" feature, or a save file
## restoring dozens of animals that all re-path at once, can't spike one
## frame's cost.
const MAX_PATH_REQUESTS_PER_FRAME := 3

const TOOL_SLOTS := 2
const XP_PER_JOB := 10.0
const XP_PER_LEVEL := 50.0
const MAX_LEVEL_SPEED_BONUS := 0.5 # level bonus caps at +50% work speed

const CATNIP_SPEED_BONUS_SCALE := 0.3  # moderate downwind scent: up to +30% work speed
const CATNIP_DOZE_THRESHOLD := 0.85    # scent intensity right at the garden -- too strong
const CATNIP_DOZE_MULTIPLIER := 0.5    # drowsy: work takes 2x as long

var _roster: Dictionary = {}            # animal_id -> {species_id, node, home, state, job_role, work_time_left}
var _housing_positions: Dictionary = {} # species_id -> Array[Vector2i]
var _next_animal_num: int = 0
var _pending_dispatches: Array = []     # [{animal_id: String, grid_pos: Vector2i}], throttled in _process
var _container: Node3D
var _ghost_container: Node3D
var _ghost_refresh_timer: float = 0.0

func _ready() -> void:
	_container = Node3D.new()
	_container.name = "Animals"
	add_child(_container)
	_ghost_container = Node3D.new()
	_ghost_container.name = "DreamGhosts"
	add_child(_ghost_container)
	EventBus.building_placed_as_blueprint.connect(_on_building_placed)
	EventBus.priority_target_set.connect(_on_priority_target_set)
	EventBus.dream_mode_changed.connect(_on_dream_mode_changed)
	EventBus.item_spoiled.connect(_on_item_spoiled)

func _process(delta: float) -> void:
	var dispatched_this_frame := 0
	while dispatched_this_frame < MAX_PATH_REQUESTS_PER_FRAME and not _pending_dispatches.is_empty():
		var request: Dictionary = _pending_dispatches.pop_front()
		_dispatch_to_target(request.animal_id, request.grid_pos)
		dispatched_this_frame += 1

	for animal_id in _roster.keys():
		var entry: Dictionary = _roster[animal_id]
		if entry.state == AnimalState.WORKING:
			entry.work_time_left -= delta
			if entry.work_time_left <= 0.0:
				_finish_work(animal_id, entry)

		entry.upkeep_timer -= delta
		if entry.upkeep_timer <= 0.0:
			_pay_upkeep(animal_id, entry)

	if DreamModeService.active:
		_ghost_refresh_timer -= delta
		if _ghost_refresh_timer <= 0.0:
			_ghost_refresh_timer = GHOST_REFRESH_INTERVAL
			_refresh_ghosts()

# --- Cat-Nap Fast-Forward ghost-path gizmos ----------------------------------

func _on_dream_mode_changed(active: bool) -> void:
	_clear_ghosts()
	if active:
		_ghost_refresh_timer = 0.0

func _clear_ghosts() -> void:
	for child in _ghost_container.get_children():
		child.queue_free()

## Every currently-moving animal's path is already fully computed A*, so
## "predicting the future" is just drawing translucent markers along the
## rest of it -- no separate simulation needed.
func _refresh_ghosts() -> void:
	_clear_ghosts()
	for entry in _roster.values():
		if entry.state != AnimalState.MOVING_TO_JOB and entry.state != AnimalState.RETURNING:
			continue
		for cell in entry.node.get_remaining_path():
			_spawn_ghost(cell)

func _spawn_ghost(cell: Vector2i) -> void:
	var ghost := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	ghost.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.7, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.set_surface_override_material(0, mat)
	ghost.position = GridService.grid_to_world(cell) + Vector3(0, 0.3, 0)
	_ghost_container.add_child(ghost)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if RECRUIT_HOTKEYS.has(event.keycode):
			recruit(RECRUIT_HOTKEYS[event.keycode])
		if CRAFT_HOTKEYS.has(event.keycode):
			craft_tool(CRAFT_HOTKEYS[event.keycode])

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var grid_pos = _mouse_grid_pos()
		if grid_pos != null and GridService.in_bounds(grid_pos) and GridService.is_revealed(grid_pos):
			EventBus.priority_target_set.emit(grid_pos)

func _mouse_grid_pos():
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
	return GridService.world_to_grid(from + dir * t)

# --- Housing tracking --------------------------------------------------------

func _on_building_placed(building_id: String, grid_pos: Vector2i) -> void:
	for animal in DataRegistry.get_animal_types_with_housing_available([building_id]):
		var species_id: String = animal.get("id")
		if not _housing_positions.has(species_id):
			_housing_positions[species_id] = []
		_housing_positions[species_id].append(grid_pos)

func housing_capacity(species_id: String) -> int:
	var animal := DataRegistry.get_animal_type(species_id)
	if animal.is_empty():
		return 0
	var building := DataRegistry.get_building(animal.get("housing_building_type", ""))
	var per_building: int = building.get("housing_capacity", 0)
	var placed: int = _housing_positions.get(species_id, []).size()
	return per_building * placed

func recruited_count(species_id: String) -> int:
	var count := 0
	for entry in _roster.values():
		if entry.species_id == species_id:
			count += 1
	return count

func striking_count() -> int:
	var count := 0
	for entry in _roster.values():
		if entry.on_strike:
			count += 1
	return count

# --- Recruitment --------------------------------------------------------------

## Attempts to recruit one animal of `species_id`. Returns true on success;
## prints (and returns false) if there's no housing left or the upkeep item
## animal_types.json lists as its cost can't be afforded.
func recruit(species_id: String) -> bool:
	var animal_type := DataRegistry.get_animal_type(species_id)
	if animal_type.is_empty():
		push_warning("[AnimalManager] Unknown species '%s'" % species_id)
		return false

	if not _housing_positions.has(species_id) or _housing_positions[species_id].is_empty():
		print("[AnimalManager] No housing placed for '%s' yet." % species_id)
		return false

	if recruited_count(species_id) >= housing_capacity(species_id):
		print("[AnimalManager] Housing full for '%s' (%d/%d)." % [species_id, recruited_count(species_id), housing_capacity(species_id)])
		return false

	var upkeep: Dictionary = animal_type.get("upkeep", {})
	var cost_item: String = upkeep.get("item", "")
	var cost_amount: int = upkeep.get("amount", 0)
	if cost_item != "" and cost_amount > 0 and not Inventory.remove_item(cost_item, cost_amount):
		print("[AnimalManager] Not enough '%s' to recruit a %s (need %d, have %d)." % [
			cost_item, species_id, cost_amount, Inventory.get_item_count(cost_item)
		])
		return false

	var home: Vector2i = _housing_positions[species_id][0]
	var animal_id := "%s_%d" % [species_id, _next_animal_num]
	_next_animal_num += 1

	var mouse := Node3D.new()
	mouse.set_script(MOUSE_SCRIPT)
	mouse.species_id = species_id
	mouse.grid_pos = home
	# Guaranteed-unique body/eye/decoration combo (see AppearanceService) --
	# set before add_child() since mouse.gd's _ready() reads it immediately
	# to build the visual.
	mouse.appearance = AppearanceService.assign_appearance(animal_id)
	# Resonance/founder bonuses targeting a species' stat_group (e.g. "The
	# Herbal Triad" gives global_mice +0.15 movement_speed) apply here at
	# recruit time, same modifier pipeline as everything else. stat_group
	# is plain data (defaults to species_id if a species doesn't define
	# one) so irregular plurals like mouse -> mice never need special-casing
	# in code.
	var stat_group: String = animal_type.get("stat_group", species_id)
	var base_speed: float = animal_type.get("movement_speed", 3.5)
	mouse.movement_speed = StatsService.get_effective(stat_group, "movement_speed", base_speed)
	_container.add_child(mouse)
	mouse.path_finished.connect(_on_animal_path_finished.bind(animal_id))

	_roster[animal_id] = {
		"species_id": species_id,
		"node": mouse,
		"home": home,
		"state": AnimalState.IDLE,
		"job_role": {},
		"build_info": {},
		"work_time_left": 0.0,
		"upkeep_timer": upkeep.get("interval", 60.0),
		"on_strike": false,
		"xp": 0.0,
		"inventory": [],
	}

	EventBus.animal_recruited.emit(animal_id, species_id)
	print("[AnimalManager] Recruited %s (%s). Roster: %d/%d" % [
		animal_id, species_id, recruited_count(species_id), housing_capacity(species_id)
	])
	return true

## Step 9: save/load robustness. Just the facts worth persisting -- species,
## home tile, XP, and equipped tool ids. In-flight state (job_role,
## build_info, a half-walked path) is deliberately dropped; restore_roster()
## brings every animal back IDLE at home instead of trying to resume
## whatever it was mid-doing, which is a fine simplification for a
## polish-pass save format.
func serialize_roster() -> Array:
	var out: Array = []
	for animal_id in _roster:
		var entry: Dictionary = _roster[animal_id]
		var tool_ids: Array = []
		for tool in entry.get("inventory", []):
			tool_ids.append(tool.get("id", ""))
		out.append({
			"animal_id": animal_id,
			"species_id": entry.species_id,
			"home_x": entry.home.x,
			"home_y": entry.home.y,
			"xp": entry.get("xp", 0.0),
			"tool_ids": tool_ids,
			"coat_index": AppearanceService.claimed_index(animal_id),
		})
	return out

## Rebuilds the roster from a save file, then replays animal_recruited for
## each one -- the same signal recruit() fires -- so AchievementService's
## recruitment counters resync with zero code here needing to know about
## achievements at all. Unknown/removed species ids are skipped rather than
## crashing the load.
func restore_roster(data: Array) -> void:
	for animal_id in _roster:
		AppearanceService.release_appearance(animal_id)
		var entry: Dictionary = _roster[animal_id]
		if is_instance_valid(entry.node):
			entry.node.queue_free()
	_roster.clear()
	_next_animal_num = 0

	for raw in data:
		if not (raw is Dictionary):
			continue
		var species_id: String = raw.get("species_id", "")
		var animal_type := DataRegistry.get_animal_type(species_id)
		if animal_type.is_empty():
			continue

		var home := Vector2i(int(raw.get("home_x", 0)), int(raw.get("home_y", 0)))
		var animal_id: String = raw.get("animal_id", "")
		if animal_id == "":
			animal_id = "%s_%d" % [species_id, _next_animal_num]
		_next_animal_num += 1

		var mouse := Node3D.new()
		mouse.set_script(MOUSE_SCRIPT)
		mouse.species_id = species_id
		mouse.grid_pos = home
		var coat_index: int = int(raw.get("coat_index", -1))
		if coat_index >= 0:
			mouse.appearance = AppearanceService.claim_specific(animal_id, coat_index)
		else:
			mouse.appearance = AppearanceService.assign_appearance(animal_id)
		var stat_group: String = animal_type.get("stat_group", species_id)
		var base_speed: float = animal_type.get("movement_speed", 3.5)
		mouse.movement_speed = StatsService.get_effective(stat_group, "movement_speed", base_speed)
		_container.add_child(mouse)
		mouse.path_finished.connect(_on_animal_path_finished.bind(animal_id))

		var inventory: Array = []
		for tool_id in raw.get("tool_ids", []):
			var tool := DataRegistry.get_item(str(tool_id))
			if not tool.is_empty():
				inventory.append(tool)

		_roster[animal_id] = {
			"species_id": species_id,
			"node": mouse,
			"home": home,
			"state": AnimalState.IDLE,
			"job_role": {},
			"build_info": {},
			"work_time_left": 0.0,
			"upkeep_timer": animal_type.get("upkeep", {}).get("interval", 60.0),
			"on_strike": false,
			"xp": float(raw.get("xp", 0.0)),
			"inventory": inventory,
		}
		EventBus.animal_recruited.emit(animal_id, species_id)

# --- Delegation / job loop -----------------------------------------------------

func _on_priority_target_set(grid_pos: Vector2i) -> void:
	var animal_id := _find_idle_animal()
	if animal_id == "":
		return
	# Claim the animal immediately (so a second click before this one's
	# path resolves doesn't also grab it via _find_idle_animal), but defer
	# the actual AStarGrid2D query + dispatch to _process's throttled queue.
	_roster[animal_id].state = AnimalState.QUEUED_FOR_PATH
	_pending_dispatches.append({"animal_id": animal_id, "grid_pos": grid_pos})

## The actual pathfind + job/build dispatch, throttled to
## MAX_PATH_REQUESTS_PER_FRAME by _process. See the class-level comment on
## that const for why this is worth separating from _on_priority_target_set.
func _dispatch_to_target(animal_id: String, grid_pos: Vector2i) -> void:
	if not _roster.has(animal_id):
		return
	var entry: Dictionary = _roster[animal_id]
	_try_auto_equip(animal_id, entry)

	var path := GridService.find_path(entry.node.grid_pos, grid_pos)
	if path.is_empty():
		entry.state = AnimalState.IDLE
		return

	var job_role := _job_role_for_target(entry.species_id, grid_pos)
	var build_info: Dictionary = {} if not job_role.is_empty() else _build_info_for_target(grid_pos)

	entry.job_role = job_role
	entry.build_info = build_info
	entry.state = AnimalState.MOVING_TO_JOB
	entry.node.walk_path(path)

	if not job_role.is_empty():
		EventBus.animal_assigned_job.emit(animal_id, job_role.get("id", ""))
	print("[AnimalManager] %s heading to %s%s" % [
		animal_id, grid_pos,
		" to work" if not job_role.is_empty() else (" to build" if not build_info.is_empty() else "")
	])

func _find_idle_animal() -> String:
	for animal_id in _roster:
		var entry: Dictionary = _roster[animal_id]
		if entry.state == AnimalState.IDLE and not entry.on_strike:
			return animal_id
	return ""

# --- Cheese-Standard Salary ---------------------------------------------------

## Recurring upkeep payment (animal_types.json's upkeep.item/amount, every
## upkeep.interval seconds). Success resets the timer and clears a strike
## if one was active; failure puts the animal on strike -- excluded from
## _find_idle_animal() until upkeep is next successfully paid -- with a
## removable morale penalty via StatsService's temp-modifier pipeline, and
## retries sooner than a full interval so it doesn't stay stuck for long
## once the player restocks. Species without an upkeep cost just reset
## quietly forever.
func _pay_upkeep(animal_id: String, entry: Dictionary) -> void:
	var animal_type := DataRegistry.get_animal_type(entry.species_id)
	var upkeep: Dictionary = animal_type.get("upkeep", {})
	var cost_item: String = upkeep.get("item", "")
	var cost_amount: int = upkeep.get("amount", 0)
	var interval: float = upkeep.get("interval", 60.0)

	if cost_item == "" or cost_amount <= 0:
		entry.upkeep_timer = interval
		return

	if Inventory.remove_item(cost_item, cost_amount):
		entry.upkeep_timer = interval
		if entry.on_strike:
			entry.on_strike = false
			StatsService.remove_temp_modifier("strike_%s" % animal_id, "global_town", "morale")
			EventBus.animal_on_strike.emit(animal_id, false)
			print("[AnimalManager] %s paid up -- back to work." % animal_id)
	else:
		entry.upkeep_timer = UPKEEP_RETRY_INTERVAL
		if not entry.on_strike:
			entry.on_strike = true
			StatsService.add_temp_modifier("strike_%s" % animal_id, "global_town", "morale", "additive", STRIKE_MORALE_PENALTY)
			EventBus.animal_on_strike.emit(animal_id, true)
			print("[AnimalManager] %s went on strike -- no %s to pay upkeep." % [animal_id, cost_item])

# --- Mouse Guilds & Tiny Tools --------------------------------------------------

## Crafts one `item_id` (must have properties.craft_cost in items.json) from
## Inventory materials into Inventory. Generic over any tool -- adding a
## third tool later needs only a new items.json entry and hotkey, no new
## crafting logic.
func craft_tool(item_id: String) -> bool:
	var data := DataRegistry.get_item(item_id)
	if data.is_empty():
		push_warning("[AnimalManager] Unknown item '%s'" % item_id)
		return false

	var cost: Dictionary = data.get("properties", {}).get("craft_cost", {})
	for cost_item in cost:
		if Inventory.get_item_count(cost_item) < int(cost[cost_item]):
			print("[AnimalManager] Can't craft %s -- missing %s." % [item_id, cost_item])
			return false

	for cost_item in cost:
		Inventory.remove_item(cost_item, int(cost[cost_item]))

	var item := DataRegistry.make_inventory_item(item_id)
	if item:
		Inventory.add_item(item, 1)
	print("[AnimalManager] Crafted %s." % item_id)
	return true

## Grabs whatever crafted tools are sitting in Inventory and equips them
## into the animal's own small generic inventory array (max TOOL_SLOTS,
## no duplicates) the moment it's dispatched to a job -- standing in for a
## player-driven "equip" UI. The array itself is exactly the generic,
## species-agnostic slot list the plan calls for.
func _try_auto_equip(animal_id: String, entry: Dictionary) -> void:
	var inv: Array = entry.inventory
	if inv.size() >= TOOL_SLOTS:
		return
	for tool_id in CRAFT_HOTKEYS.values():
		if inv.size() >= TOOL_SLOTS:
			break
		if Inventory.get_item_count(tool_id) <= 0:
			continue
		var already := false
		for t in inv:
			if t.get("id") == tool_id:
				already = true
				break
		if already:
			continue
		if Inventory.remove_item(tool_id, 1):
			inv.append(DataRegistry.get_item(tool_id))
			print("[AnimalManager] %s equipped %s" % [animal_id, tool_id])

func level_of(entry: Dictionary) -> int:
	return 1 + int(floor(entry.get("xp", 0.0) / XP_PER_LEVEL))

## Per-individual work-speed multiplier from level + equipped speed_boost
## tools -- deliberately separate from StatsService, since that pipeline is
## keyed by species/global targets, not one specific animal instance.
func _individual_speed_multiplier(entry: Dictionary) -> float:
	var level_bonus := minf(MAX_LEVEL_SPEED_BONUS, 0.05 * (level_of(entry) - 1))
	return (1.0 + level_bonus) * (1.0 + _tool_bonus(entry, "speed_boost")) * _catnip_scent_multiplier(entry)

## Catnip Drift Dynamics (Step 6, mechanic 5): a light downwind dose of
## Catnip Garden aroma perks an animal up (+30% at most); standing right on
## top of the source is overpowering and makes them drowsy instead. Read at
## the moment a job starts (same as the tool/level bonuses above) rather
## than continuously, since work_time_left is a fixed countdown once set.
func _catnip_scent_multiplier(entry: Dictionary) -> float:
	if entry.node == null:
		return 1.0
	var scent := CatnipDriftService.get_scent_at(entry.node.grid_pos)
	if scent >= CATNIP_DOZE_THRESHOLD:
		return CATNIP_DOZE_MULTIPLIER
	return 1.0 + scent * CATNIP_SPEED_BONUS_SCALE

func _tool_bonus(entry: Dictionary, effect_id: String) -> float:
	var total := 0.0
	for tool in entry.get("inventory", []):
		var props: Dictionary = tool.get("properties", {})
		if props.get("tool_effect", "") == effect_id:
			total += props.get("value", 0.0)
	return total

func _grant_xp(animal_id: String, entry: Dictionary) -> void:
	var before := level_of(entry)
	entry.xp = entry.get("xp", 0.0) + XP_PER_JOB
	var after := level_of(entry)
	if after > before:
		print("[AnimalManager] %s leveled up to %d!" % [animal_id, after])

func _on_item_spoiled(item_id: String, amount: int) -> void:
	# Pests raid spoiled stock -- a lighter stand-in for a dedicated pest
	# spawner, applied as a one-shot permanent morale ding (not a temp
	# modifier, since there's no single ongoing "cause" to later resolve
	# the way a strike has).
	StatsService.add_modifiers([
		{"target": "global_town", "stat": "morale", "modifier_type": "additive", "value": PEST_MORALE_PENALTY},
	])
	print("[AnimalManager] %d x %s spoiled -- pests knock morale down." % [amount, item_id])

func _job_role_for_target(species_id: String, grid_pos: Vector2i) -> Dictionary:
	var node := GridService.get_resource_node(grid_pos)
	if node == null:
		return {}
	var animal_type := DataRegistry.get_animal_type(species_id)
	for job in animal_type.get("job_roles", []):
		if job.get("output", "") == node.item_id:
			return job
	return {}

## Construction isn't species/job_role-gated -- any recruited animal can
## build any placed-but-unbuilt blueprint. Returns {anchor, building_id} or
## {} if there's nothing to build at grid_pos (already built, or empty).
func _build_info_for_target(grid_pos: Vector2i) -> Dictionary:
	var info: Dictionary = BuildingManager.get_building_at(grid_pos)
	if info.is_empty() or info.get("built", true):
		return {}
	return info

func _on_animal_path_finished(_mouse: Node3D, animal_id: String) -> void:
	if not _roster.has(animal_id):
		return
	var entry: Dictionary = _roster[animal_id]

	match entry.state:
		AnimalState.MOVING_TO_JOB:
			if not entry.job_role.is_empty():
				entry.state = AnimalState.WORKING
				var base_duration: float = entry.job_role.get("duration", 2.0)
				entry.work_time_left = base_duration / max(_individual_speed_multiplier(entry), 0.01)
			elif not entry.build_info.is_empty():
				_start_construction(animal_id, entry)
			else:
				_head_home(animal_id, entry)
		AnimalState.RETURNING:
			entry.state = AnimalState.IDLE
			entry.job_role = {}
			entry.build_info = {}
		_:
			pass

## Spends the building's build_cost from Inventory and starts the work
## timer, scaled by the founder-cat/resonance construction-speed stat --
## same modifier pipeline used everywhere else (StatsService.get_effective).
## If materials are short, the mouse just heads home instead of blocking.
func _start_construction(animal_id: String, entry: Dictionary) -> void:
	var building := DataRegistry.get_building(entry.build_info.building_id)
	var cost: Dictionary = building.get("build_cost", {})

	for item_id in cost:
		if Inventory.get_item_count(item_id) < int(cost[item_id]):
			print("[AnimalManager] %s can't start building %s -- missing %s." % [animal_id, entry.build_info.building_id, item_id])
			entry.build_info = {}
			_head_home(animal_id, entry)
			return

	for item_id in cost:
		Inventory.remove_item(item_id, int(cost[item_id]))

	var base_time: float = building.get("build_time", 6.0)
	var speed := StatsService.get_effective("global_construction", "speed", 1.0) * _individual_speed_multiplier(entry)
	entry.state = AnimalState.WORKING
	entry.work_time_left = base_time / max(speed, 0.01)
	print("[AnimalManager] %s started building %s (%.1fs)" % [animal_id, entry.build_info.building_id, entry.work_time_left])

func _finish_work(animal_id: String, entry: Dictionary) -> void:
	if not entry.build_info.is_empty():
		BuildingManager.complete_construction(entry.build_info.anchor)
		entry.build_info = {}
		_grant_xp(animal_id, entry)
	else:
		var mouse = entry.node
		var node := GridService.get_resource_node(mouse.grid_pos)
		if node:
			var result: Dictionary = node.harvest()
			if not result.is_empty():
				var bonus := int(round(_tool_bonus(entry, "yield_boost")))
				var total_amount: int = result.amount + bonus
				var item := DataRegistry.make_inventory_item(result.item_id)
				if item:
					Inventory.add_item(item, total_amount)
				print("[AnimalManager] %s gathered %d x %s (+%d tool bonus)" % [animal_id, total_amount, result.item_id, bonus])
				_grant_xp(animal_id, entry)
	_head_home(animal_id, entry)

func _head_home(_animal_id: String, entry: Dictionary) -> void:
	var mouse = entry.node
	entry.state = AnimalState.RETURNING
	var path := GridService.find_path(mouse.grid_pos, entry.home)
	if path.is_empty():
		entry.state = AnimalState.IDLE
		entry.job_role = {}
		entry.build_info = {}
	else:
		mouse.walk_path(path)
