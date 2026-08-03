class_name RebootSeasonalResonanceService
extends Node

signal feedback_changed(result: Dictionary)
signal component_changed(plinth_index: int, component_id: StringName)
signal activation_started(pattern_id: StringName)
signal activation_completed(pattern_id: StringName)

const PATTERN_ID := &"resonance_first_bloom"
const FEEDBACK_NAMES := ["Dormant", "Stirring", "Echoing", "Aligned", "Activated"]
const COMPONENT_IDS: Array[StringName] = [&"component_rain_lens", &"component_copper_gear", &"component_heirloom_seeds"]
const DEBOUNCE_SECONDS := 0.25

var pattern: Dictionary = {}
var plinth_components: Array[StringName] = [&"", &"", &""]
var current_result: Dictionary = {"tier":0, "tier_name":"Dormant"}
var watching_condition: bool = false
var activated: bool = false
var activation_in_progress: bool = false
var applied_effects: Dictionary = {}
var flower_palette_unlocked: bool = false
var evaluation_count: int = 0
var evaluation_request_count: int = 0
var reaction_log: Array[Dictionary] = []
var autosave_path: String = "user://catmando_save.json"
var _site: Node
var _debounce_timer: Timer

var legacy_resonance_service: Node:
	get: return get_node_or_null("/root/ResonanceService")

func _ready() -> void:
	pattern = get_node("/root/DataRegistry").get_resonance_pattern(String(PATTERN_ID))
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = DEBOUNCE_SECONDS
	_debounce_timer.timeout.connect(_evaluate_live_attempt)
	add_child(_debounce_timer)
	get_node("/root/WeatherService").weather_transition.connect(_on_weather_transition)

func supports_seasonal_evaluation() -> bool: return true

func reapply_legacy_discoveries() -> void:
	if legacy_resonance_service != null: legacy_resonance_service.reapply_discovered_bonuses()

func reset() -> void:
	plinth_components = [&"", &"", &""]
	current_result = {"tier":0, "tier_name":"Dormant"}
	watching_condition = false
	activated = false
	activation_in_progress = false
	applied_effects.clear()
	flower_palette_unlocked = false
	evaluation_count = 0
	evaluation_request_count = 0
	reaction_log.clear()
	_refresh_site()

func bind_site(site: Node) -> void:
	_site = site
	_refresh_site()

func unbind_site(site: Node) -> void:
	if _site == site: _site = null

func handle_plinth_interaction(plinth_index: int) -> bool:
	if plinth_index < 0 or plinth_index >= 3: return false
	if not plinth_components[plinth_index].is_empty(): return retrieve_component(plinth_index) != &""
	for component_id: StringName in COMPONENT_IDS:
		if component_id not in plinth_components and get_node("/root/DiscoveryService").state(component_id) == &"interpreted":
			return place_component(plinth_index, component_id)
	return false

func place_component(plinth_index: int, component_id: StringName) -> bool:
	if plinth_index < 0 or plinth_index >= 3 or component_id not in COMPONENT_IDS: return false
	if get_node("/root/DiscoveryService").state(component_id) != &"interpreted": return false
	if component_id in plinth_components: return false
	if not plinth_components[plinth_index].is_empty(): return false
	plinth_components[plinth_index] = component_id
	component_changed.emit(plinth_index, component_id)
	queue_evaluation()
	return true

func retrieve_component(plinth_index: int) -> StringName:
	if plinth_index < 0 or plinth_index >= 3: return &""
	var component_id := plinth_components[plinth_index]
	if component_id.is_empty(): return &""
	plinth_components[plinth_index] = &""
	component_changed.emit(plinth_index, &"")
	watching_condition = false
	queue_evaluation()
	return component_id

func queue_evaluation() -> void:
	evaluation_request_count += 1
	if activated:
		current_result = {"tier":4, "tier_name":"Activated", "geometry_score":1.0, "component_role_score":1.0, "center_score":1.0, "condition_status":"met"}
		_refresh_site()
		return
	_debounce_timer.start(DEBOUNCE_SECONDS)

