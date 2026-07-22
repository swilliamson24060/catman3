extends SceneTree

const HUD_SCENE: PackedScene = preload("res://scenes/ui/phase1_hud.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var audio: Node = root.get_node("AudioService")
	var original_enabled := bool(audio.call("is_music_enabled"))
	var diagnostics: Dictionary = audio.call("get_pool_diagnostics")
	assert(bool(diagnostics.music_loaded), "Highland Moonlight must load as the background music stream")

	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	var button := hud.get_node("MarginContainer/PanelContainer/MarginContainer/HBoxContainer/Resources/MusicToggle") as Button
	assert(button.text == ("Music: On" if original_enabled else "Music: Off"), "The HUD button must reflect the saved music preference")

	button.pressed.emit()
	assert(bool(audio.call("is_music_enabled")) != original_enabled, "The HUD button must toggle background music")
	assert(button.text == ("Music: Off" if original_enabled else "Music: On"), "The HUD button must immediately show the new state")
	audio.call("set_music_enabled", original_enabled)

	print("MUSIC_CONTROL_SMOKE_TEST_PASS")
	quit(0)
