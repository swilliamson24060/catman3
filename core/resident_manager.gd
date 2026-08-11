class_name RebootResidentManager
extends Node

signal residents_spawned(count: int)
signal dialogue_requested(resident: ResidentAgent, text: String)
signal dialogue_closed(resident_id: StringName)
signal priority_changed(priority_id: StringName)
signal locator_changed(entries: Array[Dictionary])
signal board_requested
signal social_activity_started(session: Dictionary)
signal social_activity_completed(session: Dictionary)
signal project_contribution_started(session: Dictionary)
signal project_contribution_completed(session: Dictionary)
signal project_coordination_comment(text: String)
signal resonance_reaction(text: String, witnessed_residents: Array[StringName])

const RESIDENT_SCENE := preload("res://scenes/residents/resident_agent.tscn")
const RESTORE_GARDEN_PRIORITY := &"project_restore_garden"

var current_priority: StringName
var recent_discoveries: Array[String] = []
var _agents: Dictionary = {}
var _world_root: Node3D
var _pending_state: Dictionary = {}
var _active_dialogue_resident: ResidentAgent
var _social_sessions: Dictionary = {}
var _next_social_session_index: int = 1
var _project_session: Dictionary = {}
var _reading_opportunities: Dictionary = {}  # discovery_id (StringName) -> {specialty: StringName, position: Vector3}
var _errand_session: Dictionary = {}  # {resident_id, discovery_id, phase, remaining_seconds}
var _pending_errand_discovery: StringName = &""
var _pending_ask_resident: ResidentAgent  # who the "what would you like to ask about" list is currently open for, if anyone

var legacy_animal_manager: Node:
	get: return get_node_or_null("/root/AnimalManager")

func _ready() -> void:
	if bool(ProjectSettings.get_setting("feature/reboot_mode", true)):
		get_node("/root/CalendarService").resident_schedule_changed.connect(_on_period_changed)
		get_node("/root/WeatherService").forecast_changed.connect(_on_forecast_changed)
		get_node("/root/RelationshipService").social_activity_enabled.connect(_on_social_activity_enabled)

func _process(delta: float) -> void:
	if _world_root == null or not is_instance_valid(_world_root):
		return
	_process_project_contribution(delta)
	_process_errand(delta)
	for session_id: StringName in _social_sessions.keys():
		var session: Dictionary = _social_sessions[session_id]
		if str(session.get("phase", "traveling")) == "traveling":
			var all_ready := true
			for resident_id_value: Variant in session.participant_ids:
				var agent := get_agent(StringName(str(resident_id_value)))
				if agent == null or not agent.is_social_ready(session_id):
					all_ready = false
					break
			if all_ready:
				session.phase = "performing"
				_social_sessions[session_id] = session
		elif str(session.get("phase", "")) == "performing":
			session.remaining_seconds = maxf(float(session.get("remaining_seconds", 6.0)) - delta, 0.0)
			_social_sessions[session_id] = session
			if is_zero_approx(float(session.remaining_seconds)):
				complete_social_activity(session_id)

func bind_world(world_root: Node3D) -> void:
	if not bool(ProjectSettings.get_setting("feature/reboot_mode", true)):
		return
	_world_root = world_root
	_spawn_residents()
	# Pip's authored off-screen observation is a player rumor, not a command or
	# a progression gate. The component remains safely recoverable at its site.
	get_node("/root/DiscoveryService").resident_observed(&"component_copper_gear", &"resident_pip")

func meet_for_investigation(specialty: StringName) -> StringName:
	var best: ResidentAgent
	for agent: ResidentAgent in get_agents():
		if StringName(str(agent.definition.get("specialty", ""))) == specialty:
			best = agent
			break
	if best == null: best = get_agent(&"resident_elowen")
	if best == null and not get_agents().is_empty(): best = get_agents()[0]
	if best == null: return &""
	best.begin_investigation_meet(Vector3(13.0, 0.2, -2.0))
	best.global_position = Vector3(13.0, best.global_position.y, -2.0)
	return best.resident_id

func unbind_world(world_root: Node3D) -> void:
	if _world_root != world_root:
		return
	cancel_all_social_activities(false)
	cancel_project_contribution(false)
	_agents.clear()
	_world_root = null

