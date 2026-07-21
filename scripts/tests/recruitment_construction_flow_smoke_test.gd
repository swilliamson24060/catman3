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
	var picnic := PICNIC_SCENE.instantiate() as Phase1Picnic
	root.add_child(picnic)
	await process_frame
	assert(mouse.respond_to_picnic(picnic, mouse.global_position), "Mouse must be attending a picnic before recruitment")
	var reserved_marker := Marker3D.new()
	picnic.add_child(reserved_marker)
	picnic.set("_reservations", {mouse: reserved_marker})
	picnic.set("_event_active", true)
	assert(mouse.try_recruit(), "Mouse must recruit through the real transaction")
	assert(mouse.get_state_name() == "RECRUITED", "A new recruit must wait at an active picnic")
	assert(game_state.is_build_menu_open, "Recruitment must open the next-step build menu")
	assert(mouse.get_node("RecruitmentBadge").visible, "Recruited mouse needs an in-world badge")
	assert(mouse.get_node("RecruitmentBadge").text.contains(mouse.get_display_name()), "Recruitment badge must identify the mouse")
	picnic.end_picnic_event(false)
	assert(mouse.get_state_name() == "FOLLOW_PLAYER", "Recruit must leave patiently when the picnic ends")

	var site := SITE_SCENE.instantiate() as ConstructionSite
	site_container.add_child(site)
	site.global_position = mouse.global_position
	site.configure(TEST_STRUCTURE)
	game_state.construction_site_placed.emit(site)
	mouse.call("_evaluate_work_opportunities")
	assert(site.get_worker_count() == 1, "A healthy nearby recruit must autonomously claim a placed site")
	assert(site.get_node("WorldStatus").text.contains("1 MICE BUILDING"), "Site must show worker activity in-world")

	site.contribute_work(TEST_STRUCTURE.work_required)
	await process_frame
	var completed: Array[Node] = building_container.get_children()
	assert(completed.size() == 1, "Autonomous construction must produce the completed building")
	assert(completed[0].has_node("CompletionMarker"), "Completed building must show a world-space notification")
	assert(completed[0].get_node("CompletionMarker").text.contains("COMPLETE"), "Completion notification must be explicit")

	print("RECRUITMENT_CONSTRUCTION_FLOW_SMOKE_TEST_PASS")
	quit(0)
