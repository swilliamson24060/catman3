extends SceneTree
## Regression guard for material pickup guidance (material_source.gd's
## _show_pickup_guidance): the first-ever material pickup must show a
## dismissable modal explaining where to bring it, since gather_material()
## alone changes real state (source_remaining, carried_material) with
## nothing on screen previously explaining what the player should do next.
## Every later pickup should fall back to a lighter, non-blocking reminder
## instead of repeating the modal.

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	# Boot may have loaded a stray save carrying prior introduced_anchors/
	# carried-material state -- reset after boot, not before, matching
	# anchor_intro_smoke_test.gd, so this test's assertions start clean.
	root.get_node("UserExperienceService").reset_story_state()
	root.get_node("CommunityProjectService").reset()

	var shell := world.get_tree().get_first_node_in_group("reboot_ui_shell")
	_check(shell != null, "RebootUIShell must be present in the clearing")
	var service := root.get_node("CommunityProjectService")
	var wood: ProjectMaterialSource = world.get_node("Projects/MaterialSources/ReclaimedWood")
	var stone: ProjectMaterialSource = world.get_node("Projects/MaterialSources/SmoothStone")

	# First-ever pickup: full modal, not a toast that could be missed.
	wood._anchor.interact(null)
	await process_frame
	_check(service.carried_material == &"reclaimed_wood", "interacting with an available source must gather it")
	_check(shell.intro_panel.visible, "the first-ever material pickup must show a dialog explaining where it goes")
	_check(shell.intro_body_label.text.contains("abandoned garden"), "the pickup dialog must say where to bring the material")
	_check(not shell._event_toast_panel.visible, "show_dialog must supersede any toast queued by the same interaction")

	shell._on_intro_continue()
	await process_frame
	_check(not shell.intro_panel.visible, "dismissing the pickup dialog must close it")

	# Return it, then gather a different material: second-ever pickup should
	# use the lighter reminder toast, not repeat the modal.
	wood._anchor.interact(null)
	await process_frame
	_check(service.carried_material.is_empty(), "interacting again while carrying the same material must return it")

	stone._anchor.interact(null)
	await process_frame
	_check(service.carried_material == &"smooth_stone", "gathering a different material must succeed after returning the first")
	_check(not shell.intro_panel.visible, "a second-ever pickup must not repeat the modal")
	_check(shell._event_toast_panel.visible, "a second-ever pickup must still surface a reminder toast")
	_check(shell.event_toast.text.contains("smooth stone") and shell.event_toast.text.contains("abandoned garden"), "the reminder toast must name the material and destination")

	_check(not root.get_node("UserExperienceService").introduce_anchor(&"gather_material"), "the pickup guidance gate must already be consumed after the first pickup")

	world.queue_free()
	await process_frame
	if _failure.is_empty():
		print("MATERIAL_PICKUP_GUIDANCE_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