func _spawn_residents() -> void:
	for agent: ResidentAgent in _agents.values():
		if is_instance_valid(agent):
			agent.queue_free()
	_agents.clear()
	var saved_state := _pending_state.duplicate(true)
	var saved_residents: Dictionary = saved_state.get("residents", {})
	for definition_value: Variant in get_node("/root/DataRegistry").get_all_residents():
		if not definition_value is Dictionary:
			continue
		var definition: Dictionary = definition_value
		var resident_id := StringName(str(definition.get("id", "")))
		var agent := RESIDENT_SCENE.instantiate() as ResidentAgent
		_world_root.get_node("Residents").add_child(agent)
		agent.conversation_requested.connect(_on_conversation_requested)
		agent.activity_changed.connect(_on_agent_activity_changed)
		agent.configure(definition, saved_residents.get(String(resident_id), {}))
		_agents[resident_id] = agent
	current_priority = StringName(str(saved_state.get("current_priority", current_priority)))
	_pending_state.clear()
	_restore_social_sessions(saved_state.get("social_sessions", []))
	residents_spawned.emit(_agents.size())
	_emit_locator()

func new_game() -> void:
	current_priority = &""
	recent_discoveries.clear()
	cancel_all_social_activities()
	cancel_project_contribution()
	cancel_errand()
	# _reading_opportunities is deliberately untouched -- it's static world
	# layout (who can read what, where), registered once at spawn, not
	# session progress. Actual progress lives in DiscoveryService's state,
	# which callers reset separately; clearing this here would permanently
	# strand any anchor's reading errand the moment a fresh game starts,
	# since nothing re-registers it after the world has already booted.
	_pending_errand_discovery = &""
	_pending_ask_resident = null
	_pending_state.clear()
	if _world_root != null:
		_spawn_residents()

func propose_priority(priority_id: StringName) -> bool:
	if priority_id != RESTORE_GARDEN_PRIORITY:
		return false
	current_priority = priority_id
	priority_changed.emit(current_priority)
	get_node("/root/CalendarService").record_project_progress("The community proposed restoring the abandoned garden.")
	get_node("/root/CommunityProjectService").start_project(priority_id)
	return true

func consider_project_contributions() -> void:
	if not _project_session.is_empty(): return
	var service := get_node("/root/CommunityProjectService")
	if not service.active or not service.materials_ready(): return
	var specialties: Array[StringName] = service.required_specialties()
	var best_agent: ResidentAgent
	var best_score := -INF
	for agent: ResidentAgent in get_agents():
		if agent.is_away(): continue
		if not service.can_resident_contribute(agent.resident_id): continue
		var specialty := StringName(str(agent.definition.get("specialty", "")))
		var score := (40.0 if specialty in specialties else 8.0) + agent.energy * 10.0 + agent.mood * 5.0
		if str(agent.definition.get("aspiration_id", "")) == "aspiration_restore_garden": score += 20.0
		if current_priority == RESTORE_GARDEN_PRIORITY: score += 12.0
		if score > best_score:
			best_score = score
			best_agent = agent
	if best_agent == null: return
	var project := _world_root.get_node_or_null("Projects/RestoreGarden")
	if project == null: return
	_project_session = {"resident_id":String(best_agent.resident_id), "phase_id":String(service.current_phase_id()), "phase":"traveling", "remaining_seconds":2.0, "work_action":String(service.work_action())}
	best_agent.begin_project_contribution(service.current_phase_id(), service.current_phase_label(), service.work_action(), project.contribution_slot_position(1))
	project_contribution_started.emit(_project_session.duplicate(true))

func _process_project_contribution(delta: float) -> void:
	if _project_session.is_empty(): return
	var agent := get_agent(StringName(str(_project_session.resident_id)))
	if agent == null:
		_project_session.clear()
		return
	if str(_project_session.phase) == "traveling" and agent.is_project_ready():
		_project_session.phase = "performing"
	elif str(_project_session.phase) == "performing":
		_project_session.remaining_seconds = maxf(float(_project_session.remaining_seconds) - delta, 0.0)
		if is_zero_approx(float(_project_session.remaining_seconds)):
			var service := get_node("/root/CommunityProjectService")
			var session := _project_session.duplicate(true)
			agent.finish_project_contribution()
			_project_session.clear()
			service.contribute(agent.resident_id, false)
			project_contribution_completed.emit(session)
			project_coordination_comment.emit(_project_comment(StringName(str(session.phase_id)), agent.display_name()))

