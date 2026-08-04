extends SceneTree

const SAVE_PATH := "user://milestone10_test_save.json"

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var experience := get_root().get_node("UserExperienceService")
	experience.reset_story_state()
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"interact", &"camera_snap_left", &"camera_snap_right", &"ui_menu", &"open_almanac", &"request_hint", &"quick_save", &"quick_load"]:
		_check(experience.action_has_keyboard_and_controller(action), "%s must have keyboard and controller bindings" % action)
	var symbols := {}; var motions := {}
	for tier in range(5):
		var cue: Dictionary = experience.tier_accessible_cue(tier); symbols[cue.symbol] = true; motions[cue.motion] = true
	_check(symbols.size() == 5 and motions.size() == 5, "all Resonance tiers need non-color symbols and motion labels")
	_check(experience.request_next_hint().begins_with("Guidance will unlock"), "hint ladder must remain locked until the initial clue")
	experience.record_lesson(&"resonance_initial_clue")
	var hint_one: String = experience.request_next_hint(); var hint_two: String = experience.request_next_hint(); var hint_three: String = experience.request_next_hint()
	_check("triangle" not in hint_one.to_lower() and "triangle" not in hint_two.to_lower(), "initial hint steps must preserve geometric mystery")
	_check("triangle" in hint_three.to_lower() and "rain lens" not in hint_three.to_lower(), "optional explicit help may reveal geometry but never the exact answer")
	var world: Node = (load("res://scenes/world/village_clearing.tscn") as PackedScene).instantiate(); get_root().add_child(world)
	var completed_buildings := Node3D.new(); completed_buildings.add_to_group("completed_building_container"); get_root().add_child(completed_buildings)
	await process_frame; await process_frame
	var save := get_root().get_node("SaveService")
	save.new_game("founder_calico"); experience.record_lesson(&"resonance_initial_clue"); experience.request_next_hint(); experience.request_next_hint()
	_check(save.save_game(SAVE_PATH), "onboarding and hint state must save")
	experience.reset_story_state()
	_check(save.load_game(SAVE_PATH) and experience.hint_level == 2, "onboarding and hint state must restore")
	var shell := world.get_node("RebootUIShell") as RebootUIShell
	_check(shell != null and shell.top_bar != null, "replacement HUD must instantiate in the active scene")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		get_root().size = size; await process_frame
		_check(shell.top_bar.position.x >= 0.0 and shell.top_bar.size.x <= size.x, "top HUD must remain inside %s" % size)
		shell.open_menu(); await process_frame
		_check(shell.menu_panel.position.x >= 0.0 and shell.menu_panel.position.y >= 0.0, "menu must remain on screen at %s" % size)
		shell.close_all()
	shell.open_screen("Village Almanac"); await process_frame
	_check("Rumors" in shell.content_text.text and "Confirmed Patterns" in shell.content_text.text, "critical discovery information must exist in a persistent Almanac")
	shell.open_screen("Guidance History"); await process_frame
	_check(not shell.content_text.text.is_empty(), "transient guidance must have a persistent history screen")
	shell.close_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH)); DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH) + ".bak")
	world.queue_free(); completed_buildings.queue_free(); await process_frame; await process_frame; await process_frame
	print("MILESTONE_10_UI_ACCESSIBILITY_SMOKE_TEST_PASS"); quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message); quit(1); assert(condition, message)
