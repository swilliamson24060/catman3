extends SceneTree
## Regression guard for the Almanac's unread badge and note archiving:
## 1) A red "!" badge on the top bar's Almanac button appears the moment
##    something new is scheduled and clears once the player actually opens
##    the Almanac -- see AlmanacNotificationService.has_unread()/acknowledge_unread().
## 2) The first Almanac entry (an explanation of the top bar) can be archived
##    without disappearing -- it just moves to Archived Notes.
## Founder selection triggering this immediately (rather than the usual
## multi-period delay) is covered separately in milestone15_founder_selection_smoke_test.gd.

const CLEARING := preload("res://scenes/world/village_clearing.tscn")

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	# Boot may have loaded a stray save -- reset after boot, not before.
	root.get_node("AlmanacNotificationService").reset()
	await process_frame

	var shell := world.get_tree().get_first_node_in_group("reboot_ui_shell")
	var resident_hud := world.get_tree().get_first_node_in_group("resident_hud")
	_check(shell != null, "RebootUIShell must be present")
	_check(resident_hud != null, "ResidentHUD must be present")
	if shell == null or resident_hud == null:
		world.queue_free()
		await process_frame
		push_error(_failure if not _failure.is_empty() else "missing a required node")
		quit(1)
		return

	_check(not shell.almanac_unread_badge.visible, "the badge must start hidden with nothing pending")

	# Scheduling with a 0 delay (the founder-selection case) fires immediately.
	root.get_node("AlmanacNotificationService").schedule(&"note_top_bar", 0)
	await process_frame
	_check(shell.almanac_unread_badge.visible, "the badge must appear the moment something new is ready, without waiting for a period change")

	# Opening the Almanac clears the badge and shows the note as the first, active entry.
	shell.open_screen("Village Almanac")
	await process_frame
	_check(not shell.almanac_unread_badge.visible, "opening the Almanac must clear the unread badge")
	var document: String = resident_hud.almanac_document()
	_check(document.begins_with("[b]Notes[/b]"), "the top-bar note must be the very first thing in the Almanac: got '%s'" % document.substr(0, 60))
	_check(document.contains("Reading the Top Bar"), "the note's actual content must appear, not just an empty section: got '%s'" % document.substr(0, 200))
	_check(shell.archive_note_button.visible, "an active note must offer a way to archive it")
	shell.close_all()
	await process_frame

	# Archiving moves it to Archived Notes -- present, not deleted -- and the
	# button disappears once there's nothing left to archive.
	shell.open_screen("Village Almanac")
	await process_frame
	shell._on_archive_note_pressed()
	await process_frame
	_check(not shell.archive_note_button.visible, "archiving the only active note must hide the button, not leave it dangling")
	var archived_document: String = resident_hud.almanac_document()
	var notes_section := archived_document.split("[b]Archived Notes[/b]")
	_check(notes_section.size() == 2 and notes_section[0].contains("Nothing new right now."), "the note must leave the active Notes section once archived: got '%s'" % archived_document.substr(0, 120))
	_check(notes_section.size() == 2 and notes_section[1].contains("Reading the Top Bar"), "but must still be readable under Archived Notes, not deleted: got '%s'" % archived_document)
	_check(root.get_node("AlmanacNotificationService").is_note_archived(&"note_top_bar"), "the service itself must record the note as archived")
	shell.close_all()
	await process_frame

	world.queue_free()
	await process_frame
	if _failure.is_empty():
		print("ALMANAC_UI_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
