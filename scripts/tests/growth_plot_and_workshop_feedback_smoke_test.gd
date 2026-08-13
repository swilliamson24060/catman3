extends SceneTree
## Regression guard for two real, reported bugs, both the same "anchor fires
## but nothing tells the player" shape already fixed once for abandoned_garden
## (see garden_and_plinth_feedback_smoke_test.gd):
## 1) The growth_plot anchor's _on_anchor_activated branch only ever mutated
##    GrowthPlotService state (check_growth()/plant_seed()) -- every visit
##    past the first (which at least gets intro_title/intro_body) looked
##    like interacting did nothing.
## 2) workshop_edge had an intro_title/intro_body for its first-ever visit
##    but no branch at all in _on_anchor_activated, so every later visit was
##    a total no-op -- and it sits close enough to the irrigation machine's
##    own anchor (~2.9m, under the ~4.8m separation every other anchor
##    keeps) that a player aiming for the machine and landing on this one
##    instead would see nothing happen, reading as the machine being broken.
##    Also confirms the irrigation machine anchor itself now has a
##    first-visit intro (it previously had none at all).

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const GROWTH_CAP_SECONDS := 60.0 * 60.0 * 24.0 * 3.0

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

	root.get_node("GrowthPlotService").new_game()
	var shell := world.get_tree().get_first_node_in_group("reboot_ui_shell")
	_check(shell != null, "RebootUIShell must be present")
	_clear_toast(shell)

	# --- Growth plot: first-ever visit shows the one-time modal, not a toast. ---
	var growth_anchor: InteractionAnchor = world.get_node("AuthoredInteractionAnchors/GrowthPlotAnchor")
	var growth: Node = root.get_node("GrowthPlotService")
	growth_anchor.interact(null)
	await process_frame
	_check(shell.intro_panel.visible, "the first-ever growth plot visit must show the intro modal")
	shell._on_intro_continue()
	await process_frame
	_check(bool(growth.is_growing()), "the intro dismissal fires _fire(), which should have planted a first seed")

	# --- Repeat visit while still growing: must report progress, not go silent. ---
	_clear_toast(shell)
	growth_anchor.interact(null)
	await process_frame
	_check(shell._event_toast_panel.visible and not shell.event_toast.text.is_empty(), "a repeat growth-plot visit while still growing must show feedback, not fire silently")
	_check(shell.event_toast.text.contains("%"), "the repeat-visit toast should report growth progress")
	_clear_toast(shell)

	# --- Backdate past the cap, then visit again: must announce completion and that a new seed was sown. ---
	var timer: AwayTimer = growth._timer
	timer.started_at = Time.get_unix_time_from_system() - (GROWTH_CAP_SECONDS * 2.0)
	growth_anchor.interact(null)
	await process_frame
	_check(shell.event_toast.text.contains("fully grown"), "finishing growth on a visit must be announced, not silently replanted")
	_check(bool(growth.is_growing()), "a finished plot should be replanted automatically, as before")
	_clear_toast(shell)

	# --- workshop_edge: repeat visit must give feedback, not go silent. ---
	var workshop_anchor: InteractionAnchor = world.get_node("AuthoredInteractionAnchors/WorkshopEdgeAnchor")
	root.get_node("UserExperienceService").introduce_anchor(&"workshop_edge")  # simulate having already seen the one-time intro
	workshop_anchor.interact(null)
	await process_frame
	_check(shell._event_toast_panel.visible and not shell.event_toast.text.is_empty(), "a repeat workshop_edge visit must show feedback, not fire silently")
	_clear_toast(shell)

	# --- Irrigation machine: must now have a first-visit intro (it had none before). ---
	var machine_anchor: InteractionAnchor = world.get_node("WorkshopMachineSlot/GardenIrrigationAssembly/InteractionAnchor")
	_check(not machine_anchor.intro_title.is_empty(), "the irrigation machine anchor should now carry first-visit intro content")

	world.queue_free()
	completed_buildings.queue_free()
	await process_frame
	if _failure.is_empty():
		print("GROWTH_PLOT_AND_WORKSHOP_FEEDBACK_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _clear_toast(shell: Node) -> void:
	shell._event_toast_panel.visible = false
	shell._event_toast_queue.clear()

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
