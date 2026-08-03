class_name RebootRelationshipService
extends Node

signal bond_changed(resident_a: StringName, resident_b: StringName, new_bond: int, visible_message: String)
signal moment_remembered(memory: Dictionary)
signal social_activity_enabled(activity_id: StringName)

const TIERS := {"acquaintance":0, "friend":20, "close_friend":45, "community_bond":75}
const BASE_ACTIVITIES: Array[StringName] = [&"conversation", &"shared_meal", &"collaboration", &"visit", &"celebration"]

var _bonds: Dictionary = {}
var _memories: Array[Dictionary] = []
var _repeat_counts: Dictionary = {}
var _enabled_social_activities: Array[StringName] = BASE_ACTIVITIES.duplicate()
var _social_places: Dictionary = {}

func _ready() -> void:
	if bool(ProjectSettings.get_setting("feature/reboot_mode", true)):
		call_deferred("initialize_from_resident_data")

func initialize_from_resident_data() -> void:
	if not _bonds.is_empty():
		return
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null:
		return
	for resident_value: Variant in registry.get_all_residents():
		if not resident_value is Dictionary:
			continue
		var resident: Dictionary = resident_value
		var resident_id := StringName(str(resident.get("id", "")))
		var seeds: Dictionary = resident.get("relationship_seeds", {})
		for other_id_value: Variant in seeds:
			var other_id := StringName(str(other_id_value))
			var key := pair_key(resident_id, other_id)
			_bonds[key] = maxi(int(_bonds.get(key, 0)), int(seeds[other_id_value]))

func reset() -> void:
	_bonds.clear()
	_memories.clear()
	_repeat_counts.clear()
	_enabled_social_activities.assign(BASE_ACTIVITIES)
	initialize_from_resident_data()

func bond(resident_a: StringName, resident_b: StringName) -> int:
	return int(_bonds.get(pair_key(resident_a, resident_b), 0))

func tier(resident_a: StringName, resident_b: StringName) -> StringName:
	var value := bond(resident_a, resident_b)
	if value >= int(TIERS.community_bond):
		return &"community_bond"
	if value >= int(TIERS.close_friend):
		return &"close_friend"
	if value >= int(TIERS.friend):
		return &"friend"
	return &"acquaintance"

func compatibility_score(resident_a: StringName, resident_b: StringName) -> float:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null:
		return 0.0
	var a: Dictionary = registry.get_resident(String(resident_a))
	var b: Dictionary = registry.get_resident(String(resident_b))
	if a.is_empty() or b.is_empty():
		return 0.0
	var score := 0.0
	for preference: Variant in a.get("likes", []):
		if preference in b.get("likes", []):
			score += 1.5
	for tag: Variant in a.get("personality_tags", []):
		if tag in b.get("personality_tags", []):
			score += 1.0
	# Preferences shade choices; they never create deterministic enemies.
	return clampf(score, -4.0, 6.0)

func record_moment(resident_a: StringName, resident_b: StringName, moment_type: StringName, description: String, context_key: String = "") -> int:
	if resident_a == resident_b or resident_a == &"" or resident_b == &"":
		return 0
	var signature := "%s|%s|%s" % [pair_key(resident_a, resident_b), moment_type, context_key]
	var repeat_count := int(_repeat_counts.get(signature, 0))
	var reward := 4 if repeat_count == 0 else (1 if repeat_count == 1 else 0)
	_repeat_counts[signature] = repeat_count + 1
	var key := pair_key(resident_a, resident_b)
	var previous_tier := tier(resident_a, resident_b)
	_bonds[key] = clampi(int(_bonds.get(key, 0)) + reward, 0, 100)
	var memory := {"resident_a":String(resident_a), "resident_b":String(resident_b), "moment_type":String(moment_type), "description":description, "context_key":context_key, "day":_current_day(), "bond_reward":reward, "repeat_count":repeat_count}
	_memories.append(memory)
	while _memories.size() > 40:
		_memories.pop_front()
	moment_remembered.emit(memory.duplicate(true))
	if reward > 0:
		var visible_message := description
		if tier(resident_a, resident_b) != previous_tier:
			visible_message += " Their friendship found a new rhythm."
		bond_changed.emit(resident_a, resident_b, bond(resident_a, resident_b), visible_message)
		var calendar := get_node_or_null("/root/CalendarService")
		if calendar != null:
			calendar.record_relationship_moment(visible_message)
	return reward

func memories_for(resident_id: StringName, limit: int = 3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(_memories.size() - 1, -1, -1):
		var memory: Dictionary = _memories[index]
		if str(memory.resident_a) == String(resident_id) or str(memory.resident_b) == String(resident_id):
			result.append(memory.duplicate(true))
			if result.size() >= limit:
				break
	return result

func enable_social_activity(activity_id: StringName) -> bool:
	if activity_id == &"" or activity_id in _enabled_social_activities:
		return false
	_enabled_social_activities.append(activity_id)
	social_activity_enabled.emit(activity_id)
	return true

func is_social_activity_enabled(activity_id: StringName) -> bool:
	return activity_id in _enabled_social_activities

func enabled_social_activities() -> Array[StringName]:
	return _enabled_social_activities.duplicate()

func register_social_place(place: SocialPlace) -> void:
	_social_places[place.place_id] = place

func unregister_social_place(place_id: StringName, place: SocialPlace) -> void:
	if _social_places.get(place_id) == place:
		_social_places.erase(place_id)

func get_social_place(place_id: StringName) -> SocialPlace:
	return _social_places.get(place_id) as SocialPlace

func social_places_for(activity_id: StringName) -> Array[SocialPlace]:
	var result: Array[SocialPlace] = []
	for place: SocialPlace in _social_places.values():
		if place.supports_activity(activity_id):
			result.append(place)
	return result

func serialize_state() -> Dictionary:
	var enabled: Array[String] = []
	for activity_id: StringName in _enabled_social_activities:
		enabled.append(String(activity_id))
	return {"bonds":_bonds.duplicate(), "memories":_memories.duplicate(true), "repeat_counts":_repeat_counts.duplicate(), "enabled_social_activities":enabled}

func restore_state(data: Dictionary) -> void:
	_bonds = (data.get("bonds", {}) as Dictionary).duplicate()
	_memories.clear()
	var saved_memories: Variant = data.get("memories", [])
	if saved_memories is Array:
		for memory: Variant in saved_memories:
			if memory is Dictionary:
				_memories.append(memory.duplicate(true))
	_repeat_counts = (data.get("repeat_counts", {}) as Dictionary).duplicate()
	_enabled_social_activities.clear()
	var enabled: Variant = data.get("enabled_social_activities", [])
	if enabled is Array:
		for activity_id: Variant in enabled:
			if activity_id is String:
				_enabled_social_activities.append(StringName(activity_id))
	if _enabled_social_activities.is_empty():
		_enabled_social_activities.assign(BASE_ACTIVITIES)
	initialize_from_resident_data()

func pair_key(resident_a: StringName, resident_b: StringName) -> String:
	var ids: Array[String] = [String(resident_a), String(resident_b)]
	ids.sort()
	return "%s::%s" % ids

func _current_day() -> int:
	var calendar := get_node_or_null("/root/CalendarService")
	return int(calendar.current_day) if calendar != null else 1
