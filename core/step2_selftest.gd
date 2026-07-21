extends Node
## Temporary smoke test for Step 2 (Founder Cat Selection). This harness
## can't drive real mouse clicks, so it simulates choosing "turbo" directly
## and verifies the resulting stats/HUD/pause state end to end. Safe to
## delete once verified in the editor with real input.

func _ready() -> void:
	await get_tree().process_frame
	print("--- Step 2 self-test ---")

	var founder_select := get_tree().root.find_child("FounderSelectUI", true, false)
	print("founder select UI present: ", founder_select != null)
	print("tree paused at start: ", get_tree().paused)

	if founder_select:
		founder_select._on_founder_selected("turbo")

	print("tree paused after selection: ", get_tree().paused)
	print("save_service founder_cat_id: ", SaveService.current.founder_cat_id)

	var harvest := StatsService.get_effective("global_player", "resource_harvest", 1.0)
	var move_speed := StatsService.get_effective("global_player", "movement_speed", 1.0)
	print("turbo resource harvest effective (expect ~1.30): ", harvest)
	print("turbo movement speed effective (expect ~1.25): ", move_speed)

	var hud := get_tree().root.find_child("HUD", true, false)
	if hud:
		print("HUD label text: ", hud.label.text)

	print("--- Step 2 self-test complete ---")