## Registers a field discovery that's been found but needs a resident's
## specialty to make sense of -- e.g. a weathered plaque only history can
## read. Purely static data (who could read it, where it is); it has no
## visible effect until DiscoveryService actually marks the discovery found
## (see _find_reading_opportunity_for), so registering early -- at world
## spawn, before the player has ever seen the marker -- is harmless.
func register_reading_opportunity(discovery_id: StringName, resident_specialty: StringName, world_position: Vector3) -> void:
	_reading_opportunities[discovery_id] = {"specialty":resident_specialty, "position":world_position}

## Every unresolved discovery the player could bring up in conversation --
## field-bound ones like the plaque included, since the player has no way to
## know in advance which resident (if any) can actually help; that's part of
## asking around. Offered as an explicit list (see RebootUIShell.show_ask_about)
## rather than a resident automatically volunteering, so nothing gets
## resolved without the player choosing to bring it up.
func _conversation_topics() -> Array[Dictionary]:
	var discovery := get_node("/root/DiscoveryService")
	var result: Array[Dictionary] = []
	for discovery_id: StringName in discovery.pending_investigations():
		result.append({"discovery_id":discovery_id, "label":discovery.unidentified_name(discovery_id)})
	return result

## Called once the player has picked a specific topic from that list.
## Specialty match decides everything from here: a field-bound discovery gets
## offered as an errand, a portable one resolves immediately, and a mismatch
## still names what the resident does know instead of a flat "no."
func resolve_conversation_topic(resident: ResidentAgent, discovery_id: StringName) -> void:
	_pending_ask_resident = null
	var discovery := get_node("/root/DiscoveryService")
	var specialty := StringName(str(resident.definition.get("specialty", "")))
	var needed_specialty := StringName(str(discovery.definition(discovery_id).get("resident_specialty", "")))
	if needed_specialty != specialty:
		_open_dialogue(resident, "Sorry! I don't know about %s. I mostly know about %s." % [discovery.unidentified_name(discovery_id), specialty])
		return
	if _reading_opportunities.has(discovery_id):
		if not _errand_session.is_empty():
			_open_dialogue(resident, "Someone's already out looking into something else -- ask me again once they're back.")
			return
		_pending_errand_discovery = discovery_id
		_open_dialogue(resident, "Let me take a look at that for you.")
		return
	var result: Dictionary = discovery.investigate(discovery_id, specialty)
	if result.is_empty():
		_open_dialogue(resident, resident.conversation_text())
		return
	_open_dialogue(resident, "About that %s you found -- %s" % [discovery.unidentified_name(discovery_id), str(result.get("interpretation", ""))])

## The player chose not to bring anything up this time -- falls back to the
## resident's normal conversation rather than leaving them nothing to say.
func decline_conversation_topics(resident: ResidentAgent) -> void:
	_pending_ask_resident = null
	if resident == null or not resident.is_inside_tree(): return
	_open_dialogue(resident, resident.conversation_text())

func _begin_reading_errand(resident: ResidentAgent, discovery_id: StringName) -> void:
	var opportunity: Dictionary = _reading_opportunities.get(discovery_id, {})
	if opportunity.is_empty(): return
	_reading_opportunities.erase(discovery_id)
	resident.begin_reading_errand(opportunity.position, "Reads the weathered marker")
	_errand_session = {"resident_id":String(resident.resident_id), "discovery_id":String(discovery_id), "phase":"traveling", "remaining_seconds":2.5}

func _process_errand(delta: float) -> void:
	if _errand_session.is_empty(): return
	var agent := get_agent(StringName(str(_errand_session.resident_id)))
	if agent == null:
		_errand_session.clear()
		return
	if str(_errand_session.phase) == "traveling" and agent.is_errand_ready():
		_errand_session.phase = "reading"
	elif str(_errand_session.phase) == "reading":
		_errand_session.remaining_seconds = maxf(float(_errand_session.remaining_seconds) - delta, 0.0)
		if is_zero_approx(float(_errand_session.remaining_seconds)):
			var discovery_id := StringName(str(_errand_session.discovery_id))
			var specialty := StringName(str(agent.definition.get("specialty", "")))
			agent.finish_reading_errand()
			_errand_session.clear()
			# No dialogue here on purpose: unlike resolve_conversation_topic()
			# above, the player isn't mid-conversation when this fires -- it
			# completes off-screen, possibly while they're elsewhere entirely.
			# investigate() below already queues the Almanac's own delayed
			# notification (AlmanacNotificationService), so the translation
			# surfaces there instead of interrupting with a popup.
			get_node("/root/DiscoveryService").investigate(discovery_id, specialty)

