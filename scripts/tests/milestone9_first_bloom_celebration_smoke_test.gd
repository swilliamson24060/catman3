extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	await process_frame
	var save := root.get_node("SaveService")
	var celebration := root.get_node("CelebrationService")
	var resonance := root.get_node("SeasonalResonanceService")
	var relationships := root.get_node("RelationshipService")
	var manager := root.get_node("ResidentManager")
	var calendar := root.get_node("CalendarService")
	var path := "user://milestone9_celebration_test.json"
	save.new_game("founder_milestone9")
	var clearing := CLEARING.instantiate()
	root.add_child(clearing)
	var completed_buildings := Node3D.new()
	completed_buildings.add_to_group("completed_building_container")
	root.add_child(completed_buildings)
	await process_frame
	celebration.contribution_duration = 0.05
	_check(celebration.definition.id == "event_first_bloom_celebration", "First Bloom must have one authored celebration definition")
	_check(celebration.state == &"dormant", "celebration must be dormant before activation")
	_check(save.save_game(path) and save.load_game(path), "save/load before preparation must be safe")
	_check(celebration.state == &"dormant", "preparation must not start before First Bloom")
	await process_frame
	await process_frame

	relationships.enable_social_activity(&"garden_gathering")
	resonance.activated = true
	_check(celebration.start_celebration(), "activation must begin celebration preparation")
	_check(celebration.activation_day == calendar.current_day, "activation day must not be hard-coded")
	for resident: ResidentAgent in manager.get_agents(): resident.global_position = Vector3(90.0, 0.2, -90.0)
	await _finish_one_contribution(celebration, manager)
	_check(celebration.completed_contributions.size() == 1, "first resident contribution must become visible")
	_check(save.save_game(path), "save during preparation must succeed")
	celebration.reset()
	_check(save.load_game(path), "load during preparation must succeed")
	celebration.contribution_duration = 0.05
	_check(celebration.state == &"preparing" and celebration.completed_contributions.size() == 1, "preparation checkpoint must resume without duplicating completed work")
	while celebration.state == &"preparing": await _finish_one_contribution(celebration, manager)
	_check(celebration.completed_contributions.size() == 3 and celebration.state == &"awaiting_choice", "all three residents must contribute before the founder choice")
	var event_scene := clearing.get_node("FirstBloomCelebration")
	_check(event_scene.get_node("ContributionProps/FlowerTable").visible and event_scene.get_node("ContributionProps/FestivalLights").visible and event_scene.get_node("ContributionProps/StoryCards").visible, "resident contributions must have distinct visible props")
	_check(celebration.choose_decoration(&"firefly_lanterns"), "player decoration choice must be accepted")
	_check(celebration.state == &"gathering" and celebration.player_choice == &"firefly_lanterns", "choice must affect presentation without gating success")
	_check(event_scene.get_node("PlayerChoices/FireflyLanterns").visible, "chosen decoration must be visible")
	_check(not gathering_failed(celebration.gathering_session_id), "garden gathering must start regardless of prior resident positions")
	manager.complete_social_activity(celebration.gathering_session_id)
	await process_frame
	_check(celebration.state == &"closing", "gathering must lead to the closing conversation")
	while celebration.state == &"closing": celebration.advance_closing_conversation()
	_check(celebration.state == &"complete" and celebration.distant_rumors.size() == 2, "closing must seed distant-pattern rumors and complete the slice")
	_check(calendar.current_day == celebration.completion_day, "completion stays in the current repeatable day instead of ending the save")
	for resident: ResidentAgent in manager.get_agents():
		_check(not bool(resident.current_activity.get("event", false)) and resident.state_name() not in [&"socializing", &"social_travel"], "no resident may remain trapped in an event state")
	_check(save.save_game(path), "save after completion must succeed")
	celebration.reset()
	_check(save.load_game(path), "load after completion must succeed")
	_check(celebration.state == &"complete" and celebration.player_choice == &"firefly_lanterns", "completed celebration and choice must persist")
	calendar.end_day()
	_check(calendar.current_day == celebration.completion_day + 1 and celebration.state == &"complete", "ordinary repeatable days must continue after the narrative slice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path) + ".bak")
	clearing.queue_free()
	completed_buildings.queue_free()
	await process_frame
	await process_frame
	print("MILESTONE_9_FIRST_BLOOM_CELEBRATION_SMOKE_TEST_PASS")
	quit(0)

func _finish_one_contribution(celebration: Node, manager: Node) -> void:
	await process_frame
	var contribution: Dictionary = celebration._active_contribution()
	_check(not contribution.is_empty(), "preparation must select an incomplete resident contribution")
	var resident: ResidentAgent = manager.get_agent(StringName(str(contribution.resident_id)))
	var scene := root.get_node("VillageClearing/FirstBloomCelebration")
	resident.global_position = scene.contribution_slot_position(int(contribution.get("slot", 0)))
	await create_timer(0.12).timeout
	await process_frame

func gathering_failed(session_id: StringName) -> bool: return session_id == &""

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)
