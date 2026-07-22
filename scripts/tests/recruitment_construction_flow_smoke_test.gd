extends SceneTree

const MOUSE_SCENE: PackedScene = preload("res://scenes/mice/wild_mouse.tscn")
const PICNIC_SCENE: PackedScene = preload("res://scenes/picnic/picnic.tscn")
const SITE_SCENE: PackedScene = preload("res://scenes/construction/construction_site.tscn")
const TEST_STRUCTURE: BuildingDefinition = preload("res://resources/buildings/test_structure.tres")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var game_state := root.get_node("GameState") as Phase1GameState
	game_state.reset()
	assert(game_state.select_founder(&"barnaby"))

	var player := Node3D.new()
	player.add_to_group("player")
	root.add_child(player)
	var site_container := Node3D.new()
	site_container.add_to_group("construction_site_container")
	root.add_child(site_container)
	var building_container := Node3D.new()
	building_container.add_to_group("completed_building_container")
	root.add_child(building_container)

	var mouse := MOUSE_SCENE.instantiate() as Phase1WildMouse
	root.add_child(mouse)
	var second_mouse := MOUSE_SCENE.instantiate() as Phase1WildMouse
	root.add_child(second_mouse)
	var picnic := PICNIC_SCENE.instantiate() as Phase1Picnic
	root.add_child(picnic)
	assert(game_state.register_picnic(picnic), "The active recruitment picnic must be registered")
	await process_frame
	assert(mouse.respond_to_picnic(picnic, mouse.global_position), "Mouse must be attending a picnic before recruitment")
	assert(second_mouse.respond_to_picnic(picnic, second_mouse.global_position), "Every picnic attendee must enter the same conversation cycle")
	var reserved_marker := Marker3D.new()
	picnic.add_child(reserved_marker)
	var second_marker := Marker3D.new()
	picnic.add_child(second_marker)
	picnic.set("_reservations", {mouse: reserved_marker, second_mouse: second_marker})
	picnic.set("_event_active", true)
	assert(mouse.try_recruit(), "Mouse must recruit through the real transaction")
	assert(mouse.get_state_name() == "RECRUITED", "A new recruit must wait at an active picnic")
	assert(not game_state.is_build_menu_open, "Recruiting one mouse must not interrupt the picnic with building selection")
	assert(mouse.get_node("RecruitmentBadge").visible, "Recruited mouse needs an in-world badge")
	assert(mouse.get_node("RecruitmentBadge").text.contains(mouse.get_display_name()), "Recruitment badge must identify the mouse")
	mouse.close_negotiation()
	assert(not game_state.is_build_menu_open, "Building selection must wait until every attendee has had a turn")
	assert(mouse.get_state_name() == "RECRUITED", "First recruit must remain patient while another attendee awaits conversation")
	assert(second_mouse.try_recruit(), "The founder must be able to recruit the next picnic attendee")
	second_mouse.close_negotiation()
	assert(not game_state.has_picnic(), "A qualifying completed picnic must pack before building selection")
	assert(not game_state.is_build_menu_open, "The build menu must wait until automatic picnic removal completes")
	await process_frame
	assert(game_state.is_build_menu_open, "The final completed conversation must open building selection")
	assert(game_state.is_build_decision_pending(), "Completed recruitment must lock picnic relocation until construction starts")
	assert(mouse.get_state_name() == "FOLLOW_PLAYER", "Recruit must leave patiently when the picnic ends")
	assert(second_mouse.get_state_name() == "FOLLOW_PLAYER", "Every recruit must leave together after the final conversation")
	var placement_owner := CharacterBody3D.new()
	root.add_child(placement_owner)
	var picnic_placement := PicnicPlacementController.new()
	placement_owner.add_child(picnic_placement)
	await process_frame
	picnic_placement.begin_placement()
	assert(not picnic_placement.is_placing(), "Picnic placement must remain locked while the build decision is pending")

	var site := SITE_SCENE.instantiate() as ConstructionSite
	site_container.add_child(site)
	site.global_position = Vector3(14.0, 0.0, 0.0)
	site.configure(TEST_STRUCTURE)
	game_state.construction_site_placed.emit(site)
	assert(not game_state.is_build_decision_pending(), "Starting the selected construction site must unlock picnic relocation")
	mouse.call("_evaluate_work_opportunities")
	assert(site.get_worker_count() == 1, "A healthy nearby recruit must autonomously claim a placed site")
	assert(site.get_node("WorldStatus").text.contains("0/2 MICE READY"), "Site must show the minimum crew requirement in-world")

	var first_slot := site.get("_reserved_workers")[mouse] as Marker3D
	mouse.global_position = first_slot.global_position
	site.set_worker_active(mouse, true)
	assert(site.reserve_worker(second_mouse) != null, "A second mouse must be able to complete the minimum crew")
	site.set_worker_active(second_mouse, true)
	assert(site.get_node("WorldStatus").text.contains("2 MICE BUILDING"), "A complete crew must begin construction")
	site.call("_on_simulation_advanced", Phase2SimulationClock.NEED_CYCLE_SECONDS * 4.99)
	assert(building_container.get_child_count() == 0, "The minimum crew must not finish before five game turns")
	site.call("_on_simulation_advanced", Phase2SimulationClock.NEED_CYCLE_SECONDS * 0.01)
	await process_frame
	var completed: Array[Node] = building_container.get_children()
	assert(completed.size() == 1, "Autonomous construction must produce the completed building")
	assert(completed[0].has_node("CompletionMarker"), "Completed building must show a world-space notification")
	assert(completed[0].get_node("CompletionMarker").text.contains("COMPLETE"), "Completion notification must be explicit")
	assert(completed[0].has_node("SettlementInfluenceRing"), "An expanding building must show its new settlement boundary")
	var settlement_manager := root.get_node("SettlementManager") as Phase2SettlementManager
	assert(settlement_manager.is_position_inside_settlement(Vector3(20.0, 0.0, 0.0)), "A completed edge building must expand valid placement territory")
	assert(not settlement_manager.is_position_inside_settlement(Vector3(22.0, 0.0, 0.0)), "Expansion must stop at the building's influence radius")

	print("RECRUITMENT_CONSTRUCTION_FLOW_SMOKE_TEST_PASS")
	quit(0)
