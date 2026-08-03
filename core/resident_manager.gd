class_name RebootResidentManager
extends Node
## Milestone 0 naming and persistence seam. Resident simulation begins in
## Milestone 3; until then legacy roster data remains recoverable explicitly.

var legacy_animal_manager: Node:
	get: return get_node_or_null("/root/AnimalManager")

func serialize_legacy_roster() -> Array:
	return legacy_animal_manager.serialize_roster() if legacy_animal_manager != null else []

func restore_legacy_roster(data: Array) -> void:
	if legacy_animal_manager != null:
		legacy_animal_manager.restore_roster(data)

func legacy_recruited_count(species_id: String) -> int:
	return legacy_animal_manager.recruited_count(species_id) if legacy_animal_manager != null else 0
