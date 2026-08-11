extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const FOUNDER_SELECT_UI := preload("res://founder/founder_select_ui.tscn")

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("feature/reboot_mode", true)
	_cleanup_default_save()
	root.get_node("StatsService").reset()

	_check_headless_boot_skips_modal()
	await _check_founder_select_standalone()
	await _check_autoload_path_applies_appearance()

	_cleanup_default_save()
	if _failure.is_empty():
		print("MILESTONE_15_FOUNDER_SELECTION_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

## Regression guard for the bug this milestone introduced and fixed: headless
## + no save must NOT show the modal or pause the tree, since every existing
## smoke test instantiates this scene under exactly that condition and
## several of them depend on unpaused timers/processing right afterward.
func _check_headless_boot_skips_modal() -> void:
	var world := CLEARING.instantiate()
	root.add_child(world)
	_check(root.find_child("FounderSelectUI", true, false) == null, "headless boot with no save must not show the founder-select modal")
	_check(not paused, "headless boot with no save must not leave the tree paused")
	world.queue_free()

## FounderSelectUI is data-driven and independently testable regardless of
## when/whether village_clearing.gd's boot gate decides to show it.
func _check_founder_select_standalone() -> void:
	await process_frame   # let the previous check's queue_free() actually clear
	var select_ui := FOUNDER_SELECT_UI.instantiate()
	root.add_child(select_ui)
	_check(paused, "FounderSelectUI should pause the tree itself when shown directly")

	var cards_row: HBoxContainer = select_ui.get_node("Control/Panel/Margin/VBox/CardsRow")
	_check(cards_row.get_child_count() == 3, "one card per non-bonus founder (Barnaby/Whisper/Turbo) should be built: got %d" % cards_row.get_child_count())

	# Regression guard: cards must not describe the legacy mice-recruitment
	# game's pros/cons in reboot mode -- only the reboot_relevant modifier
	# (resident interest) should be visible.
	var barnaby_card: FounderCard = cards_row.get_child(0)
	var modifiers_text: String = barnaby_card.get_node("Margin/VBox/ModifiersLabel").text
	_check(not modifiers_text.contains("mice") and not modifiers_text.contains("construction"), "founder cards must not show legacy mice/construction modifiers in reboot mode: got '%s'" % modifiers_text)
	_check(modifiers_text.contains("gardening"), "Barnaby's card should describe his reboot-relevant gardening interest bonus: got '%s'" % modifiers_text)

	select_ui._on_founder_selected("barnaby")
	await process_frame

	var save_service := root.get_node("SaveService")
	var stats := root.get_node("StatsService")
	_check(not paused, "selecting a founder should unpause the tree")
	_check(str(save_service.current.founder_cat_id) == "barnaby", "SaveData should record the chosen founder")
	_check(stats.get_effective("resident_interest", "specialty:gardening", 0.0) > 0.0, "Barnaby's resident_interest modifier should be live in StatsService immediately after selection")

	# The player's very first Almanac entry (explaining the top bar) must be
	# waiting immediately, not after the usual multi-period pacing -- there's
	# nothing to wait on before the village even exists yet.
	var notifications := root.get_node("AlmanacNotificationService")
	_check(notifications.has_unread(), "choosing a founder must immediately flag the Almanac as having something new, not wait out the default delay")
	_check(not notifications.is_note_archived(&"note_top_bar"), "the top-bar note must start active, not pre-archived")

	# player_cat group membership and coat application are checked in
	# _check_autoload_path_applies_appearance() below, where an actual
	# reboot founder cat exists (no clearing is instantiated in this
	# standalone-modal check, so there's nothing to find here).

	# --- persistence: the modifier must survive a reload, not just the session ---
	var save_path := "user://milestone15_founder_test.json"
	_check(save_service.save_game(save_path), "save should succeed after founder selection")
	stats.reset()
	_check(stats.get_effective("resident_interest", "specialty:gardening", 0.0) == 0.0, "sanity: reset() should actually clear the modifier before reload")
	_check(save_service.load_game(save_path), "load should succeed")
	_check(stats.get_effective("resident_interest", "specialty:gardening", 0.0) > 0.0, "reloading a save must re-apply the founder's modifier, not just the original selection")

	# --- the modifier should measurably affect scoring, not just exist inertly ---
	var mara: ResidentAgent = root.get_node("ResidentManager").get_agent(&"resident_mara")
	if mara != null:
		var gardening_candidate := {"id": "test_gardening_activity", "specialty": "gardening", "position": [0.0, 0.2, 0.0]}
		var with_modifier: float = mara.score_activity(gardening_candidate).score
		stats.reset()
		var without_modifier: float = mara.score_activity(gardening_candidate).score
		_check(with_modifier > without_modifier, "Barnaby's modifier should measurably raise gardening-candidate scores: with=%f without=%f" % [with_modifier, without_modifier])

	_cleanup(save_path)

## village_clearing.gd's other branch: a save already exists at boot -> load
## it automatically (no modal at all) and apply the restored founder's coat.
func _check_autoload_path_applies_appearance() -> void:
	var save_service := root.get_node("SaveService")
	save_service.new_game("turbo")
	var registry := root.get_node("DataRegistry")
	registry.apply_global_bonuses(registry.get_founder_cat("turbo").get("modifiers", []), "founder")
	_check(save_service.save_game(), "seeding a default-path save for the autoload-path check should succeed")

	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	_check(root.find_child("FounderSelectUI", true, false) == null, "a pre-existing save must auto-load, not show the modal")
	_check(str(save_service.current.founder_cat_id) == "turbo", "the restored founder id should come from the loaded save")

	var player := get_first_node_in_group("player_cat")
	_check(player != null, "the reboot founder cat should be registered in the player_cat group (group-membership fix)")
	if player != null:
		var visual_root := player.get_node_or_null("VisualRoot")
		_check(visual_root != null and visual_root.get_node_or_null("CatModel") != null, "the auto-load path must actually populate VisualRoot with Turbo's model, not leave it empty")
		var anim_player := CatAppearance.find_animation_player(player)
		_check(anim_player != null, "the applied model's AnimationPlayer must be discoverable via CatAppearance.find_animation_player")
		if anim_player != null:
			for clip in ["idle", "walk", "run"]:
				_check(anim_player.has_animation(clip), "the merged AnimationLibrary must expose a clean '%s' clip, not Meshy's raw clip name" % clip)

	world.queue_free()
	await process_frame

func _cleanup_default_save() -> void:
	_cleanup(root.get_node("SaveService").SAVE_PATH if root.has_node("SaveService") else "user://catmando_save.json")

func _cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var absolute := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