func cancel_errand() -> void:
	if _errand_session.is_empty(): return
	var agent := get_agent(StringName(str(_errand_session.resident_id)))
	if agent != null and agent.is_inside_tree(): agent.finish_reading_errand()
	_errand_session.clear()

func cancel_project_contribution(resume_routine: bool = true) -> void:
	if _project_session.is_empty(): return
	var agent := get_agent(StringName(str(_project_session.resident_id)))
	if resume_routine and agent != null and agent.is_inside_tree(): agent.finish_project_contribution()
	_project_session.clear()

func on_community_project_completed(project_id: StringName) -> void:
	if project_id != RESTORE_GARDEN_PRIORITY: return
	for agent: ResidentAgent in get_agents(): agent.unlock_garden_routine()
	project_coordination_comment.emit("The restored beds are ready for ordinary village flowers. Something rarer still waits beyond today's work.")

func request_board() -> void:
	board_requested.emit()

func priority_display_name() -> String:
	return "Restore the abandoned garden" if current_priority == RESTORE_GARDEN_PRIORITY else "No priority proposed"

func record_discovery_context(display_name: String) -> void:
	if not display_name.is_empty() and display_name not in recent_discoveries:
		recent_discoveries.append(display_name)
	while recent_discoveries.size() > 3:
		recent_discoveries.pop_front()

func residents_near(position: Vector3, radius: float) -> Array[StringName]:
	var result: Array[StringName] = []
	for agent: ResidentAgent in get_agents():
		if agent.global_position.distance_to(position) <= radius: result.append(agent.resident_id)
	return result

func react_to_resonance(tier: int, activation: bool, witnessed: Array[StringName]) -> void:
	var text := "The old stones answer with a steady echo. The arrangement feels close." if tier == 2 else "The old tree pulses softly. The arrangement is waiting for the right morning."
	if activation: text = "Rain and sunrise move through the stones — The First Bloom has awakened."
	for resident_id: StringName in witnessed:
		var agent := get_agent(resident_id)
		if agent != null: agent.begin_resonance_reaction(tier, activation)
	resonance_reaction.emit(text, witnessed)
	project_coordination_comment.emit(text)
	_resume_resonance_reactions_later(witnessed)

func _resume_resonance_reactions_later(witnessed: Array[StringName]) -> void:
	await get_tree().create_timer(2.0).timeout
	for resident_id: StringName in witnessed:
		var agent := get_agent(resident_id)
		if agent != null and agent.activity_id() in [&"resonance_reaction", &"first_bloom_reaction"]: agent.set_period(agent.current_period)

func apply_first_bloom_aspiration() -> void:
	var mara := get_agent(&"resident_mara")
	if mara != null: mara.aspiration_step = maxi(mara.aspiration_step, 1)

func react_to_machine_state(machine_state: StringName) -> void:
	var pip := get_agent(&"resident_pip")
	if pip == null: return
	if machine_state == &"maintenance":
		pip.begin_machine_activity(&"maintain_irrigation", "Maintains the communal irrigation gear", Vector3(16.0, 0.2, 1.1), &"maintain")
	elif machine_state == &"operating":
		pip.begin_machine_activity(&"operate_irrigation", "Guides flowers through the dye assembly", Vector3(16.0, 0.2, 1.1), &"operate")
	elif machine_state in [&"installed_idle", &"resonant"] and pip.current_period in [&"morning", &"afternoon"]:
		pip.begin_machine_activity(&"inspect_irrigation", "Checks the village irrigation assembly", Vector3(16.0, 0.2, 1.1), &"inspect")
	_emit_locator()

func begin_celebration_contribution(resident_id: StringName, contribution_id: StringName, label: String, target: Vector3, action: StringName) -> bool:
	var agent := get_agent(resident_id)
	if agent == null: return false
	agent.begin_event_activity(contribution_id, label, target, action)
	_emit_locator()
	return true

func celebration_contribution_ready(resident_id: StringName) -> bool:
	var agent := get_agent(resident_id)
	return agent != null and agent.is_event_ready()

func finish_celebration_contribution(resident_id: StringName) -> void:
	var agent := get_agent(resident_id)
	if agent != null: agent.finish_event_activity()
	_emit_locator()

