extends Node
## Autoload "BuildingManager". Owns the registry of placed buildings
## (blueprint or built) and drives two things off it:
##   - lookups AnimalManager needs to know "is there an unbuilt blueprint at
##     this tile, and what building is it" for the construction job type.
##   - the production timer for any BUILT building with a `produces` field
##     in buildings.json, depositing output into TownStorage.
##
## Populated purely from EventBus signals (building_placed_as_blueprint,
## building_constructed) that already exist -- this never needs a direct
## reference from BlueprintPlacer or AnimalManager.

const MAX_DURABILITY := 100.0
const RAIN_DAMAGE_PER_SEC := 4.0
const CLEAR_REGEN_PER_SEC := 2.0

var _placed: Dictionary = {} # anchor Vector2i -> {building_id, footprint: Vector2i, built: bool, produce_timer: float, durability: float}

func _ready() -> void:
	EventBus.building_placed_as_blueprint.connect(_on_placed)

func _process(delta: float) -> void:
	var collapsed: Array = []

	for anchor in _placed:
		var entry: Dictionary = _placed[anchor]
		if not entry.built:
			continue
		var building := DataRegistry.get_building(entry.building_id)

		_tick_weather_durability(anchor, entry, building, delta)
		if entry.durability <= 0.0:
			collapsed.append(anchor)
			continue

		var produces: Dictionary = building.get("produces", {})
		if produces.is_empty():
			continue
		var base_duration: float = produces.get("duration", 10.0)
		# Resonance Patterns (and anything else) can bump a specific
		# building's production_rate via the standard {target, stat} bonus
		# shape -- e.g. "The Herbal Triad" gives building_catnip_garden a
		# 1.5x multiplier here, read live so it applies retroactively to
		# already-built buildings the moment the pattern is discovered.
		var rate := StatsService.get_effective(entry.building_id, "production_rate", 1.0)
		var duration: float = base_duration / max(rate, 0.01)
		entry.produce_timer += delta
		if entry.produce_timer >= duration:
			entry.produce_timer -= duration
			var item := DataRegistry.make_inventory_item(produces.get("output", ""))
			if item:
				TownStorage.add_item(item, 1)
				print("[BuildingManager] %s produced 1 x %s" % [entry.building_id, item.id])

	for anchor in collapsed:
		_collapse(anchor)

## Cardboard Tier & Rain Events (Step 6, mechanic 3): non-waterproof
## buildings lose durability while it's raining, and slowly repair
## themselves during clear weather. Reads `waterproof` straight off
## buildings.json -- no building type is special-cased here.
func _tick_weather_durability(anchor: Vector2i, entry: Dictionary, building: Dictionary, delta: float) -> void:
	var waterproof: bool = building.get("waterproof", false)
	var before: float = entry.durability

	if WeatherService.is_raining() and not waterproof:
		entry.durability = maxf(0.0, entry.durability - RAIN_DAMAGE_PER_SEC * delta)
	elif entry.durability < MAX_DURABILITY:
		entry.durability = minf(MAX_DURABILITY, entry.durability + CLEAR_REGEN_PER_SEC * delta)

	if entry.durability != before:
		EventBus.building_damaged.emit(entry.building_id, anchor, entry.durability)

func _collapse(anchor: Vector2i) -> void:
	if not _placed.has(anchor):
		return
	var entry: Dictionary = _placed[anchor]
	var fp: Vector2i = entry.footprint
	for x in range(anchor.x, anchor.x + fp.x):
		for y in range(anchor.y, anchor.y + fp.y):
			GridService.set_tile_state(Vector2i(x, y), GridService.TileState.EMPTY)
	_placed.erase(anchor)
	EventBus.building_collapsed.emit(entry.building_id, anchor)
	print("[BuildingManager] %s collapsed at %s (rain damage) -- tile reverted to EMPTY" % [entry.building_id, anchor])

func _on_placed(building_id: String, grid_pos: Vector2i) -> void:
	var building := DataRegistry.get_building(building_id)
	var footprint: Dictionary = building.get("footprint", {"width": 1, "height": 1})
	var fp := Vector2i(footprint.get("width", 1), footprint.get("height", 1))
	_placed[grid_pos] = {
		"building_id": building_id,
		"footprint": fp,
		"built": false,
		"produce_timer": 0.0,
		"durability": MAX_DURABILITY,
	}
	# Tile occupancy lives here (not in BlueprintPlacer) so it's set no
	# matter who fired the signal -- a live placement or a save restoring
	# buildings that were never placed through the UI this session.
	for x in range(grid_pos.x, grid_pos.x + fp.x):
		for y in range(grid_pos.y, grid_pos.y + fp.y):
			GridService.set_tile_state(Vector2i(x, y), GridService.TileState.BLUEPRINT)

