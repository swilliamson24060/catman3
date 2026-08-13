extends SceneTree
## Regression guard for the resume-or-new-game boot choice
## (founder/boot_resume_ui.gd): a save existing at boot must no longer
## silently auto-load in the non-headless case -- the player gets an
## explicit choice to resume or start fresh instead. Headless keeps the old
## silent-auto-load behavior (covered by milestone15_founder_selection_smoke_test.gd's
## _check_autoload_path_applies_appearance), so this test drives
## BootResumeUI directly, the same technique welcome_dialog_smoke_test.gd
## uses for FounderSelectUI.

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const BOOT_RESUME_UI := preload("res://founder/boot_resume_ui.tscn")
const FOUNDER_SELECT_UI := preload("res://founder/founder_select_ui.tscn")

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var save_service := root.get_node("SaveService")
	save_service.new_game("turbo")
	var registry := root.get_node("DataRegistry")
	registry.apply_global_bonuses(registry.get_founder_cat("turbo").get("modifiers", []), "founder")
	_check(save_service.save_game(), "seeding a save for the resume-choice check should succeed")

	await _check_peek_reads_founder_without_side_effects()
	await _check_resume_path()
	await _check_start_new_path()

	_cleanup_default_save()
	if _failure.is_empty():
		print("BOOT_RESUME_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check_peek_reads_founder_without_side_effects() -> void:
	var save_service := root.get_node("SaveService")
	var stats := root.get_node("StatsService")
	stats.reset()
	_check(str(save_service.peek_founder_cat_id()) == "turbo", "peek_founder_cat_id must read the saved founder id")
	_check(stats.get_effective("resident_interest", "specialty:building", 0.0) == 0.0, "peeking must not re-apply the founder's modifiers the way a full load_game() would")

func _check_resume_path() -> void:
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var resume_ui := BOOT_RESUME_UI.instantiate() as BootResumeUI
	root.add_child(resume_ui)
	await process_frame
	_check(paused, "BootResumeUI should pause the tree itself when shown directly")
	_check(resume_ui.subtitle_label.text.contains("Turbo"), "the subtitle should name the saved founder: got '%s'" % resume_ui.subtitle_label.text)
	_check(resume_ui.resume_button.text.contains("Turbo"), "the resume button should name the saved founder: got '%s'" % resume_ui.resume_button.text)

	resume_ui._on_resume()
	await process_frame
	_check(not paused, "resuming must unpause the tree")
	var player := get_first_node_in_group("player_cat")
	if player != null:
		# Not a get_node_or_null("CatModel") name check: this world already
		# auto-loaded its own model once (headless + a save on disk both
		# being true here, same as any other headless test), and this call
		# re-applies on top of that -- the still-queue_free()-pending first
		# model means the second gets auto-uniquified to "CatModel2" by the
		# time this runs, which is a test-harness double-application
		# artifact, not something the real (mutually exclusive) boot paths
		# ever do. AnimationPlayer discoverability is the actual contract.
		_check(CatAppearance.find_animation_player(player) != null, "resuming must apply the restored founder's model")

	world.queue_free()
	await process_frame

func _check_start_new_path() -> void:
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var resume_ui := BOOT_RESUME_UI.instantiate() as BootResumeUI
	world.add_child(resume_ui)
	await process_frame

	resume_ui._on_start_new()
	await process_frame
	_check(world.find_child("FounderSelectUI", true, false) != null, "starting new must open the founder-select modal")
	_check(paused, "the founder-select modal must keep the tree paused until a founder is actually chosen")

	world.queue_free()
	await process_frame

func _cleanup_default_save() -> void:
	var save_service := root.get_node_or_null("SaveService")
	if save_service == null:
		return
	for suffix in ["", ".bak", ".tmp"]:
		var absolute := ProjectSettings.globalize_path(save_service.SAVE_PATH + suffix)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
