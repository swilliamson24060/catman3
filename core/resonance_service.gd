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

func _on_building_constructed(building_id: String, anchor: Vector2i) -> void:
	for pattern in DataRegistry.get_all_resonance_patterns():
		if pattern.get("anchor_building_type", "") != building_id:
			continue

		var pattern_id: String = pattern.get("id", "")
		if pattern_id in SaveService.current.discovered_patterns:
			continue # RULE ENFORCEMENT: already granted, skip.

		if _offsets_match(anchor, pattern.get("required_offsets", [])):
			SaveService.current.discovered_patterns.append(pattern_id)
			DataRegistry.apply_global_bonuses(pattern.get("bonuses", []))
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