func release_celebration_residents() -> void:
	for agent: ResidentAgent in get_agents():
		if bool(agent.current_activity.get("event", false)): agent.finish_event_activity()
	_emit_locator()

func find_social_session(activity_id: StringName, place_id: StringName) -> StringName:
	for session_id: StringName in _social_sessions:
		var session: Dictionary = _social_sessions[session_id]
		if str(session.get("activity_id", "")) == String(activity_id) and str(session.get("place_id", "")) == String(place_id): return session_id
	return &""

func get_agent(resident_id: StringName) -> ResidentAgent:
	return _agents.get(resident_id) as ResidentAgent

func get_agents() -> Array[ResidentAgent]:
	var result: Array[ResidentAgent] = []
	for agent: ResidentAgent in _agents.values():
		result.append(agent)
	return result

func social_activity_candidates(agent: ResidentAgent) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var relationship_service := get_node("/root/RelationshipService")
	for activity_id: StringName in relationship_service.enabled_social_activities():
		var places: Array[SocialPlace] = relationship_service.social_places_for(activity_id)
		if places.is_empty():
			continue
		var best_partner: ResidentAgent
		var best_relationship: float = -INF
		for other: ResidentAgent in get_agents():
			if other == agent or other.is_away():
				continue
			var relationship_weight: float = float(relationship_service.bond(agent.resident_id, other.resident_id)) + float(relationship_service.compatibility_score(agent.resident_id, other.resident_id))
			if relationship_weight > best_relationship:
				best_relationship = relationship_weight
				best_partner = other
		if best_partner != null:
			candidates.append({"id":activity_id, "place_id":places[0].place_id, "partner_ids":[best_partner.resident_id], "relationship_weight":best_relationship})
	return candidates

func plan_social_activity(activity_id: StringName, participant_ids: Array[StringName], place_id: StringName, duration_seconds: float = 6.0) -> StringName:
	var relationship_service := get_node("/root/RelationshipService")
	if not relationship_service.is_social_activity_enabled(activity_id) or participant_ids.size() < 2:
		return &""
	var place: SocialPlace = relationship_service.get_social_place(place_id)
	if place == null or not place.supports_activity(activity_id) or not place.reserve_group(participant_ids):
		return &""
	for resident_id: StringName in participant_ids:
		if get_agent(resident_id) == null:
			place.release_group(participant_ids)
			return &""
	var session_id := StringName("social_%d" % _next_social_session_index)
	_next_social_session_index += 1
	var label := _social_activity_label(activity_id)
	var session := {"session_id":String(session_id), "activity_id":String(activity_id), "place_id":String(place_id), "participant_ids":_string_names(participant_ids), "phase":"traveling", "remaining_seconds":maxf(duration_seconds, 0.1)}
	_social_sessions[session_id] = session
	for resident_id: StringName in participant_ids:
		var partners: Array[StringName] = participant_ids.duplicate()
		partners.erase(resident_id)
		get_agent(resident_id).begin_social_activity(session_id, activity_id, label, place.display_name, place.slot_position_for(resident_id), partners)
	get_node("/root/EventBus").social_activity_changed.emit(activity_id, true)
	social_activity_started.emit(session.duplicate(true))
	return session_id

func complete_social_activity(session_id: StringName) -> bool:
	if not _social_sessions.has(session_id):
		return false
	var session: Dictionary = _social_sessions[session_id]
	var participant_ids := _string_name_array(session.participant_ids)
	var activity_id := StringName(str(session.activity_id))
	var place: SocialPlace = get_node("/root/RelationshipService").get_social_place(StringName(str(session.place_id)))
	if place != null:
		place.release_group(participant_ids)
	for resident_id: StringName in participant_ids:
		var agent := get_agent(resident_id)
		if agent != null:
			agent.finish_social_activity()
	for left_index in range(participant_ids.size()):
		for right_index in range(left_index + 1, participant_ids.size()):
			var left := participant_ids[left_index]
			var right := participant_ids[right_index]
			var description := "%s and %s %s." % [get_agent(left).display_name(), get_agent(right).display_name(), _social_memory_phrase(activity_id)]
			get_node("/root/RelationshipService").record_moment(left, right, activity_id, description, "%s:%s" % [session.place_id, _current_day()])
			get_node("/root/EventBus").relationship_moment.emit(left, right, activity_id)
	_social_sessions.erase(session_id)
	get_node("/root/EventBus").social_activity_changed.emit(activity_id, false)
	social_activity_completed.emit(session.duplicate(true))
	_emit_locator()
	return true

