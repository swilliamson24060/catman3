extends SceneTree
## Regression guard for AlmanacNotificationService's core promise: a resolved
## discovery's "something new in the Almanac" notification is deliberately
## delayed (default DEFAULT_DELAY_PERIODS period changes -- this real-time
## project's closest thing to a discrete "turn"), and that delay is trivially
## overridable per call so a specific kind of resolution can be paced
## differently without ever touching this service.

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	# Boot may have loaded a stray save -- reset after boot, not before.
	root.get_node("ResidentManager").new_game()
	var service := root.get_node("AlmanacNotificationService")
	var calendar := root.get_node("CalendarService")
	service.reset()

	var shell := world.get_tree().get_first_node_in_group("reboot_ui_shell")
	_check(shell != null, "RebootUIShell must be present")
	if shell == null:
		world.queue_free()
		await process_frame
		push_error(_failure)
		quit(1)
		return
	shell.event_toast.visible = false
	shell._event_toast_queue.clear()

	# Default delay: not one period change early, fires exactly on schedule.
	# Not a real discovery_id -- schedule() is deliberately decoupled from
	# DiscoveryService, so any StringName works here.
	service.schedule(&"test_default_discovery")
	for _i in range(service.DEFAULT_DELAY_PERIODS - 1):
		calendar.debug_jump_to_period(&"afternoon")
	await process_frame
	_check(not shell.event_toast.visible, "the notification must not fire before its delay elapses")
	calendar.debug_jump_to_period(&"evening")
	await process_frame
	_check(shell.event_toast.visible and shell.event_toast.text.to_lower().contains("almanac"), "the notification must fire once the default delay elapses")
	shell.event_toast.visible = false
	shell._event_toast_queue.clear()

	# A custom, per-call delay: tunable independently of the default without
	# touching this service -- the exact "easy to customize" requirement.
	service.schedule(&"test_fast_discovery", 1)
	calendar.debug_jump_to_period(&"night")
	await process_frame
	_check(shell.event_toast.visible, "a custom shorter delay must fire on its own schedule, independent of the default")
	shell.event_toast.visible = false
	shell._event_toast_queue.clear()

	# A delay of 0 (the founder-selection use case) fires immediately -- no
	# period change needed at all, unlike delay 1 above which still needs one.
	service.reset()
	_check(not service.has_unread(), "reset() must clear the unread flag along with pending entries")
	service.schedule(&"test_immediate", 0)
	await process_frame
	_check(shell.event_toast.visible, "a 0 delay must fire the very next frame, not wait for any period change")
	_check(service.has_unread(), "firing must raise the unread flag")
	service.acknowledge_unread()
	_check(not service.has_unread(), "acknowledge_unread() must clear it, the same action opening the Almanac performs")
	shell.event_toast.visible = false
	shell._event_toast_queue.clear()

	# Multiple pending entries count down independently, not off one shared clock.
	service.reset()
	service.schedule(&"test_a", 2)
	service.schedule(&"test_b", 4)
	calendar.debug_jump_to_period(&"morning")
	calendar.debug_jump_to_period(&"afternoon")
	await process_frame
	var state_after_two: Dictionary = service.serialize_state()
	_check(not state_after_two.has("test_a"), "an entry must fire and clear itself once its own delay elapses")
	_check(int(state_after_two.get("test_b", -1)) == 2, "a later entry must keep counting down on its own schedule, unaffected by an earlier one firing")

	# Save/restore round-trips the pending queue exactly. (serialize_state()
	# always carries "_archived_notes"/"_unread" too -- see the service's own
	# comment on why those are reserved keys rather than a nested wrapper --
	# so "cleared" means "no pending id left," not an empty dict.)
	service.reset()
	service.schedule(&"test_persist", 3)
	var saved: Dictionary = service.serialize_state()
	service.reset()
	_check(not service.serialize_state().has("test_persist"), "reset() must actually clear pending entries")
	service.restore_state(saved)
	_check(int(service.serialize_state().get("test_persist", -1)) == 3, "restore_state() must bring back exactly what was saved")

	# Archiving a note persists too.
	service.archive_note(&"note_top_bar")
	var saved_with_archive: Dictionary = service.serialize_state()
	service.reset()
	_check(not service.is_note_archived(&"note_top_bar"), "reset() must actually clear archived-note state")
	service.restore_state(saved_with_archive)
	_check(service.is_note_archived(&"note_top_bar"), "restore_state() must bring back which notes were archived")

	world.queue_free()
	await process_frame
	if _failure.is_empty():
		print("ALMANAC_NOTIFICATION_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
