extends SceneTree

const MOUSE_SCENE: PackedScene = preload("res://scenes/mice/wild_mouse.tscn")
const PICNIC_SCENE: PackedScene = preload("res://scenes/picnic/picnic.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var game_state := root.get_node("GameState") as Phase1GameState
	var feedback_messages: Array[String] = []
	game_state.feedback_requested.connect(func(message: String) -> void: feedback_messages.append(message))
	game_state.reset()
	assert(game_state.select_founder(&"barnaby"))

	game_state.set_build_menu_open(true)
	assert(not game_state.is_build_menu_open, "Construction must remain locked before two mice are recruited")

	var player := CharacterBody3D.new()
	player.add_to_group("player")
	root.add_child(player)
	var mouse := MOUSE_SCENE.instantiate() as Phase1WildMouse
	root.add_child(mouse)
	var declined_mouse := MOUSE_SCENE.instantiate() as Phase1WildMouse
	root.add_child(declined_mouse)
	var picnic := PICNIC_SCENE.instantiate() as Phase1Picnic
	root.add_child(picnic)
	assert(game_state.register_picnic(picnic))
	await process_frame
	assert(mouse.respond_to_picnic(picnic, mouse.global_position))
	assert(declined_mouse.respond_to_picnic(picnic, declined_mouse.global_position))
	var marker := Marker3D.new()
	picnic.add_child(marker)
	var declined_marker := Marker3D.new()
	picnic.add_child(declined_marker)
	picnic.set("_reservations", {mouse: marker, declined_mouse: declined_marker})
	picnic.set("_event_active", true)
	assert(mouse.try_recruit())
	mouse.close_negotiation()
	assert(game_state.has_picnic(), "The picnic must wait for the undecided attendee")
	assert(declined_mouse.begin_picnic_negotiation(), "An attendee must be selectable through the picker path")
	game_state.close_mouse_dialogue()
	assert(picnic.get_attendee_decision(declined_mouse) == "declined", "Declined attendees must receive an x status")

	assert(game_state.get_recruited_mouse_count() == 1)
	assert(not game_state.is_build_decision_pending(), "One recruit must not create a build decision")
	assert(not game_state.is_build_menu_open, "One recruit must not open the build menu")
	await process_frame
	assert(not game_state.has_picnic(), "A fully decided one-recruit picnic must pack automatically")
	assert(not feedback_messages.is_empty() and feedback_messages[-1].contains("another picnic"), "Below-minimum packing must tell the player to hold another picnic before building")
	assert(not game_state.is_build_decision_pending(), "Packing with one recruit must not lock picnic relocation")
	var preview_container := Node3D.new()
	root.add_child(preview_container)
	current_scene = preview_container
	var placement := PicnicPlacementController.new()
	player.add_child(placement)
	await process_frame
	placement.begin_placement()
	assert(placement.is_placing(), "After packing, the picnic must be placeable near another wild mouse")

	print("BUILD_UNLOCK_PICNIC_SMOKE_TEST_PASS")
	quit(0)
