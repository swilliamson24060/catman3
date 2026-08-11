extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

var _failure := ""
var _work_actions: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("feature/reboot_mode", true)
	root.get_node("RelationshipService").reset()
	root.get_node("CommunityProjectService").reset()
	root.get_node("ResidentManager").new_game()
	var completed_buildings := Node3D.new()
	completed_buildings.add_to_group("completed_building_container")
	root.add_child(completed_buildings)
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var manager := root.get_node("ResidentManager")
	var service := root.get_node("CommunityProjectService")
	var project := world.get_node("Projects/RestoreGarden")
	# This test exercises material/contribution mechanics, not the first-visit
	# intro dialog (covered separately by anchor_intro_smoke_test.gd) -- mark
	# the garden's anchor already-seen so interact() below fires immediately.
	# Same reasoning for the first-ever-pickup guidance dialog material_source.gd
	# shows (covered separately once a dedicated test exists): pre-consume it so
	# gathering below doesn't open a modal this test never closes, which would
	# leave CalendarService's pause counter elevated and freeze resident travel.
	root.get_node("UserExperienceService").introduce_anchor(project.interaction_anchor.anchor_id)
	root.get_node("UserExperienceService").introduce_anchor(&"gather_material")
	manager.project_contribution_started.connect(func(session: Dictionary) -> void: _work_actions[str(session.work_action)] = true)
	_check(project.phase_presentations.get_child_count() == 5, "garden must expose five replacement-safe phase presentations")
	_check(project.contribution_slots.get_child_count() >= 2, "garden must expose player and resident contribution slots")
	_check(manager.propose_priority(&"project_restore_garden"), "board proposal should start the garden project")
	_check(service.active and service.current_phase_id() == &"clear_debris", "project should begin at clear debris")

	for expected_phase in range(5):
		_check(service.phase_index == expected_phase, "unexpected garden phase before contribution")
		var restored: Dictionary = service.serialize_state()
		service.restore_state(restored)
		_check(project.phase_presentations.get_child(expected_phase).visible, "phase visual did not restore for phase %d" % expected_phase)
		await _supply_current_materials(world, service, project)
		project.interaction_anchor.interact(world.get_node("RebootFounderCat"))
		_check(&"founder" in service.phase_contributors, "founder interaction must contribute direct work")
		await _complete_resident_work(manager, service)
		if not _failure.is_empty(): break

	_check(service.completed, "garden should complete through ordinary anchors and resident work")
	_check(service.player_participated and service.resident_participated, "completion must prove founder and resident participation")
	_check(_work_actions.size() >= 3, "residents must visibly use at least three contribution actions")
	for agent: ResidentAgent in manager.get_agents():
		_check(agent.garden_routine_unlocked, "completion should add ordinary garden routines")
	_check(not root.get_node("RelationshipService").is_social_activity_enabled(&"garden_gathering"), "First Bloom garden gathering must remain locked")

	var save_path := "user://milestone5_garden_test.json"
	_check(root.get_node("SaveService").save_game(save_path), "garden save should succeed")
	service.reset()
	_check(root.get_node("SaveService").load_game(save_path), "garden load should succeed")
	_check(service.completed and project.phase_presentations.get_child(4).visible, "completed garden visual should restore")
	_cleanup_save(save_path)
	world.queue_free()
	completed_buildings.queue_free()
	await process_frame
	if _failure.is_empty():
		print("MILESTONE_5_COMMUNITY_GARDEN_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _supply_current_materials(world: Node, service: Node, project: Node) -> void:
	var needs: Dictionary = service.current_phase().get("material_needs", {})
	for material_value: Variant in needs:
		var material_id := StringName(str(material_value))
		var source := _source_for(world, material_id)
		for count in range(int(needs[material_value])):
			var before := int(service.source_remaining.get(material_id, 0))
			source._anchor.interact(world.get_node("RebootFounderCat"))
			_check(service.carried_material == material_id, "source interaction should place one material in founder carry socket")
			var mid_state: Dictionary = service.serialize_state()
			service.restore_state(mid_state)
			_check(int(service.source_remaining.get(material_id, 0)) == before - 1, "save restore must not duplicate gathered material")
			project.interaction_anchor.interact(world.get_node("RebootFounderCat"))
			_check(service.carried_material.is_empty(), "project delivery should empty founder carry socket")
			project.interaction_anchor.interact(world.get_node("RebootFounderCat"))
			_check(int(service.deposited_materials.get(material_id, 0)) == count + 1, "repeat project interaction must not double-deposit material")
	await process_frame

func _complete_resident_work(manager: Node, service: Node) -> void:
	for attempt in range(240):
		for agent: ResidentAgent in manager.get_agents():
			if agent.current_state == ResidentAgent.State.CONTRIBUTION_TRAVEL:
				agent.global_position = agent.activity_position()
				agent._physics_process(0.016)
		manager._process(0.1)
		await process_frame
		if service.completed or service.phase_contributors.is_empty() or service.phase_index > 0 and &"founder" not in service.phase_contributors:
			return
		if service.phase_contributors.size() >= 2:
			return
	_check(false, "resident contribution did not travel, perform, and exit")

func _source_for(world: Node, material_id: StringName) -> Node:
	match material_id:
		&"reclaimed_wood": return world.get_node("Projects/MaterialSources/ReclaimedWood")
		&"smooth_stone": return world.get_node("Projects/MaterialSources/SmoothStone")
		_: return world.get_node("Projects/MaterialSources/CommonSeeds")

func _cleanup_save(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var absolute := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
