extends Node
## Autoload "AchievementService" (Step 7: Achievement & Unlock Engine).
## Listens on EventBus for qualifying events, keeps a running counter per
## condition, and unlocks any achievements.json entry whose condition is
## satisfied -- writing both the achievement's own id and whatever content
## ids it lists under `unlocks` into SaveService.current.unlocked_content
## (mirroring discovered_patterns' one-time-only shape). UI (BlueprintPlacer
## gating a locked building, a future recruitment-board filter, etc.) only
## ever needs to ask is_unlocked(content_id) -- it never needs to know which
## achievement, if any, granted it.
##
## Condition types are a small fixed vocabulary (same idiom as
## modifier_type "additive"/"multiplier" elsewhere) rather than a fully
## generic signal-arg matcher, since EventBus signals don't share a common
## shape: "building_constructed_count" (optional building_id, else counts
## any construction), "animal_recruited_count" (species_id required),
## "pattern_discovered_count" (counts any pattern). Adding a new condition
## type only ever means one more match arm in _condition_met -- the
## achievement catalog itself stays 100% data-driven.

var _building_counts: Dictionary = {} # building_id -> int, plus "_any" for totals
var _animal_counts: Dictionary = {}   # species_id -> int, cumulative recruits (not current roster)
var _pattern_count: int = 0
var _tracking_enabled: bool = true

func _ready() -> void:
	EventBus.building_constructed.connect(_on_building_constructed)
	EventBus.animal_recruited.connect(_on_animal_recruited)
	EventBus.pattern_discovered.connect(_on_pattern_discovered)
	SettlementManager.building_registered.connect(_on_phase2_building_registered)
	GameState.mouse_recruited.connect(_on_phase2_mouse_recruited)

func _on_building_constructed(building_id: String, _anchor: Vector2i) -> void:
	if not _tracking_enabled:
		return
	_building_counts[building_id] = _building_counts.get(building_id, 0) + 1
	_building_counts["_any"] = _building_counts.get("_any", 0) + 1
	_check_achievements("building_constructed_count")

func _on_animal_recruited(_animal_id: String, species_id: String) -> void:
	if not _tracking_enabled:
		return
	_animal_counts[species_id] = _animal_counts.get(species_id, 0) + 1
	_check_achievements("animal_recruited_count")

func _on_pattern_discovered(_pattern_id: String) -> void:
	if not _tracking_enabled:
		return
	_pattern_count += 1
	_check_achievements("pattern_discovered_count")


func _on_phase2_building_registered(building: Node3D) -> void:
	if not _tracking_enabled or not building is CompletedBuilding:
		return
	var completed := building as CompletedBuilding
	if completed.building_definition == null:
		return
	_on_building_constructed(str(completed.building_definition.id), Vector2i.ZERO)


func _on_phase2_mouse_recruited(_mouse: Phase1WildMouse) -> void:
	if not _tracking_enabled:
		return
	_animal_counts["mouse"] = _animal_counts.get("mouse", 0) + 1
	_check_achievements("animal_recruited_count")

func _check_achievements(condition_type: String) -> void:
	for achievement in DataRegistry.get_all_achievements():
		var condition: Dictionary = achievement.get("condition", {})
		if condition.get("type", "") != condition_type:
			continue
		var achievement_id: String = achievement.get("id", "")
		if is_unlocked(achievement_id):
			continue
		if _condition_met(condition):
			_unlock(achievement)

func _condition_met(condition: Dictionary) -> bool:
	var threshold: int = condition.get("count", 1)
	match condition.get("type", ""):
		"building_constructed_count":
			var building_id: String = condition.get("building_id", "")
			var key := building_id if building_id != "" else "_any"
			return _building_counts.get(key, 0) >= threshold
		"animal_recruited_count":
			return _animal_counts.get(condition.get("species_id", ""), 0) >= threshold
		"pattern_discovered_count":
			return _pattern_count >= threshold
	return false

func _unlock(achievement: Dictionary) -> void:
	var achievement_id: String = achievement.get("id", "")
	SaveService.current.unlocked_content.append(achievement_id)
	for content_id in achievement.get("unlocks", []):
		if not is_unlocked(content_id):
			SaveService.current.unlocked_content.append(content_id)
	EventBus.achievement_unlocked.emit(achievement_id)
	print("[AchievementService] Unlocked achievement '%s': %s (unlocks: %s)" % [
		achievement_id, achievement.get("display_name", achievement_id), achievement.get("unlocks", [])
	])

## True if `content_id` -- an achievement id OR any id listed in some
## achievement's `unlocks` -- has been granted this run.
func is_unlocked(content_id: String) -> bool:
	return content_id in SaveService.current.unlocked_content


func serialize_progress() -> Dictionary:
	return {
		"building_counts": _building_counts.duplicate(true),
		"animal_counts": _animal_counts.duplicate(true),
		"pattern_count": _pattern_count,
	}


func restore_progress(data: Dictionary) -> void:
	_building_counts = _sanitized_counts(data.get("building_counts", {}))
	_animal_counts = _sanitized_counts(data.get("animal_counts", {}))
	_pattern_count = maxi(int(data.get("pattern_count", 0)), 0)


func set_tracking_enabled(enabled: bool) -> void:
	_tracking_enabled = enabled


func reset_progress() -> void:
	_building_counts.clear()
	_animal_counts.clear()
	_pattern_count = 0


func _sanitized_counts(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for key: Variant in value:
			result[str(key)] = maxi(int(value[key]), 0)
	return result
