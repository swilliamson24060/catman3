extends SceneTree
## Regression guard for the welcome dialog shown immediately after choosing a
## founder: it must actually appear (not just the badge/toast), must show up
## after the tree is unpaused (RebootUIShell's own panels aren't process_mode
## ALWAYS like the founder-select modal, so their buttons wouldn't respond
## while get_tree().paused is still true), and its claim that the Almanac
## badge is lit must actually be true at the moment it's shown.

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const FOUNDER_SELECT_UI := preload("res://founder/founder_select_ui.tscn")

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var shell := world.get_tree().get_first_node_in_group("reboot_ui_shell")
	_check(shell != null, "RebootUIShell must be present")
	if shell == null:
		world.queue_free()
		await process_frame
		push_error(_failure)
		quit(1)
		return

	# Headless boot skips the modal (see milestone15_founder_selection_smoke_test.gd's
	# _check_headless_boot_skips_modal) -- mimic the real, non-headless flow by
	# attaching FounderSelectUI to the already-booted world directly.
	var select_ui := FOUNDER_SELECT_UI.instantiate()
	root.add_child(select_ui)
	await process_frame

	select_ui._on_founder_selected("barnaby")
	await process_frame

	_check(not paused, "the welcome dialog must appear after unpausing, not while the tree is still paused")
	_check(shell.almanac_unread_badge.visible, "the dialog claims the badge is lit -- that must actually be true at this moment")
	_check(shell.intro_panel.visible, "a welcome dialog must actually appear, not just the badge/toast")
	var body: String = shell.intro_body_label.text
	_check(body.begins_with("Welcome to the village!"), "must open with the requested welcome line: got '%s'" % body)
	_check(body.contains("3 residents"), "must state the actual resident count, not a stale hardcoded one: got '%s'" % body)
	_check(body.to_lower().contains("community board"), "must mention the community board: got '%s'" % body)
	_check(body.to_lower().contains("red exclamation point"), "must point the player at the almanac badge by name: got '%s'" % body)

	# Closing it works the same as any other dialog -- no special-cased button needed.
	shell._on_intro_continue()
	await process_frame
	_check(not shell.intro_panel.visible, "closing the welcome dialog must actually close it")

	world.queue_free()
	await process_frame
	if _failure.is_empty():
		print("WELCOME_DIALOG_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
