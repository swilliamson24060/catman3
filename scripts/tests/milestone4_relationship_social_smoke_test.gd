extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const SAVE_PATH := "/tmp/catmando_milestone4_relationship_save.json"

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
	var relationships := root.get_node("RelationshipService")
	var calendar := root.get_node("CalendarService")
	var save_service := root.get_node("SaveService")
	relationships.reset()

	# Four authored places expose stable props and atomic reservation slots.
	assert(scene.get_node("SocialPlaces").get_child_count() == 4)
	for place_node: Node in scene.get_node("SocialPlaces").get_children():
		var place := place_node as SocialPlace
		assert(place != null and place.capacity >= 2)
		assert(place.get_node("Presentation").get_child_count() > 0)
		assert(place.get_node("Slots").get_child_count() == place.capacity)
	var old_tree: SocialPlace = relationships.get_social_place(&"old_tree")
	assert(old_tree.reserve_group([&"test_a", &"test_b"]))
	assert(not old_tree.reserve_group([&"test_b", &"test_c"]))
	old_tree.release_all()

	# Two residents plan, travel to separate slots, perform, remember, and exit.
	var mara: ResidentAgent = manager.get_agent(&"resident_mara")
	var pip: ResidentAgent = manager.get_agent(&"resident_pip")
	var pair: Array[StringName] = [mara.resident_id, pip.resident_id]
	var starting_bond: int = relationships.bond(mara.resident_id, pip.resident_id)
	var session_id: StringName = manager.plan_social_activity(&"conversation", pair, &"old_tree", 0.2)
	assert(session_id != &"")
	assert(old_tree.reserved_count() == 2)
	for agent: ResidentAgent in [mara, pip]:
		agent.global_position = agent.activity_position()
		agent._physics_process(0.016)
		assert(agent.current_state == ResidentAgent.State.SOCIALIZING)
		assert(agent.activity_bubble.visible)
	manager._process(0.01)
	manager._process(0.25)
	assert(old_tree.reserved_count() == 0)
	assert(mara.social_session_id == &"" and pip.social_session_id == &"")
	assert(relationships.bond(mara.resident_id, pip.resident_id) == starting_bond + 4)
	assert(not relationships.memories_for(mara.resident_id).is_empty())
	assert("conversation" not in str(mara.state_name()))

	# Repeating an identical witnessed moment has diminishing then no reward.
	var first_repeat: int = relationships.record_moment(mara.resident_id, pip.resident_id, &"conversation", "Mara and Pip chatted again.", "old_tree:%d" % calendar.current_day)
	var second_repeat: int = relationships.record_moment(mara.resident_id, pip.resident_id, &"conversation", "Mara and Pip chatted once more.", "old_tree:%d" % calendar.current_day)
	assert(first_repeat == 1)
	assert(second_repeat == 0)

	# Compatibility shades selection without forcing friend/enemy categories.
	var compatibility: float = relationships.compatibility_score(mara.resident_id, pip.resident_id)
	assert(compatibility >= -4.0 and compatibility <= 6.0)
	var candidate := {"position":[0.0,0.2,0.0], "partner_ids":[String(pip.resident_id)]}
	assert(float(mara.score_activity(candidate).relationship) > 0.0)

	# A future Resonance effect enables a social activity immediately, without reload.
	assert(not relationships.is_social_activity_enabled(&"garden_gathering"))
	assert(relationships.enable_social_activity(&"garden_gathering"))
	assert(not relationships.enable_social_activity(&"garden_gathering"))
	var candidates: Array[Dictionary] = manager.social_activity_candidates(mara)
	assert(candidates.any(func(entry: Dictionary) -> bool: return entry.id == &"garden_gathering"))
	var garden_session: StringName = manager.plan_social_activity(&"garden_gathering", pair, &"garden_table", 1.0)
	assert(garden_session != &"")
	manager.cancel_social_activity(garden_session)
	assert(relationships.get_social_place(&"garden_table").reserved_count() == 0)

	# Social feedback is behavioral, textual, and journaled rather than numeric UI.
	var memories_text := mara.conversation_text()
	assert("still smile" in memories_text.to_lower())
	assert(scene.has_node("ResidentHUD/RelationshipToast"))
	var calendar_state: Dictionary = calendar.serialize_state()
	assert(not (calendar_state.summary_events.relationship_moments as Array).is_empty())

	# Bonds, memories, repeat suppression, and enabled activities persist.
	save_service.current.world_seed = 4444
	assert(save_service.save_game(SAVE_PATH))
	var saved_bond: int = relationships.bond(mara.resident_id, pip.resident_id)
	relationships.reset()
	assert(not relationships.is_social_activity_enabled(&"garden_gathering"))
	assert(save_service.load_game(SAVE_PATH))
	await process_frame
	assert(relationships.bond(&"resident_mara", &"resident_pip") == saved_bond)
	assert(relationships.is_social_activity_enabled(&"garden_gathering"))
	assert(not relationships.memories_for(&"resident_mara").is_empty())

	scene.queue_free()
	completed_buildings.queue_free()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".bak")
	await process_frame
	print("MILESTONE_4_RELATIONSHIP_SOCIAL_SMOKE_TEST_PASS")
	quit(0)
