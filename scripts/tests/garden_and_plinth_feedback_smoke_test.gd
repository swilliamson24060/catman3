extends SceneTree
## Regression guard for two real, reported bugs:
## 1) CommunityProjectService.interaction_prompt() used to suggest "Deliver X
##    to the garden" even when the current phase didn't need X (e.g. phase 0
##    "clear_debris" needs no materials at all) -- a player carrying
##    something the phase didn't want was told to do something that would
##    silently no-op.
## 2) SeasonalResonanceService.handle_plinth_interaction() fired the anchor's
##    activated signal but did nothing and said nothing when no interpreted
##    component was available to place.

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var completed_buildings := Node3D.new()
	completed_buildings.add_to_group("completed_building_container")
	root.add_child(completed_buildings)
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	# Boot may have loaded a stray save -- reset after boot, not before, so
	# this test's own assertions start from a clean slate regardless of
	# what's on disk (a save-file load would otherwise clobber an earlier reset).
	root.get_node("CommunityProjectService").reset()
	root.get_node("DiscoveryService").reset()
	root.get_node("SeasonalResonanceService").reset()
	root.get_node("RumorService").reset()
	root.get_node("ResidentManager").new_game()

	var project_service := root.get_node("CommunityProjectService")
	var shell := world.get_tree().get_first_node_in_group("reboot_ui_shell")
	_check(shell != null, "RebootUIShell must be present")
	# A restored save can also replay rumor_acquired for each previously-known
	# rumor, queuing boot-time toasts ahead of this test's own -- start clean.
	_clear_toast(shell)

	# --- Garden prompt correctness ---
	_check(project_service.interaction_prompt() == "Propose this project at the Community Board", "prompt must ask for proposal before the project is active")
	root.get_node("ResidentManager").propose_priority(&"project_restore_garden")
	_check(project_service.active and project_service.current_phase_id() == &"clear_debris", "proposing must start the project at clear_debris")
	project_service.carried_material = &"reclaimed_wood"
	_check(not project_service.interaction_prompt().begins_with("Deliver"), "the prompt must not offer to deliver a material the current phase (clear_debris) doesn't need")
	project_service.carried_material = &""

	# --- Garden delivery toast for a not-needed material ---
	var project := world.get_node("Projects/RestoreGarden")
	root.get_node("UserExperienceService").introduce_anchor(project.interaction_anchor.anchor_id)
	project_service.carried_material = &"reclaimed_wood"
	project.interaction_anchor.interact(null)
	await process_frame
	_check(shell._event_toast_panel.visible and shell.event_toast.text.contains("doesn't need"), "delivering an unneeded material must explain why, not silently do nothing")
	_check(project_service.carried_material == &"reclaimed_wood", "an unneeded material must stay carried, not vanish silently")
	_clear_toast(shell)

	# Move to repair_beds (needs reclaimed_wood) the direct way, then confirm delivery now works and is confirmed on screen.
	project_service.deposited_materials.clear()
	project_service.phase_index = 1
	_check(project_service.interaction_prompt().begins_with("Deliver"), "once the phase needs the carried material, the prompt must say so")
	project.interaction_anchor.interact(null)
	await process_frame
	_check(project_service.carried_material.is_empty(), "delivering a needed material must succeed")
	_check(shell.event_toast.text.begins_with("Delivered"), "a successful delivery must be confirmed on screen")
	_clear_toast(shell)

	# --- Plinth: nothing interpreted yet -> explained, not silent ---
	# Pre-introduce the shared plinth intro (all three plinths share one key)
	# so these checks exercise handle_plinth_interaction()'s own feedback,
	# not the separately-covered first-visit dialog (anchor_intro_smoke_test.gd).
	root.get_node("UserExperienceService").introduce_anchor(&"resonance_plinth")
	var plinth0: ResonancePlinth = world.get_node("FirstBloomResonanceSite/Plinths/WaterPlinth")
	plinth0.interaction_anchor.interact(null)
	await process_frame
	_check(shell._event_toast_panel.visible and not shell.event_toast.text.is_empty(), "an empty plinth with nothing interpreted yet must explain itself, not fire silently")
	_check(root.get_node("SeasonalResonanceService").plinth_components[0].is_empty(), "nothing should place without an interpreted component")
	_clear_toast(shell)

	# --- Plinth: found but not interpreted -> points at the investigation table ---
	root.get_node("DiscoveryService").find(&"component_rain_lens")
	await process_frame
	_clear_toast(shell)  # find() also queues its own "Found: ..." toast (see RebootUIShell._on_discovery_changed) -- isolate the plinth's own feedback
	plinth0.interaction_anchor.interact(null)
	await process_frame
	_check(shell.event_toast.text.contains("investigation table"), "an unidentified find should point the player at the investigation table, not stay silent")
	_clear_toast(shell)

	# --- Plinth: interpreted -> placement succeeds and is confirmed ---
	root.get_node("DiscoveryService").investigate(&"component_rain_lens")
	await process_frame
	_clear_toast(shell)
	plinth0.interaction_anchor.interact(null)
	await process_frame
	_check(root.get_node("SeasonalResonanceService").plinth_components[0] == &"component_rain_lens", "an interpreted component must actually place")
	_check(shell.event_toast.text.begins_with("Placed"), "a successful placement must be confirmed on screen")

	world.queue_free()
	completed_buildings.queue_free()
	await process_frame
	if _failure.is_empty():
		print("GARDEN_AND_PLINTH_FEEDBACK_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _clear_toast(shell: Node) -> void:
	shell._event_toast_panel.visible = false
	shell._event_toast_queue.clear()

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
