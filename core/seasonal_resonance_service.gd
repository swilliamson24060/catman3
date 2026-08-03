class_name RebootSeasonalResonanceService
extends Node
## Milestone 0 boundary around Architectural Resonance. The tolerant Seasonal
## Resonance evaluator is intentionally deferred to Milestone 7.

var legacy_resonance_service: Node:
	get: return get_node_or_null("/root/ResonanceService")

func reapply_legacy_discoveries() -> void:
	if legacy_resonance_service != null:
		legacy_resonance_service.reapply_discovered_bonuses()

func supports_seasonal_evaluation() -> bool:
	return false
