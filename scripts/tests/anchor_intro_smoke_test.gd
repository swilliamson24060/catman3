extends SceneTree
## Regression guard for the first-visit anchor introduction system
## (InteractionAnchor.intro_title/intro_body + RebootUIShell.maybe_show_intro):
## the first interact() on an anchor with intro content must show the
## explanation and defer its real action until "Got it" is pressed; every
## later interact() on that same anchor_id must fire immediately, with no
## dialog and no re-deferral.

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

var _failure := ""
var _fire_count := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	# Boot may have loaded a stray save carrying prior introduced_anchors
	# state -- reset after boot, not before, so this test's own assertions
	# start from a clean slate regardless of what's on disk.
	root.get_node("UserExperienceService").reset_story_state()

	var shell := world.get_tree().get_first_node_in_group("reboot_ui_shell")
	_check(shell != null, "RebootUIShell must be present in the clearing")

	var anchor: InteractionAnchor = world.get_node("AuthoredInteractionAnchors/GrowthPlotAnchor")
	_check(not anchor.intro_title.is_empty(), "growth_plot anchor should carry first-visit intro content")
	anchor.activated.connect(func(_id: StringName) -> void: _fire_count += 1)

	# First interact: intro shows, the real action is deferred.
	anchor.interact(null)
	await process_frame
	_check(shell.intro_panel.visible, "first interact on a fresh anchor must show the intro panel")
	_check(_fire_count == 0, "the underlying action must not fire until the intro is dismissed")

	# Dismiss: the deferred action fires now, and the panel closes.
	shell._on_intro_continue()
	await process_frame
	_check(not shell.intro_panel.visible, "dismissing the intro must hide the panel")
	_check(_fire_count == 1, "dismissing the intro must fire the deferred action exactly once")

	# Second interact on the same anchor: no intro, fires immediately.
	anchor.interact(null)
	await process_frame
	_check(not shell.intro_panel.visible, "a previously-introduced anchor must not show the intro again")
	_check(_fire_count == 2, "a previously-introduced anchor must fire immediately")

	# introduce_anchor() itself: true exactly once per id, independent of the panel.
	_check(root.get_node("UserExperienceService").introduce_anchor(&"__test_only_anchor__"), "introduce_anchor must return true the first time")
	_check(not root.get_node("UserExperienceService").introduce_anchor(&"__test_only_anchor__"), "introduce_anchor must return false on repeat calls for the same id")

	world.queue_free()
	await process_frame
	if _failure.is_empty():
		print("ANCHOR_INTRO_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