## Returns {anchor, building_id, built} for whichever placed building (if
## any) occupies `grid_pos` -- footprint-aware, so clicking any tile of a
## multi-tile building finds it, not just its anchor corner. Empty
## Dictionary if nothing is placed there.
func get_building_at(grid_pos: Vector2i) -> Dictionary:
	for anchor in _placed:
		var entry: Dictionary = _placed[anchor]
		var fp: Vector2i = entry.footprint
		if grid_pos.x >= anchor.x and grid_pos.x < anchor.x + fp.x \
				and grid_pos.y >= anchor.y and grid_pos.y < anchor.y + fp.y:
			return {"anchor": anchor, "building_id": entry.building_id, "built": entry.built}
	return {}

## Anchor positions of every placed-but-unbuilt blueprint -- "active
## construction sites" for anything that wants to react to them (e.g.
## DustBunnySpawner, which spawns swattable dust bunnies near active builds).
func get_unbuilt_anchors() -> Array:
	var anchors: Array = []
	for anchor in _placed:
		if not _placed[anchor].built:
			anchors.append(anchor)
	return anchors

## Called by AnimalManager once a mouse finishes its work timer on a
## blueprint tile. Flips every footprint tile to BUILT and fires
## EventBus.building_constructed -- the hook point blueprint_marker.gd
## listens on to swap its visual, and the future Architectural Resonance
## detector (step 5) will listen on too.
## Step 9: save/load robustness. Just the static facts a save needs --
## produce_timer resets to 0 on restore, which is a fine simplification
## (worst case a building's next output is delayed by up to its full
## production duration, never lost).
func serialize() -> Array:
	var out: Array = []
	for anchor in _placed:
		var entry: Dictionary = _placed[anchor]
		out.append({
			"anchor_x": anchor.x, "anchor_y": anchor.y,
			"building_id": entry.building_id,
			"built": entry.built,
			"durability": entry.durability,
		})
	return out

## Rebuilds _placed by replaying the exact same signals a live placement
## fires (building_placed_as_blueprint, then building_constructed for
## anything that had finished) -- so BlueprintPlacer respawns the visual
## marker, AnimalManager resyncs housing_positions, and AchievementService
## resyncs its counters, all with zero code here needing to know any of
## that. Unknown/removed building ids are skipped rather than crashing the
## load (a dropped expansion, a save from an older content version).
func restore(data: Array) -> void:
	_placed.clear()
	for raw in data:
		if not (raw is Dictionary):
			continue
		var building_id: String = raw.get("building_id", "")
		if DataRegistry.get_building(building_id).is_empty():
			continue
		var anchor := Vector2i(int(raw.get("anchor_x", 0)), int(raw.get("anchor_y", 0)))

		EventBus.building_placed_as_blueprint.emit(building_id, anchor)
		if not _placed.has(anchor):
			continue # defensive: a listener elsewhere could theoretically reject it

		var entry: Dictionary = _placed[anchor]
		entry.built = raw.get("built", false) == true
		entry.durability = clampf(float(raw.get("durability", MAX_DURABILITY)), 0.0, MAX_DURABILITY)

		if entry.built:
			var fp: Vector2i = entry.footprint
			for x in range(anchor.x, anchor.x + fp.x):
				for y in range(anchor.y, anchor.y + fp.y):
					GridService.set_tile_state(Vector2i(x, y), GridService.TileState.BUILT)
			EventBus.building_constructed.emit(building_id, anchor)

func complete_construction(anchor: Vector2i) -> void:
	if not _placed.has(anchor):
		return
	var entry: Dictionary = _placed[anchor]
	if entry.built:
		return

	var fp: Vector2i = entry.footprint
	for x in range(anchor.x, anchor.x + fp.x):
		for y in range(anchor.y, anchor.y + fp.y):
			GridService.set_tile_state(Vector2i(x, y), GridService.TileState.BUILT)

	entry.built = true
	entry.produce_timer = 0.0
	entry.durability = MAX_DURABILITY
	EventBus.building_constructed.emit(entry.building_id, anchor)
	print("[BuildingManager] %s construction complete at %s" % [entry.building_id, anchor])