func evaluate_attempt(candidate: Dictionary, condition_met: bool = false) -> Dictionary:
	var positions: Array = candidate.get("positions", [])
	var components: Array = candidate.get("components", [])
	var center: Vector3 = candidate.get("center", Vector3.ZERO)
	var landmark_ready := bool(candidate.get("landmark_ready", true))
	var result := {"geometry_score":0.0, "component_role_score":0.0, "center_score":0.0, "condition_status":"met" if condition_met else "waiting", "tier":0, "tier_name":"Dormant", "scale_valid":false, "unique_assignments":false}
	if positions.size() != 3 or components.size() != 3: return result
	var unique_positions: bool = positions[0] != positions[1] and positions[0] != positions[2] and positions[1] != positions[2]
	var nonempty_components: Array = components.filter(func(value: Variant) -> bool: return not StringName(str(value)).is_empty())
	var unique_components: bool = nonempty_components.size() == _unique_strings(nonempty_components).size()
	result.unique_assignments = unique_positions and unique_components
	var sides: Array[float] = [positions[0].distance_to(positions[1]), positions[1].distance_to(positions[2]), positions[2].distance_to(positions[0])]
	var scale_range: Array = pattern.get("geometry", {}).get("scale_range", [3.5, 5.5])
	var scale_valid := sides.all(func(side: float) -> bool: return side >= float(scale_range[0]) and side <= float(scale_range[1]))
	var tolerance := float(pattern.get("geometry", {}).get("tolerance_meters", 0.65))
	var equilateral_error: float = sides.max() - sides.min()
	var equilateral_score := clampf(1.0 - equilateral_error / maxf(tolerance * 2.0, 0.01), 0.0, 1.0)
	var in_range_count := sides.filter(func(side: float) -> bool: return side >= float(scale_range[0]) and side <= float(scale_range[1])).size()
	result.geometry_score = (float(in_range_count) / 3.0) * 0.55 + equilateral_score * 0.45
	result.scale_valid = scale_valid
	var centroid: Vector3 = (positions[0] + positions[1] + positions[2]) / 3.0
	var contains_center := _point_in_triangle_xz(center, positions[0], positions[1], positions[2])
	result.center_score = 1.0 if landmark_ready and contains_center and centroid.distance_to(center) <= tolerance else (0.5 if landmark_ready and contains_center else 0.0)
	var nodes: Array = pattern.get("geometry", {}).get("nodes", [])
	var correct_roles := 0
	var relevant := 0
	var allowed_all: Array[StringName] = []
	for node_value: Variant in nodes:
		for allowed: Variant in (node_value as Dictionary).get("allowed_components", []): allowed_all.append(StringName(str(allowed)))
	for index in range(3):
		var component_id := StringName(str(components[index]))
		if component_id in allowed_all: relevant += 1
		if index < nodes.size() and component_id in (nodes[index] as Dictionary).get("allowed_components", []): correct_roles += 1
	result.component_role_score = float(correct_roles) / 3.0
	var fully_aligned: bool = result.unique_assignments and scale_valid and equilateral_error <= tolerance and float(result.center_score) >= 1.0 and correct_roles == 3
	var tier := 0
	if fully_aligned: tier = 4 if condition_met else 3
	elif relevant > 0 and (float(result.geometry_score) >= 0.55 or float(result.component_role_score) >= 0.34 or float(result.center_score) > 0.0): tier = 2
	elif relevant > 0: tier = 1
	result.tier = tier
	result.tier_name = FEEDBACK_NAMES[tier]
	return result

func serialize_state() -> Dictionary:
	return {"plinth_components":_strings(plinth_components), "watching_condition":watching_condition, "activated":activated, "applied_effects":applied_effects.duplicate(true), "flower_palette_unlocked":flower_palette_unlocked, "current_result":current_result.duplicate(true), "reaction_log":reaction_log.duplicate(true)}

func restore_state(data: Dictionary) -> void:
	plinth_components = [&"", &"", &""]
	var saved: Array = data.get("plinth_components", [])
	for index in range(mini(saved.size(), 3)): plinth_components[index] = StringName(str(saved[index]))
	watching_condition = bool(data.get("watching_condition", false))
	activated = bool(data.get("activated", false))
	applied_effects = (data.get("applied_effects", {}) as Dictionary).duplicate(true)
	flower_palette_unlocked = bool(data.get("flower_palette_unlocked", false))
	current_result = (data.get("current_result", {"tier":0,"tier_name":"Dormant"}) as Dictionary).duplicate(true)
	reaction_log.clear()
	for entry: Variant in data.get("reaction_log", []):
		if entry is Dictionary: reaction_log.append(entry.duplicate(true))
	_reapply_persistent_effects()
	_refresh_site()

func confirmed_pattern_text() -> String:
	if not activated: return "None yet — the arrangement can still be tested."
	return "[b]The First Bloom[/b]\nTriangle: rain lens, carved copper gear, and heirloom seeds around the old garden tree. Condition: rain followed by sunrise."