func cancel_social_activity(session_id: StringName, resume_routines: bool = true) -> bool:
	if not _social_sessions.has(session_id):
		return false
	var session: Dictionary = _social_sessions[session_id]
	var participant_ids := _string_name_array(session.participant_ids)
	var place: SocialPlace = get_node("/root/RelationshipService").get_social_place(StringName(str(session.place_id)))
	if place != null:
		place.release_group(participant_ids)
	for resident_id: StringName in participant_ids:
		var agent := get_agent(resident_id)
		if resume_routines and agent != null and agent.is_inside_tree():
			agent.finish_social_activity()
	_social_sessions.erase(session_id)
	return true

func cancel_all_social_activities(resume_routines: bool = true) -> void:
	for session_id: StringName in _social_sessions.keys():
		cancel_social_activity(session_id, resume_routines)

func set_debug_visualization(enabled: bool) -> void:
	for agent: ResidentAgent in get_agents():
		agent.show_debug_scores = enabled
		agent.debug_label.visible = enabled

func locator_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for agent: ResidentAgent in get_agents():
		entries.append({"resident_id":agent.resident_id, "display_name":agent.display_name(), "location":agent.location_name(), "activity":str(agent.current_activity.get("label", "Taking a quiet pause")), "state":agent.state_name()})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.display_name) < str(b.display_name))
	return entries

func serialize_state() -> Dictionary:
	var resident_states: Dictionary = {}
	for resident_id: StringName in _agents:
		resident_states[String(resident_id)] = (_agents[resident_id] as ResidentAgent).serialize_state()
	return {"current_priority":String(current_priority), "recent_discoveries":recent_discoveries.duplicate(), "residents":resident_states, "social_sessions":_social_sessions.values()}

func restore_state(data: Dictionary) -> void:
	_pending_state = data.duplicate(true)
	current_priority = StringName(str(data.get("current_priority", "")))
	recent_discoveries.assign(_string_array(data.get("recent_discoveries", [])))
	if _world_root != null:
		_spawn_residents()

func close_dialogue() -> void:
	if _active_dialogue_resident == null:
		return
	var resident_id := _active_dialogue_resident.resident_id
	var resident := _active_dialogue_resident
	_active_dialogue_resident.end_talking()
	_active_dialogue_resident = null
	get_node("/root/CalendarService").pop_modal_pause()
	dialogue_closed.emit(resident_id)
	# Deferred until after end_talking()/pop_modal_pause() so the errand's
	# own travel isn't fighting the dialogue's pause or routine reselection.
	if not _pending_errand_discovery.is_empty():
		var discovery_id := _pending_errand_discovery
		_pending_errand_discovery = &""
		_begin_reading_errand(resident, discovery_id)

func _open_dialogue(resident: ResidentAgent, text: String) -> void:
	_active_dialogue_resident = resident
	resident.begin_talking()
	get_node("/root/CalendarService").push_modal_pause()
	dialogue_requested.emit(resident, text)

func _on_conversation_requested(resident: ResidentAgent) -> void:
	if _active_dialogue_resident != null or _pending_ask_resident != null:
		return
	var busy_on_errand := not _errand_session.is_empty() and StringName(str(_errand_session.resident_id)) == resident.resident_id
	if busy_on_errand:
		_open_dialogue(resident, "One moment -- I'm still looking that over.")
		return
	# A first meeting is just that -- introductions, nothing else -- even if
	# something's already pending that they could help with. Everything below
	# only becomes available starting the next time you talk to them.
	if get_node("/root/UserExperienceService").introduce_anchor(StringName("met_%s" % resident.resident_id)):
		_open_dialogue(resident, resident.introduction_text())
		return
	var topics := _conversation_topics()
	if not topics.is_empty():
		_pending_ask_resident = resident
		resident.begin_talking()
		var shell := get_tree().get_first_node_in_group("reboot_ui_shell")
		if shell != null: shell.show_ask_about(resident, topics)
		return
	_open_dialogue(resident, resident.conversation_text())

