extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const SAVE_PATH := "/tmp/catmando_milestone3_save.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("feature/reboot_mode", true)
	var completed_buildings := Node3D.new()
	completed_buildings.add_to_group("completed_building_container")
	root.add_child(completed_buildings)
	var scene := CLEARING.instantiate()
	root.add_child(scene)
	await process_frame
	var manager := root.get_node("ResidentManager")
	var calendar := root.get_node("CalendarService")
	var weather := root.get_node("WeatherService")
	var save_service := root.get_node("SaveService")
	assert(root.get_node("DataRegistry").get_all_residents().size() == 3)
	assert(root.get_node("DataRegistry").load_errors.is_empty())

	# Exactly three authored residents spawn from the data registry, not recruitment.
	var agents: Array[ResidentAgent] = manager.get_agents()
	assert(agents.size() == 3)
	var names: Array[String] = []
	for agent: ResidentAgent in agents:
		names.append(agent.display_name())
		assert(agent.has_node("NavigationAgent3D"))
		assert(agent.has_node("InteractionAnchor"))
		assert(agent.has_node("SpeechBubbleAnchor"))
		assert(agent.has_node("CarriedItemSocket"))
		assert(agent.has_node("AnimationPlayer"))
	assert(names.has("Mara") and names.has("Pip") and names.has("Elowen"))

	# A full four-period day gives every resident a reachable authored activity.
	var choices_by_resident: Dictionary = {}
	for period_id: StringName in calendar.PERIOD_IDS:
		calendar.debug_jump_to_period(period_id)
		for agent: ResidentAgent in manager.get_agents():
			var target := agent.activity_position()
			agent.global_position = Vector3(target.x, agent.global_position.y, target.z)
			agent._physics_process(0.016)
			assert(agent.current_state in [ResidentAgent.State.ROUTINE_ACTIVITY, ResidentAgent.State.SLEEPING])
			var resident_choices: Array = choices_by_resident.get(agent.resident_id, [])
			resident_choices.append(String(agent.activity_id()))
			choices_by_resident[agent.resident_id] = resident_choices
	for resident_id: StringName in choices_by_resident:
		assert((choices_by_resident[resident_id] as Array).size() == 4)
	assert(choices_by_resident[&"resident_mara"] != choices_by_resident[&"resident_pip"])
	assert(choices_by_resident[&"resident_pip"] != choices_by_resident[&"resident_elowen"])

	# Scoring is inspectable and includes every Milestone 3 factor plus the
	# relationship seam that Milestone 4 will make non-neutral.
	var mara: ResidentAgent = manager.get_agent(&"resident_mara")
	var score: Dictionary = mara.score_activity(mara.current_activity)
	for factor: String in ["schedule", "specialty", "aspiration", "distance", "weather", "comfort", "priority", "relationship"]:
		assert(score.has(factor))
	manager.set_debug_visualization(true)
	assert(mara.debug_label.visible and not mara.debug_label.text.is_empty())
	manager.set_debug_visualization(false)

	# Priority is proposed rather than commanded, and declines explain why.
	assert(not manager.propose_priority(&"unknown_priority"))
	assert(manager.propose_priority(&"project_restore_garden"))
	calendar.debug_jump_to_period(&"night")
	var declined: Dictionary = mara.request_contribution(&"gardening")
	assert(not declined.accepted and "rest" in str(declined.reason).to_lower())
	calendar.debug_jump_to_period(&"morning")
	var accepted: Dictionary = mara.request_contribution(&"gardening")
	assert(accepted.accepted)

	# Contextual conversation exposes activity, weather/priority, and aspiration.
	weather.force_weather("rain")
	manager.record_discovery_context("a moss-covered garden plaque")
	var conversation := mara.conversation_text()
	assert("rain" in conversation.to_lower())
	assert("restore" in conversation.to_lower())
	assert("plaque" in conversation.to_lower())
	assert("I hope to:" in conversation)

	# Locator access is always available without permanent resident markers.
	var locator: Array[Dictionary] = manager.locator_entries()
	assert(locator.size() == 3)
	for entry: Dictionary in locator:
		assert(not str(entry.location).is_empty())
	assert(scene.has_node("ResidentHUD/ResidentLocator"))
	for agent: ResidentAgent in manager.get_agents():
		assert(not agent.debug_label.visible)

	# Save/load restores priority, home, routine period, aspiration and position.
	calendar.debug_jump_to_period(&"evening")
	mara = manager.get_agent(&"resident_mara")
	mara.aspiration_step = 1
	mara.global_position = Vector3(-5.0, 0.2, 6.0)
	calendar.set_simulation_paused(true)
	var saved_home := str(mara.definition.home_id)
	assert(save_service.save_game(SAVE_PATH))
	mara.aspiration_step = 0
	mara.global_position = Vector3.ZERO
	manager.current_priority = &""
	assert(save_service.load_game(SAVE_PATH))
	await process_frame
	mara = manager.get_agent(&"resident_mara")
	assert(manager.current_priority == &"project_restore_garden")
	assert(str(mara.definition.home_id) == saved_home)
	assert(mara.current_period == &"evening")
	assert(mara.aspiration_step == 1)
	assert(mara.global_position.distance_to(Vector3(-5.0, 0.2, 6.0)) < 0.05)
	calendar.set_simulation_paused(false)

	scene.queue_free()
	completed_buildings.queue_free()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".bak")
	await process_frame
	print("MILESTONE_3_RESIDENT_ROUTINE_SMOKE_TEST_PASS")
	quit(0)
