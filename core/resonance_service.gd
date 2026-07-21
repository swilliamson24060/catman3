extends Node
## Autoload "ResonanceService". Ports the GDD's Architectural Resonance
## detector (section 5) close to verbatim:
##
##   def on_building_constructed(new_building, save_data):
##       for pattern in lookup_patterns_by_anchor(new_building.type):
##           if pattern.id in save_data.discovered_patterns: continue
##           if check_grid_offsets_match(new_building.position, pattern.required_offsets):
##               save_data.discovered_patterns.append(pattern.id)
##               apply_global_bonuses(pattern.bonuses)
##               trigger_discovery_ui(pattern.display_name)
##               break
##
## Every building-completion (EventBus.building_constructed, fired by
## BuildingManager once a mouse finishes construction) re-checks every
## resonance_patterns.json entry anchored on that building type. Offsets are
## tested across all 4 cardinal rotations so a pattern isn't orientation-
## locked to however the player happened to lay it out. discovered_patterns
## lives on SaveService.current (SaveData), so the one-time rule survives a
## save/load and re-triggering an already-discovered pattern is a no-op.

func _ready() -> void:
	EventBus.building_constructed.connect(_on_building_constructed)
	SettlementManager.building_registered.connect(_on_phase2_building_registered)

func _on_building_constructed(building_id: String, anchor: Vector2i) -> void:
	for pattern in DataRegistry.get_all_resonance_patterns():
		if pattern.get("anchor_building_type", "") != building_id:
			continue

		var pattern_id: String = pattern.get("id", "")
		if pattern_id in SaveService.current.discovered_patterns:
			continue # RULE ENFORCEMENT: already granted, skip.

		if _offsets_match(anchor, pattern.get("required_offsets", [])):
			SaveService.current.discovered_patterns.append(pattern_id)
			_apply_pattern_bonuses(pattern)
			EventBus.pattern_discovered.emit(pattern_id)
			print("[ResonanceService] Discovered pattern '%s' at %s" % [pattern_id, anchor])
			break

## Checks required_offsets against `anchor` across all 4 cardinal rotations
## (0/90/180/270 degrees) of the offset set as a whole, so the same
## triangle/shape is recognized no matter which way the player built it.
func _offsets_match(anchor: Vector2i, required_offsets: Array) -> bool:
	for rotation in range(4):
		var all_match := true
		for offset in required_offsets:
			var raw := Vector2i(offset.get("x_offset", 0), offset.get("z_offset", 0))
			var target_pos := anchor + _rotate(raw, rotation)
			if not _has_built_building(target_pos, offset.get("building_type", "")):
				all_match = false
				break
		if all_match:
			return true
	return false

func _rotate(v: Vector2i, times: int) -> Vector2i:
	var result := v
	for i in times:
		result = Vector2i(-result.y, result.x)
	return result

func _has_built_building(anchor_pos: Vector2i, building_type: String) -> bool:
	var info := BuildingManager.get_building_at(anchor_pos)
	if info.is_empty() or not info.get("built", false):
		return false
	return info.get("anchor") == anchor_pos and info.get("building_id", "") == building_type


## Phase 2 uses the same JSON schema over a snapped 3D-world grid. Recheck
## every eligible anchor whenever any building completes so construction order
## does not force the Catnip Garden anchor to be built last.
func _on_phase2_building_registered(_new_building: Node3D) -> void:
	for pattern: Dictionary in DataRegistry.get_all_resonance_patterns():
		var pattern_id := str(pattern.get("id", ""))
		if pattern_id in SaveService.current.discovered_patterns:
			continue
		var anchor_type := StringName(str(pattern.get("anchor_building_type", "")))
		for anchor: CompletedBuilding in SettlementManager.get_completed_buildings_of_type(anchor_type):
			var anchor_grid := SettlementManager.world_to_resonance_grid(anchor.global_position)
			if _phase2_offsets_match(anchor_grid, pattern.get("required_offsets", [])):
				SaveService.current.discovered_patterns.append(pattern_id)
				_apply_pattern_bonuses(pattern)
				EventBus.pattern_discovered.emit(pattern_id)
				print("[ResonanceService] Phase 2 discovered pattern '%s' at %s" % [pattern_id, anchor_grid])
				return


func _phase2_offsets_match(anchor: Vector2i, required_offsets: Array) -> bool:
	for rotation: int in range(4):
		var all_match := true
		for offset: Dictionary in required_offsets:
			var raw := Vector2i(int(offset.get("x_offset", 0)), int(offset.get("z_offset", 0)))
			var target := anchor + _rotate(raw, rotation)
			if not SettlementManager.has_completed_building_at(target, StringName(str(offset.get("building_type", "")))):
				all_match = false
				break
		if all_match:
			return true
	return false


## Rebuilds all persisted resonance rewards without rediscovering patterns or
## replaying banners/achievements. Named modifier sources prevent stacking.
func reapply_discovered_bonuses() -> void:
	for pattern_id: String in SaveService.current.discovered_patterns:
		var pattern := DataRegistry.get_resonance_pattern(pattern_id)
		if pattern.is_empty():
			push_warning("[ResonanceService] Save references unknown pattern '%s'." % pattern_id)
			continue
		_apply_pattern_bonuses(pattern)


func _apply_pattern_bonuses(pattern: Dictionary) -> void:
	var pattern_id := str(pattern.get("id", ""))
	DataRegistry.apply_global_bonuses(pattern.get("bonuses", []), "resonance:%s" % pattern_id)
