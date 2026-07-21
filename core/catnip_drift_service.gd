extends Node
## Autoload "CatnipDriftService" (Step 6, mechanic 5: Catnip Drift
## Dynamics). Tracks every *built* Catnip Garden and computes how strong the
## aroma is at any grid position given WeatherService's current wind
## direction. Nothing here is mouse-specific -- it just answers "how much
## catnip scent is at this tile," and AnimalManager decides what that does
## to whichever animal happens to be standing there.
##
## Scoping note: the plan calls for scent to speed up work downwind but
## "lull guard mice to sleep." There's no dedicated guard-mouse role in the
## current job system, so the drowsiness effect is folded into the same
## per-tile intensity curve any working animal reads: a moderate, spread-out
## dose of aroma is invigorating (speed bonus), but standing right on top of
## the source is overpowering (a work-speed penalty representing dozing
## off). This keeps the mechanic generic across species/roles rather than
## requiring a new "guard" job that doesn't otherwise exist.

const DRIFT_RANGE := 6.0       # tiles downwind the scent plume can reach
const LATERAL_SPREAD := 2.5    # tiles the plume widens to either side
const NEAR_RADIUS := 1.5       # tiles around the garden itself -- overpoweringly strong, any direction
const DOWNWIND_PEAK := 0.6     # max strength of the downwind plume (below the doze threshold)
const MAX_INTENSITY := 1.5     # cap when multiple gardens/plumes overlap

var _garden_anchors: Dictionary = {} # anchor Vector2i -> footprint Vector2i, built catnip gardens only

func _ready() -> void:
	EventBus.building_constructed.connect(_on_building_constructed)
	EventBus.building_collapsed.connect(_on_building_removed)

func _on_building_constructed(building_id: String, grid_pos: Vector2i) -> void:
	if building_id != "building_catnip_garden":
		return
	var building := DataRegistry.get_building(building_id)
	var footprint: Dictionary = building.get("footprint", {"width": 1, "height": 1})
	_garden_anchors[grid_pos] = Vector2i(footprint.get("width", 1), footprint.get("height", 1))

func _on_building_removed(building_id: String, grid_pos: Vector2i) -> void:
	if building_id != "building_catnip_garden":
		return
	_garden_anchors.erase(grid_pos)

## Scent intensity at `grid_pos`, summed across every built Catnip Garden and
## capped at MAX_INTENSITY. 0.0 means no detectable aroma there right now.
func get_scent_at(grid_pos: Vector2i) -> float:
	if _garden_anchors.is_empty():
		return 0.0
	var wind := Vector2(WeatherService.wind_direction())
	var total := 0.0
	for anchor in _garden_anchors:
		var footprint: Vector2i = _garden_anchors[anchor]
		var center := Vector2(anchor) + Vector2(footprint) / 2.0
		var offset: Vector2 = Vector2(grid_pos) - center
		var dist_to_center := offset.length()

		# Right on top of the garden: overpowering, in any direction.
		if dist_to_center <= NEAR_RADIUS:
			total += 1.0
			continue

		# Further out, only the downwind plume carries any scent.
		var downwind_dist := offset.dot(wind)
		if downwind_dist <= 0.0 or downwind_dist > DRIFT_RANGE:
			continue
		var lateral_dist: float = (offset - wind * downwind_dist).length()
		if lateral_dist > LATERAL_SPREAD:
			continue

		var strength: float = DOWNWIND_PEAK * (1.0 - downwind_dist / DRIFT_RANGE) * (1.0 - lateral_dist / LATERAL_SPREAD)
		total += strength

	return minf(total, MAX_INTENSITY)
