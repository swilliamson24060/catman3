class_name RebootInvestigationService
extends Node

signal table_requested(pending_discoveries: Array[StringName])
signal investigation_completed(result: Dictionary)

var last_investigation_resident: StringName

func reset() -> void:
	last_investigation_resident = &""

func request_table() -> void:
	table_requested.emit(get_node("/root/DiscoveryService").pending_investigations())

func investigate(discovery_id: StringName) -> Dictionary:
	var definition: Dictionary = get_node("/root/DiscoveryService").definition(discovery_id)
	if definition.is_empty(): return {}
	last_investigation_resident = get_node("/root/ResidentManager").meet_for_investigation(StringName(str(definition.get("resident_specialty", "history"))))
	var specialty := &""
	var agent: Node = get_node("/root/ResidentManager").get_agent(last_investigation_resident)
	if agent != null: specialty = StringName(str(agent.definition.get("specialty", "")))
	var result: Dictionary = get_node("/root/DiscoveryService").investigate(discovery_id, specialty)
	if not result.is_empty():
		result["resident_id"] = String(last_investigation_resident)
		investigation_completed.emit(result)
	return result

func serialize_state() -> Dictionary: return {"last_investigation_resident":String(last_investigation_resident)}
func restore_state(data: Dictionary) -> void: last_investigation_resident = StringName(str(data.get("last_investigation_resident", "")))
