extends SceneTree

const CLEARING := preload("res://scenes/world/village_clearing.tscn")
const EXPEDITION_CAP_SECONDS := 60.0 * 60.0 * 24.0

var _failure := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("feature/reboot_mode", true)
	root.get_node("ResidentManager").new_game()
	root.get_node("ExpeditionService").new_game()
	root.get_node("GrowthPlotService").new_game()
	var world := CLEARING.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var resident_manager := root.get_node("ResidentManager")
	var expedition := root.get_node("ExpeditionService")

	_check_departure_and_availability(resident_manager, expedition)
	_check_project_contribution_exclusion(resident_manager)
	_check_cap_resolution(expedition)
	_check_unlock_feed(expedition)
	_check_visit_teleport(expedition)
	await _check_restore_ordering(resident_manager, expedition)

	world.queue_free()
	await process_frame
	if _failure.is_empty():
		print("MILESTONE_14_RESIDENT_EXPLORATION_SMOKE_TEST_PASS")
		quit(0)
	else:
		push_error(_failure)
		quit(1)

func _check_departure_and_availability(resident_manager: Node, expedition: Node) -> void:
	var pip = resident_manager.get_agent(&"resident_pip")
	_check(pip != null, "resident_pip should exist in the spawned roster")
	_check(not bool(pip.is_away()), "Pip should not be away before departing")

	var available_ids_before := _resident_ids(expedition.available_residents())
	_check(&"resident_pip" in available_ids_before, "Pip should be available before departing")

	_check(bool(expedition.depart(&"resident_pip")), "depart() should succeed for an available resident")
	_check(bool(pip.is_away()), "Pip should be away immediately after departing")
	_check(not bool(expedition.depart(&"resident_pip")), "a second depart() for the same resident should be refused")

	var available_ids_after := _resident_ids(expedition.available_residents())
	_check(not (&"resident_pip" in available_ids_after), "Pip should be excluded from available_residents() while away")
	_check(&"resident_pip" in expedition.away_residents(), "Pip should be listed in away_residents()")

func _resident_ids(agents: Array) -> Array:
	var ids: Array = []
	for agent in agents: ids.append(agent.resident_id)
	return ids

## consider_project_contributions() is existing Milestone-10 functionality;
## fully exercising its scoring (an active project, ready materials, a
## specialty match) is out of scope here. What Milestone 14 actually owns is
## the one-line "if agent.is_away(): continue" guard -- verify the invariant
## it establishes (Pip, marked away above, must never be selected) holds
## regardless of whether a project happens to be active in this fixture.
func _check_project_contribution_exclusion(resident_manager: Node) -> void:
	resident_manager.consider_project_contributions()
	var session: Dictionary = resident_manager._project_session
	if not session.is_empty():
		_check(str(session.get("resident_id", "")) != "resident_pip", "an away resident must never be selected for a project contribution")

func _check_cap_resolution(expedition: Node) -> void:
	_check(bool(expedition.depart(&"resident_elowen")), "depart() should succeed for Elowen")
	var entry: Dictionary = expedition._expeditions[&"resident_elowen"]
	var timer: AwayTimer = entry.timer
	timer.started_at = Time.get_unix_time_from_system() - (EXPEDITION_CAP_SECONDS * 2.0)
	expedition.check_expeditions()
	var plot: TileFogPlot = entry.plot
	_check(plot.revealed_fraction() >= 1.0, "past the cap, the exploration area should be fully revealed: got %f" % plot.revealed_fraction())

func _check_unlock_feed(expedition: Node) -> void:
	var growth := root.get_node("GrowthPlotService")
	_check(not ("expansion_undersea:kelp_bed" in growth.unlocked_tile_ids), "sanity: kelp_bed should not be pre-unlocked")
	var entry: Dictionary = expedition._expeditions[&"resident_elowen"]
	var plot: TileFogPlot = entry.plot
	plot.set_tile_id(Vector2i(0, 0), "expansion_undersea:kelp_bed")
	expedition._feed_discoveries(plot)
	_check("expansion_undersea:kelp_bed" in growth.unlocked_tile_ids, "a non-starter tile placed in an exploration area should feed GrowthPlotService's unlocked vocabulary")

## Visiting/leaving an exploration area is a teleport, not a walk (there's
## no ground between the clearing and the exploration stage) -- confirm both
## legs actually move the founder, and that leaving returns to where the
## founder was standing before visiting rather than some fixed point.
func _check_visit_teleport(expedition: Node) -> void:
	var founder := get_first_node_in_group("player_cat")
	_check(founder != null, "the reboot founder cat should exist for the teleport check")
	if founder == null:
		return
	var pre_visit_position: Vector3 = founder.global_position
	expedition.visit_area(&"resident_elowen")
	var after_visit_position: Vector3 = founder.global_position
	_check(after_visit_position.distance_to(pre_visit_position) > 5.0, "visiting an exploration area should teleport the founder there, not leave them where they were: moved %f" % after_visit_position.distance_to(pre_visit_position))
	_check(after_visit_position.y > -5.0, "the teleported-to position should be on solid ground, not falling")

	expedition.leave_visited_area()
	var after_leave_position: Vector3 = founder.global_position
	_check(after_leave_position.distance_to(pre_visit_position) < 0.5, "leaving should return the founder to exactly where they visited from: got %s, expected %s" % [after_leave_position, pre_visit_position])

func _check_restore_ordering(resident_manager: Node, expedition: Node) -> void:
	var mara_before = resident_manager.get_agent(&"resident_mara")
	_check(mara_before != null, "resident_mara should exist before the restore-ordering check")
	_check(bool(expedition.depart(&"resident_mara")), "Mara should be able to depart for the restore-ordering check")

	var save_path := "user://milestone14_expedition_test.json"
	var save_service := root.get_node("SaveService")
	_check(bool(save_service.save_game(save_path)), "save should succeed with active expeditions in flight")
	_check(bool(save_service.load_game(save_path)), "load should succeed")
	await process_frame

	var mara_after = resident_manager.get_agent(&"resident_mara")
	_check(mara_after != null, "resident_mara should exist after reload")
	_check(mara_after != mara_before, "reload should respawn a genuinely fresh agent instance, not reuse the old one")
	_check(mara_after != null and bool(mara_after.is_away()), "the freshly-respawned Mara must still report is_away() == true -- this is exactly what breaks if ExpeditionService.restore_state() ran before ResidentManager.restore_state()")
	_check(&"resident_mara" in expedition.away_residents(), "Mara should still be tracked as away in ExpeditionService after reload")

	_cleanup(save_path)

func _cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var absolute := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)

func _check(condition: bool, message: String) -> void:
	if not condition and _failure.is_empty(): _failure = message
