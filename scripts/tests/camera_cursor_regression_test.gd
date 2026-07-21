extends SceneTree

const FOUNDER_SCENE: PackedScene = preload("res://scenes/player/founder_cat.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/phase1_hud.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var game_state := root.get_node("GameState") as Phase1GameState
	game_state.reset()
	assert(game_state.select_founder(&"barnaby"))

	var player := FOUNDER_SCENE.instantiate()
	root.add_child(player)
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame

	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "The pointer must remain player-controlled by default")
	assert(not bool(player.call("is_camera_adjustment_enabled")), "Camera movement must start locked")
	assert(is_equal_approx(player.get_node("CameraRig/YawPivot/PitchPivot").position.y, 2.6), "Overview camera must be raised")
	assert(is_equal_approx(player.get_node("CameraRig/YawPivot/PitchPivot/SpringArm3D").spring_length, 7.5), "Overview must show more settlement")

	player.call("enable_camera_adjustment")
	assert(bool(player.call("is_camera_adjustment_enabled")), "HUD camera adjustment must explicitly unlock rotation")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Even camera adjustment must keep the pointer visible")
	player.call("return_cursor_control")
	assert(not bool(player.call("is_camera_adjustment_enabled")), "Return Cursor must lock camera motion")

	assert(bool(player.call("toggle_camera_closeup")), "Close-up menu action must enable close view")
	assert(is_equal_approx(player.get_node("CameraRig/YawPivot/PitchPivot/SpringArm3D").spring_length, 4.2), "Close-up must shorten camera distance")
	assert(not bool(player.call("toggle_camera_closeup")), "Second close-up action must restore overview")
	assert(hud.has_node("MarginContainer/PanelContainer/MarginContainer/HBoxContainer/CameraControls/ReturnCursor"), "HUD must expose a Return Cursor menu item")

	print("CAMERA_CURSOR_REGRESSION_TEST_PASS")
	quit(0)