func _on_period_changed(period_id: StringName) -> void:
	if _active_dialogue_resident != null:
		close_dialogue()
	if _pending_ask_resident != null:
		_pending_ask_resident = null
		var shell := get_tree().get_first_node_in_group("reboot_ui_shell")
		if shell != null: shell.close_all()
	cancel_all_social_activities()
	cancel_project_contribution()
	cancel_errand()
	for agent: ResidentAgent in get_agents():
		if agent.is_away(): continue
		agent.set_period(period_id)
	if period_id == &"evening":
		call_deferred("_schedule_evening_social")
	_emit_locator()

func _on_forecast_changed(_forecast: Array[String]) -> void:
	# Weather preference is part of scoring, so a changed day may alter the
	# resident's choice without adding a separate hidden need system.
	for agent: ResidentAgent in get_agents():
		if agent.is_away(): continue
		agent.set_period(agent.current_period)

func _on_agent_activity_changed(_resident_id: StringName, _activity_id: StringName, _state: StringName) -> void:
	_emit_locator()

func _emit_locator() -> void:
	locator_changed.emit(locator_entries())

func _schedule_evening_social() -> void:
	if not _social_sessions.is_empty():
		return
	var agents: Array[ResidentAgent] = []
	for agent: ResidentAgent in get_agents():
		if not agent.is_away():
			agents.append(agent)
	if agents.size() < 2:
		return
	var relationship_service := get_node("/root/RelationshipService")
	var best_pair: Array[StringName] = []
	var best_score: float = -INF
	for left_index in range(agents.size()):
		for right_index in range(left_index + 1, agents.size()):
			var left: ResidentAgent = agents[left_index]
			var right: ResidentAgent = agents[right_index]
			var score: float = float(relationship_service.bond(left.resident_id, right.resident_id)) + float(relationship_service.compatibility_score(left.resident_id, right.resident_id))
			if score > best_score:
				best_score = score
				best_pair = [left.resident_id, right.resident_id]
	if not best_pair.is_empty():
		plan_social_activity(&"conversation", best_pair, &"old_tree")

func _on_social_activity_enabled(_activity_id: StringName) -> void:
	_emit_locator()

func _restore_social_sessions(saved_sessions: Variant) -> void:
	if not saved_sessions is Array:
		return
	for saved_value: Variant in saved_sessions:
		if not saved_value is Dictionary:
			continue
		var saved: Dictionary = saved_value
		var duration := float(saved.get("remaining_seconds", 6.0))
		plan_social_activity(StringName(str(saved.get("activity_id", ""))), _string_name_array(saved.get("participant_ids", [])), StringName(str(saved.get("place_id", ""))), duration)

func _social_activity_label(activity_id: StringName) -> String:
	match activity_id:
		&"shared_meal": return "Shares a peaceful meal"
		&"collaboration": return "Works side by side"
		&"visit": return "Visits a neighbor"
		&"celebration": return "Celebrates together"
		&"garden_gathering": return "Gathers among the flowers"
		_: return "Chats with a friend"

func _social_memory_phrase(activity_id: StringName) -> String:
	match activity_id:
		&"shared_meal": return "shared a quiet meal"
		&"collaboration": return "found an easy rhythm working together"
		&"visit": return "made time for a neighborly visit"
		&"celebration": return "celebrated a village moment"
		&"garden_gathering": return "enjoyed the garden together"
		_: return "lost track of time in conversation"

func _project_comment(phase_id: StringName, resident_name: String) -> String:
	match phase_id:
		&"clear_debris": return "%s: The old paths are visible again. Let's repair what the roots can still use." % resident_name
		&"repair_beds": return "%s: The frames are sturdy. The water route comes next." % resident_name
		&"restore_irrigation": return "%s: Water can reach every bed now. Common seeds will prove the soil." % resident_name
		&"plant": return "%s: These familiar flowers belong here. The unusual colors are still only a hope." % resident_name
		_: return "%s: We did this together. The garden can be part of our days again." % resident_name

func _string_names(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result

func _string_name_array(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		for value: Variant in values:
			result.append(StringName(str(value)))
	return result

func _current_day() -> int:
	return int(get_node("/root/CalendarService").current_day)

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			if entry is String:
				result.append(entry)
	return result

func serialize_legacy_roster() -> Array:
	return legacy_animal_manager.serialize_roster() if legacy_animal_manager != null else []

func restore_legacy_roster(data: Array) -> void:
	if legacy_animal_manager != null:
		legacy_animal_manager.restore_roster(data)

func legacy_recruited_count(species_id: String) -> int:
	return legacy_animal_manager.recruited_count(species_id) if legacy_animal_manager != null else 0