func _evaluate_live_attempt() -> void:
	if _site == null or not is_instance_valid(_site): return
	evaluation_count += 1
	current_result = evaluate_attempt(_site.candidate_data(plinth_components), false)
	watching_condition = int(current_result.tier) == 3 and not activated
	feedback_changed.emit(current_result.duplicate(true))
	get_node("/root/EventBus").resonance_feedback_changed.emit(PATTERN_ID, int(current_result.tier))
	_record_reactions(int(current_result.tier), false)

func _on_weather_transition(transition_id: StringName, _day: int) -> void:
	if transition_id != &"rain_to_sunrise" or get_node("/root/CalendarService").period_id() != &"morning" or not watching_condition or activated or activation_in_progress: return
	var candidate: Dictionary = _site.candidate_data(plinth_components) if _site != null else {}
	var result := evaluate_attempt(candidate, true)
	if int(result.tier) == 4: _activate(result)

func _activate(result: Dictionary) -> void:
	activation_in_progress = true
	watching_condition = false
	current_result = result.duplicate(true)
	activation_started.emit(PATTERN_ID)
	get_node("/root/CalendarService").push_modal_pause()
	feedback_changed.emit(current_result.duplicate(true))
	if _site != null: _site.play_activation_sequence()
	await get_tree().create_timer(0.5, true).timeout
	activated = true
	_apply_effects_once()
	_record_reactions(4, true)
	activation_in_progress = false
	get_node("/root/CalendarService").pop_modal_pause()
	activation_completed.emit(PATTERN_ID)
	get_node("/root/EventBus").seasonal_resonance_activated.emit(PATTERN_ID)
	get_node("/root/SaveService").save_game(autosave_path)

func _apply_effects_once() -> void:
	_apply_effect("flower_palette", func() -> void: flower_palette_unlocked = true)
	_apply_effect("garden_gathering", func() -> void: get_node("/root/RelationshipService").enable_social_activity(&"garden_gathering"))
	_apply_effect("mara_aspiration", func() -> void: get_node("/root/ResidentManager").apply_first_bloom_aspiration())
	_apply_effect("almanac_pattern", func() -> void:
		if String(PATTERN_ID) not in get_node("/root/SaveService").current.discovered_patterns: get_node("/root/SaveService").current.discovered_patterns.append(String(PATTERN_ID)))
	_apply_effect("world_sequence", func() -> void: pass)
	_refresh_site()

func _apply_effect(effect_id: String, action: Callable) -> void:
	if bool(applied_effects.get(effect_id, false)): return
	action.call()
	applied_effects[effect_id] = true

func _reapply_persistent_effects() -> void:
	if activated:
		flower_palette_unlocked = true
		get_node("/root/RelationshipService").enable_social_activity(&"garden_gathering")
		get_node("/root/ResidentManager").apply_first_bloom_aspiration()
		if String(PATTERN_ID) not in get_node("/root/SaveService").current.discovered_patterns: get_node("/root/SaveService").current.discovered_patterns.append(String(PATTERN_ID))

func _record_reactions(tier: int, activation: bool) -> void:
	if tier < 2: return
	var witnessed: Array[StringName] = get_node("/root/ResidentManager").residents_near(Vector3(-7.0, 0.2, 19.0), 10.0)
	var entry := {"tier":tier, "activation":activation, "witnessed":_strings(witnessed)}
	reaction_log.append(entry)
	get_node("/root/ResidentManager").react_to_resonance(tier, activation, witnessed)

func _refresh_site() -> void:
	if _site != null and is_instance_valid(_site): _site.apply_state(plinth_components, current_result, activated, flower_palette_unlocked)

func _point_in_triangle_xz(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var p := Vector2(point.x, point.z)
	var av := Vector2(a.x, a.z)
	var bv := Vector2(b.x, b.z)
	var cv := Vector2(c.x, c.z)
	var denominator := (bv.y - cv.y) * (av.x - cv.x) + (cv.x - bv.x) * (av.y - cv.y)
	if absf(denominator) < 0.0001: return false
	var alpha := ((bv.y - cv.y) * (p.x - cv.x) + (cv.x - bv.x) * (p.y - cv.y)) / denominator
	var beta := ((cv.y - av.y) * (p.x - cv.x) + (av.x - cv.x) * (p.y - cv.y)) / denominator
	var gamma := 1.0 - alpha - beta
	return alpha >= 0.0 and beta >= 0.0 and gamma >= 0.0

func _unique_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		var text := str(value)
		if text not in result: result.append(text)
	return result

func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values: result.append(str(value))
	return result
